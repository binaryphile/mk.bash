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
# You must let mk.bash process arguments before you do with the line:
#
#     Args=( "$@" ); processArgs; set -- "${Args[@]}"; unset -v Args
#
# Finally, call main "$@" and your script is ready to run.
#
# Some variables are made available to your script (don't redefine
# these unless you know what you're doing):
#   Tab - a tab character
#   Nl - a newline character
#   IFS - set to newline
#
# This library disables word-splitting (by setting IFS to newline) and
# globbing so you can reference any variables that
# don't contain newlines (i.e. most variables with known values)
# without the need for double-quotes.
Version=0.0.3

# main runs the provided command.
main () {
  cmd=${1^}   # capitalize
  shift

  $cmd "$@"
}

# announce runs a command after echoing it to stdout.
# It can only echo arguments as it receives them,
# so quotation marks that disambiguate the original command
# may be missing when echoed.
# Doesn't work on pipelines or other compound commands,
# or any non-argument token.
announce() {
  echo "$@"

  "$@"
}

# processArgs handles standard flags.
# It uses a global array for handling values without losing field separators.
processArgs() {
  set -- "${Args[@]}"

  echo "$Prog version $Version$Nl"

  case ${1:-} in
    -h|--help ) echo "$Usage"; exit;;

    --version ) exit;;

    --trace ) shift; set -x;;
  esac

  (( $# )) || { echo "Error: at least one argument required.$Nl$Nl$Usage"; exit 2; }

  Args=( "$@" )
}

set -o noglob
Tab=$'\t'
Nl=$'\n'
IFS=$Nl

