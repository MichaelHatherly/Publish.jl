# Cell Tests

{cell}
```julia
using DataFrames
@assert imported_dataframe isa DataFrame
imported_dataframe
```

{cell}
```julia
Table(imported_dataframe)
```
