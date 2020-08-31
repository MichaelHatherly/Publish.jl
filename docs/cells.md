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

## Suppressing Output and Results

You may need a cell's results or computations, but not want to display the
result after that cell. This can be achieved using `output=false` and
`result=false` attributes.

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

