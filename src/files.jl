# # Files and Related Functionality
#
# {#mime-type-defs}
# Below we have defined the `MIME` types (and extensions) that [`Publish`](#)
# supports. It will ignore anything not on this list.
const MIMETYPES = Dict(
    ".ipynb"    => MIME("application/ipynb+json"),
    ".jl"       => MIME("text/julia"),
    ".md"       => MIME("text/markdown"),
    ".toml"     => MIME("application/toml"),
    ".js"       => MIME("text/javascript"),
    ".css"      => MIME("text/css"),
    ".html"     => MIME("text/html"),
    ".tex"      => MIME("text/tex"),
    ".mustache" => MIME("text/mustache"),
    ".png"      => MIME("image/png"),
    ".svg"      => MIME("image/svg"),
    ".jpg"      => MIME("image/jpeg"),
)
# We also want an inverse lookup `Dict` to that we can handle converting a
# `MIME` to it's file extension.
const EXTENSIONS = Dict(v => k for (k, v) in MIMETYPES)

# Next we define a [`File`](#) type.

"""
    File(; kws...)

A `File` object represents a real, or "virtual", file within a [`Project`](#).

The following are the available keyword's supported by the `File` constructor.

  - `name`: full path to the `File`. `nothing` if it is "virtual".
  - `mime`: the `MIME` type as defined [above](# "mime-type-defs").
  - `text`: Raw `String` content of the `File`.
  - `dict`: `Dict{String,Any}` data from a parsed `.toml` file.
  - `node`: `CommonMark.Node` abstract syntax tree from a parsed markdown file.
"""
Base.@kwdef struct File
    name :: Union{Nothing,String}           = nothing
    mime :: Union{Nothing,MIME}             = nothing
    text :: Union{Nothing,String}           = nothing
    dict :: Union{Nothing,Dict{String,Any}} = nothing
    node :: Union{Nothing,CommonMark.Node}  = nothing
end

Base.show(io::IO, file::File) = print(io, "$File($(file.name), $(file.mime))")

# We also have a number of constructors for [`File`](#) objects that make it
# easier to create different variants of `File`s.
#
# This one dispatches to others further down by examining the file extensions.
function File(path::AbstractString)
    if isfile(path)
        _, ext = splitext(path)
        mime = get(MIMETYPES, ext, nothing)
        return File(mime, path)
    else
        @error "unknown file '$path'"
    end
end

const CODE_FENCE = "~"^10

# This `File` constructor handles Jupyter Notebooks, which are written in
# `JSON` format.
function File(mime::MIME"application/ipynb+json", path::AbstractString)
    dict = JSON.parsefile(path)
    io = IOBuffer()
    if haskey(dict, "cells")
        for cell in dict["cells"]
            if haskey(cell, "cell_type")
                type = cell["cell_type"]
                source = get(cell, "source", "")
                if type == "markdown"
                    join(io, source)
                    println(io)
                elseif type == "code"
                    println(io, CODE_FENCE, "julia")
                    join(io, source)
                    println(io)
                    println(io, CODE_FENCE)
                end
            end
        end
    end
    node = load_markdown(io)
    return File(
        name = path,
        mime = mime,
        node = node,
        dict = frontmatter(node),
    )
end

# `.jl` files are treated as Literate Julia. This function below provides a
# reduced set of functionality compared to the Literate.jl package.
function File(mime::MIME"text/julia", path::AbstractString)
    io = IOBuffer()
    code = String[]
    state = :text
    ## Helper function the reduces code duplication below.
    code_block_helper = function (state)
        if state === :code
            first = findfirst(l -> any(!isspace, l), code)
            last  = findlast(l -> any(!isspace, l), code)
            (first === last === nothing) || join(io, code[first:last])
            empty!(code)
            println(io, CODE_FENCE, "\n")
        end
    end
    for line in eachline(path)
        occursin(r"#src\b", line) && continue
        m = match(r"^(\s*)([#]*)(.*)", line)
        if m !== nothing
            ws, comments, rest = m[1], m[2], m[3]
            count = length(comments)
            if count == 1
                ## Remove single whitespace after the comment.
                line = chop(rest; head=1, tail=0)
                code_block_helper(state)
                println(io, line)
                state = :text
            else
                ## Start a new code block.
                state === :text && println(io, CODE_FENCE, "julia")
                push!(code, string(ws, count === 0 ? "" : '#'^(count-1), rest, '\n'))
                state = :code
            end
        end
    end
    ## Clean up last code block.
    code_block_helper(state)
    node = load_markdown(io)
    return File(
        name = path,
        mime = mime,
        node = node,
        dict = frontmatter(node),
    )
end

# Markdown files, `.md` extension, is pretty simple to handle.
function File(mime::MIME"text/markdown", path::AbstractString)
    node = open(load_markdown, path)
    return File(
        name = path,
        mime = mime,
        node = node,
        dict = frontmatter(node)
    )
end

# As is the `.toml` filetype. For both we're just using the provided packages
# that parse those file types.
function File(mime::MIME"application/toml", path::AbstractString)
    dict = TOML.parsefile(path)
    return File(
        name = path,
        mime = mime,
        dict = dict,
    )
end

# There's also a number of file types that we don't want to do any kind of
# parsing to. These are listed below and just produce a raw `File`.
const SIMPLE_FILETYPES = Union{
    MIME"text/javascript",
    MIME"text/css",
    MIME"text/html",
    MIME"text/tex",
    MIME"text/mustache",
}
File(m::SIMPLE_FILETYPES, p::AbstractString) = File(name=p, mime=m, text=read(p, String))

# A nice error message is provided for other mime types.
function File(::Nothing, path::AbstractString)
    supported = join(repr.(keys(MIMETYPES)), ", ", ", and ")
    @error "unsupported file '$path'. Only $supported are supported."
end

# ## File Utilities
#
# Our markdown parser setup:
"""
    init_markdown_parser()

Create a new `CommonMark.Parser` object with the extensions we want to support
in [`Publish`](#).
"""
function init_markdown_parser()
    cm = CommonMark
    return cm.enable!(cm.Parser(), [
        cm.AdmonitionRule(),
        cm.AttributeRule(),
        cm.AutoIdentifierRule(),
        cm.CitationRule(),
        cm.DollarMathRule(),
        cm.FootnoteRule(),
        cm.FrontMatterRule(toml=TOML.parse),
        cm.MathRule(),
        cm.RawContentRule(),
        cm.TableRule(),
        cm.TypographyRule(),
    ])
end

# Parsing of markdown files:

"""
    load_markdown(io, [parser])

Parse the contents found in `io` as markdown using the provided `parser` or the
default created by [`init_markdown_parser`](#).
"""
load_markdown(io::IO, parser=init_markdown_parser()) = parser(seekstart(io))

# Extraction of frontmatter content from a markdown AST:

"""
    frontmatter(ast) -> Dict{String,Any}

Return the frontmatter content of the given `ast` if it exists, otherwise
return an empty `Dict`.
"""
function frontmatter(ast::CommonMark.Node)
    CommonMark.isnull(ast.first_child)           && return Dict{String,Any}()
    ast.first_child.t isa CommonMark.FrontMatter && return ast.first_child.t.data
    return Dict{String,Any}()
end
