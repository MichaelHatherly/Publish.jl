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

It's now time to move on to the details of how to customise your project in the
[next section](structure.md).
