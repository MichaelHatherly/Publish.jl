"""
    deploy(
        source, [dir="."], [targets...=html];
        versioned=true,
        named=false,
        force=false,
        label=nothing,
    )

Build the `source` using the given `targets` list in the `dir` directory.
`source` can be either a `Module` or a `String` representing a `Project.toml`
path.

Keyword arguments can be used to control resulting directory structure.

{#keywords}
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

## Examples

In the following examples our project will be the `Publish` package. This can
be switched out for any other project source, such as a Julia package or a
simple `Project.toml` file.

```julia
deploy(Publish, "build")
```

writes the output to the `"build"` subdirectory of the current directory.
There will be a `build/<version>` folder containing HTML content.

```julia
deploy(Publish, "build", pdf)
```

does the same as above, but build the [`pdf`](#) output instead.

```julia
deploy(Publish, "all-docs", pdf, html)
```

or build everything at once.

The keyword arguments control other aspects of the build, as shown
[above](#keywords). For example,

```julia
deploy(Publish, "ecosystem"; named=true)
```

would build `Publish` documentation to an `ecosystem/Publish/<version>`
subdirectory.
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
    p = Project(source; kws...)
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
        versions = sort!(filter(s->!startswith(s, '.') && isdir(s), readdir(dir)); rev=true)
        ## Write a version.js file containing the list of all versions.
        io = IOBuffer()
        println(io, "var PUBLISH_VERSIONS = [")
        for v in versions
            println(io, " "^4, "[", repr(v), ",", repr(abspath(joinpath(root, dir, v, "index.html"))), "],")
        end
        println(io, "];")
        ## Create/update versions.js file for every built version.
        for v in versions
            file = joinpath(dir, v, "versions.js")
            open(file, "w") do f
                println(f, "var PUBLISH_ROOT = '$(abspath(joinpath(root, dirname(file))))';")
                println(f, "var PUBLISH_VERSION = $(repr(v));")
                write(f, seekstart(io))
            end
        end
    end
    return source
end
