# mk.bash - a tiny library to create make-like commands.
#
# To use it, create a command file called "mk" in the directory you want.
# The directory should be where you want to run the command with "./mk".
# The command file must source this file.
# It must also define a usage message in $mkUsage,
# and the program name in $mkProg.
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
# mk.handleOptions $*   # standard options
# mk.main ${*:$?+1}     # showtime
#
# Now your script is ready.

# mk.main runs the provided command.
mk.main () {
  set -eu           # enable strict mode
  local cmd=cmd.$1  # prefix
  [[ -v mkProg && -v mkVersion ]] && echo -e "$mkProg version $mkVersion\n"
  $cmd ${*:2}
}

Yellow=$'\033[1;33m'
Reset=$'\033[0m'

# mk.cue runs its arguments as a command after echoing them to stdout in yellow.
mk.cue() {
  local i args=()
  for (( i = 1; i <= $#; i++ )); do
    printf -v args[i-1] %q "${!i}"
  done

  (IFS=' '; echo "$Yellow${args[*]}$Reset")
  unset -v i args

  "$@"
}

# mk.handleOptions provides some standard flags.
# Its return code is the number of arguments processed (removed).
# Call it before enabling strict mode.
mk.handleOptions() {
  local -i shifts=0
  while [[ ${1:-} == -?* ]]; do
    case $1 in
      -h|--help )     [[ -v mkUsage ]] && echo "$mkUsage"; exit;;

      -v|--version )  [[ -v mkProg && -v mkVersion ]] && echo "$mkProg version $mkVersion"; exit;;

      -x|--trace )    set -x;;

      -- )            shift; shifts+=1; break;;

      * )             [[ -v mkUsage ]] && echo -e "$mkUsage\n\n"; mk.fatal "unknown option: $1" 2;;
    esac
    shift; shifts+=1
  done

  (( $# > 0 )) || { [[ -v mkUsage ]] && echo -e "$mkUsage\n\n"; mk.fatal "at least one argument required." 2; }

  return $shifts
}

## fp

# mk.each applies command to each argument from stdin.
mk.each() {
  local command=$1 arg
  while read -r arg; do
    eval "$command $arg"
  done
}

# mk.keepif filters lines from stdin using command.
mk.keepif() {
  local command=$1 arg
  while read -r arg; do
    eval "$command $arg" && echo $arg
  done
}

# mk.map evaluates expression for its output with $varname set to each line from stdin.
mk.map() {
  local varname=$1 expression=$2
  local $varname
  while read -r $varname; do
    eval "echo \"$expression\""
  done
}

## logging

# debug logs a debug message to stderr when $Debug is set to 1.
mk.debug() { (( Debug )) && echo -e "debug: $1" >&2; }

# error logs an error message to stderr.
# Works with values containing newline.
mk.error() { echo -e "error: $1" >&2; }

# mk.fatal logs an error message on stderr and exits with result code rc.
mk.fatal() {
  local msg=$1 rc=${2:-$?}
  echo -e "fatal: $msg" >&2
  exit $rc
}

mk.info() { echo -e "info: $1" >&2; }

