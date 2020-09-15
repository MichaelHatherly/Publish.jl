"""
    save(f, tree)

Wrapper function for `FileTrees.save` to configure whether to use parallel
saving using `FileTrees` or to just use a basic serial implementation.
Typically the simpler serial code will be faster unless the project is very
large.
"""
function save(f, tree)
    if DAGGER[]
        FileTrees.save(f, tree)
    else
        for file in FileTrees.files(tree)
            dir = dirname(file)
            isdir(dir) || mkpath(dir)
            f(file)
        end
    end
end

# # HTML

"""
Convert the given `src` project to a collection of HTML files.
"""
function html(src, dst=nothing; keywords...)
    p = Project(src; keywords...)
    p === nothing && return src
    h = p.env["publish"]["html"]
    h["template"]["string"] = String(exec(p.tree[h["template"]["file"]][]))
    sandbox(dst) do
        default_html_pages(p) # TODO: handle as part of template?
        tree = rename(p.tree, pwd())
        mapping = page_neighbours(p.pages)
        searchmd = p"search.md"
        tree = touch(tree, searchmd; value=load_markdown("# Search\n<div id='search-results'></div>"))
        mapping[searchmd] = (prev=searchmd, next=searchmd)
        save(f -> _html(p, tree, f, mapping), tree)
    end
    return src
end

function init(p::Project, ::typeof(html); port=nothing, dir=nothing, kws...)
    html(p, dir; kws...)
    LiveServer.serve(; port=port, dir=dir)
end

_html(p::Project, t::FileTree, f::File, m::Dict) = _html(p, exec(f[]), relative(path(f), basename(t)), m)

function _html(p::Project, node::CommonMark.Node, path::AbstractPath, mapping::Dict)
    if haskey(mapping, path)
        dst = with_extension(path, "html")
        ## Setup.
        let pub = p.env["publish"]
            pub["mapping"] = mapping
            pub["smartlink-engine"] = (_,_,n,_)->toc_link(n, p, p.env["publish"], path)
            ast = exec(p.tree[pub["toc"]][])
            pub["html"]["toc"] = CommonMark.html(ast, p.env["publish"])
            pub["html"]["prev"], pub["html"]["next"] = mapping[path]
        end
        ## Writing.
        relative_paths(p, path) do pub
            pub["html"]["prev"] = with_extension(pub["html"]["prev"], "html")
            pub["html"]["next"] = with_extension(pub["html"]["next"], "html")
            dir, name = splitdir(dst)
            cd(isempty(dir) ? "." : dir) do
                open(name, "w") do io
                    pub["template-engine"] = Mustache.render
                    pub["smartlink-engine"] = (_,_,n,_)->html_link(n, p, pub, path)
                    CommonMark.html(io, node, pub)
                end
            end
        end
        write("search.json", JSON.json(json_search_data(p)))
        ## Cleanup.
        let pub = p.env["publish"]
            delete!(pub, "mapping")
            delete!(pub, "template-engine")
            delete!(pub, "smartlink-engine")
            delete!(pub["html"], "toc")
            delete!(pub["html"], "prev")
            delete!(pub["html"], "next")
        end
    end
    return nothing
end
_html(::Project, data::Vector{UInt8}, path::AbstractPath, ::Dict) = write(path, data)
_html(p::Project, t::FileTrees.Thunk, path::AbstractPath, env::Dict) = _html(p, exec(t), path, env)
_html(::Project, ::Any, ::AbstractPath, ::Dict) = nothing

function toc_link(node, project, pub, path)
    obj = deepcopy(node.t)
    ## Change to toc location based on the current path.
    reltoc = relpath(pub["toc"], dirname(joinpath(".", string(path))))
    ## Adjust the toc link's path based on the new toc root.
    obj.destination = joinpath(dirname(reltoc), obj.destination)
    return html_link(obj, node, project, pub, path)
end

html_link(node, project, pub, path) = html_link(deepcopy(node.t), node, project, pub, path)

function html_link(obj, node, project, pub, path)
    if obj.destination == "#"
        function docs_func!(literal::AbstractString)
            dict = frontmatter(exec(project.tree[path][]))
            module_binding = binding(get(dict, "module", findmodule(project.env)))
            if Docs.defined(module_binding)
                target_binding = binding(Docs.resolve(module_binding), literal)
                if Docs.defined(target_binding)
                    rel = relpath("docstrings/$target_binding.html", string(dirname(path)))
                    obj.destination = rel
                    @goto END
                end
            end
            @warn "cross-reference link '$literal' on page '$path' cound not be found."
            @label END
            return nothing
        end
        function header_func!(literal::AbstractString)
            slug = CommonMark.slugify(literal)
            for each in project.pages, (node, enter) in exec(project.tree[each][])
                if enter && get(node.meta, "id", nothing) == slug
                    name = with_extension(relpath(each, dirname(path)), "html")
                    obj.destination = "$name#$slug"
                    obj.title = ""
                    @goto END
                end
            end
            @warn "cross-reference link '$literal' on page '$path' could not be found."
            @label END
            return nothing
        end
        ## `#` is used for cross-references. The link is determined by either
        ## the provided `.title` field of the link, or the contents of the link.
        if isempty(obj.title)
            ## No title provided so we use the contents of the link.
            (!CommonMark.isnull(node.first_child) && node.first_child.t isa CommonMark.Code) ?
                docs_func!(node.first_child.literal) : header_func!(node.first_child.literal)
        else
            ## The `.title` is available, so use that to determine the link.
            m = match(r"^`(.+)`$", obj.title)
            m === nothing ? header_func!(obj.title) : docs_func!(m[1])
        end
    elseif startswith(obj.destination, "#")
        ## Skip these kind of links, they're just page-local.
    else
        dst = Path(normpath(dirname(string(path)), obj.destination))
        if haskey(pub["mapping"], dst)
            ## If it's in the project's page mapping then we change the extension.
            obj.destination = with_extension(obj.destination, "html")
        end
    end
    return obj
end

function default_html_pages(p::Project)
    if !isempty(p.pages)
        content =
            """
            <!DOCTYPE html>
            <html>
            <head>
            <meta http-equiv = "refresh" content = "0; url = $(with_extension(first(p.pages), "html"))" />
            </head>
            </html>
            """
        write("index.html", content)
    end
    return nothing
end

"""
Extract JSON search data from a project for use in lunr.js.
"""
function json_search_data(project::Project)
    dict = Dict{String,String}()
    root = dirname(joinpath(".", project.env["publish"]["toc"]))
    for page in project.pages
        path = relpath(string(page), root)
        path = with_extension(path, "html")
        id = path
        if hasfile(project.tree, page)
            for (node, enter) in exec(project.tree[page][])
                if enter
                    if haskey(node.meta, "id")
                        id = "$path#$(node.meta["id"])"
                    end
                    if (node.t isa CommonMark.Text || node.t isa CommonMark.Code)
                        if haskey(dict, id)
                            dict[id] = "$(dict[id]) $(node.literal)"
                        else
                            dict[id] = node.literal
                        end
                    end
                end
            end
        end
    end
    json = Dict{String,String}[]
    for (id, body) in dict
        push!(json, Dict("id" => id, "body" => body))
    end
    return json
end

# # PDF

"""
Convert the given `src` project to a PDF file.
"""
function pdf(src, dst=nothing; keywords...)
    p = Project(src; keywords...)
    p === nothing && return nothing
    sandbox(dst) do
        tree = rename(p.tree, pwd())
        save(f -> _pdf(p, tree, f), tree)
        tocroot = joinpath(".", dirname(p.env["publish"]["toc"]))
        io = IOBuffer()
        println(io, "```{=latex}")
        for page in p.pages
            rpath = relpath(string(page), tocroot)
            name, _ = splitext(rpath)
            name = unix_style_path(name) # Path adjustments for Windows.
            println(io, "\\include{$name}")
        end
        println(io, "```")
        ast = load_markdown(io)
        project_file = p.env["name"] * ".tex"
        t = p.env["publish"]["latex"]
        t["template"]["string"] = String(exec(p.tree[t["template"]["file"]][]))
        p.env["publish"]["template-engine"] = Mustache.render
        open(project_file, "w") do handle
            CommonMark.latex(handle, ast, p.env["publish"])
        end
        ## Build the final PDF document using tectonic.
        Tectonic.tectonic() do path
            run(`$path $project_file`)
        end
    end
    return src
end

function init(p::Project, ::typeof(pdf); dir=nothing, kws...)
    pdf(p, dir; kws...)
    pdf_viewer = Sys.iswindows() ? "start" : Sys.isapple() ? "open" : "xdg-open"
    run(`$pdf_viewer $(joinpath(dir, p.env["name"] * ".pdf"))`)
end

_pdf(p::Project, t::FileTree, f::File) = _pdf(p, exec(f[]), relative(path(f), basename(t)))

function _pdf(p::Project, node::CommonMark.Node, path::AbstractPath)
    pub = p.env["publish"]
    pub["smartlink-engine"] = (_, _, n, _) -> tex_link(n)
    dst = with_extension(path, "tex")
    dir, name = splitdir(dst)
    cd(isempty(dir) ? "." : dir) do
        open(name, "w") do io
            CommonMark.latex(io, node, pub)
        end
    end
end
_pdf(::Project, data::Vector{UInt8}, path::AbstractPath) = write(path, data)
_pdf(::Project, ::Any, ::AbstractPath) = nothing

function tex_link(n::CommonMark.Node)
    ## TODO: make links work.
    obj = deepcopy(n.t)
    obj.destination = ""
    return obj
end
