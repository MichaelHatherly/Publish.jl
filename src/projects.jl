# # Project-related Definitions
#
# A collection of different globals related to default template files and other
# assets.
const TEMPLATE_DIR = joinpath(@__DIR__, "templates")
const DEFAULT_TEMPLATES = Dict(
    "html"  => joinpath(TEMPLATE_DIR, "html.mustache"),
    "latex" => joinpath(TEMPLATE_DIR, "latex.mustache"),
)
const DEFAULT_CSS = [joinpath(TEMPLATE_DIR, f) for f in ["normalize.css", "tabulator_simple.min.css", "publish.css", "default.min.css"]]
const DEFAULT_ASSETS = Dict(
    "default_css" => DEFAULT_CSS,
    "default_js"  => [
        joinpath(@__DIR__, "templates", "versions.js"),
        joinpath(@__DIR__, "templates", "lunr.js"),
        joinpath(@__DIR__, "templates", "highlight.min.js"),
        joinpath(@__DIR__, "templates", "tabulator.min.js"),
        joinpath(@__DIR__, "templates", "julia.min.js"),
        joinpath(@__DIR__, "templates", "julia-repl.min.js"),
        joinpath(@__DIR__, "templates", "publish.js"),
    ],
)
const DEFAULT_ASSETS_SET = Set(Iterators.flatten(values(DEFAULT_ASSETS)))

# The default contents of a `[publish]` section in a `Project.toml` file.
project_defaults() = Dict(
    "name" => "README",
    "deps" => Dict{String,String}(),
    "publish" => Dict(
        "toc" => "toc.md",
        "pages" => ["README.md"],
        "extra" => [],
        "template-engine" => Mustache.render,
        "html" => Dict(
            "paths" => "normal",
            "default_js" => DEFAULT_ASSETS["default_js"],
            "default_css" => DEFAULT_ASSETS["default_css"],
            "template" => Dict("file" => DEFAULT_TEMPLATES["html"]),
        ),
        "latex" => Dict(
            "template" => Dict("file" => DEFAULT_TEMPLATES["latex"]),
            "documentclass" => "scrartcl",
        ),
    ),
)

# The [`Project`](#) struct itself, which holds all the data related to how to
# build it and all it's file dependencies.

"""
    struct Project

Holds all the data needed to represent a `Publish` "project".

`Project` objects can be constructed by either providing a `Module` or a
`Project.toml` file.
"""
Base.@kwdef struct Project
    project   :: File
    parent    :: Union{Nothing,Project}   = nothing
    pages     :: OrderedDict{String,File} = OrderedDict{String,File}()
    docs      :: OrderedDict{String,File} = OrderedDict{String,File}()
    resources :: Dict{String,File}        = Dict{String,File}()
    extra     :: Dict{String,Project}     = Dict{String,Project}()
    deps      :: Dict{String,Project}     = Dict{String,Project}()
    env       :: Dict{String,Any}         = Dict{String,Any}()
    globals   :: Dict{String,Any}         = Dict{String,Any}()
    mods      :: Set{Module}              = Set{Module}()
    loaded    :: Dict{String,Project}     = Dict{String,Project}()
end

Base.show(io::IO, project::Project) = print(io, "$Project($(project.project))")

# The main constructor for [`Project`](#) objects.

"""
    Project(path, [loaded, parent]; [globals])

A constructor for [`Project`](#) structs. Takes a `path` representing a
`Project.toml` file. Optional arguments `loaded` and `parent` are for internal
use only.
"""
function Project(
    path::AbstractString,
    loaded=Dict{String,Project}(),
    parent=nothing;
    globals=Dict{String,Any}()
)
    path = isdir(path) ? joinpath(path, "Project.toml") : path
    path = isfile(path) ? abspath(path) : error("unknown project file '$path'.")
    path = realpath(path) # Normalise symlinked paths, to handle standard libs.
    ## If we have already created this project then just return it, avoids recursive deps.
    haskey(loaded, path) && return loaded[path]
    ## Drop into the directory containing the project file.
    cd(dirname(path)) do
        ## Load the project configuration.
        project_file = File(path)
        env = CommonMark.recursive_merge(project_defaults(), project_file.dict, globals)
        publish = env["publish"]
        ## Create a table-of-contents. Either from a toc.md file or a list of
        ## markdown pages listed in the [publish] section of the Project.toml.
        toc_file =
            if isfile(publish["toc"])
                File(abspath(publish["toc"]))
            else
                io = IOBuffer()
                for page in filter(isfile, publish["pages"])
                    _, file = splitdir(page)
                    name, _ = splitext(file)
                    println(io, "  - [$name]($page)")
                end
                File(
                    mime = MIMETYPES[".md"],
                    node = load_markdown(io)
                )
            end
        ## Load all of the files referenced in the table-of-contents.
        pages = loadpages(toc_file)
        ## Modules visible from the current project.
        mods = visible_modules(env)
        ## Create and cache the project.
        project = loaded[path] = Project(
            project = project_file,
            parent  = parent,
            pages   = pages,
            mods    = mods,
            env     = env,
            globals = globals,
            loaded  = loaded,
        )
        ## Register project resources. Ignores virtual resources.
        tryset!(project.resources, toc_file.name, toc_file)
        project.env["_toc"] = toc_file
        register_resources!(project.resources, publish)
        ## The following must happen after creation of the project since they reference it:
        ## Extra internal projects.
        extra = Dict(abspath(f) => Project(f, loaded, project; globals=globals) for f in publish["extra"])
        merge!(project.extra, extra)
        ## Add available docstrings.
        merge!(project.docs, docstrings(project))
        ## Package dependencies.
        for (name, uuid) in env["deps"]
            file = find_project(uuid, name)
            if is_valid_project(file)
                project.deps[file] = Project(file, loaded; globals=globals)
            end
        end
        return project
    end
end

"""
    register_resources!(resources, env)

A helper function for use in `Project` that finds all files referenced in the
`[publish.html]` and `[publish.latex]` sections of a `Project.toml` and adds
them to the `.resources` list in a [`Project`](#).
"""
function register_resources!(resources, env::AbstractDict)
    function reg!(resources, path::AbstractString)
        if isfile(path)
            _, ext = splitext(path)
            if haskey(MIMETYPES, ext)
                file = File(abspath(path))
                tryset!(resources, file.name, file)
            end
        end
        return
    end
    reg!(resources, dict::AbstractDict) = foreach(v -> reg!(resources, v), values(dict))
    reg!(resources, vector::Vector) = foreach(v -> reg!(resources, v), vector)
    reg!(resources, other) = nothing
    for fmt in ("html", "latex")
        if haskey(env, fmt)
            reg!(resources, env[fmt])
        end
    end
end

_env_project_file(path::AbstractString) = Base.env_project_file(path)
_env_project_file(other) = nothing

# A constructor for [`Project`](#) objects that takes a `Module` as it's input source.
Project(mod::Module; kws...) = Project(_env_project_file(Base.pkgdir(mod)); kws...)

"""
    update!(project, file)

Removes the cached project and then rebuilds it to a new project and moves it's
content over to the old project.
"""
function update!(p::Project, file::AbstractString)
    ## TODO: Make more efficient. Currently everything is rebuilt instead of
    ## taking the changed `file` into account.
    new_p = p
    try
        _ = isfile(file) ? abspath(file) : error("not a file '$file'.")
        path = p.project.name
        delete!(p.loaded, path)
        new_p = Project(path, p.loaded, p.parent; globals=p.globals)
    catch err
        @error err
    finally
        p.loaded[p.project.name] = p
        move!(p, new_p)
    end
    return p
end

"""
    move!(to, from)

Transfers the data stored in `from::Project` to `to::Project`.
"""
function move!(to::Project, from::Project)
    replace!(to.project.dict, from.project.dict)
    replace!(to.pages, from.pages)
    replace!(to.docs, from.docs)
    replace!(to.resources, from.resources)
    replace!(to.extra, from.extra)
    replace!(to.deps, from.deps)
    replace!(to.env, from.env)
    replace!(to.globals, from.globals)
    replace!(to.mods, from.mods)
    return to
end
replace!(d::AbstractDict, ds::AbstractDict...) = (empty!(d); merge!(d, CommonMark.recursive_merge(ds...)))
replace!(s::AbstractSet, ss::AbstractSet...) = (empty!(s); union!(s, ss...))

# ## Project Watching-related functions.

files(p::Project) = Set{String}(IterTools.chain((p.project.name,), keys(p.resources), keys(p.pages)))
extra(p::Project) = Set{String}(keys(p.extra))

"""
    editable(p)

Returns the set of `Project`s that can be edited in relation to the initial
`Project`. This means the project itself, as well as an `publish.extra`
projects that are listed in the `Project.toml`.
"""
function editable(p::Project, out=Base.IdSet{Project}())
    if !(p in out)
        push!(out, p)
        for each in values(p.extra)
            editable(each, out)
        end
        editable(p.parent, out)
    end
    return out
end
editable(::Nothing, out=Base.IdSet{Project}()) = out

"""
    struct WatchedProject

An internal wrapper type that stores a `Project` object and watches for changes
to occur in any files that the `Project` makes use of. When any changes occur
the provided `actions` list is iterated over.
"""
struct WatchedProject
    p::Project
    dict::IdDict{Project,LiveServer.SimpleWatcher}
    dirs::IdDict{Function,String}

    function WatchedProject(p::Project, actions...)
        dirs = IdDict{Function,String}()
        fn = function (action)
            temp = get!(() -> mktempdir(), dirs, action)
            (project, changed) -> action(project, changed, temp)
        end
        new(p, watch(p, map(fn, actions)...), dirs)
    end
end

Base.show(io::IO, wp::WatchedProject) = print(io, "$WatchedProject($(wp.p), ...)")

"""
    watch(p, actions...)

Watch a `p::Project` for changes and run all `actions...` when any changes
occur.
"""
function watch(p::Project, actions...; dict=IdDict{Project,LiveServer.SimpleWatcher}())
    ## We only setup a watcher if the project it's already being watched.
    if !haskey(dict, p)
        ## Watch the project and any 'extra' projects that it references.
        sw = watch_files(p, get!(() -> LiveServer.SimpleWatcher(), dict, p))
        for each in values(p.extra)
            watch(each; dict=dict)
        end
        ## The callback function that gets called whenever we notice a change in
        ## the current project.
        callback = function (path)
            @info "$p => $path" # TODO: use loggin package.
            ## Hook into Revise for code reloading.
            revise(p)
            ## We've had a change within project so update it.
            update!(p, path)
            ## Re-watch this project to pick up new files to watch.
            watch_files(p, sw)
            ## Also re-watch it's 'extra' projects.
            for each in values(p.extra)
                watch(each; dict=dict)
            end
            ## There may be projects that aren't in 'extra' any more. Stop
            ## watching them to avoid updating things that we don't need to.
            for each in setdiff(Base.IdSet{Project}(keys(dict)), editable(p))
                LiveServer.stop(dict[each]) # Stop it's watcher.
                delete!(dict, each) # And remove it from the cache.
            end
            ## Run user-provided actions after each update.
            @sync for each in actions
                @async each(p, path)
            end
        end
        LiveServer.set_callback!(sw, callback)
        LiveServer.start(sw)
    end
    return dict
end

function watch_files(p::Project, sw::LiveServer.SimpleWatcher)
    empty!(sw.watchedfiles) # TODO: proper API for this?
    for file in files(p)
        LiveServer.is_watched(sw, file) || LiveServer.watch_file!(sw, file)
    end
    return sw
end

stop(ws::WatchedProject) = foreach(LiveServer.stop, values(ws.dict))
start(ws::WatchedProject) = foreach(LiveServer.start, values(ws.dict))

# A section of helper functions for the code found above.

function loadpages(::Nothing, toc::File)
    pages = OrderedDict{String,File}()
    for page in pageorder(toc)
        page = abspath(page)
        pages[page] = File(page)
    end
    return pages
end
loadpages(toc::File) = loadpages(toc.name, toc)
loadpages(path::AbstractString, toc::File) = cd(() -> loadpages(nothing, toc), dirname(path))

function pageorder(ast::CommonMark.Node)
    pages = String[]
    for (node, enter) in ast
        if enter && node.t isa CommonMark.Link
            if isfile(node.t.destination)
                push!(pages, node.t.destination)
            end
        end
    end
    return pages
end
pageorder(toc::File) = pageorder(toc.node)
pageorder(::Nothing) = String[]

function find_project(pkgid::Base.PkgId)
    haskey(Base.loaded_modules, pkgid) || Base.require(pkgid)
    mod = Base.loaded_modules[pkgid]
    return _env_project_file(Base.pkgdir(mod))
end
find_project(uuid, name) = find_project(Base.PkgId(Base.UUID(uuid), name))

is_valid_project(path::AbstractString) = true
is_valid_project(other) = false

"""
    visible_modules(env)

What modules are available from the given project environment `env`.
"""
function visible_modules(env::AbstractDict)
    mod = project_to_module(env)
    return mod === nothing ? Set{Module}() : modules(mod)
end

"""
    project_to_module(env)

Find the top-level module associated with a given project environment `env`.
"""
function project_to_module(env::AbstractDict)
    if haskey(env, "uuid") && haskey(env, "name")
        pkgid = Base.PkgId(Base.UUID(env["uuid"]), env["name"])
        haskey(Base.loaded_modules, pkgid) || Base.require(pkgid)
        return Base.loaded_modules[pkgid]
    else
        return nothing
    end
end

# Modules that should be ignored when finding which modules a [`Project`](#)
# depends on.
const IGNORE_LIST = (Main, Base.__toplevel__, Base.MainInclude)

"""
    modules(root)

A `Set` of all modules reachable from the given `root` `Module`. This includes
un-exported and imported `Module`s.
"""
modules(root::Module) = union!(modules(root, Set{Module}()), DEFAULT_MODULES)
function modules(root::Module, mods::Set{Module})
    for name in names(root; all=true, imported=true)
        if !Base.isdeprecated(root, name) && isdefined(root, name) && ismodule(root, name)::Bool
            mod = convert(Module, getfield(root, name))
            if !(mod in mods) && !(mod in IGNORE_LIST)
                push!(mods, mod)
                modules(mod, mods)
            end
        end
    end
    return mods
end
@noinline ismodule(m::Module, s::Symbol) = getfield(m, s)::Any isa Module

"""
    DEFAULT_MODULES::Set{Module}

The set of modules that every package has access to.
"""
const DEFAULT_MODULES = modules(Core, modules(Base, Set{Module}()))

"""
    tryset!(dict, key, value) -> Bool

Try to add the given `key`/`value` pair to the object `dict`. Returns `true`
or `false` depending on whether the action was successful.
"""
function tryset! end

tryset!(dict::AbstractDict{K}, key::K, value) where K = (dict[key] = value; true)
tryset!(dict, key, value) = false

"""
    revise(p)

If `Revise` has been loaded into the current session then run `Revise.revise` to
pick up any changes within out project's docstrings.
"""
function revise(p::Project)
    id = Base.PkgId(Base.UUID("295af30f-e4ad-537b-8983-00126c2a3abe"), "Revise")
    if haskey(Base.loaded_modules, id)
        Revise = Base.loaded_modules[id]
        try
            Revise.revise()
        catch err
            @error err
        end
    end
    return
end
