# Unstable features, preview status. May change at any time.
module Experimental

import ..Publish
import ..Publish.Objects: Figure, Table
import TOML

export Page, Project, Figure, Table, deploy

"""
    Page(blocks...)

Virtual page contents in a markdown file. Each block can be either a `String`,
which is interpreted as markdown text and directly embedded in the page, or any
other value, which will be embedded in a `{cell}` block.
"""
struct Page
    blocks::Vector{Any}
    Page(blocks...) = new(collect(blocks))
end

Base.show(io::IO, ::Page) = print(io, "$Page(...)")

"""
    Project(pages...; config...)

Virtual Publish project object for programmatically building a document.
`pages` can be any number of `Page` objects. `config` is any number of keyword
arguments which is used to build the generated project's `Project.toml`.
"""
struct Project
    pages::Vector{Page}
    config::Dict
end

function Project(pages...; config...)
    # Convert the nested `config` into `Dict{String,Any}` structure that can be
    # saved as a TOML file.
    _nt_dict(ps::Iterators.Pairs) = Dict(string(k) => _nt_dict(v) for (k, v) in ps)
    _nt_dict(nt::NamedTuple) = Dict(string(k) => _nt_dict(v) for (k, v) in pairs(nt))
    _nt_dict(d::Dict) = Dict(string(k) => _nt_dict(v) for (k, v) in d)
    _nt_dict(other) = other

    config = _nt_dict(config)
    get!(config, "name", "Project") # Ensure that name exists.
    return Project(collect(pages), config)
end

Base.show(io::IO, ::Project) = print(io, "$Project(...)")

"""
    deploy(project::Project, out, formats...)

Build a Publish project from the given "virtual" `project` object.  Output is
built in `out` directory, which is either an absolute path or relative to the
present working directory. `formats` is the list of formats to build in `out`:
`pdf` and `html` are supported.
"""
function Publish.deploy(p::Project, out::AbstractString, formats...)
    out = isabspath(out) ? out : joinpath(pwd(), out)
    sandbox() do
        project = "Project.toml"
        open(project, "w") do io
            TOML.print(io, p.config)
        end
        # Build a table of contents for the virtual Pages.  Print out the
        # contents as well for each Page and capture the cell values for
        # evaluation.
        toc = "toc.md"
        __CELLS__ = []
        open(toc, "w") do toc_io
            for (n, page) in enumerate(p.pages)
                println(toc_io, "  - [$n]($n.md)")
                open("$n.md", "w") do page_io
                    for block in page.blocks
                        if isa(block, String)
                            println(page_io, block)
                        else
                            push!(__CELLS__, block)
                            cell =
                                """
                                {:cell display = false output = false}
                                ```julia
                                __CELLS__[$(length(__CELLS__))]
                                ```
                                """
                            println(page_io, cell)
                        end
                    end
                end
            end
        end
        # Make the cell values available to the cells.
        mod = Module()
        Core.eval(mod, :(export __CELLS__; __CELLS__ = $__CELLS__))
        globals = Dict("publish" => Dict("cell-imports" => [mod]))

        # Build and deploy the generated project.
        Publish.deploy(
            project,
            out,
            formats...;
            force = true,
            versioned = false,
            globals = globals,
        )
    end
    return out
end

sandbox(f) = mktempdir(dir -> cd(f, dir))

end
