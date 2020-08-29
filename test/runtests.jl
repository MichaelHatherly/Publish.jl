using Test, Publish

test_theme() = joinpath(@__DIR__, "_projects", "theme_test", "_theme")

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
                    @test contains(read("README.html", String), "<!--test-template-->")
                    @test contains(read("search.html", String), "<!--test-template-->")
                end
            end
        end
    end
    @testset "Integration" begin
        @test html(Publish) == Publish
        @test pdf(Publish) == Publish
        mktempdir() do dir
            cd(dir) do
                mkdir("project")
                setup("project"; pkg=false)
                @test isfile(joinpath("project", "Project.toml"))
                @test isfile(joinpath("project", "README.md"))

                @test deploy(Publish, "deploy") == Publish
                @test isfile(joinpath("deploy", "0.1.0", "index.html"))
                rm("deploy"; recursive=true)

                @test deploy(Publish, "deploy"; named=true) == Publish
                @test isfile(joinpath("deploy", "Publish", "0.1.0", "index.html"))
                rm("deploy"; recursive=true)

                @test deploy(Publish, "deploy"; versioned=false) == Publish
                @test isfile(joinpath("deploy", "index.html"))
                rm("deploy"; recursive=true)

                @test deploy(Publish, "deploy"; named=true, versioned=false) == Publish
                @test isfile(joinpath("deploy", "Publish", "index.html"))
                rm("deploy"; recursive=true)

                @test deploy(Publish, "deploy", pdf) == Publish
                @test isfile(joinpath("deploy", "0.1.0", "Publish.pdf"))
                rm("deploy"; recursive=true)

                @test deploy(Publish, "deploy", pdf, html) == Publish
                @test isfile(joinpath("deploy", "0.1.0", "Publish.pdf"))
                @test isfile(joinpath("deploy", "0.1.0", "index.html"))
                rm("deploy"; recursive=true)
            end
        end
    end
end
