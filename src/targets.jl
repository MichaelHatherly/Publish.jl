# # Output Formats
#
# "Targets" represent different ways to output [`Project`](#) objects.  This
# might be as a literal file or tree of files, or it may be test results from
# running doctests, or perhaps checking validity of external links.

writer(f, p::Project, temp::AbstractString) = f(p, temp)

html(p::Project, changed, temp) = writer(html, p, temp)
search(p::Project, changed, temp) = writer(search, p, temp)
pdf(p::Project, changed, temp) = writer(pdf, p, temp)
test(p::Project, changed, temp) = writer(test, p, temp)

"""
    html(source, [dir])

Write `source` to HTML format. `dir` optionally provides the directory to write
the final content to. When this directory is not provided then a temporary
directory is used.
"""
function html(source, temp=nothing)
    p = from_source(source)
    sandbox(temp) do
        ## Clean up the index.html since we check it's existance for redirect page.
        rm("index.html"; force=true)
        ## Copy over resources that are important to this target type.
        suitable_mimes = map(MIME, ("text/html", "text/javascript", "text/css"))
        write_resources(p, suitable_mimes)
        ## Write all the pages out to html.
        toc_root = tocroot(p)
        ## Define the page ordering. We partition the order so that we have
        ## access to each page's previous and next siblings for use in page
        ## navigation. For this we need a `fake` page at the start and end of
        ## our document.
        fake = Ref(nothing => nothing)
        order = Iterators.flatten((fake, p.pages, p.docs, fake))
        for ((prev, _), (path, page), (next,_)) in IterTools.partition(order, 3, 1)
            rpath = relpath(path, toc_root)
            rdir = dirname(rpath)
            isdir(rdir) || mkpath(rdir)
            name, _ = splitext(rpath)
            html_file = name * ".html"
            ## Calculate the previous and next page URLs.
            if prev !== nothing
                name, _ = splitext(relpath(prev, dirname(path)))
                p.env["publish"]["html"]["prev"] = "$name.html"
            end
            if next !== nothing
                name, _ = splitext(relpath(next, dirname(path)))
                p.env["publish"]["html"]["next"] = "$name.html"
            end
            ## Calculate the table of contents for this page.
            p.env["publish"]["html"]["toc"] = build_html_toc(p, path)
            ## Activate smart linking relative to the current `html_file`.
            p.env["publish"]["smartlink-engine"] = (mime, obj, node, env) -> smartlink(mime, obj, node, env, p, html_file, page)
            relative_paths(p, p.env["publish"], html_file) do pub
                open(html_file, "w") do handle
                    fm = frontmatter(page.node)
                    pub = isempty(fm) ? pub : CommonMark.recursive_merge(pub, fm)
                    CommonMark.html(handle, page.node, pub)
                end
            end
            ## Delete previous and next pages.
            delete!(p.env["publish"]["html"], "prev")
            delete!(p.env["publish"]["html"], "next")
        end
        ## Generate a fake index.html page that redirects to the first page in the p.pages dict.
        if !isfile("index.html") && !isempty(p.pages)
            path, _ = first(p.pages)
            rpath = relpath(path, toc_root)
            name, _ = splitext(rpath)
            content = """
            <!DOCTYPE html>
            <html><head><meta http-equiv = "refresh" content = "0; url = $name.html" /></head></html>
            """
            write("index.html", content)
        end
        ## Build the search page, overwrites any search.html already written.
        html_file = "search.html"
        p.env["publish"]["html"]["toc"] = build_html_toc(p, joinpath(p.project.name))
        relative_paths(p, p.env["publish"], html_file) do pub
            open(html_file, "w") do handle
                node = load_markdown(IOBuffer("# Search\n<div id='search-results'></div>"))
                CommonMark.html(handle, node, pub)
            end
        end
        ## Write the search data to file.
        search(p, pwd())
        ## Build a basic versions.js file, this is overwritten by `deploy`.
        open("versions.js", "w") do handle
            println(handle, "const PUBLISH_ROOT = '';")
            println(handle, "const PUBLISH_VERSION = null;")
            println(handle, "const PUBLISH_VERSIONS = [];")
        end
        ## Remove the generated table of contents string.
        delete!(p.env["publish"]["html"], "toc")
    end
    return source
end

# ## "Smart" Link Implementation
#
# First some helper methods for looking up the `Binding` object of a value.

function binding(mod::Module, expr::Expr)
    if Meta.isexpr(expr, :.)
        parent = binding(mod, expr.args[1])
        if Docs.defined(parent)
            return binding(Docs.resolve(parent), expr.args[2:end]...)
        end
    end
    return Docs.Binding(mod, nameof(mod))
end
binding(mod::Module, str::AbstractString) = binding(mod, Meta.parse(str; raise=false))
binding(mod::Module, symbol::Symbol) = Docs.Binding(mod, symbol)
binding(mod::Module, quot::QuoteNode) = Docs.Binding(mod, quot.value)
binding(mod, other...) = Docs.Binding(mod, nameof(mod))
binding(str::AbstractString) = binding(Main, str)
binding(mod::Module) = binding(mod, nameof(mod))

# "Smart" link cross-referencing.

"""
    smartlink(mime, obj, node, env, p, html_file, page)

Generate a cross-reference link.
"""
function smartlink(
    ::MIME"text/html",
    obj::CommonMark.Link,
    node::CommonMark.Node,
    env,
    p::Project,
    html_file::AbstractString,
    page
)
    if obj.destination == "#"
        ## The following closures are used in multiple branches and so are
        ## defined above to avoid repetition.
        function docs_func!(literal::AbstractString)
            dict = page.dict === nothing ? Dict() : page.dict
            module_binding = binding(get(dict, "module", project_to_module(p.env)))
            if Docs.defined(module_binding)
                target_binding = binding(Docs.resolve(module_binding), literal)
                if Docs.defined(target_binding)
                    obj = deepcopy(obj)
                    rel = relpath("docstrings/$target_binding.html", dirname(html_file))
                    obj.destination = rel
                    @goto END
                end
            end
            @warn "cross-reference link '$literal' on page '$html_file' cound not be found."
            @label END
            return nothing
        end
        function header_func!(literal::AbstractString)
            toc_dir = joinpath(dirname(p.project.name), dirname(p.env["publish"]["toc"]))
            slug = CommonMark.slugify(literal)
            for (path, page) in p.pages, (node, enter) in page.node
                if enter && get(node.meta, "id", nothing) == slug
                    name, _ = splitext(relpath(relpath(path, toc_dir), dirname(html_file)))
                    obj = deepcopy(obj)
                    obj.destination = "$name.html#$slug"
                    obj.title = ""
                    @goto END
                end
            end
            @warn "cross-reference link '$literal' on page '$html_file' could not be found."
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
        return obj
    elseif startswith(obj.destination, '#')
        ## Ignore bare anchor links.
        return obj
    else
        ## Links that aren't cross-references are either left as is, or adjusted
        ## to point at the generated `.html` file rather than the original
        ## source file.
        uri = parse(HTTP.URIs.URI, obj.destination)
        uri.scheme == "" || return obj
        ## Only try local URLs.
        obj = deepcopy(obj)
        if get(env, "#toc", false)
            # Adjust paths due to inclusion of a toc, which has a different path.
            rpath = joinpath(".", relpath(html_file, tocroot(p)))
            name, _ = splitext(relpath(obj.destination, dirname(rpath)))
            obj.destination = "$name.html"
        else
            name, _ = splitext(obj.destination)
            obj.destination = "$name.html"
        end
        return obj
    end
end
smartlink(mime, obj, node, env, p, html_file, page) = obj

# And some other helpers needed for [`html`](#) generation.

function build_html_toc(p::Project, path::AbstractString)
    fn = (mime, obj, node, env) -> smartlink(mime, obj, node, env, p, path, nothing)
    return CommonMark.html(p.env["_toc"].node, Dict("smartlink-engine" => fn, "#toc" => true))
end

function relative_paths(f, p::Project, pub::AbstractDict, file::AbstractString)
    root = dirname(p.project.name)
    file_dir = dirname(joinpath(".", file))
    temp_pub = with_replacement(pub) do value
        if value in DEFAULT_ASSETS_SET
            ## Default resources are set relative to the `src/templates`
            ## directory.  which 'mirrors' the project root directory. Resources
            ## with the same names that the user provides will get overwritten.
            rpath = relpath(value, joinpath(@__DIR__, "templates"))
            return relpath(rpath, file_dir)
        elseif isabspath(value) && isfile(value)
            ## Handles template files.
            return value
        else
            path = joinpath(root, value)
            return _isfile(path) ? relpath(value, file_dir) : value
        end
    end
    f(temp_pub)
end

_isfile(s::AbstractString) = length(s) ≤ 144 && isfile(s) # TODO: hack for ENAMETOOLONG.

with_replacement(f, value) = value
with_replacement(f, value::AbstractString) = f(value)
with_replacement(f, vec::Vector{T}) where T = T[with_replacement(f, elem) for elem in vec]
with_replacement(f, dict::T) where T <: AbstractDict = T(k => with_replacement(f, v) for (k, v) in dict)

from_source(p::Project) = p
from_source(m::Module) = Project(m)
from_source(s::AbstractString) = Project(s)

# ## JSON Search Data Target

function search(source, temp=nothing)
    p = from_source(source)
    dict = Dict{String,String}()
    root = tocroot(p)
    for (path, page) in Iterators.flatten((p.pages, p.docs))
        path = relpath(path, root)
        name, _ = splitext(path)
        path = "$name.html"
        id = path
        for (node, enter) in page.node
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
    json = Dict{String,String}[]
    for (id, body) in dict
        push!(json, Dict("id" => id, "body" => body))
    end
    sandbox(temp) do
        write("search.json", JSON.json(json))
    end
    return source
end

# ## PDF generation.
#
# Our PDF creation uses a LaTeX engine, in the form of *tectonic*, to make PDF output.

"""
    pdf(source, [dir])

Write `source` project to PDF format. `dir` may optionally specify the
directory to write the finished document to. Intermediate `.tex` files are
retained for debugging purposes.
"""
function pdf(source, temp=nothing)
    p = from_source(source)
    sandbox(temp) do
        toc_root = tocroot(p)
        ## Write pages to separate document and include it in main tex document.
        includes = IOBuffer()
        println(includes, "```{=latex}")
        for (path, page) in p.pages
            rpath = relpath(path, toc_root)
            name, _ = splitext(rpath)
            name = unix_style_path(name) # Path adjustments for Windows.
            println(includes, "\\include{$name}")
            out = tex(name)
            dir = dirname(out)
            isdir(dir) || mkpath(dir)
            open(out, "w") do handle
                CommonMark.latex(handle, page.node)
            end
        end
        println(includes, "```")
        parser = CommonMark.enable!(CommonMark.Parser(), CommonMark.RawContentRule())
        ast = load_markdown(includes, parser)
        project_file = tex(p.env["name"])
        open(project_file, "w") do handle
            CommonMark.latex(handle, ast, p.env["publish"])
        end
        ## Build the final PDF document using tectonic.
        Tectonic.tectonic() do path
            run(`$path $project_file`)
        end
    end
    return source
end

## Needed by latex engine since it doesn't like windows paths.
if Sys.iswindows()
    unix_style_path(path) = unix_joinpath(splitpath(path)...)
else
    unix_style_path(path) = path
end
function unix_joinpath(path::AbstractString, paths::AbstractString...)::String
    for p in paths
        if isabspath(p)
            path = p
        elseif isempty(path) || path[end] == '/'
            path *= p
        else
            path *= "/" * p
        end
    end
    return path
end
unix_joinpath(path::AbstractString) = path

# ## "Doctests" Stub
#
# This is not implemented yet. Output should be the same as for the `Test`
# module. Probably use it to do the actual testing.

"""
    test(source)

Run all doctests defined within project `source`.
"""
function test(source, temp=nothing)
    p = from_source(source)
    sandbox(temp) do
        for (path, page) in p.pages, (node, enter) in page.node
            if enter && isdoctest(node)
                ## TODO: do testing here.
            end
        end
    end
    return source
end

# ## Live Server
#
# Used to do iterative editing by avoiding the edit-compile-read-loop.

"""
    serve(source, [targets...])

Start watching the project defined by `source` for changes and rebuild it when
any occur. `targets` lists the functions to run when any changes take place. By
default this is [`html`](#), which runs a background HTTP server that presents
the generated HTML output at `localhost:8000`.
"""
function serve(source, targets...=html; kws...)
    p = from_source(source)
    w = WatchedProject(p, targets...)
    try
        for target in targets
            target(w; kws...)
        end
    finally
        wait() # Wait until all tasks done.
        stop(w)
    end
    return source
end

function html(w::WatchedProject; port=8000, kws...)
    dir = w.dirs[html]
    html(w.p, dir)
    @async LiveServer.serve(; dir=dir, port=port)
end

function search(w::WatchedProject; kws...)
    if haskey(w.dirs, html)
        ## Search data is written to the HTML directory.
        dir = w.dirs[html]
        search(w.p, dir)
    end
end

function pdf(w::WatchedProject; kws...)
    dir = w.dirs[pdf]
    pdf(w.p, dir)
    file = joinpath(dir, w.p.env["name"] * ".pdf")
    run(`$PDF_VIEWER $file`; wait=false)
end

# ## Utilities

const PDF_VIEWER = Sys.iswindows() ? "start" : Sys.isapple() ? "open" : "xdg-open"

isdoctest(n) = n.t isa CommonMark.CodeBlock && n.t.info == "jldoctest"

function write_resources(p::Project, mimes)
    project_root = projectroot(p)
    assets_root = joinpath(@__DIR__, "templates")
    for (path, file) in p.resources
        rpath = relpath(path, path in DEFAULT_ASSETS_SET ? assets_root : project_root)
        dir = dirname(rpath)
        if file.text !== nothing && file.mime in mimes
            isdir(dir) || mkpath(dir)
            write(rpath, file.text)
        end
    end
end

sandbox(f, ::Nothing) = mktempdir(dir -> cd(f, dir))
sandbox(f, temp::AbstractString) = isdir(temp) ? cd(f, temp) : (mkpath(temp); cd(f, temp))

tocroot(p::Project) = abspath(joinpath(dirname(p.project.name), dirname(p.env["publish"]["toc"])))
projectroot(p::Project) = abspath(dirname(p.project.name))
tex(filename::AbstractString) = filename * ".tex"
