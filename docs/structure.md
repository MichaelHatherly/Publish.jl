# Project Structure

When a project is composed of multiple pages we need to provide `Publish` with
the order in which we would like to include them in the final document. This
can be done in two distinct ways.

## Table of Contents

Firstly, you can add a `toc.md` file in the same folder as your `Project.toml`
and `README.md` files. Here "toc" stands for table-of-contents. Is provides a
nested structure that describes your page order to `Publish`. For example

```markdown
  * [Introduction](README.md)
  * [Details](docs/details.md)
      * [Public Interface](docs/public.md)
      * [Developer Docs](docs/dev.md)
```

In the above example we've included four `.md` files in our `toc.md` as well as
more friendly titles. All links are relative to the location of your `toc.md`
file, so keep that in mind when linking to files. The layout and formatting
your give your table-of-contents will be reproduced in the navigation menu of
your HTML output, similar to what you'll see if you open the navigation menu in
the top left of this site. For PDF output only the page inclusion *order* is
taken into account since LaTeX provides it's own table-of-contents formatting.

{#complex-layouts}
!!! tip

    It's worth noting that your `toc.md` doesn't need to be a simple nested
    markdown list. If your document layout should be split into two distinct
    lists, each with titles, then do that. For example

    ```markdown
    **Documentation**

      * [Introduction](README.md)
      * [Details](docs/details.md)
          * [Public Interface](docs/public.md)
          * [Developer Docs](docs/dev.md)

    **Examples & Tutorials**

      * [Basics](examples/basics.ipynb)
      * [Advanced](examples/advanced.jl)
    ```

## Pages List

The other option for specifying your document structure is to add some
configuration to your `Project.toml`. Add a section to the end of the file like
the example below

```toml
[publish]
pages = ["README.md", "docs/details.md", "docs/public.md", "docs/dev.md"]
```

!!! warning

    You'll likely have some amount of other information in this file since it's
    used by [Pkg.jl][] to manage your Julia package source code. So long as you
    include all of the `Publish`-specific configuration inside the `[publish]`
    section it won't disturb anything else.

The `pages` key doesn't allow you to define a nested structure or provide
human-readable titles to each page. If you outgrow what is provided by `pages`
then you must switch to using a [`toc.md`](#table-of-contents) instead.

[pkg.jl]: https://julialang.github.io/Pkg.jl

## Special Pages

There's a couple of pages that will appear in your output but that don't exist
within your project's source files. These are the generated docstring pages
(under `docstrings/*.md`) and a docstring index page (found at `docstrings.md`).

!!! tip

    You may want to add `/docstrings.md` to your `toc.md` if you'd like people
    to be able to search through your project's available docstrings. If you'r
    viewing this document in a browser then there should be a link to **Library
    Explorer** in the sidebar navigation menu.
