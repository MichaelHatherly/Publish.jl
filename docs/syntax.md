# Markdown Syntax

All standard [commonmark][] syntax is supported and provide by the
[CommonMark.jl] package. What follows on this page is a summary of the
additional syntax extensions provided through `Publish`. Refer to the
*commonmark spec* for details on the standard syntax. The extensions that
`Publish` uses are documented in more detail in the [CommonMark.jl][]
README.

[commonmark]: https://commonmark.org/
[CommonMark.jl]: https://www.github.com/MichaelHatherly/CommonMark.jl

## Admonitions

These are specially marked blocks of markdown text that will be rendered
differently to their surrounding text.

```plaintext
!!! <word> "<title>"

    <content>
```

Where `<word>` is a required single word, `<title>` is an optional plain text
title to use with the admonition, and `<content>` is a four-space indented
block of markdown text. When no `<title>` is provided then the `<word>` is
capitalised and used as the title.

Special-cased `<words>` are `info`, `tip`, `warning`, `danger`, and `compat`
which will be rendered in distinct colors.

## Attributes

These are used to assign arbitrary key/value pairs of metadata to any other
markdown element, such as headings, paragraphs, inline formatting, etc.

```markdown
{#id-1 .class-1 one="1"}
# Heading `code`{#id-2 .class-2 two="2"}
```

Block-level attributes apply to the subsequent block. In this case it assigns
the following attributes to the `#` heading.

```toml
id    = "id-1"
class = "class-1"
one   = "1"
```

Inline-level attributes apply to previous element. In this case it assigns the
following attributes to the ``` `code` ``` inline code.

```toml
id    = "id-2"
class = "class-2"
two   = "2"
```

## Auto-Identifiers

This rule assigns page-unique `:id` attributes to all headings by stripping
whitespace, lowercasing, and Unicode transformation. It is modelled on the
behaviour of [Pandoc][]'s auto identifiers.

[Pandoc]: https://pandoc.org

## Citations

Citations can be included using the `@citeid` syntax in the same way as [Pandoc][].

## Footnotes

These can be added on a per-page basis. Cross-document footnotes is not supported.

```plaintext
A paragraph containing[^1] a footnote.

[^1]: The footnote content.
```

Numbers and single word identifiers can be used as footnote names.

# Front Matter

At the start of any markdown file you can add a fenced block of [TOML][] content.

```plaintext
+++
key = "value" # pairs
+++
```

The TOML content is placed between triple `+++` signs at the *very* start of a
file. The TOML parser is the same that is used for parsing your `Project.toml`
files by Pkg.jl.

`Publish` allows you to override some global configuration from your
`[publish]` block in `Project.toml` within your pages' front matter blocks on a
per-page basis.

[TOML]: https://github.com/toml-lang/toml

# LaTeX Maths

Double backticks, ` `` `, are used to write inline LaTeX mathematics. Fenced code
blocks with the language set to `math` are used to write display equations.

~~~plaintext
Inline mathematics ``x = 1``.

```math
f(x) = x
```
~~~

You may also need to use dollar-style syntax for mathematics, such as when
writing Jupyter notebooks that you want to include in your project. Inline
dollar mathematics uses single `$` signs and display mathematics uses double
`$$`.

```plaintext
Inline mathematics $x = 1$.

$$f(x) = x$$
```

!!! warning

    Double `$$` signs for display mathematics must be on a single line and
    cannot span multiple lines.

!!! tip

    You should, by default, use backtick math syntax rather than dollar signs.
    This syntax is only provided to allow for interoperation with documents
    that do not use backticks.

## Raw Content

These block and inline elements can be used to pass raw LaTeX or HTML through
to the resulting output without processing it further. Similar syntax to
the [Attributes](#attributes) above is used.

~~~plaintext
Inline raw `\LaTeX`{=latex}.

```{=html}
<!--a raw block of hmtl-->
```
~~~

!!! info "Note"

    Raw HTML blocks typically don't need to be wrapped in `{=html}` since the
    commonmark parser supports raw HTML tags by default.

## Tables

GitHub-style pipe tables are supported with the same syntax.

```plaintext
| Column One | Column Two | Column Three |
|:---------- | ---------- |:------------:|
| Row `1`    | Column `2` |              |
| *Row* 2    | **Row** 2  | Column ``|`` |
```

## Fancy Typography

The following "punctuation" replacements are made during parsing,

  - double quotes (`"`) are replaced with `“` and `”`,
  - single quotes (`'`) are replaced with  `‘` and `’`,
  - ellipses (`...`) are replace with `…`,
  - double dashes (`--`) is replaced with `–`,
  - and triple dashes (`---`) is replaced with `—`.
