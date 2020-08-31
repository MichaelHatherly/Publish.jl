# # Publish.jl Literate Source Code
#
# This package can use Julia source files as a content source, similar to
# normal markdown files. It uses the same syntax to mark source lines as either
# markdown content or codeblocks. You can read about the details of literate
# Julia files [here](# "Literate Julia").
#
# !!! info "Literate Programming"
#
#     These source file only make use of literate features as a test case for
#     the package. They should not be thought of as a showcase for literate
#     programming itself.
module Publish

# ## Exports

export html, pdf, serve, deploy, setup

# ## Imports

import CommonMark
import DataStructures
import IterTools
import JSON
import LiveServer
import Mustache
import Pkg
import Pkg.TOML
import Requires
import Tectonic

using FilePathsBase
using FileTrees
using Logging

# ## Configuration

const DAGGER = Ref(false)
const LAZY = Ref(true)

# ## Includes

include("projects.jl")
include("themes.jl")
include("load.jl")
include("cells.jl")
include("save.jl")
include("serve.jl")
include("deploy.jl")
include("tools.jl")
include("utilities.jl")

# ## Package Initialisation
#
# Revise.jl is an optional dependency, we use Requires.jl to define a
# [`revise`](#) method when it is available that triggers `Revise.revise`.

function __init__()
    Requires.@require Revise="295af30f-e4ad-537b-8983-00126c2a3abe" begin
        revise(::Project) = Revise.revise()
    end
end

end # module
