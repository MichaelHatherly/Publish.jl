using Test, Publish

@testset "Publish" begin
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
        @test pdf(Publish) == Publish
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

                @test deploy(Publish, "deploy", pdf) == Publish
                @test isfile(joinpath("deploy", version, "Publish.pdf"))
                rm("deploy"; recursive=true)

                @test deploy(Publish, "deploy", pdf, html) == Publish
                @test isfile(joinpath("deploy", version, "Publish.pdf"))
                @test isfile(joinpath("deploy", version, "index.html"))
                rm("deploy"; recursive=true)
            end
        end
    end
end
