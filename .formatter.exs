[
  inputs: [
    "mix.exs",
    ".formatter.exs",
    "config/*.exs",
    "lib/**/*.ex"
  ],
  line_length: 120,
  plugins: [Styler],
  import_deps: [:plug]
]
