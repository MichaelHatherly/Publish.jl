using Test, Publish

@testset "Publish" begin
    @test html(Publish) == Publish
    @test pdf(Publish) == Publish
    mktempdir() do dir
        cd(dir) do
            mkdir("project")
            setup("project")
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
