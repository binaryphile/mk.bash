#!/usr/bin/env bash

IFS=$'\n'
set -o noglob

NL=$'\n'

source ./mk.bash

test_mk.Cue() {
  ## act

  # run the command and capture the output and result code
  got_=$(mk.Cue echo 'hello, world!' 2>&1) && rc=$? || rc=$?

  ## assert

  # assert no error
  (( rc == 0 )) || {
    echo "mk.Cue: error = $rc, wantLines: 0$NL$got_"
    return 1
  }

  # assert that we got the wanted output

  yellow=$'\E[1;33m'
  reset=$'\E[0m'

  wantLines="${yellow}echo hello\,\ world\!$reset
hello, world!"

  [[ $got_ == "$wantLines" ]] || {
    echo "${NL}mk.Cue: got_ doesn't match wantLines:$NL$(tesht.Diff "$got_" "$wantLines")$NL"
    echo "use this line to update wantLines to match this output:${NL}wantLines=${got_@Q}"
    return 1
  }
}

test_mk.Main_unknownCommand() {
  ## arrange

  # cmd.known registers one real subcommand, so the dispatcher's miss is not vacuous.
  cmd.known() { :; }

  ## act
  local got_
  local -i rc
  got_=$(mk.Main bogus 2>&1) && rc=$? || rc=$?

  ## assert
  tesht.AssertRC $rc 1
  tesht.AssertGot "$got_" 'fatal: unknown command: bogus'
}

test_mk.HandleOptions() {
  # test case parameters

  local -A case1=(
    [name]='accept a no-option argument'

    # mk.HandleOptions returns a shift-offset (shifts consumed + 1), never a
    # plain boolean -- zero options consumed still returns 1, the offset
    # `main "${@:$?}"` needs to skip past zero args. See bash-style-guide
    # §pipefail's "return-offset option parsers" note.
    [args]='one'
    [wantrc]=1
  )

  local -A case2=(
    [name]='require at least one argument'

    [args]=''
    [wantLines]='at least one argument required'
    [wantrc]=2
  )

  local -A case3=(
    [name]='output help with the short option'

    [args]='-h'
    [usageLines]='sample usage message'
    [wantLines]='sample usage message'
  )

  local -A case3b=(
    [name]='output help with the long option'

    [args]='--help'
    [usageLines]='sample usage message'
    [wantLines]='sample usage message'
  )

  local -A case4=(
    [name]='report version with the short option'

    [args]='-v'
    [prog]='myprog'
    [version]='0.1'
    [wantLines]='myprog version 0.1'
  )

  local -A case5=(
    [name]='report version with the long option'

    [args]='--version'
    [prog]='myprog'
    [version]='0.1'
    [wantLines]='myprog version 0.1'
  )

  local -A case6=(
    [name]='enable tracing with the short option'

    # 1 option shifted (-x) -> shift-offset 2, not the option count itself.
    [args]='-x one'
    [wantLines]='+++ shift'
    [wantrc]=2
  )

  local -A case7=(
    [name]='enable tracing with the long option'

    [args]='--trace one'
    [wantLines]='+++ shift'
    [wantrc]=2
  )

  local -A case8=(
    [name]='stop taking options after --'

    # 1 shift for `--` itself -> shift-offset 2.
    [args]='-- --one'
    [wantrc]=2
  )

  local -A case9=(
    [name]='exit if there is an unknown option'

    [args]='-b'
    [wantLines]='unknown option: -b'
    [wantrc]=2
  )

  # subtest is the the test code run against the test cases.
  # command is the command under test.
  # casename is the name of an associative array holding at least the key "name".
  # Each subtest that needs a directory creates it in /tmp.
  subtest() {
    local casename=$1

    ## arrange

    # create variables from the keys/values of the test case map
    unset -v args prog usageLines version wantLines wantrc    # unset optional fields
    eval "$(tesht.Inherit $casename)"

    [[ -v prog    ]] && mk.SetProg $prog
    [[ -v usageLines   ]] && mk.SetUsage "$usageLines"
    [[ -v version ]] && mk.SetVersion $version

    ## act

    # run the command and capture the output and result code
    local got_ rc
    got_=$(eval "mk.HandleOptions $args" 2>&1) && rc=$? || rc=$?

    ## assert

    # assert that we got the wanted result
    [[ -v wantrc ]] || local wantrc=0
    (( rc == wantrc )) || {
      echo "${NL}mk.HandleOptions/$name: rc = $rc, wantLines: $wantrc$NL$got_"
      return 1
    }

    [[ -v wantLines ]] && {
      # assert that we got the wanted output
      [[ $got_ == *"$wantLines"* ]] || {
        echo "${NL}mk.HandleOptions/$name got_ doesn't match wantLines:$NL$(tesht.Diff "$got_" "$wantLines")$NL"
        echo "use this line to update wantLines to match this output:${NL}wantLines=${got_@Q}"
        return 1
      }
    }

    return 0
  }

  tesht.Run ${!case@}
}

test_mk.Each() {
  # test case parameters
  local -A case1=(
    [name]='allow redirection'

    [args]="'wc -c <<<'"
    [fieldsLines]=$'a\nab\nabc'
    [wantLines]=$'2\n3\n4'
  )

  local -A case2=(
    [name]='accept empty input gracefully'

    [args]='echo'
    [fieldsLines]=''
    [wantLines]=''
  )

  # subtest function to apply test cases
  subtest() {
    local casename=$1

    ## arrange
    eval "$(tesht.Inherit $casename)"

    ## act
    local got_ rc
    got_=$(echo "$fieldsLines" | eval "mk.Each $args" 2>&1) && rc=$? || rc=$?

    ## assert

    # assert no error
    (( rc == 0 )) || {
      echo "${NL}mk.Each/$name: error = $rc, wantLines: 0$NL$got_"
      return 1
    }

    # assert that we got the wanted output
    [[ $got_ == "$wantLines" ]] || {
      echo "${NL}mk.Each/$name got_ doesn't match wantLines:$NL$(tesht.Diff "$got_" "$wantLines")$NL"
      echo "use this line to update wantLines to match this output:${NL}wantLines=${got_@Q}"
      return 1
    }

    return 0
  }

  tesht.Run ${!case@}
}

test_mk.KeepIf() {
  isEven() { (( $1 % 2 == 0 )); }

  local -A case1=(
    [name]='keep even numbers'

    [args]='isEven'
    [fieldsLines]=$'1\n2\n3\n4'
    [wantLines]=$'2\n4'
  )

  isNonEmpty() { [[ -n ${1:-} ]]; }

  local -A case2=(
    [name]='keep non-empty lines'

    [args]='isNonEmpty'
    [fieldsLines]=$'\none\n\ntwo'
    [wantLines]=$'one\ntwo'
  )

  local -A case3=(
    [name]='accept empty input gracefully'

    [args]='true'
    [fieldsLines]=''
    [wantLines]=''
  )

  local -A case4=(
    [name]='succeeds even when the LAST line fails the predicate'

    # Regression case: mk.KeepIf's while-loop body used to leave a false
    # arithmetic test as its final per-iteration statement whenever the
    # predicate failed, which becomes the function's own return code if
    # that's the last line processed. An explicit `return 0` after the
    # loop fixes this; this case fails loudly (rc != 0) if it regresses.
    [args]='isNonEmpty'
    [fieldsLines]=$'one\n'
    [wantLines]='one'
  )

  subtest() {
    local casename=$1

    ## arrange
    eval "$(tesht.Inherit $casename)"

    ## act
    local got_ rc
    got_=$(echo "$fieldsLines" | eval "mk.KeepIf $args" 2>&1) && rc=$? || rc=$?

    ## assert
    (( rc == 0 )) || {
      echo "${NL}mk.KeepIf/$name: error = $rc, wantLines: 0$NL$got_"
      return 1
    }

    [[ $got_ == "$wantLines" ]] || {
      echo "${NL}mk.KeepIf/$name got_ doesn't match wantLines:$NL$(tesht.Diff "$got_" "$wantLines")$NL"
      echo "use this line to update wantLines to match this output:${NL}wantLines=${got_@Q}"
      return 1
    }

    return 0
  }

  tesht.Run ${!case@}
}

test_mk.Map() {
  local -A case1=(
    [name]='prepend text'

    [args]="line 'prefix: \$line'"
    [fieldsLines]=$'one\ntwo'
    [wantLines]=$'prefix: one\nprefix: two'
  )

  local -A case2=(
    [name]='convert to uppercase'

    [args]="line '\${line^^}'"
    [fieldsLines]=$'one\ntwo'
    [wantLines]=$'ONE\nTWO'
  )

  local -A case3=(
    [name]='accept empty input gracefully'

    [args]="line '\$line'"
    [fieldsLines]=''
    [wantLines]=''
  )

  subtest() {
    local casename=$1

    ## arrange
    eval "$(tesht.Inherit $casename)"

    ## act
    local got_ rc
    got_=$(echo "$fieldsLines" | eval "mk.Map $args" 2>&1) && rc=$? || rc=$?

    ## assert
    (( rc == 0 )) || {
      echo "${NL}mk.Map/$name: error = $rc, wantLines: 0$NL$got_"
      return 1
    }

    [[ $got_ == "$wantLines" ]] || {
      echo "${NL}mk.Map/$name got_ doesn't match wantLines:$NL$(tesht.Diff "$got_" "$wantLines")$NL"
      echo "use this line to update wantLines to match this output:${NL}wantLines=${got_@Q}"
      return 1
    }

    return 0
  }

  tesht.Run ${!case@}
}

test_mk.Shellcheck() {
  # boundary-mock shellcheck to capture the argv mk.Shellcheck composes
  # (blank line before the def keeps SC9007 from reading this as its docstring).

  shellcheck() { local IFS=' '; echo "$*"; }

  ## act
  local got_
  got_=$(mk.Shellcheck a.bash b.bash)

  ## assert -- convention-only (--include the SC9xxx vocabulary, base checks off:
  ## no --exclude / no --severity), plugin loaded, gcc format, files forwarded
  [[ $got_ == *"--include=SC9001,SC9002,SC9003,SC9004,SC9005,SC9006,SC9007,SC9008,SC9009,SC9010"* ]] || {
    echo "mk.Shellcheck: convention-only --include missing; got_: $got_"
    return 1
  }
  [[ $got_ == *"--plugin-dir "* && $got_ == *"-f gcc a.bash b.bash"* ]] || {
    echo "mk.Shellcheck: expected --plugin-dir + gcc format + files; got_: $got_"
    return 1
  }
}

