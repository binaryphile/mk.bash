# Tandem Protocol
@~/icarus/tandem-protocol/README.md

# mk.bash

Tiny bash library for creating make-like commands with subcommands.

## Dev

```bash
tesht                     # run tests (uses tesht test runner)
kcov --include-path mk.bash kcov tesht  # coverage
mk badges                # regenerate badges (bin/mk; .envrc puts bin/ on PATH)
```

## Structure

- `mk.bash` — the library (sourced by consumer scripts)
- `bin/mk` — this project's own mk command (builds badges, runs tests/coverage)
- `mk-example` — example consumer script
- `mk_test.bash` — tests (tesht format)

## Conventions

- Bash naming: functions are `camelCase`, globals `PascalCase`, locals `camelCase`
- Library globals suffixed with `M` for namespacing (e.g. `ProgM`, `UsageM`)
- Public functions prefixed `mk.` with uppercase first letter (e.g. `mk.Main`)
- Private functions prefixed `mk.` with lowercase first letter (e.g. `mk.setNoglob`)
- Subcommands defined as `cmd.NAME` functions by consumers
- Library installed to `~/.local/lib/mk.bash`
- Strict mode: `IFS=$'\n'` and `set -o noglob` ABOVE the sourcing guard;
  `set -euo pipefail` BELOW it. `-e` above the guard aborts at the guard's own
  top-level `return` on the executed path, silently no-opping every invocation.
- `mk.HandleOptions` returns a 1-based arg OFFSET as its exit status, so
  consumers capture it as `mk.HandleOptions "$@" && Offset=$? || Offset=$?`
  followed by `mk.Main "${@:$Offset}"`. `!` also suppresses `-e` but inverts
  the status, collapsing every offset to 0. See README "Strict mode in the
  boilerplate".
