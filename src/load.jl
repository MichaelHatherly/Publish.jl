# # File Loaders

function loadtoml(path::AbstractPath, globals)
    defaults = Dict{String,Any}(
        "deps" => Dict{String,String}(),
        "publish" => Dict(
            "ignore" => [],
            "theme" => string(Themes.default),
            "config" => "Project.toml",
            "pages" => ["README.md"],
            "toc" => "toc.md",
            "modules" => [],
        ),
    )
    return rmerge(defaults, open(TOML.parse, path), globals)
end

rtree(f, d) = isdir(d) ? (d => [cd(()->rtree(f, x), d) for x in readdir(d) if f(x)]) : d
mktree(dir::Union{AbstractPath,AbstractString}, f=x->true) = FileTrees.maketree(rtree(f, abspath(dir)))

function loadtree(env::AbstractDict, p::AbstractPath)
    ## Custom ignore patterns from configuration are regular expressions.
    ignore = map(Regex, env["publish"]["ignore"])
    fn = function (path::AbstractString)
        ## Always ignore anything starting with '.' or '_'.
        startswith(path, ['.', '_']) && return true
        for each in ignore
            occursin(each, path) && return true
        end
        return false
    end
    ## Construct the initial FileTree manually since this avoids reading in
    ## huge directories that exceed open file limit on default OSX.
    tree = mktree(string(isfile(p) ? dirname(p) : p), !fn)
    return FileTrees.load(tree; lazy=LAZY[]) do file
        loadfile(env, joinpath(basename(tree), path(file)))
    end
end

"""
A dispatch type used to make file loading extensible by extension name.
"""
struct Extension{E} end
Extension(path::AbstractPath) = Extension{Symbol(extension(path))}()

"""
    loadfile(env, path)

Loads a file. Extended by `loadfile` methods that dispatch based on the
[extension](# "`Extension`") of the file.
"""
loadfile(env::AbstractDict, path::AbstractPath) = loadfile(Extension(path), env, path)

loadfile(::Extension{:md}, env, path) = open(load_markdown, path)

function loadfile(::Extension{:jl}, env, path)
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
    open(path) do handle
        for line in eachline(handle)
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
    end
    ## Clean up last code block.
    code_block_helper(state)
    return load_markdown(io)
end

function loadfile(::Extension{:ipynb}, env, path)
    dict = open(JSON.parse, path)
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
    return load_markdown(io)
end

loadfile(::Extension, env, path) = read(path)

"""
Loads "virtual" files for each docstring that is defined within the given
project. Merges these files into the given `tree` as well as appending them to
`pages`.
"""
function loaddocs(tree::FileTree, env::AbstractDict, pages::Vector)
    docs_dir, docs_index = "docstrings", "docstrings.md"
    roots = findmodules(env)
    docs = DataStructures.SortedDict{String,Tuple{Module,Docs.Binding,Docs.MultiDoc}}()
    for mod in visible_modules(env)
        if Base.moduleroot(mod) in roots
            for (k, v) in Docs.meta(mod)
                docs["$k.md"] = (mod, k, v)
            end
        end
    end
    isempty(docs) && return tree, pages # Bail early if no docstrings are found.
    push!(pages, Path(docs_index))
    append!(pages, sort!([joinpath(Path(docs_dir), k) for k in keys(docs)]; by=string))
    dtree = maketree(basename(tree) => [docs_index, docs_dir => keys(docs)])
    dtree = FileTrees.load(dtree; lazy=LAZY[]) do file
        name = basename(path(file))
        io = IOBuffer()
        visibility(binding) = Base.isexported(binding.mod, binding.var) ? "public" : "private"
        if name == docs_index
            println(io, "{#docstring-index}")
            println(io, "| Name | Module | Visibility | Category |")
            println(io, "|------|--------|------------|----------|")
            for (k, (mod, bind, doc)) in docs
                vis, cat = visibility(bind), categorise(bind)
                println(io, "| [`$(bind.var)`](docstrings/$k) | `$mod` | `$vis` | `$cat` |")
            end
        else
            mod, bind, doc = docs[name]
            println(io, "```{=html}\n<div class='docs' id='$(bind.var)'>\n```") # TODO: raw latex.
            println(io, "`$(visibility(bind))` `$(bind.var)` --- `$(categorise(bind))`")
            for (n, sig) in enumerate(doc.order)
                println(io)
                println(io, "```{=html}\n<div class='doc' id='$n'>\n```")
                printdoc(io, doc.docs[sig])
                println(io, "```{=html}\n</div>\n```")
            end
            println(io, "```{=html}\n</div>\n```")
        end
        return load_markdown(io)
    end
    return merge(tree, dtree), pages
end

"""
    loadpages(tree, env)

Finds all files defined by the project's table of contents and loads them into
the `tree`.
"""
function loadpages(tree::FileTree, env::AbstractDict)
    toc = env["publish"]["toc"]
    tree = try_touch(tree, toc) do
        io = IOBuffer()
        for page in env["publish"]["pages"]
            path = Path(page)
            println(io, "  - [$(filename(path))]($path)")
        end
        return load_markdown(io)
    end
    pages = []
    for (node, enter) in exec(tree[toc][])
        if enter && node.t isa CommonMark.Link
            push!(pages, Path(node.t.destination))
        end
    end
    return tree, pages
end
