# # Executable [Cells](# "Executable Cells")
#
# This file defines a custom CommonMark node type that provides executable code
# cells.

"""
A CommonMark rule used to define the "cell" parser. A `CellRule` holds a
`.cache` of the `Module`s that have been defined in a markdown document to that
cells can depend on definitions and values from previous cells.
"""
struct CellRule
    cache::Dict{String,Module}
    CellRule(cache=Dict()) = new(cache)
end

"""
    struct Cell

A custom node type for CommonMark.jl that holds an executable "cell" of code.
"""
mutable struct Cell <: CommonMark.AbstractBlock
    rule::CellRule
    node::CommonMark.Node
end

# The `block_modifier` definition hooks into the markdown parser to allow for
# modifying each Julia code block that has a [cell attribute](# "Attributes")
# attached.

CommonMark.block_modifier(c::CellRule) = CommonMark.Rule(100) do parser, node
    if isjuliacode(node) && iscell(node.meta)
        CommonMark.insert_after(node, CommonMark.Node(Cell(c, node)))
    end
    return nothing
end

isjuliacode(n::CommonMark.Node) = n.t isa CommonMark.CodeBlock && n.t.info == "julia"
iscell(d::AbstractDict) = haskey(d, "cell") || get(d, "element", "") == "cell"

# ## Cell Evaluator

"""
    moduleof(cell)

Returns the cached `Module` associated with a [`Cell`](#). Creates a new one if
there is not associated with the cell.
"""
moduleof(c::Cell) = moduleof(c, get(c.node.meta, "cell", nothing))
moduleof(c::Cell, id::AbstractString) = get!(()->Module(), c.rule.cache, id)
moduleof(::Cell, ::Nothing) = Module()

"""
    display_as(default, cell, writer, [mimes...])

Given a `cell` this function evaluates it and prints the output to `writer`
using the first available `MIME` from `mimes`. Uses the `default` printer
function to print any code blocks that are required in the output.
"""
function display_as(default, cell, w, mimes...)
    ## Display options for cell:
    show_output = get(cell.node.meta, "output", "true")
    show_result = get(cell.node.meta, "result", "true")
    ## Evaluate the cell contents in a sandboxed module, possibly reusing one
    ## from an earlier cell if the names match.
    mod = moduleof(cell)
    result, success, bt, output = capture_output() do
        include_string(mod, cell.node.literal)
    end
    if !isempty(output) && show_output == "true"
        ## There's been some output to the stream, put that in
        ## a verbatim block before the real output so long as
        ## `output=false` was not set for the cell.
        out = CommonMark.Node(CommonMark.CodeBlock())
        out.meta["class"] = ["plaintext", "cell-output", "cell-stream"]
        out.literal = output
        default(out.t, w, out, true)
    end
    show_result == "true" || return nothing # Display result unless `result=false` was set.
    result === nothing && return nothing # Skip `nothing` results.
    for mime in mimes
        if showable(mime, result)
            ## We've found a suitable mimetype, display as that.
            limitedshow(w.buffer, mime, result)
            return nothing
        end
    end
    ## Default output displays the result as in the REPL.
    code = CommonMark.Node(CommonMark.CodeBlock())
    code.t.info = "plaintext"
    code.meta["class"] = ["plaintext", "cell-output", "cell-result"]
    code.literal = limitedshow(MIME("text/plain"), result)
    default(code.t, w, code, true)
    return nothing
end

"""
    limitedshow([io], mime, result)

Prints out a "limited" representation of `result` in the given `mime` to the
provided `io` stream, or returns a `String` of the output when no `io` is
given.
"""
function limitedshow end

limitedshow(io::IO, m, r) = Base.invokelatest(show, IOContext(io, :limit=>true), m, r)
limitedshow(m, r) = sprint(limitedshow, m, r)

# ## Capturing Cell Output
#
# The following function is taken from Documenter's source, MIT licensed.
function capture_output(f)
    ## Save the default output streams.
    default_stdout = stdout
    default_stderr = stderr

    ## Redirect both the `stdout` and `stderr` streams to a single `Pipe` object.
    pipe = Pipe()
    Base.link_pipe!(pipe; reader_supports_async = true, writer_supports_async = true)
    redirect_stdout(pipe.in)
    redirect_stderr(pipe.in)
    ## Also redirect logging stream to the same pipe
    logger = ConsoleLogger(pipe.in)

    ## Bytes written to the `pipe` are captured in `output` and converted to a `String`.
    output = UInt8[]

    ## Run the function `f`, capturing all output that it might have generated.
    ## Success signals whether the function `f` did or did not throw an exception.
    result, success, backtrace = with_logger(logger) do
        try
            f(), true, Vector{Ptr{Cvoid}}()
        catch err
            ## InterruptException should never happen during normal doc-testing
            ## and not being able to abort the doc-build is annoying (#687).
            isa(err, InterruptException) && rethrow(err)

            err, false, catch_backtrace()
        finally
            ## Force at least a single write to `pipe`, otherwise `readavailable` blocks.
            println()
            ## Restore the original output streams.
            redirect_stdout(default_stdout)
            redirect_stderr(default_stderr)
            ## NOTE: `close` must always be called *after* `readavailable`.
            append!(output, readavailable(pipe))
            close(pipe)
        end
    end
    return result, success, backtrace, chomp(String(output))
end

# ## CommonMark Writers
#
# These definitions are needed by CommonMark to hook into it's display system.

function CommonMark.write_html(cell::Cell, w, n, ent)
    ent && display_as(CommonMark.write_html, cell, w, MIME("text/html"))
    return nothing
end

function CommonMark.write_latex(cell::Cell, w, n, ent)
    ent && display_as(CommonMark.write_latex, cell, w, MIME("text/latex"))
    return nothing
end

# The following two definitions aren't really needed since Publish doesn't support
# output to terminal or markdown, but are defined to ensure the display system is
# complete for the [`Cell`](#) node type.

function CommonMark.write_term(cell::Cell, w, n, ent)
    if ent
        display_as(CommonMark.write_term, cell, w)
        ## Make sure to add a linebreak afterwards if needed.
        if !CommonMark.isnull(n.nxt)
            CommonMark.print_margin(w)
            CommonMark.print_literal(w, "\n")
        end
    end
    return nothing
end

## Markdown roundtrips, so shouldn't display cells.
CommonMark.write_markdown(cell::Cell, w, n, ent) = nothing
