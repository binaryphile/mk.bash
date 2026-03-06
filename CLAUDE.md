# Tandem Protocol
@~/projects/tandem-protocol/README.md

# mk.bash

Tiny bash library for creating make-like commands with subcommands.

## Dev

```bash
tesht                     # run tests (uses tesht test runner)
kcov --include-path mk.bash kcov tesht  # coverage
./mk badges              # regenerate all badges
```

## Structure

- `mk.bash` — the library (sourced by consumer scripts)
- `mk` — this project's own mk command (builds badges, runs tests/coverage)
- `mk-example` — example consumer script
- `mk_test.bash` — tests (tesht format)

## Conventions

- Bash naming: functions are `camelCase`, globals `PascalCase`, locals `camelCase`
- Library globals suffixed with `M` for namespacing (e.g. `ProgM`, `UsageM`)
- Public functions prefixed `mk.` with uppercase first letter (e.g. `mk.Main`)
- Private functions prefixed `mk.` with lowercase first letter (e.g. `mk.setNoglob`)
- Subcommands defined as `cmd.NAME` functions by consumers
- Library installed to `~/.local/lib/mk.bash`
- Strict mode: `IFS=$'\n'`, `set -o noglob`
