"""
    setup(dir)

Initialise a `Publish` project in the given directory `dir`, which is created
if it does not already exist.

When `dir` has a Julia project structure with a `Project.toml` file then
`Publish` is added to it's dependencies list, otherwise, if it is not a Julia
package then a `Project.toml` file is created as well as a `README.md` file.

## Keywords

  - `pkg::Bool=true` can be set to `false` to disable all `Pkg` calls during
    use of `setup`.
"""
function setup(dir; pkg=true)
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
        if pkg
            @info "Activating and instantiating '$proj'."
            Pkg.activate(proj)
            Pkg.instantiate()
            @info "Adding 'Publish' to project dependencies."
            Pkg.add("Publish")
        end
        ## Content setup.
        readme = "README.md"
        if isfile(readme)
            @info "found '$readme'."
        else
            @info "no '$readme' found, creating one."
            write(readme, "# $name\n")
        end
        ## Create github actions workflow.
        action = ".github/workflows/Publish.yml"
        if isfile(action)
            @warn "This project already has a 'Publish.yml' workflow."
        else
            @info "Creating a GitHub Actions workflow for deployment."
            mkpath(dirname(action))
            contents = read(joinpath(@__DIR__, "templates", "Publish.yml"), String)
            open(action, "w") do handle
                write(handle, contents)
            end
        end
        ## Display a message for users to help them start a server.
        path = joinpath(pwd(), proj)
        @info "run `serve(Project($(repr(path))))` to start a server."
    end
end
