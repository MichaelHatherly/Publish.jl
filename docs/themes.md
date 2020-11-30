# Custom Themes

Aside from altering the templates and providing your own custom CSS and JS
files you may also create a fully customised theme that does not use any of the
default assets shipped with Publish.

To write your own theme create a folder with the name of your theme and add a
`Theme.toml` file to it.

!!! tip

    Add an underscore at the start of your folder name so that Publish won't
    load it's content automatically. We'll be adding the path manually to your
    `[publish]` section of the project's configuration file.

Add the supporting assets, such as CSS, JS, and Mustache templates to the theme
folder and then reference them in your `_my_theme_folder/Theme.toml` file like so

```toml
theme = "theme_name"

[html]
default_css = ["custom.css"]
default_js = ["custom.js"]
template = {file = "custom_html.mustache"}

[latex]
template = {file = "custom_latex.mustache"}
```

and then in your project's `Project.toml` file add a reference to this folder

```toml
[publish]
theme = "_my_theme_folder"
```

## Contributing

Contributions to the provided themes is encouraged. The default themes, and
their assets, live in a separate repository called [PublishThemes][themes].
They are hosted separately from the main Publish.jl package and are downloaded
via Julia's artifacts system when the package is installed by users. To
contribute please open pull requests against the PublishThemes repository.

[themes]: https://github.com/MichaelHatherly/PublishThemes