# Publish.jl

*A universal document authoring package for [Julia][julia].*

<!--written as raw html to avoid including these in the generated PDFs-->
<a href="https://travis-ci.org/MichaelHatherly/Publish.jl"><img src="https://travis-ci.org/MichaelHatherly/Publish.jl.svg?branch=master" alt="Build Status" /></a>
<a href="https://codecov.io/gh/MichaelHatherly/Publish.jl"><img src="https://codecov.io/gh/MichaelHatherly/Publish.jl/branch/master/graph/badge.svg" alt="codecov" /></a>

> **Disclaimer**
>
> Currently this package should be regarded as experimental --- a proving
> ground for new features for the Julia documentation ecosystem rather than
> a mature and proven piece of software. If you need a solution that will
> definitely work, look at [Documenter.jl][] instead.

[documenter.jl]: https://juliadocs.github.io/Documenter.jl/stable/

This is a package for [Julia][] that provides a general framework for writing
prose --- technical documentation is it's focus, though it is general enough to
be applied to any kind of written document.

Some standout features:

  - built-in live server to view your changes in real-time,
  - uses a fully-compliant [commonmark][] parser, [CommonMark.jl][],
  - produces HTML and PDF files natively, no LaTeX dependencies to manage yourself,
  - publication-quality PDF generation uses [tectonic][] for self-contained, reproducible builds,
  - combine markdown files, [Jupyter][] notebooks, and Julia files for your content,
  - and declarative configuration built on top of Julia's [Pkg.jl][] package manager.

`Publish` can scale from single pages all the way to large cross-referenced
multi-project documents.

To jump straight in and begin using `Publish` run the following in your Julia REPL:

```julia-repl
pkg> add Publish

julia> using Publish

julia> serve(Publish)
✓ LiveServer listening on http://localhost:8000/ ...
  (use CTRL+C to shut down)
```

The above will install `Publish`, import it, and then start up a local
web-server for `Publish`'s own documentation --- the content you're reading
right now. Open the link in your web browser and then continue on to the next
section, [Getting Started](docs/getting_started.md).

[commonmark]: https://commonmark.org/
[CommonMark.jl]: https://www.github.com/MichaelHatherly/CommonMark.jl
[Julia]: https://www.julialang.org
[Jupyter]: https://jupyter.org/
[tectonic]: https://tectonic-typesetting.github.io/en-US/
[pkg.jl]: https://julialang.github.io/Pkg.jl
