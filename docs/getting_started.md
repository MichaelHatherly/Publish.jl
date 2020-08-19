# Getting Started

{#serving-publish}
You might have a `Publish` server running at the moment, pointed at
`Publish`'s own documentation. If not you can start one with

```julia-repl
julia> using Publish

julia> serve(Publish)
✓ LiveServer listening on http://localhost:8000/ ...
  (use CTRL+C to shut down)
```

Don't forget to install `Publish` first using `Pkg.add`. You can leave this
server running while we walk through creating your own project. Choose one
of the options below that best describes your needs:

1.  **Julia package authors:**

    The easiest way to get started with `Publish` if you're a Julia package author
    is to import your package and then [`serve`](#) it with `Publish` like we've done
    [above](#serving-publish). `Publish` will look for the `Project.toml` for your
    package and use it to serve your project. You should have a `README.md` as part
    of your package, which is what `Publish` will initially read since you've not
    specified anything else for it to find.

2.  {#step-two}
    **Everyone else:**

    If you've not got a Julia package that you'd like to document then don't
    worry about it --- `Publish` is still perfect for your needs. Run the following

    ```julia-repl
    julia> using Publish

    julia> setup("<directory>")
    ```

    where `<directory>` is the path to the directory containing the prose you'd
    like to use.

    If you've not got anything written yet, that's fine too. Just point `setup`
    at an empty directory. `Publish` will name your new project based on the
    directory's name.

You're now ready to start serving a project and working on it. If it's a
package that you're working on use

```julia-repl
julia> using Publish, MyPackage

julia> serve(MyPackage; port=8001)
✓ LiveServer listening on http://localhost:8001/ ...
  (use CTRL+C to shut down)
```

!!! info "Assigning a port"

    We've set the keyword `port=8001` since we've still got the other server
    running with `Publish`'s documentation. If you've only got one server going
    then you don't need to worry about `port`.

If you've got a non-package project setup from [above](#step-two) then just use
the command it printed out to run. Something like

```julia-repl
julia> serve("<path to Project.toml>"; port=8001)
✓ LiveServer listening on http://localhost:8001/ ...
  (use CTRL+C to shut down)
```

That's all you need to get started. Open that `localhost` link in a browser of
your choice, edit your `README.md`, and save it. You'll see the changes reflect
in the browser soon afterwards.

# I was promised PDFs

Correct, `Publish` doesn't just produce HTML websites. PDF output is also
available.  You don't have to change anything with your `Project.toml` or
`README.md` to get it working either. Just change your `serve` call slightly,

```julia-repl
julia> serve(MyPackage, pdf)
```

This might take longer on your first run since `Publish` needs to download
the support files needed by LaTeX to build your document. You should get
plenty of informative output in the REPL to tell you what's happening.

Once it's finished compiling the PDF it should get opened in your default PDF
viewer. If your viewer supports auto-updates then when you make changes to
`README.md` is should be reflected automatically in the PDF.

If you're greedy and want both `pdf` and `html` then just run

```julia-repl
julia> serve("<path to Project.toml>", pdf, html; port=8001)
```

## Publishing

If you're writing documentation for a package you'll probably want to host it
online somewhere in HTML form for potential users to browse through before they
decide whether to install it or not. Even if what you're writing isn't a Julia
package the following guide can be applied to it.

`Publish` provides the function [`deploy`](#) for the purpose of creating
output that is suitable for hosting online. This is similar in spirit to
`Documenter`'s function that goes by same name.

The [`deploy`](#) function is "layered" on top of [`html`](#) and [`pdf`](#),
just as [`serve`](#) is also a "layer" on top of these simpler functions.
Whereas [`serve`](#) is meant for local use, [`deploy`](#) is intended for use
building documents for hosting online --- though it can be used locally as well
if you'd like to see what it produces.

When you run `deploy` it will create a folder in the current directory named
after the `version` field found in `Project.toml` containing the built HTML
documentation. For example,

```julia-repl
julia> deploy(Publish)
```

will build the HTML project defined by the `Publish` package in a folder named
after the current `Publish` version in the current directory. You can adjust
these settings a fair amount. See the [`deploy`](#) docs for details.

!!! info "Choosing a hosting service"

    For this part of the guide we'll be using GitHub for building and hosting,
    but there is nothing in [`deploy`](#) that is *specific* to GitHub and it
    should work fine on any other kind of service.

We'll be using GitHub Actions and Pages to make building and deploying simple
and straightforward. It's assumed that you've already got your source code
hosted on a public GitHub repository.

First, create a `gh-pages` branch for your repository. Delete *all* the
contents of this branch and then commit and push your changes to GitHub. Switch
back to your main development branch.

Next we'll need a GitHub Actions workflow file. If you ran the [`setup`](#)
function [earlier](# "step-two") then you'll already have a
`.github/workflows/Publish.yml`. If not then run that now to add the file.
Open it up in an editor and find the line with

```plaintext
julia --project=.. -e 'using Publish, USER; deploy(USER; root="/USER.jl", label="dev")'
```

and edit the `USER` to be what is needed to build your project correctly. The
keywords used by [`deploy`](#) here are `root` and `label`:

  - `root` specifies a "root" path for all deployed documentation. Since we're
    using GitHub Pages to host your documentation it'll be hosted at
    `<username>.github.io/<pkg>.jl/`. We need to tell [`deploy`](#) about this
    otherwise it'll set the root to `<username>.gitgub.io/` which won't point
    to the correct place.

  - `label` is used to assign a "tracking" folder that follows any changes you
    make, rather than just being an immutable version folder. In this case we
    are deploying when changes are pushed to `master` and so the "tracking"
    folder is `dev` which follows `Documenter`'s naming scheme.

    !!! tip

        You can change this to whatever you want. For example you could create
        a separate actions file that runs when new releases are published to
        your repository and have that build your project in a `stable` folder
        to track your most recent stable documentation.

Once you've committed and pushed these changes to GitHub it will start building
your project on every commit to `master`. Read the [Actions][] documentation
for more details on what you can change.

[Actions]: https://docs.github.com/en/actions

It's now time to move on to the details of how to customise your project in the
[next section](structure.md).
