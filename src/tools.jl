# # Tools
#
# Utility functions that aren't needed directly for [`Project`](#)s, but are
# still useful for users.

"""
    setup(dir)

Initialise a `Publish` project in the given directory `dir`, which is created
if it does not already exist.

When `dir` has a Julia project structure with a `Project.toml` file then
`Publish` is added to it's dependencies list, otherwise, if it is not a Julia
package then a `Project.toml` file is created as well as a `README.md` file.
"""
function setup(dir)
    isdir(dir) || mkpath(dir)
    cd(dir) do
        _, name = splitdir(pwd())
        ## Project setup.
        proj = "Project.toml"
        if isfile(proj)
            @info "found '$proj'. Using it."
        else
            @info "no '$proj' found. Creating one."
            uuid = string(Base.identify_package("Publish").uuid)
            toml = """
            name = "$name"

            [deps]
            Publish = "$uuid"
            """
            write(proj, toml)
        end
        @info "Activating and instantiating '$proj'."
        ## Pkg.activate(proj) # TODO
        ## Pkg.instantiate() # TODO
        @info "Adding 'Publish' to project dependencies."
        ## Pkg.add("Publish") # TODO
        ## Content setup.
        readme = "README.md"
        if isfile(readme)
            @info "found '$readme'."
        else
            @info "no '$readme' found, creating one."
            write(readme, "# $name\n")
        end
        path = joinpath(pwd(), proj)
        @info "run `serve(Project($(repr(path))))` to start a server."
    end
end

# [`deploy`](#) is for use as the equivalent to Documenters `deploy`, but
# without the network interaction ---  that should be provided separately.

"""
    deploy(
        source, dir, [targets...];
        versioned=true,
        named=false,
        force=false,
        label=nothing,
    )

Build the `source` using the given `targets` list in the `dir` directory.
`source` can be either a `Module` or a `String` representing a `Project.toml`
path.

Keyword arguments can be used to control resulting directory structure.

  - `versioned` and `named`.

    These keywords will place the built files in either a versioned subdirectory,
    or a named subdirectory of `dir`, or both (with name superceding version).

    The values for `name` and `version` are taken from those provided in the
    project's `Project.toml` file. If these values are not specified then the
    "deployment" will fail.

  - `force` will remove the calculated build path prior to building
    if it already exists.

  - `label` specifies a temporal folder name to copy the finished build to.
    This can be used to build a "tracking" version of documentation such as a
    "dev" or "stable" that changes over time while still retaining the exact
    versioned builds.
"""
function deploy(
    source,
    dir::AbstractString=".",
    targets...=html;
    versioned::Bool=true,
    named::Bool=false,
    force::Bool=false,
    label::AbstractString="",
    root::AbstractString="/",
    kws...
)
    startswith(root, '/') || error("'root' keyword must be an absolute path.")
    p = from_source(source)
    name = named ? p.env["name"] : ""
    version = versioned ? p.env["version"] : ""
    parts = filter(!isempty, [dir, name, version])
    path = joinpath(parts...)
    force && rm(path; recursive=true, force=true)
    if isdir(path)
        @warn "'$path' already exists. Use force to overwrite it."
    else
        for target in targets
            target(p, path)
        end
    end
    if !isempty(label)
        ## Build the project for the given `label` as well.
        to = joinpath(filter(!isempty, [dir, name, label])...)
        rm(to; recursive=true, force=true)
        for target in targets
            target(p, to)
        end
    end
    if versioned
        ## Find the current versions.
        dir = joinpath(filter(!isempty, [dir, name])...)
        versions = sort!(filter(s->!startswith(s, '.'), readdir(dir)); rev=true)
        ## Write a version.js file containing the list of all versions.
        io = IOBuffer()
        println(io, "const PUBLISH_VERSIONS = [")
        for v in versions
            println(io, " "^4, "[", repr(v), ",", repr(abspath(joinpath(root, dir, v, "index.html"))), "],")
        end
        println(io, "];")
        ## Create/update versions.js file for every built version.
        for v in versions
            file = joinpath(dir, v, "versions.js")
            open(file, "w") do f
                println(f, "const PUBLISH_ROOT = '$(abspath(joinpath(root, dirname(file))))';")
                println(f, "const PUBLISH_VERSION = $(repr(v));")
                write(f, seekstart(io))
            end
        end
    end
    return source
end
