#!/usr/bin/env bash

Prog=$(basename "$0")   # match what the user called
Version=0.1

read -rd '' Usage <<END
Usage:

  $Prog [OPTIONS] [--] COMMAND

  Commands:

  The following commands update report.json:
    cover -- run kcov and record coverage_percent
    lines -- run scc and record code_lines
    test -- run tesht and record results
    stats -- run all three

  Options (if multiple, must be provided as separate flags):

    -h | --help     show this message and exit
    -v | --version  show the program version and exit
    -x | --trace    enable debug tracing
END

## commands

cmd.cover() {
  kcov --include-path mk.bash kcov tesht &>/dev/null
  local filenames=( $(mk.Glob kcov/tesht.*/coverage.json) )
  (( ${#filenames[*]} == 1 )) || { echo 'fatal: could not identify report file'; exit 1; }

  local percent=$(jq -r .percent_covered ${filenames[0]})
  setField coverage_percent ${percent%%.*} report.json
}

cmd.lines() {
  local lines=$(scc -f csv mk.bash | tail -n 1 | { IFS=, read -r language rawLines lines rest; echo $lines; })
  setField code_lines $lines report.json
}

cmd.stats() {
  cmd.cover
  cmd.lines
  local result=$(tesht | tail -n 1)
  setField tests_passing \"$result\" report.json
}

cmd.test() {
  local result=$(tesht | tee /dev/tty | tail -n 1)
  setField tests_passing \"$result\" report.json
}

## helpers

setField() {
  local fieldname=$1 value=$2 filename=$3

  [[ -e $filename ]] || echo {} >$filename
  tmpname=$(mktemp tmp.XXXXXX)
  jq ".$fieldname = $value" $filename >$tmpname && mv $tmpname $filename
}

## globals

## boilerplate

source ~/.local/lib/mk.bash 2>/dev/null || { echo 'fatal: mk.bash not found' >&2; exit 1; }

# enable safe expansion
IFS=$'\n'
set -o noglob

mk.SetProg $Prog
mk.SetUsage "$Usage"
mk.SetVersion $Version

return 2>/dev/null    # stop if sourced, for interactive debugging
mk.HandleOptions $*   # standard options
mk.Main ${*:$?+1}     # showtime
