# Executable "Cells"

Not all content you'll want to write is static. Sometimes you may want to
generate content on the page using code. Publish handles this in a similar way
to packages such as Documenter (and others).

Julia code blocks are marked for execution using [attribute](# "Attributes")
syntax.

````markdown
{cell=name}
```julia
using DataFrames
df = DataFrame(A = 1:4, B = cumsum(1:4))
```
````

The key/value attribute `cell=name` "namespaces" the cell under a unique
`Module` called `name`. Other cells on the *same page* can use the same name to
share the namespace. Cells are evaluated top to bottom on each page. To use a
unique namespace you can use the shorthand syntax `{:cell}`:

````markdown
{:cell}
```julia
fac(n) = n < 2 ? n : n * fac(n - 1)
fac(10)
```
````

All output to `stdout` and `stderr` during the evaluation of a cell is captured
and, if any is actually produced, is displayed immediately below the cell in a
code block. The final value, so long as it is not `nothing`, of a cell is
displayed below this in a suitable format for the given output ([`html`](#) or
[`pdf`](#)).

````markdown
{:cell}
```julia
@info "print a message..."
```
````

Below is an example of the evaluation of the cell above.

{:cell}
```julia
@info "print a message..."
```

## `MIME` types

Many types in Julia will already have the required `show` methods defined to
display the type as either `"text/html"` or `"text/latex"`. `DataFrames` is an
example of this --- if the result of a cell is a `DataFrame` then is will
correctly render an HTML table or a LaTeX tabular environment in the output
document since the package defines the needed `show` method.

Some types you want to print may not come with a predefined `show` method. In
these cases the textual representation defined by the `"text/plain"` `show`
method will be used to print the result.

!!! tip

    If a package provides a type that you'd like to display from a cell then
    it's best practise to define the `show` method within that package so that
    it "owns" the method rather than defining it yourself.

## Markdown `MIME` type

If a type captured in the result of a cell has a `show` method defined for the
`MIME` type `text/markdown` then it will immediately be printed to this
representation and then re-parsed by the markdown parser and embedded within
the document's AST rather as a "dumb" value. This allows, for example,
generated internal document links to be resolved correctly.

If your type has suitable `show` definition, but you do not want to display as
the AST then pass `markdown=false` as a cell attribute to use the normal
display procedures instead.

## Suppressing Input, Output, and Results

You may need a cell's results or computations, but not want to display the
result after that cell. This can be achieved using

  - `display=false` to remove the cell itself from the final document,
  - `output=false` to skip showing the `stdout` and `stderr` streams below the cell,
  - `result=false` to suppress showing the resulting output value from the cell.

````markdown
{cell=example output=false result=false}
```julia
f(x) = @show x
f(1)
```
````

Below is an example of the cell above.

{cell=example output=false result=false}
```julia
f(x) = @show x
y = f(1)
```

And then a cell that prints the value of `y`, but does not display it's result.

{cell=example result=false}
```julia
@show y
```

## Figures

Some results may have common requirements for their display within a finished document,
such as displaying an image within a figure environment in a PDF document. Cells provide
a default imported type called `Figure` which can wrap any type to provide some control
over how it will be displayed.

!!! info

    Currently this is only supported for LaTeX/PDF output. HTML figure environments will
    be added later.

Figures can be created as follows:

````markdown
{cell}
```julia
p = plot(...)
Figure(
    p;
    caption = "This is the caption text.",
)
```
````

Supported keywords, along with their default values, are:

  - `placement = 'h'`: where on the page the figure should to be placed.
  - `alignment = "center"`: horizontal alignment of the figure.
  - `maxwidth = "\\linewidth"`: the maximum width that the image should take up.
  - `caption = ""`: a simple caption to go with the figure.
  - `desc = ""`: a short description to use in a *List of Figures*.

## Tables

Similar to `Figure` discussed above, we also have a `Table` object imported by default
into cells that can be used to format tabular data in a more presentable way. Under the
hood it uses `PrettyTables.jl` for the formatting.

!!! info

    Currently this is only supported for LaTeX/PDF output. HTML table environments will
    be added later.

Tables can be created as follows:

````markdown
{cell}
```julia
df = DataFrame(...) # Or any other "table"-like object that PrettyTables supports.
Table(
    df;
    caption = "This is the caption text.",
)
```
````

Supported keywords, along with their default values, are:

  - `placement = "h"`: where on the page to place the table.
  - `alighment = "center"`: horizontal alighment of the table.
  - `caption = ""`: a simple caption to go with the figure.
  - `desc = ""`: short description to use in a *List of Tables*.