# # Themes

"""
Namespace for all themes that are provided with the package.

Themes defined here should be 0-arity functions that return the absolute path
to the folder containing the theme definition.

Provided themes are currently:

  - [`default`](# "`Themes.default`")
"""
module Themes

using Pkg.Artifacts

"""
The "default" theme used by this package.
"""
const default = artifact"publish_theme_default"

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
    theme = env["publish"]["theme"]
    file = joinpath(path(tree), theme, "Theme.toml")
    if !isfile(file)
        bind = binding(theme)
        dir = joinpath(Docs.defined(bind) ? Docs.resolve(bind) : Themes.default)
        file = joinpath(dir, "Theme.toml")
        isfile(file) || error("'$theme' theme does not exist.")
    end
    dict = TOML.parsefile(string(file))
    env = rmerge(env, Dict("publish" => dict))
    tree′ = FileTree(dirname(file))
    tree′ = FileTrees.load(tree′; lazy=LAZY[]) do file
        loadfile(env, joinpath(basename(tree′), path(file)))
    end
    return merge(tree, rename(tree′, basename(tree))), env
end
