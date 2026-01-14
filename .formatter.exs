[
  inputs: [
    "mix.exs",
    ".formatter.exs",
    "config/*.exs",
    "{lib,test}/**/*.{ex,exs}"
  ],
  line_length: 120,
  plugins: [Styler],
  import_deps: [:plug]
]
