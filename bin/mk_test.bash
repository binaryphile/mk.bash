#!/usr/bin/env bash

IFS=$'\n'
set -o noglob

# Resolve this repo's own bin/mk regardless of tesht's cwd handling
# (tesht's eval-based sourcing makes $BASH_SOURCE unreliable -- see
# tesht.md §"Script discovery"; $TESHT_TEST_FILE is the documented fix).
BinMk=$(dirname "$TESHT_TEST_FILE")/mk

source "$BinMk" 2>/dev/null || { echo "fatal: $BinMk not found" >&2; exit 1; }

# noDiscovery scopes cmd.check-drift's estate-wide discovery pass away
# from the real filesystem -- a nonexistent root makes the grep a fast
# no-op instead of scanning ~/projects and ~/icarus on every test run
# (slow, and dependent on the real estate's current drift state).
noDiscovery() { DiscoveryRoots=("/tmp/mk-check-drift-test-no-such-root"); }

# mkFixtureDir builds a temp dir containing a canonical mk.bash copy plus
# the shapes cmd.check-drift needs to distinguish: a symlink site, an
# identical-copy site, and a diverged-copy site. Writes the dir path into
# the caller-supplied out-param (nameref convention: UPPERCASE).
mkFixtureDir() {
  local -n FIXTURE_DIR=$1
  tesht.MktempDir FIXTURE_DIR

  # symlink-site points at the REAL canonical mk.bash (cmd.check-drift's
  # own "safe" comparison is against $PWD/mk.bash, not a fixture copy).
  ln -sf "$PWD/mk.bash" "$FIXTURE_DIR/symlink-site.bash"
  cp "$PWD/mk.bash" "$FIXTURE_DIR/identical-site.bash"
  cp "$PWD/mk.bash" "$FIXTURE_DIR/diverged-site.bash"
  echo '# intentional drift for the diverged-site fixture' >>"$FIXTURE_DIR/diverged-site.bash"
}

test_cmdCheckDrift_symlinkSite_reportsOk() {
  local dir_
  mkFixtureDir dir_
  noDiscovery

  # KnownSites is a global cmd.check-drift reads (see bin/mk); plain
  # assignment here (no `local`) sets it for this test's cmd.check-drift
  # call, inherited into the $(...) subshell below.
  KnownSites=("$dir_/symlink-site.bash")

  local got_
  got_=$(cmd.check-drift 2>&1)

  [[ $got_ == *"OK    $dir_/symlink-site.bash: symlink to canonical"* ]] || {
    echo "${NL}cmd.check-drift/symlink site: got doesn't match want:$NL$got_"
    return 1
  }
}

test_cmdCheckDrift_identicalCopy_reportsOk() {
  local dir_
  mkFixtureDir dir_
  noDiscovery

  KnownSites=("$dir_/identical-site.bash")

  local got_
  got_=$(cmd.check-drift 2>&1)

  [[ $got_ == *"OK    $dir_/identical-site.bash: identical to canonical"* ]] || {
    echo "${NL}cmd.check-drift/identical copy: got doesn't match want:$NL$got_"
    return 1
  }
}

test_cmdCheckDrift_divergedCopy_reportsDrift() {
  local dir_
  mkFixtureDir dir_
  noDiscovery

  KnownSites=("$dir_/diverged-site.bash")

  local got_ rc
  got_=$(cmd.check-drift 2>&1) && rc=$? || rc=$?

  (( rc != 0 )) || {
    echo "${NL}cmd.check-drift/diverged copy: rc = 0, want: nonzero"
    return 1
  }

  [[ $got_ == *"DRIFT $dir_/diverged-site.bash: "*" diff lines vs canonical"* ]] || {
    echo "${NL}cmd.check-drift/diverged copy: got doesn't match want:$NL$got_"
    return 1
  }
}

test_cmdCheckDrift_missingSite_warnsAndFails() {
  noDiscovery
  KnownSites=("/tmp/does-not-exist-$$.bash")

  local got_ rc
  got_=$(cmd.check-drift 2>&1) && rc=$? || rc=$?

  (( rc != 0 )) || {
    echo "${NL}cmd.check-drift/missing site: rc = 0, want: nonzero"
    return 1
  }

  [[ $got_ == *"WARN  /tmp/does-not-exist-$$.bash: does not exist"* ]] || {
    echo "${NL}cmd.check-drift/missing site: got doesn't match want:$NL$got_"
    return 1
  }
}
