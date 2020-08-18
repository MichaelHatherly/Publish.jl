# # Interface for Julia's Docsystem
#
# Not much is needed from the docsystem, we just build each `Binding`'s
# docstrings as separate pages, as well as a table with links to each docstring
# page. There's no concept of `@docs` and `@autodocs` found in Documenter.jl.

"""
    docstrings(p)

Extract all available docstrings for given `Project` `p` and return a
`files::Dict` containing a mapping from absolute path to `File` object and an
`index` object, which is [`File`](#) object containing a formatted table of all
docstrings with information on `name`, `module`, `visibility`, and `category`
of each docstring.
"""
function docstrings(p::Project)
    toc_root = dirname(joinpath(dirname(p.project.name), p.env["publish"]["toc"]))
    docstring_dir = joinpath(toc_root, "docstrings")
    mod = project_to_module(p.env)
    files = Pair{String,File}[]
    table = IOBuffer()
    println(table, "{#docstring-index}")
    println(table, "| Name | Module | Visibility | Category |")
    println(table, "|:---- |:------:|:----------:| --------:|")
    for each in p.mods
        root = rootmodule(each)
        if root === mod
            for (k, v) in Docs.meta(each)
                object_name = string(k.var)
                module_name = string(k.mod)
                visibility = Base.isexported(k.mod, k.var) ? "public" : "private"
                category = categorise(k)
                ## Write the docstring file, may concatenate several similar
                ## docstrings -- those with the same name, but different
                ## signatures.
                filename = joinpath(docstring_dir, "$k.md")
                io = IOBuffer()
                println(io, "```{=html}\n<div class='docs' id='$(k.var)'>\n```")
                println(io, "*`$visibility`* **`$object_name`** --- `$category`\n")
                for (n, sig) in enumerate(v.order)
                    println(io, "```{=html}\n<div class='doc' id='$n'>\n```")
                    println
                    doc = v.docs[sig]
                    println(io)
                    printdoc(io, doc)
                    println(io)
                    println(io, "```{=html}\n</div>\n```")
                end
                println(io, "```{=html}\n</div>\n```")
                file = File(
                    name = filename,
                    mime = MIMETYPES[".md"],
                    node = load_markdown(io),
                    dict = Dict("module" => each),
                )
                push!(files, filename => file)
                ## Add an entry to the table index for this name.
                println(table, "| [`$object_name`](docstrings/$(k).html) | `$module_name` | `$visibility` | `$category` |")
            end
        end
    end
    sort!(files; by=first)
    index = File(
        name = joinpath(toc_root, "docstrings.md"),
        mime = MIMETYPES[".md"],
        node = load_markdown(table),
    )
    docs = OrderedDict{String,File}()
    docs[index.name] = index
    for (path, file) in files
        docs[path] = file
    end
    return docs
end

# ## Helpers

"""
    printdoc(io, docstr)

This method prints out the parts of an individual `Docs.DocStr` object to the
given `IO` object `io`. It is used to get the "formatted" content of the
docstring without it being pre-parsed by the `Markdown` standard library.
"""
function printdoc(io::IO, docstr)
    for part in docstr.text
        Docs.formatdoc(io, docstr, part)
    end
    return io
end

"""
    rootmodule(m)

The "root" module of a given `Module` `m`.
"""
rootmodule(m::Module) = (p = parentmodule(m); p === m ? m : rootmodule(p))

"""
    categorise(binding)

For the given `Docs.Binding` object, determine and return its "category",
namely either "constant", "global", "struct", "type", "parametric struct",
"parametric type", "module", "macro", or "function.
"""
function categorise(binding)
    ## Helpers.
    ismacro(binding) = startswith(string(binding.var), '@')
    ## Categoriser.
    category(other)         = isconst(binding.mod, binding.var) ? "constant" : "global"
    category(obj::Module)   = "module"
    category(obj::DataType) = isconcretetype(obj) ? "struct" : "type"
    category(obj::UnionAll) = isconcretetype(obj) ? "parametric struct" : "parametric type"
    category(obj::Function) = ismacro(binding) ? "macro" : "function"

    if Docs.defined(binding)
        object = Docs.resolve(binding)
        return category(object)
    else
        return "undefined"
    end
end
