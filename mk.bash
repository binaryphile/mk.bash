# mk.bash - a tiny library to create make-like commands.
#
# To use it, create a command file called "mk" in the directory you want.
# The directory should be where you want to run the command with "./mk".
# The command file must source this file.
# It must also define a usage message in $Usage,
# and the program name in $Prog.
#
# Subcommands are any function that is defined capitalized in the command file.
# You may, of course, define other functions as well,
# but they should not be capitalized unless you want a user to call them.
# Users do not have to call subcommands with capitalization;
# subcommands are capitalized automatically before calling their function.
#
# This library relies on strict mode, which means:
#
# - errors cause execution to stop
# - unset variable reference cause errors, see last point
# - variable expansions are safe and do not require quotes,
# unless dealing with input or newlines:
#   - IFS is set to newline
#   - globbing is disabled
#
# Include the following boilerplate to begin:
#
# ## boilerplate
#
# source ~/.local/libexec/mk.bash 2>/dev/null || { echo 'fatal: mk.bash not found' >&2; exit 128; }
#
# # enable safe expansion
# IFS=$'\n'
# shopt -o noglob
#
# return 2>/dev/null  # stop if sourced
# handleOptions $*    # standard options
# main ${*:?+1}
#
# Now your script is ready.

# main runs the provided command.
main () {
  local cmd=${1^}   # capitalize
  set -eu           # enable strict mode
  [[ -v Prog && -v Version ]] && echo -e "$Prog version $Version\n"
  $cmd ${*:2}
}

Yellow=$'\033[1;33m'
Reset=$'\033[0m'

# cue runs its arguments as a command after echoing them to stdout in yellow.
# Works with values that have newlines.
cue() {
  local i args=()
  for (( i = 1; i <= $#; i++ )); do
    printf -v args[i-1] %q "${!i}"
  done

  (IFS=' '; echo "$Yellow${args[*]}$Reset")

  "$@"
}

# handleOptions provides some standard flags and returns the remaining arguments.
handleOptions() {
  local -i shifts=0
  while [[ ${1:-} == -?* ]]; do
    case $1 in
      -h|--help )     echo "$Usage"; exit;;

      -v|--version )  echo "$Prog version $Version"; exit;;

      -x|--trace )    set -x;;

      -- )            shift; shifts+=1; break;;

      * )             echo "fatal: unknown option $1"; exit;;
    esac
    shift
    shifts+=1
  done

  (( $# > 0 )) || fatal "at least one argument required.\n\n$Usage" 2

  return $shifts
}

## fp

# each applies command to each argument from stdin.
each() {
  local command=$1 arg
  while IFS='' read -r arg; do
    eval "$command $arg"
  done
}

# keepif filters lines from stdin using expression.
# Lines are stored in the variable name provided for the expression.
# It runs in a subshell so as not to pollute the namespace with $varname.
# Works with values containing newlines.
keepif() (
  local command=$1 arg
  while IFS='' read -r arg; do
    eval "$command $arg" && echo "$arg"
  done
)

## logging

# debug logs a debug message.
debug() { (( Debug )) && echo -e "debug: $1" >&2; }

# error logs an error.
# Works with values containing newline.
error() { echo -e "error: $1" >&2; }

# fatal echoes msg on stderr and exits with code rc.
# Works with values containing newlines.
fatal() {
  local msg=$1 rc=${2:-$?}
  echo -e "fatal: $msg" >&2
  exit $rc
}

info() { echo -e "info: $1" >&2; }

