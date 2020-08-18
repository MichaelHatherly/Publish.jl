# Configuration

`Publish` stores all it's configuration data within the `Project.toml` file.
So long as you do not access arbitrary global data and maintain suitable
`[compat]` bounds on packages where needed your `Publish` builds should be
reproducible. If you're needing fully reproducible environments then you should
also be saving the `Manifest.toml` file to track exact versions of
dependencies.  For details on this topic please see the Pkg.jl docs on
[Manifest.toml files][manifest].

[manifest]: https://julialang.github.io/Pkg.jl/v1/toml-files/#Manifest.toml-1

The heart of `Publish`'s configuration is the `[publish]` section of your
`Project.toml` file. This is where everything related to `Publish` is stored.
You've already seen some of it in [action](# "pages-list"). Below we'll go over
what options are available when you need to customise your project.

Some features you can make use of via `Publish`'s configuration:

  - set the `title`, `subtitle`, and `author` of your document,
  - load custom CSS and JavaScript into your HTML,
  - add custom LaTeX preamble content to your PDF documents,
  - used-defined templates for your documents,
  - and numerous other options.

## Common Settings

  - **`title`** --- `String` of the document title.

  - **`subtitle`** --- `String` of the document subtitle.

  - **`authors`** --- `Vector{String}` of author names. This is not the same as
    the `author` key in the root of your package's `Project.toml` and may
    contain a different list of names, or it might be the same.
  
  - **`lang`** --- `String` of the document language. What language is the
    project written in, use [ISO Language Codes][lang-codes].

  - **`keywords`** --- `Vector{String}` of document keywords. Useful for
    categorising your project.

[lang-codes]: https://www.w3.org/International/articles/language-tags/

## HTML-specific

These must be added to a `[publish.html]` section rather than directly to your
`[publish]` section since they are "namespaced" to avoid conflicting with other
keys.

  - **`js`** --- `Vector{String}` of local and remote JavaScript resources that
    you want included in the `<head>` of your HTML pages.

  - **`css`** --- `Vector{String}` similar to the one above for `js`, but for
    CSS instead.

  - **`header`** --- `String` of content to be inserted at the end of the HTML
    page's `<head>`.

  - **`footer`** --- `String` of content to be inserted at the end of the HTML
    page's `<body>`.

If you're adding your own CSS and JavaScript then you may want to completely
disable inclusion of the default files. To do that you can set the following
keys to `[]`, an empty `Vector`.

  - **`default_js`** --- similar to `js`, but the defaults of the provided template.

  - **`default_css`** --- similar to `css`, but the defaults of the provided template.

## PDF-specific

These settings must be added to a `[publish.latex]` section, similar to how the
[HTML](#html-specific) ones above.

!!! tip

    These **aren't** configured in a `[publish.pdf]` section since they apply
    to the underlying LaTeX document rather than the PDF itself.

    If any settings do get added to specifically target the PDF generator then
    they will be added under a new `[publish.pdf]` section in future.

  - **`documentclass`** --- `String` of the LaTeX "document class" to use for
    this document.

  - **`preamble`** --- `String` content to add at the end of the LaTeX document
    preamble. This can include package imports new command definitions and
    package settings that aren't included in the default template.
