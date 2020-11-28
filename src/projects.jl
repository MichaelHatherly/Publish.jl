# # Projects

"""
    struct Project

A `struct` that holds details of a "project", which is defined as

> a configuration file (in TOML format), along with a collection of associated
> source and support files.

"Projects" can be created in two ways, by `Module`, or configuration path.
"""
Base.@kwdef mutable struct Project
    path::Union{Nothing,AbstractPath} = nothing
    env::Dict{String,Any} = Dict()
    tree::FileTree = maketree("." => [])
    pages::Vector{AbstractPath} = []
    loaded::Dict{AbstractPath,Project} = Dict()
    globals::Dict{String,Any} = Dict()
end
Base.show(io::IO, p::Project) = print(io, "$Project($(p.path))")

# ## `Project` Constructors

"""
    Project(mod)

Create a new [`Project`](#) object from the given module `mod`.
"""
Project(mod::Module; kws...) = Project(findproject(mod); kws...)

"""
    Project(path)

Create a new [`Project`](#) object from the given configuration `path`. The
`path` must be a TOML file.
"""
Project(path::AbstractString; kws...) = Project(Path(path); kws...)

function Project(path::AbstractPath; loaded=Dict{AbstractPath,Project}(), globals=Dict{String,Any}())
    if haskey(loaded, path)
        return loaded[path]
    elseif isfile(path)
        path = abspath(path)
        cd(dirname(path)) do
            path = canonicalize(path)
            env = loadtoml(path, globals)
            env = loadrefs(env)
            tree = loadtree(env, path)
            tree, env = loadtheme(tree, env)
            tree, pages = loadpages(tree, env)
            tree, pages = loaddocs(tree, env, pages)
            loaded[path] = Project(
                path    = path,
                env     = env,
                tree    = tree,
                pages   = pages,
                loaded  = loaded,
                globals = globals,
            )
            return loaded[path]
        end
    else
        ## Raise error only when at 'toplevel' of project creation.
        return isempty(loaded) ? error("not a file: '$path'.") : Project()
    end
end
Project((name, uuid)::Pair; kws...) = Project(findmodule(name, uuid); kws...)
Project(project::Project; kws...) = project
Project(::Nothing; kws...) = nothing

# ## Helper Functions

"""
    findproject(mod)

Returns the path to the configuration file for the module `mod`.

When no path can be found, for example `Base` and it's modules, then `nothing`
is returned instead.
"""
function findproject(mod::Module)
    root = Base.moduleroot(mod)
    meth = first(methods(root.eval))
    file = string(meth.file)
    isabspath(file) || return nothing
    dir = dirname(dirname(realpath(file)))
    for toml in ("Project.toml", "JuliaProject.toml")
        f = joinpath(dir, toml)
        isfile(f) && return f
    end
    return nothing
end
findproject(id::Base.PkgId) = findproject(findmodule(id))

function findmodule(id::Base.PkgId)
    haskey(Base.loaded_modules, id) || Base.require(id)
    return Base.loaded_modules[id]
end
findmodule(name::AbstractString, uuid::AbstractString) = findmodule(Base.PkgId(Base.UUID(uuid), name))
findmodule(env::AbstractDict) = findmodule(env["name"], get(env, "uuid", nothing))
findmodule(name::AbstractString, ::Nothing) = nothing

function findmodules(env::AbstractDict)
    roots = env["publish"]["modules"]
    mods = Set{Module}()
    if isempty(roots)
        mod = findmodule(env)
        mod isa Module && push!(mods, mod)
    else
        for root in roots
            bind = binding(root)
            if Docs.defined(bind)
                push!(mods, Docs.resolve(bind))
            end
        end
    end
    return mods
end

"""
    update!(project)

Reload contents of the given `project`.
"""
function update!(p::Project)
    ## TODO: make this more efficient, only update parts of project that change.
    delete!(p.loaded, p.path)
    q = Project(string(p.path); loaded=p.loaded, globals=p.globals)
    p.path = q.path
    p.env = q.env
    p.tree = q.tree
    p.pages = q.pages
    p.loaded = q.loaded
    p.globals = q.globals
    p.loaded[p.path] = p
    return p
end

function loaddeps!(project::Project)
    @info "loading project dependencies."
    for each in project.env["deps"]
        Project(each; loaded=project.loaded, globals=project.globals)
    end
end
