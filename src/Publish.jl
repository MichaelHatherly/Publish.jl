# # The Publish.jl Literate Source Code
#
# !!! info "A quick note..."
#
#     It's worth pointing out here that your own package doesn't need to follow
#     this style of writing it in a literate way and probably shouldn't. This
#     has been done for [`Publish`](#) so as to test out all of it's available
#     functionality.
#
# Welcome to the [`Publish`](#) package source code. Since [`Publish`](#)
# supports a subset of [Literate.jl][] syntax the source for this package
# itself makes a good test case for it.
#
# [Literate.jl]: https://github.com/fredrikekre/Literate.jl
#
# The content below and on the subsequent pages is all drawn from the source
# code of this package found under the `src/` directory.
#
# Displayed code blocks are the source code of this package and any markdown
# content is a comment line starting with `#`.
#
# Let's start off our exploration of the package with the `Publish` module
# definition as well as a docstring that appears prior to it.
"""
The `Publish` package provides tools for composing [markdown files](#
"Source Types"), [Jupyter Notebooks](#), and [Literate Julia](#) files into
[HTML](# "`html`") and [PDF](# "`pdf`") documents in a declarative and
reproducable way.

`Publish` documents are represented by [`Project`](#) objects that store the
information presented in a `Publish` [configuration](#) file, which also
happens to be the same `Project.toml` file used by Julia's `Pkg` package
manager.

To get started using `Publish` by spinning up a web-server for a package
of your choosing run the following:

```julia-repl
julia> serve(MyPackage)
✓ LiveServer listening on http://localhost:8000/ ...
  (use CTRL+C to shut down)
```

See the [getting started](#) section of the manual for more details.
"""
module Publish

# ## Imports
#
# Below we have all the imported packages that [`Publish`](#) itself uses.
import Base.Iterators
import CommonMark
import HTTP
import IterTools
import JSON
import LiveServer
import Mustache
import OrderedCollections: OrderedDict
import Pkg, Pkg.Artifacts, Pkg.TOML
import Tectonic

# ## Included Files
#
# And also the `include`d files that make up this package.
include("files.jl")
include("projects.jl")
include("targets.jl")
include("docstrings.jl")
include("tools.jl")

# ## Exports
#
# As well as the few functions and types that [`Publish`](#) exports for public
# use.
export serve, html, pdf, setup, deploy

# This is the end of our `src/Publish.jl` source file. The rest of the source
# code can be found by browsing further through this document.
#
# We'll hide the `end` keyword on the last line of this file by using the
# [Attributes](#) syntax provided by the [CommonMark.jl][] package. By writing
#
# ```plaintext
# # {style="display:none"}
# ```
#
# as the last line of a comment block the subsequent code block will not be
# display in the resulting output.
#
# [CommonMark.jl]: https://github.com/MichaelHatherly/CommonMark.jl
#
# {style="display:none"}
end # module
