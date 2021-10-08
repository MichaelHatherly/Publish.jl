using Test, Publish

module CellImportedModule
using DataFrames
export imported_dataframe
const imported_dataframe = DataFrame(a=1:4, b=2:5)
end

@testset "Publish" begin
    @testset "Cells" begin
        path = joinpath(@__DIR__, "_projects/cell_tests/Project.toml")
        @test html(path; globals=Dict("publish" => Dict("cell-imports" => [CellImportedModule]))) == path
        @test pdf(path; globals=Dict("publish" => Dict("cell-imports" => [CellImportedModule]))) == path
        mktempdir() do dir
            cd(dir) do
                @test deploy(path, "deploy"; versioned=false, globals=Dict("publish" => Dict("cell-imports" => [CellImportedModule]))) == path
                cd("deploy") do
                    x1 = repr("text/plain", [1, 2])
                    x2 = repr("text/plain", [2, 2])
                    @test occursin(x1, read("README.html", String))
                    @test occursin(x2, read("README.html", String))
                end
            end
        end
    end
    @testset "MIME type display" begin
        path = joinpath(@__DIR__, "_projects/mime_tests/Project.toml")
        @test html(path) == path
        @test pdf(path) == path
    end
    @testset "User Templates" begin
        path = joinpath(@__DIR__, "_projects/user_templates/Project.toml")
        @test html(path) == path
        mktempdir() do dir
            cd(dir) do
                @test deploy(path, "deploy"; versioned=false) == path
                cd("deploy") do
                    @test isfile("README.html")
                    @test isfile("custom.template")
                    @test isfile("search.html")
                    @test isfile("search.json")
                    @test isfile("index.html")
                    @test occursin("<!--user_templates-->", read("README.html", String))
                    @test occursin("<!--user_templates-->", read("search.html", String))
                end
            end
        end
    end
    @testset "Custom Themes" begin
        path = joinpath(@__DIR__, "_projects/theme_test/Project.toml")
        @test html(path) == path
        @test pdf(path) == path
        mktempdir() do dir
            cd(dir) do
                @test deploy(path, "deploy"; versioned=false) == path
                file = joinpath("deploy", "README.html")
                cd("deploy") do
                    @test isfile("README.html")
                    @test isfile("test.css")
                    @test isfile("test.js")
                    @test isfile("search.html")
                    @test isfile("search.json")
                    @test isfile("index.html")
                    @test occursin("<!--test-template-->", read("README.html", String))
                    @test occursin("<!--test-template-->", read("search.html", String))
                end
            end
        end
    end
    @testset "Integration" begin
        version = Publish.Project(Publish).env["version"]
        @test html(Publish) == Publish
        # @test pdf(Publish) == Publish
        mktempdir() do dir
            cd(dir) do
                mkdir("project")
                setup("project"; pkg=false)
                @test isfile(joinpath("project", "Project.toml"))
                @test isfile(joinpath("project", "README.md"))

                @test deploy(Publish, "deploy") == Publish
                @test isfile(joinpath("deploy", version, "index.html"))
                rm("deploy"; recursive=true)

                @test deploy(Publish, "deploy"; named=true) == Publish
                @test isfile(joinpath("deploy", "Publish", version, "index.html"))
                rm("deploy"; recursive=true)

                @test deploy(Publish, "deploy"; versioned=false) == Publish
                @test isfile(joinpath("deploy", "index.html"))
                rm("deploy"; recursive=true)

                @test deploy(Publish, "deploy"; named=true, versioned=false) == Publish
                @test isfile(joinpath("deploy", "Publish", "index.html"))
                rm("deploy"; recursive=true)

                # @test deploy(Publish, "deploy", pdf) == Publish
                # @test isfile(joinpath("deploy", version, "Publish.pdf"))
                # rm("deploy"; recursive=true)

                # @test deploy(Publish, "deploy", pdf, html) == Publish
                # @test isfile(joinpath("deploy", version, "Publish.pdf"))
                # @test isfile(joinpath("deploy", version, "index.html"))
                # rm("deploy"; recursive=true)
            end
        end
    end
    @testset "Virtual Documents" begin
        ex = Publish.Experimental
        p = ex.Project(
            name = "virtual_doc_test",
            publish = (;
                tectonic = (; args = ["-w", "https://ttassets.z13.web.core.windows.net/tlextras-2020.0r0.tar"])
            ),
            ex.Page(
                "# Virtual Document Tests",
                ex.Table(
                    CellImportedModule.imported_dataframe,
                    caption = "imported dataframe",
                    pretty_table = (nosubheader = true,),
                ),
            ),
        )

        deploy(p, "vdoctest", pdf)
        @test isdir("vdoctest")
        isdir("vdoctest") && rm("vdoctest"; force = true, recursive = true)

        deploy(p, "vdoctest", pdf; clean = true)
        @test isdir("vdoctest")
        @test isfile("vdoctest/virtual_doc_test.pdf")
        isdir("vdoctest") && rm("vdoctest"; force = true, recursive = true)
    end
end
