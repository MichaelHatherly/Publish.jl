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
    moduleof(env, cell)

Returns the cached `Module` associated with a [`Cell`](#). Creates a new one if
there is not associated with the cell. `env` is the environment used by the
current writer, used here to import default modules into cells.
"""
moduleof(env, c::Cell) = moduleof(env, c, get(c.node.meta, "cell", nothing))
moduleof(env, c::Cell, id::AbstractString) = get!(()->cell_module(env), c.rule.cache, id)
moduleof(env, ::Cell, ::Nothing) = cell_module(env)

function cell_module(env)
    outmod = Module()
    for each in get(() -> Module[], env, "cell-imports")
        name = gensym()
        Core.eval(outmod, :($name=$each; using .$name))
    end
    return outmod
end

"""
    display_as(default, cell, writer, [mimes...])

Given a `cell` this function evaluates it and prints the output to `writer`
using the first available `MIME` from `mimes`. Uses the `default` printer
function to print any code blocks that are required in the output.
"""
function display_as(default, cell, w, mimes)
    ## Display options for cell:
    show_output = get(cell.node.meta, "output", "true")
    show_result = get(cell.node.meta, "result", "true")
    ## Evaluate the cell contents in a sandboxed module, possibly reusing one
    ## from an earlier cell if the names match.
    mod = moduleof(w.env, cell)
    c = IOCapture.iocapture(throwerrors=false) do
        include_string(mod, cell.node.literal)
    end
    if !isempty(c.output) && show_output == "true"
        ## There's been some output to the stream, put that in
        ## a verbatim block before the real output so long as
        ## `output=false` was not set for the cell.
        out = CommonMark.Node(CommonMark.CodeBlock())
        out.meta["class"] = ["plaintext", "cell-output", "cell-stream"]
        out.literal = c.output
        default(out.t, w, out, true)
    end
    show_result == "true" || return nothing # Display result unless `result=false` was set.
    c.value === nothing && return nothing # Skip `nothing` results.
    for mime in mimes
        if showable(mime, c.value)
            ## We've found a suitable mimetype, display as that.
            limitedshow(w.buffer, default, mime, c.value)
            return nothing
        end
    end
    ## Default output displays the result as in the REPL.
    code = CommonMark.Node(CommonMark.CodeBlock())
    code.t.info = "plaintext"
    code.meta["class"] = ["plaintext", "cell-output", "cell-result"]
    code.literal = limitedshow(default, MIME("text/plain"), c.value)
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

limitedshow(io::IO, default, m, r) = Base.invokelatest(show, IOContext(io, :limit=>true), m, r)
limitedshow(default, m, r) = sprint(limitedshow, default, m, r)

# ## Supported image MIMES.

const SUPPORTED_MIMES = Dict{Symbol,Vector{MIME}}(
    :html  => map(MIME, [
        "image/svg+xml", # TODO: optimal ordering.
        "image/png",
        "image/jpeg",
        "image/gif",
        "text/html",
    ]),
    :latex => map(MIME, [
        "text/tikz", # TODO: optimal ordering.
        "image/png",
        "application/pdf",
        "text/latex",
    ]),
    :term  => MIME[],
)

const IMAGE_MIMES = Union{
    MIME"application/pdf",
    MIME"image/gif",
    MIME"image/jpeg",
    MIME"image/png",
    MIME"image/svg+xml",
    MIME"text/tikz",
}

function limitedshow(io::IO, fn, mime::IMAGE_MIMES, result)
    ext(::MIME"application/pdf") = ".pdf"
    ext(::MIME"image/gif") = ".gif"
    ext(::MIME"image/jpeg") = ".jpeg"
    ext(::MIME"image/png") = ".png"
    ext(::MIME"image/svg+xml") = ".svg"
    ext(::MIME"text/tikz") = ".tikz"
    name = string(hash(result), ext(mime))
    open(name, "w") do handle
        Base.invokelatest(show, handle, mime, result)
    end
    node = CommonMark.Node(CommonMark.Image())
    node.t.destination = name
    return cm_wrapper(fn)(io, node)
end

# ## CommonMark Writers
#
# These definitions are needed by CommonMark to hook into it's display system.

function CommonMark.write_html(cell::Cell, w, n, ent)
    ent && display_as(CommonMark.write_html, cell, w, SUPPORTED_MIMES[:html])
    return nothing
end
cm_wrapper(::typeof(CommonMark.write_html)) = CommonMark.html # The wrapper function for write_html

function CommonMark.write_latex(cell::Cell, w, n, ent)
    ent && display_as(CommonMark.write_latex, cell, w, SUPPORTED_MIMES[:latex])
    return nothing
end
cm_wrapper(::typeof(CommonMark.write_latex)) = CommonMark.latex # The wrapper function for write_latex

# The following two definitions aren't really needed since Publish doesn't support
# output to terminal or markdown, but are defined to ensure the display system is
# complete for the [`Cell`](#) node type.

function CommonMark.write_term(cell::Cell, w, n, ent)
    if ent
        display_as(CommonMark.write_term, cell, w, SUPPORTED_MIMES[:term])
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
