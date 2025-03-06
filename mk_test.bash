#!/usr/bin/env bash

source ./mk.bash

test_mk.cue() {
  ## act

  # run the command and capture the output and result code
  got=$(mk.cue echo "hello, world!" 2>&1)
  rc=$?

  ## assert

  # assert no error
  (( rc == 0 )) || {
    echo -e "    test_mk.cue: error = $rc, want: 0\n$got"
    return 1
  }

  # assert that we got the wanted output

  yellow=$'\E[1;33m'
  reset=$'\E[0m'

  want="${yellow}echo hello\,\ world\!$reset
hello, world!"

  [[ $got == "$want" ]] || {
    echo -e "    test_mk.cue: got doesn't match want:\n$(t.diff "$got" "$want")\n"
    echo "    got = ${got@Q}"
    return 1
  }
}

test_mk.handleOptions() {
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
    [Usage]='sample usage message'
    [args]='-h'
    [want]='sample usage message'
    [wantrc]=0
  )

  local -A case3=(
    [name]='output help with the long option'
    [args]='--help'
    [Usage]='sample usage message'
    [want]='sample usage message'
    [wantrc]=0
  )

  local -A case4=(
    [name]='report version with the short option'
    [Prog]='myprog'
    [Version]='0.1'
    [args]='-v'
    [want]='myprog version 0.1'
    [wantrc]=0
  )

  local -A case5=(
    [name]='report version with the long option'
    [Prog]='myprog'
    [Version]='0.1'
    [args]='--version'
    [want]='myprog version 0.1'
    [wantrc]=0
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
    unset -v want   # unset optional fields
    eval "$(t.inherit $casename)"

    ## act

    # run the command and capture the output and result code
    local got rc
    got=$(eval "mk.handleOptions $args" 2>&1) && rc=$? || rc=$?

    ## assert

    # assert that we got the wanted result
    (( rc == wantrc )) || {
      echo -e "\ttest_mk.handleOptions/$name: rc = $rc, want: $wantrc\n$got"
      return 1
    }

    [[ -v want ]] && {
      # assert that we got the wanted output
      [[ $got == *"$want"* ]] || {
        echo -e "\ttest_mk.handleOptions/$name got doesn't match want:\n$(t.diff "$got" "$want")\n"
        echo -e "\tgot = ${got@Q}"
        return 1
      }
    }

    return 0
  }

  local failed=0 casename
  for casename in ${!case@}; do
    t.run test_mk.handleOptions $casename || {
      (( $? == 128 )) && return 128   # fatal
      failed=1
    }
  done

  return $failed
}

test_mk.each() {
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
    eval "$(t.inherit $casename)"

    ## act
    local got rc
    got=$(echo "$fields" | eval "mk.each $args" 2>&1) && rc=$? || rc=$?

    ## assert

    # assert no error
    (( rc == 0 )) || {
      echo -e "\ttest_mk.each/$name: error = $rc, want: 0\n$got"
      return 1
    }

    # assert that we got the wanted output
    [[ $got == "$want" ]] || {
      echo -e "\ttest_mk.each/$name got doesn't match want:\n$(t.diff "$got" "$want")\n"
      echo -e "\tgot = ${got@Q}"
      return 1
    }

    return 0
  }

  local failed=0 casename
  for casename in ${!case@}; do
    t.run test_mk.each $casename || {
      (( $? == 128 )) && return 128   # fatal
      failed=1
    }
  done

  return $failed
}


test_mk.keepif() {
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
    eval "$(t.inherit $casename)"

    ## act
    local got rc
    got=$(echo "$fields" | eval "mk.keepif $args" 2>&1) && rc=$? || rc=$?

    ## assert
    (( rc == 0 )) || {
      echo -e "\ttest_mk.keepif/$name: error = $rc, want: 0\n$got"
      return 1
    }

    [[ $got == "$want" ]] || {
      echo -e "\ttest_mk.keepif/$name got doesn't match want:\n$(t.diff "$got" "$want")\n"
      echo "\tgot = ${got@Q}"
      return 1
    }

    return 0
  }

  local failed=0 casename
  for casename in ${!case@}; do
    t.run test_mk.keepif $casename || {
      (( $? == 128 )) && return 128   # fatal
      failed=1
    }
  done

  return $failed
}

test_mk.map() {
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
    eval "$(t.inherit $casename)"

    ## act
    local got rc
    got=$(echo "$fields" | eval "mk.map $args" 2>&1) && rc=$? || rc=$?

    ## assert
    (( rc == 0 )) || {
      echo -e "\ttest_mk.map/$name: error = $rc, want: 0\n$got"
      return 1
    }

    [[ $got == "$want" ]] || {
      echo -e "\ttest_mk.map/$name got doesn't match want:\n$(t.diff "$got" "$want")\n"
      echo -e "\tgot = ${got@Q}"
      return 1
    }

    return 0
  }

  local failed=0 casename
  for casename in ${!case@}; do
    t.run test_mk.map $casename || {
      (( $? == 128 )) && return 128   # fatal
      failed=1
    }
  done

  return $failed
}

