# Source Types

Up until now we've been using markdown files for our source content --- those
ending with `.md`. `Publish` also allows using several other file types to be
used in place of markdown files, so long as the text is formatted as markdown.

## Jupyter Notebooks

Notebook files, those ending with `.ipynb`, can be imported in the same way as
`.md` files in your `toc.md` or `pages = ` configuration. They will behave in
the exact same way.

Saving your notebooks within a normal Jupyter session will be reflected in your
`Publish` server just like it is when saving normal markdown files.

!!! info

    All source code cells are treated a `julia` code blocks in the resulting
    `Publish` output.

## Literate Julia

Julia source code can also be read by `Publish`. The syntax used is a stripped
down version of that available in [Literate.jl][]. All the source code for this
package is available for browsing within this document, via the *Source Code*
section in the navigation menu. To summarise,

  - lines starting with a single `#`, with any amount of leading whitespace is
    treated as a line of markdown content,
  - lines with a double `##` are treated as a normal comment and the output
    will have one `#` stripped from it,
  - other lines are treated as source code and not modified,
  - none of the code blocks are executed,
  - `Publish` does not currently support Literate.jl's filters such as `#md`,
    `#jl`, `#nb`, `#-`, or `#+`,
  - `#src` unconditional filtering is supported. Any line containing `#src`
    will be stripped from the output.

!!! tip

    `Publish` should play nicely with [Revise.jl][] and simply importing
    `Revise` prior to `Publish` and your own package will be enough to allow
    for Revise-style development when using `Publish`.

[Literate.jl]: https://fredrikekre.github.io/Literate.jl/
[Revise.jl]: https://timholy.github.io/Revise.jl/stable/
