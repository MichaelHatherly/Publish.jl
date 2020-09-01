# MIME type display tests

Import the plotting package:

{cell=plotting}
```julia
using Plots
```

Make a nice plot, with a caption below:

{#plot cell=plotting}
```julia
plot(cumsum(randn(100)))
```
{style="text-align:center;font-size:small"}
**Caption:** *A nice plot.*

Import the `DataFrames` library:

{cell=df}
```julia
using DataFrames, RDatasets
```

Create a `Dataframe` with some data, and look at some of it:

{cell=df}
```julia
iris = dataset("datasets", "iris")
first(iris, 5)
```

And also look at the end:

{cell=df}
```julia
last(iris, 5)
```
