# mk.bash - a tiny library to create make-like commands.
#
# To use it, create a command file called "mk" in the directory you want.
# The directory should be where you want to run the command with "./mk".
# The command file must source this file.
# It must also define a usage message by calling mk.SetUsage
# and the program name by calling mk.SetProg.
#
# Subcommands are any function that is defined with the prefix "cmd." in the command file.
# You may, of course, define other functions as well,
# but they should not be prefixed unless you want a user to call them.
# Users do not have to call subcommands with the prefix;
# subcommands are prefixed automatically before calling their function.
#
# This library relies on strict mode, which means:
#
# - errors cause execution to stop
# - unset variable reference cause errors, see last point
# - variable expansions are safe and do not require quotes,
# unless dealing with input or newlines:
#   - IFS is set to newline
#   - path expansion (globbing) is disabled
#
# Include the following boilerplate to begin:
#
# ## boilerplate
#
# source ~/.local/libexec/mk.bash 2>/dev/null || { echo 'fatal: mk.bash not found' >&2; exit 1; }
#
# # enable safe expansion
# IFS=$'\n'
# shopt -o noglob
#
# return 2>/dev/null    # stop if sourced, for interactive debugging
# mk.HandleOptions $*   # standard options
# mk.Main ${*:$?+1}     # showtime
#
# Now your script is ready.

# Naming Policy:
#
# All function and variable names are camelCased.
#
# Private function names begin with lowercase letters.
# Public function names begin with uppercase letters.
# Function names are prefixed with "mk." (always lowercase) so they are namespaced.
#
# Local variable names begin with lowercase letters, e.g. localVariable.
#
# Global variable names begin with uppercase letters, e.g. GlobalVariable.
# Since this is a library, global variable names are also namespaced by suffixing them with
# the randomly-generated letter M, e.g. GlobalVariableM.
# Global variables are not public.  Library consumers should not be aware of them.
# If users need to interact with them, create accessor functions for the purpose.
#
# Variable declarations that are name references borrow the environment namespace, e.g.
# "local -n ARRAY=$1".

NL=$'\n'

# mk.Main runs the provided command.
mk.Main () {
  local cmd=cmd.$1  # prefix
  [[ -v ProgM && -v VersionM ]] && echo "$ProgM version $VersionM$NL"
  $cmd ${*:2}
}

Yellow=$'\033[1;33m'
Reset=$'\033[0m'

# mk.Cue runs its arguments as a command after echoing them to stdout in yellow.
mk.Cue() {
  local i args=()
  for (( i = 1; i <= $#; i++ )); do
    printf -v args[i-1] %q "${!i}"
  done

  (IFS=' '; echo "$Yellow${args[*]}$Reset")
  unset -v i args

  "$@"
}

# mk.Glob works the same independent of IFS, noglob and nullglob
mk.Glob() {
  local pattern=$1

  local nullglobWasOn=0 noglobWasOn=1
  [[ $(shopt nullglob) == *on ]] && nullglobWasOn=1 || shopt -s nullglob  # enable nullglob
  [[ $- != *f* ]] && noglobWasOn=0 || set +o noglob                       # disable noglob

  local sep=${IFS:0:1} result
  local results=( $pattern )

  # reset to old settings
  (( noglobWasOn )) && set -o noglob
  (( nullglobWasOn )) || shopt -u nullglob

  mk.Stream "${results[@]}"
}

# mk.HandleOptions provides some standard flags.
# Its return code is the number of arguments processed (removed).
# Call it before enabling strict mode.
mk.HandleOptions() {
  local -i shifts=0
  while [[ ${1:-} == -?* ]]; do
    case $1 in
      -h|--help )     [[ -v UsageM ]] && echo "$UsageM"; exit;;

      -v|--version )  [[ -v ProgM && -v VersionM ]] && echo "$ProgM version $VersionM"; exit;;

      -x|--trace )    set -x;;

      -- )            shift; shifts+=1; break;;

      * )             [[ -v UsageM ]] && echo "$UsageM$NL$NL"; mk.Fatal "unknown option: $1" 2;;
    esac
    shift; shifts+=1
  done

  (( $# > 0 )) || { [[ -v UsageM ]] && echo "$UsageM$NL$NL"; mk.Fatal "at least one argument required." 2; }

  return $shifts
}

mk.SetDebug() {
  case $1 in
    on ) DebugM=1;;
    * ) DebugM=0;;
  esac
}

mk.SetProg() { ProgM=$1; }
mk.SetUsage() { UsageM=$1; }
mk.SetVersion() { VersionM=$1; }

## fp

# mk.Each applies command to each argument from stdin.
mk.Each() {
  local command=$1 arg
  while read -r arg; do
    eval "$command $arg"
  done
}

# mk.KeepIf filters lines from stdin using command.
mk.KeepIf() {
  local command=$1 arg
  while read -r arg; do
    eval "$command $arg" && echo $arg
  done
}

# mk.Map evaluates expression for its output with $varname set to each line from stdin.
mk.Map() {
  local varname=$1 expression=$2
  local $varname
  while read -r $varname; do
    eval "echo \"$expression\""
  done
}

# mk.Stream echoes arguments escaped and separated by the first character IFS.
mk.Stream() {
  local arg
  for arg in "$@"; do
    printf "%q${IFS:0:1}" "$arg"
  done
}

## logging

DebugM=0

# mk.Debug logs a debug message to stderr when $DebugM is set to 1.
mk.Debug() { (( DebugM )) && echo "debug: $1" >&2; }

# mk.Error logs an error message to stderr.
# Works with values containing newline.
mk.Error() { echo "error: $1" >&2; }

# mk.Fatal logs an error message on stderr and exits with result code rc.
mk.Fatal() {
  local msg=$1 rc=${2:-$?}
  echo "fatal: $msg" >&2
  exit $rc
}

mk.Info() { echo "info: $1" >&2; }

