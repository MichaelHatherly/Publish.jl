# # Serving

"""
Start a server to present built output of project `src` for the given
`targets`. The actions performed by each `target` are defined by the targets
themselves. The default target used is [`html`](#).
"""
function serve(src, targets...=html; port=8000, keywords...)
    @info "Serving '$src'..."
    old = pwd() # Save directory so it can be returned to in cleanup.
    p = Project(src; keywords...)
    dir = mktempdir()
    sw = LiveServer.SimpleWatcher()
    watch_files!(sw, p)
    callback = function (path) # Callback to update project and rerun
        @info "path: $path"    # given targets.
        revise(p)
        update!(p)
        @sync for f in targets
            @info "target: $f"
            @async f(p, dir)
        end
        watch_files!(sw, p)
    end
    LiveServer.set_callback!(sw, callback)
    LiveServer.start(sw)
    try
        ## Run target-specific initialisation code.
        @sync for f in targets
            @async init(p, f; port=port, dir=dir)
        end
    finally
        ## Cleanup steps.
        LiveServer.stop(sw)
        rm(dir; recursive=true, force=true)
        cd(old) # Reinstate original directory when server is terminated.
    end
end

"""
Set files to watch for changes within a given [`Project`](#) `p`.
"""
function watch_files!(sw::LiveServer.SimpleWatcher, p::Project)
    empty!(sw.watchedfiles) # TODO: proper API for this?
    for file in FileTrees.files(p.tree)
        f = string(path(file))
        LiveServer.is_watched(sw, f) || LiveServer.watch_file!(sw, f)
    end
end

"""
Function for defining the initialisation code called by [`serve`](#)
for a specific target output.

Should be defined for each valid output target, i.e [`html`](#), [`pdf`](#),
etc. Signature should follow the following template:

```julia
function init(project::Project, ::typeof(target); kws...)
    # ...
end
```

where `target` is the `Function` defining the output format.
"""
function init end
