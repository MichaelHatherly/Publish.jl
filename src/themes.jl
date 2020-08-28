# # Themes

"""
Namespace for all themes that are provided with the package.

Themes defined here should be 0-arity functions that return the absolute path
to the folder containing the theme definition.

Provided themes are currently:

  - [`default`](# "`Themes.default`")
"""
module Themes

"""
The "default" theme used by this package.
"""
default() = abspath(joinpath(@__DIR__, "..", "_themes", "default"))

end

# ## Theme Loader

"""
    loadtheme(tree, env)

Searches the given `env` configuration for a Publish.jl theme and loads it into
the provided `tree`. Since `tree` is immutable the updated version is returned
along with a new `env` containing any merged data from the theme.

`loadtheme` looks for a `publish.theme` key in the `env` and tries to call the
function defined by the value of the key.

The themes included with this package are listed in the [`Themes`](#) module.
"""
function loadtheme(tree::FileTree, env::AbstractDict)
    name = binding(env["publish"]["theme"])
    root = (Docs.defined(name) ? Docs.resolve(name) : Themes.default)()
    toml = joinpath(root, "Theme.toml")
    isfile(toml) || error("'$toml' theme does not exist.")
    dict = TOML.parsefile(toml)
    env = rmerge(env, Dict("publish" => dict))
    tree′ = FileTree(root)
    tree′ = FileTrees.load(tree′; lazy=LAZY[]) do file
        loadfile(env, joinpath(basename(tree′), path(file)))
    end
    return merge(tree, rename(tree′, basename(tree))), env
end
