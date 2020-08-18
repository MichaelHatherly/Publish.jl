# Templates

You can also completely replace the default HTML and LaTeX templates that
`Publish` uses with your own ones. This can be done with the `publish.html.template.file`
and `publish.latex.template.file` keys. You'll need to create specific 
sections within your `Project.toml` to add them, like so

```toml
[publish.html.template]
file = "custom-template.html"

[publish.latex.template]
file = "custom-tempalte.tex"
```

If you're going to write your own templates then having a read through then
defaults will probably help you out a bit. They can be found in the
`src/templates` directory of this package.
