#!/usr/bin/env bash

NL=$'\n'

source ./mk.bash

test_mk.Cue() {
  ## act

  # run the command and capture the output and result code
  got=$(mk.Cue echo "hello, world!" 2>&1) && rc=$? || rc=$?

  ## assert

  # assert no error
  (( rc == 0 )) || {
    echo "mk.Cue: error = $rc, want: 0$NL$got"
    return 1
  }

  # assert that we got the wanted output

  yellow=$'\E[1;33m'
  reset=$'\E[0m'

  want="${yellow}echo hello\,\ world\!$reset
hello, world!"

  [[ $got == "$want" ]] || {
    echo -e "\nmk.Cue: got doesn't match want:\n$(tesht.Diff "$got" "$want")\n"
    echo "use this line to update want to match this output:${NL}want=${got@Q}"
    return 1
  }
}

test_mk.HandleOptions() {
  # test case parameters

  local -A case1=(
    [name]='accept a no-option argument'

    [args]='one'
    [wantrc]=0
  )

  local -A case2=(
    [name]='require at least one argument'

    [args]=''
    [want]='at least one argument required'
    [wantrc]=2
  )

  local -A case3=(
    [name]='output help with the short option'

    [args]='-h'
    [usage]='sample usage message'
    [want]='sample usage message'
  )

  local -A case3=(
    [name]='output help with the long option'

    [args]='--help'
    [usage]='sample usage message'
    [want]='sample usage message'
  )

  local -A case4=(
    [name]='report version with the short option'

    [args]='-v'
    [prog]='myprog'
    [version]='0.1'
    [want]='myprog version 0.1'
  )

  local -A case5=(
    [name]='report version with the long option'

    [args]='--version'
    [prog]='myprog'
    [version]='0.1'
    [want]='myprog version 0.1'
  )

  local -A case6=(
    [name]='enable tracing with the short option'

    [args]='-x one'
    [want]='+++ shift'
    [wantrc]=1
  )

  local -A case7=(
    [name]='enable tracing with the long option'

    [args]='--trace one'
    [want]='+++ shift'
    [wantrc]=1
  )

  local -A case8=(
    [name]='stop taking options after --'

    [args]='-- --one'
    [wantrc]=1
  )

  local -A case9=(
    [name]='exit if there is an unknown option'

    [args]='-b'
    [want]='unknown option: -b'
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
    unset -v args prog usage version want wantrc    # unset optional fields
    eval "$(tesht.Inherit $casename)"

    [[ -v prog    ]] && mk.SetProg $prog
    [[ -v usage   ]] && mk.SetUsage "$usage"
    [[ -v version ]] && mk.SetVersion $version

    ## act

    # run the command and capture the output and result code
    local got rc
    got=$(eval "mk.HandleOptions $args" 2>&1) && rc=$? || rc=$?

    ## assert

    # assert that we got the wanted result
    [[ -v wantrc ]] || local wantrc=0
    (( rc == wantrc )) || {
      echo "${NL}mk.HandleOptions/$name: rc = $rc, want: $wantrc$NL$got"
      return 1
    }

    [[ -v want ]] && {
      # assert that we got the wanted output
      [[ $got == *"$want"* ]] || {
        echo "${NL}mk.HandleOptions/$name got doesn't match want:$NL$(tesht.Diff "$got" "$want")$NL"
        echo "use this line to update want to match this output:${NL}want=${got@Q}"
        return 1
      }
    }

    return 0
  }

  local failed=0 casename
  for casename in ${!case@}; do
    tesht.Run test_mk.HandleOptions $casename || {
      (( $? == 128 )) && return 128   # fatal
      failed=1
    }
  done

  return $failed
}

test_mk.Each() {
  # test case parameters
  local -A case1=(
    [name]='allow redirection'

    [args]="'wc -c <<<'"
    [fields]=$'a\nab\nabc'
    [want]=$'2\n3\n4'
  )

  local -A case2=(
    [name]='accept empty input gracefully'

    [args]='echo'
    [fields]=''
    [want]=''
  )

  # subtest function to apply test cases
  subtest() {
    local casename=$1

    ## arrange
    eval "$(tesht.Inherit $casename)"

    ## act
    local got rc
    got=$(echo "$fields" | eval "mk.Each $args" 2>&1) && rc=$? || rc=$?

    ## assert

    # assert no error
    (( rc == 0 )) || {
      echo "${NL}mk.Each/$name: error = $rc, want: 0${NL}$got"
      return 1
    }

    # assert that we got the wanted output
    [[ $got == "$want" ]] || {
      echo "${NL}mk.Each/$name got doesn't match want:$NL$(tesht.Diff "$got" "$want")$NL"
      echo "use this line to update want to match this output:${NL}want=${got@Q}"
      return 1
    }

    return 0
  }

  local failed=0 casename
  for casename in ${!case@}; do
    tesht.Run test_mk.Each $casename || {
      (( $? == 128 )) && return 128   # fatal
      failed=1
    }
  done

  return $failed
}

test_mk.KeepIf() {
  isEven() { (( $1 % 2 == 0 )); }

  local -A case1=(
    [name]='keep even numbers'

    [args]='isEven'
    [fields]=$'1\n2\n3\n4'
    [want]=$'2\n4'
  )

  isNonEmpty() { [[ -n ${1:-} ]]; }

  local -A case2=(
    [name]='keep non-empty lines'

    [args]='isNonEmpty'
    [fields]=$'\none\n\ntwo'
    [want]=$'one\ntwo'
  )

  local -A case3=(
    [name]='accept empty input gracefully'

    [args]='true'
    [fields]=''
    [want]=''
  )

  subtest() {
    local casename=$1

    ## arrange
    eval "$(tesht.Inherit $casename)"

    ## act
    local got rc
    got=$(echo "$fields" | eval "mk.KeepIf $args" 2>&1) && rc=$? || rc=$?

    ## assert
    (( rc == 0 )) || {
      echo "${NL}mk.KeepIf/$name: error = $rc, want: 0$NL$got"
      return 1
    }

    [[ $got == "$want" ]] || {
      echo "${NL}mk.KeepIf/$name got doesn't match want:$NL$(tesht.Diff "$got" "$want")$NL"
      echo "use this line to update want to match this output:${NL}want=${got@Q}"
      return 1
    }

    return 0
  }

  local failed=0 casename
  for casename in ${!case@}; do
    tesht.Run test_mk.KeepIf $casename || {
      (( $? == 128 )) && return 128   # fatal
      failed=1
    }
  done

  return $failed
}

test_mk.Map() {
  local -A case1=(
    [name]='prepend text'

    [args]="line 'prefix: \$line'"
    [fields]=$'one\ntwo'
    [want]=$'prefix: one\nprefix: two'
  )

  local -A case2=(
    [name]='convert to uppercase'

    [args]="line '\${line^^}'"
    [fields]=$'one\ntwo'
    [want]=$'ONE\nTWO'
  )

  local -A case3=(
    [name]='accept empty input gracefully'

    [args]="line '\$line'"
    [fields]=''
    [want]=''
  )

  subtest() {
    local casename=$1

    ## arrange
    eval "$(tesht.Inherit $casename)"

    ## act
    local got rc
    got=$(echo "$fields" | eval "mk.Map $args" 2>&1) && rc=$? || rc=$?

    ## assert
    (( rc == 0 )) || {
      echo "${NL}mk.Map/$name: error = $rc, want: 0\n$got"
      return 1
    }

    [[ $got == "$want" ]] || {
      echo "${NL}mk.Map/$name got doesn't match want:$NL$(tesht.Diff "$got" "$want")$NL"
      echo "use this line to update want to match this output:${NL}want=${got@Q}"
      return 1
    }

    return 0
  }

  local failed=0 casename
  for casename in ${!case@}; do
    tesht.Run test_mk.Map $casename || {
      (( $? == 128 )) && return 128   # fatal
      failed=1
    }
  done

  return $failed
}

