# # Utilities

"""
    sandbox(f, path)

Evaluate the function `f` in the given folder given by `path`. When `path`
does not exist it is created first.
"""
function sandbox end

sandbox(f, ::Nothing) = mktempdir(dir -> cd(f, dir))
sandbox(f, temp::AbstractString) = isdir(temp) ? cd(f, temp) : (mkpath(temp); cd(f, temp))

"""
    init_markdown_parser()

Returns a new `CommonMark.Parser` object with all extensions enabled.
"""
function init_markdown_parser()
    cm = CommonMark
    return cm.enable!(cm.Parser(), [
        ## CommonMark-provided.
        cm.AdmonitionRule(),
        cm.AttributeRule(),
        cm.AutoIdentifierRule(),
        cm.CitationRule(),
        cm.DollarMathRule(),
        cm.FootnoteRule(),
        cm.FrontMatterRule(toml=TOML.parse),
        cm.MathRule(),
        cm.RawContentRule(),
        cm.TableRule(),
        cm.TypographyRule(),
        ## Publish-provided.
        CellRule(), # TODO: insert cache here maybe.
    ])
end

load_markdown(io::IO, parser=init_markdown_parser()) = parser(seekstart(io))
load_markdown(str::AbstractString, parser=init_markdown_parser()) = load_markdown(IOBuffer(str), parser)

function visible_modules(env::AbstractDict)
    roots = env["publish"]["modules"]
    if isempty(roots)
        mod = findmodule(env)
        return mod === nothing ? Set{Module}() : modules(mod)
    else
        set = Set{Module}()
        for root in roots
            bind = binding(root)
            if Docs.defined(bind)
                modules(Docs.resolve(bind), set)
            else
                @warn "module '$root' listed in 'publish.modules' does not exist."
            end
        end
        return set
    end
end

"""
Modules to ignore when searching for available modules.
"""
const IGNORE_LIST = (Main, Base.__toplevel__, Base.MainInclude)

"""
    modules(root)

Returns the set of modules visible from the given `root` module.
"""
modules(root::Module) = union!(modules(root, Set{Module}()), DEFAULT_MODULES)
function modules(root::Module, mods::Set{Module})
    for name in names(root; all=true, imported=true)
        if !Base.isdeprecated(root, name) && isdefined(root, name) && ismodule(root, name)::Bool
            mod = convert(Module, getfield(root, name))
            if !(mod in mods) && !(mod in IGNORE_LIST)
                push!(mods, mod)
                modules(mod, mods)
            end
        end
    end
    return mods
end
@noinline ismodule(m::Module, s::Symbol) = getfield(m, s)::Any isa Module

"""
The set of modules available to all packages.
"""
const DEFAULT_MODULES = modules(Core, modules(Base, Set{Module}()))

"""
    categorise(binding)

Returns the category of a given `Docs.Binding` object `binding`. These
categories are used for displaying details about docstrings.
"""
function categorise(binding)
    ismacro(binding) = startswith(string(binding.var), '@')
    category(other)         = isconst(binding.mod, binding.var) ? "constant" : "global"
    category(obj::Module)   = "module"
    category(obj::DataType) = isconcretetype(obj) ? "struct" : "type"
    category(obj::UnionAll) = isconcretetype(obj) ? "parametric struct" : "parametric type"
    category(obj::Function) = ismacro(binding) ? "macro" : "function"
    return Docs.defined(binding) ? category(Docs.resolve(binding)) : "undefined"
end

"""
Returns the `Docs.Binding` object given an expression or string.
"""
function binding end

function binding(mod::Module, expr::Expr)
    if Meta.isexpr(expr, :.)
        parent = binding(mod, expr.args[1])
        if Docs.defined(parent)
            return binding(Docs.resolve(parent), expr.args[2:end]...)
        end
    end
    return Docs.Binding(mod, nameof(mod))
end
binding(mod::Module, str::AbstractString) = binding(mod, Meta.parse(str; raise=false))
binding(mod::Module, symbol::Symbol) = Docs.Binding(mod, symbol)
binding(mod::Module, quot::QuoteNode) = Docs.Binding(mod, quot.value)
binding(mod, other...) = Docs.Binding(mod, nameof(mod))
binding(str::AbstractString) = binding(Main, str)
binding(mod::Module) = binding(mod, nameof(mod))

function printdoc(io::IO, docstr)
    for part in docstr.text
        Docs.formatdoc(io, docstr, part)
    end
    return io
end

"""
    rmerge(ds...)

Recursively merge the `Dict`s provided in `ds`. Last argument wins when
conflicts occur.
"""
rmerge(ds::AbstractDict...) = merge(rmerge, ds...)
rmerge(args...) = last(args)

function try_touch(default::Function, f::FileTree, idx)
    try
        f[idx][]
    catch err
        f = touch(f, idx; value=default())
    end
    return f
end

const IGNORE_PATHS = r"^[^\.\_]"
const CODE_FENCE = '~'^10

function page_neighbours(pages::AbstractVector)
    flat = Iterators.flatten((Ref(first(pages)), pages, Ref(last(pages))))
    part = IterTools.partition(flat, 3, 1)
    return Dict(x => (prev=p, next=n) for (p, x, n) in part)
end

"""
    with_extension(path, ext)

Return a path with the extension set to `ext`.
"""
function with_extension end

with_extension(p::AbstractString, ext) = "$(first(splitext(p))).$ext"
with_extension(p::AbstractPath, ext) = with_extension(string(p), ext)

"""
    relative_paths(func, project, file)

Rewrite any file paths within a [`Project`](#)'s `.env` to be relative to the
given `file` and pass then to the `func` argument for evaluation.
"""
function relative_paths(func, p::Project, file::AbstractString)
    ## Configuration replacement walker functions.
    with_replacement(f, v) = v
    with_replacement(f, v::Union{AbstractString,AbstractPath}) = f(v)
    with_replacement(f, xs::Vector{T}) where T = T[with_replacement(f, x) for x in xs]
    with_replacement(f, dict::T) where T <: AbstractDict = T(k => with_replacement(f, v) for (k, v) in dict)
    ## Rewrite configuration paths.
    pub′ = with_replacement(p.env["publish"]) do value
        hasfile(p.tree, value) ? relpath(string(value), dirname(joinpath(".", file))) : value
    end
    return func(pub′)
end
relative_paths(f, p::Project, path::AbstractPath) = relative_paths(f, p, string(path))

"""
    revise(project)

When Revise.jl is loaded in the current session trigger `Revise.revise`.
"""
revise(project) = nothing

function hasfile(tree::FileTree, path)
    ## TODO: needs real API here.
    try
        tree[path]
    catch err
        return false
    end
    return true
end

"""
    frontmatter(ast)

Returns a `Dict` containing the front matter content of a markdown `ast`. When
no front matter is found then an empty `Dict` is returned.
"""
function frontmatter(ast::CommonMark.Node)
    CommonMark.isnull(ast.first_child)           && return Dict{String,Any}()
    ast.first_child.t isa CommonMark.FrontMatter && return ast.first_child.t.data
    return Dict{String,Any}()
end

## Needed by latex engine since it doesn't like windows paths.
if Sys.iswindows()
    unix_style_path(path) = unix_joinpath(splitpath(path)...)
else
    unix_style_path(path) = path
end
function unix_joinpath(path::AbstractString, paths::AbstractString...)::String
    for p in paths
        if isabspath(p)
            path = p
        elseif isempty(path) || path[end] == '/'
            path *= p
        else
            path *= "/" * p
        end
    end
    return path
end
unix_joinpath(path::AbstractString) = path
