# mk.bash - Project-Level Command Scripting

## Overview

`mk.bash` is a minimalistic framework for creating Bash scripts that offer subcommands.
That is to say, it allows you to easily create a script that contains multiple commands that
can be specified at runtime.  For example, if my script is called `mk`, it could offer
`build` and `clean` subcommands that run the appropriate build tools for the project, much
like `make`.

It is useful for grouping sets of related commands, for example, commands that are specific
to a project and working with its files.

Why Bash? With Bash, you don't have limitations on your ability to use the language.  This
makes it friendly to cutting and pasting shell code from web site examples, for example.
Staying close to the shell means having access to the same interface that is available
universally to manage Unix systems, and the power that requires.

`mk.bash` helps you write scripts by handling these concerns:

- a simple convention to define subcommands as regular Bash functions
- strict mode to ensure errors stop execution
- safe expansion mode so variable expansions require less quotation
- built-in `--help`, `--version`, and `--trace` flags
- logging with `mk.debug`, `mk.info`, `mk.error` and `mk.fatal` for consistent output

## Getting Started

### Installation

Copy `mk.bash` to a directory of your choice, such as `~/.local/libexec`.

### Creating a Command Script

1.  Create a script file in your project directory and `chmod +x` it.  Name it what you
    like.  We'll use `mk` for our examples.

3.  Define `$mkUsage` for the usage help message and `$mkProg` for program identity (usually
    basename $0, see example).  `$mkVersion` is optional and, when set, is reported every time
    the program is run.  They are all global variables prefixed with `mk` so as to namespace
    the variables used with `mk.bash`.

4.  Implement subcommands as Bash functions, like `cmd.build()` or `cmd.clean()`.

5.  Ensure the boilerplate is at the end of the script, which sources `mk.bash` and calls
    `mk.bash`'s `mk.main`.  Update the `source` directive with the directory for `mk.bash`.

`mk.main` runs the selected subcommand.  It echoes the program name and version, if defined,
and then runs the subcommand's function.  The subcommand's function is simply the
subcommand name, prefixed with `cmd.`.  This allows you to use subcommand names that
would otherwise conflict with built-in commands you may need, such as `install`.

### Example

``` bash
#!/usr/bin/env bash

mkProg=$(basename "$0")   # use the invoked filename as the program name
mkVersion=0.1

read -rd '' mkUsage <<END
Usage:

  $mkProg clean

  clean -- removes temporary files like build artifacts and cache files.
END

## commands

cmd.clean() {
  # cue echoes the supplied command, then runs it
  mk.cue find . -type f \( -name '*.tmp' -o -name '*.log' -o -name '*.cache' \) -delete
}

## boilerplate

source ~/.local/libexec/mk.bash 2>/dev/null || { echo 'fatal: mk.bash not found' >&2; exit 128; }

# enable safe expansion
IFS=$'\n'
set -o noglob

return 2>/dev/null      # stop execution if sourced, for debugging
mk.handleOptions $*     # standard options
mk.main $*              # showtime
```

## Using Your Script

```bash
$ ./mk clean
find . -type f \( -name '*.tmp' -o -name '*.log' -o -name '*.cache' \) -delete

$ ./mk --help
Usage:

  mk clean

  clean -- removes temporary files like build artifacts and cache files.
```

## Debugging

Use `-x` or `--trace` for tracing.

```bash
$ ./mk -x clean
[trace output not shown]
```

## Utility Functions

### `mk.cue` - Echo and Execute

Displays commands in yellow while running them, to differentiate from command output.

```bash
$ mk.cue echo "Hello, World!"
echo Hello, World! # <- in yellow
Hello, World!
```

### `mk.each` - Apply a Command to Each Line of Input

Takes an argument for a command to run and iterates over each line of input, running the
command with the line as arguments:

```bash
# symlink shell rc files to visible names
mk.each 'ln -sf' <<END
  ~/.bashrc ~/bashrc
  ~/.bash_profile ~/bash_profile
END
```

### `mk.keepif` - Filter Input by Condition

Filter items based on feeding them to a boolean function.

```bash
$ startsWithA() { [[ $1 == a* ]]; }
$ echo -e "apple\nbanana\ncherry" | mk.keepif startsWithA
apple
```

## Debugging & Logging

Output messages on stderr with the log level prepended.

- `mk.debug "message"` (only logs if `$Debug` is defined and is a positive integer)
- `mk.info "message"`
- `mk.error "message"`
- `mk.fatal "message" [exit code]` (exits with error)

## License

This project is open-source under the MIT License.
