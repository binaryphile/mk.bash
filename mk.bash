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
# mk.HandleOptions $*   # standard options, returns 1-based offset
# mk.Main ${*:$?}       # showtime
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
  local output
  printf -v output '%q ' "$@"
  echo "$Yellow${output% }$Reset"

  "$@"
}

mk.dotglobIsOn()  { [[ $(shopt dotglob) == *on ]];  }
mk.noglobIsOn()   { [[ $- == *f* ]];                }
mk.nullglobIsOn() { [[ $(shopt nullglob) == *on ]]; }

mk.setDotglob() {
  case $1 in
    on  ) shopt -s dotglob;;
    *   ) shopt -u dotglob;;
  esac
}

mk.setNoglob()  {
  case $1 in
    on  ) set -o noglob;;
    *   ) set +o noglob;;
  esac
}

mk.setNullglob()  {
  case $1 in
    on  ) shopt -s nullglob;;
    *   ) shopt -u nullglob;;
  esac
}

mk.SetGlobbing() {
  case $1 in
    on )
      mk.setDotglob on
      mk.setNoglob off
      mk.setNullglob on
      ;;
    * )
      mk.setDotglob off
      mk.setNoglob on
      mk.setNullglob off
      ;;
  esac
}

mk.GetGlobState() {
  local dotglobIsOn=0 noglobIsOn=0 nullglobIsOn=0
  mk.dotglobIsOn && dotglobIsOn=1
  mk.noglobIsOn && noglobIsOn=1
  mk.nullglobIsOn && nullglobIsOn=1
  echo "( [dotglob]=$dotglobIsOn [noglob]=$noglobIsOn [nullglob]=$nullglobIsOn )"
}

mk.SetGlobState() {
  local -A states=$1 # double-eval

  (( states[dotglob] == 1 )) && mk.setDotglob on || mk.setDotglob off
  (( states[noglob] == 1 )) && mk.setNoglob on || mk.setNoglob off
  (( states[nullglob] == 1 )) && mk.setNullglob on || mk.setNullglob off
}

# mk.Glob works the same independent of IFS, noglob and nullglob
mk.Glob() {
  local pattern=$1

  local globState=$(mk.GetGlobState)
  mk.SetGlobbing on

  local sep=${IFS:0:1} result
  local results_=( $pattern )   # expansions may contain IFS chars

  mk.SetGlobState $globState
  mk.Stream "${results_[@]}"
}

# mk.HandleOptions provides some standard flags.
# Its return code is the 1-based offset of the first non-option argument,
# suitable for use directly as ${*:$?} in the caller.
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

  return $((shifts + 1))
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

mk.WithGlob() {
  local globState=$(mk.GetGlobState)
  mk.SetGlobbing on
  local IFS=' '
  eval "$*"
  mk.SetGlobState $globState
}

## fp

# mk.Each applies command to each argument from stdin.
mk.Each() {
  local command=$1 arg rc
  while read -r arg; do
    eval "$command $arg"; rc=$?
    (( rc == 130 )) && return 130
  done
}

# mk.KeepIf filters lines from stdin using command.
mk.KeepIf() {
  local command=$1 arg rc
  while read -r arg; do
    eval "$command $arg"; rc=$?
    (( rc == 130 )) && return 130
    (( rc == 0 )) && echo $arg
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

