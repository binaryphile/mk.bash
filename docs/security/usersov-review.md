# UserSov Phase-3 Review of mk.bash

Phase-3 tooling-sweep review of mk.bash against `usersov-framework-guide.md`, per icarus #70311
(task icarus #78873). 8th review in the sweep, following era (#77716), agent-orchestration
(#77881), tandem-protocol (#77992), dotfiles (#78013), dojo (#78047), jeeves (jeeves #78292), and
evtctl (era #78537). Follows the guide's 8-block grading-payload contract (§10).

**Process note**: full cross-vendor `/grade` round run this cycle (operator choice, despite the
session's 0%-budget signal) — 3 rounds: R1 SEND BACK (Grade C+ / Posture B / Remediation C+) on
an incomplete consumer/copy inventory; R2 GAP REMAINS (Grade B+ / Posture A- / Remediation B+) on
4 narrow closure items; R3 APPROVE (Grade A-). The R1 round is the reason this review carries a
4th threat record (MK-S4) that the initial draft missed entirely — see Block 4.

**Remediation update (mk.bash#78891, 2026-08-03)**: MK-S4-CURL-EVAL-FALLBACK is now REMEDIATED. All
5 originally-identified consumers (task.bash, fluentfp, tandem-protocol, tmux-claude, cascadia's
`bin/mk`) plus a 6th site found via an estate-wide search during IMPL grading
(`cascadia/bin/orchestrator`, not a `bin/mk` file) had the curl|eval fallback removed and replaced
with the hard-fatal pattern already used by finances/bin/mk, dotfiles/mk, era/bin/evtctl, and
era/bin/era. 2 additional live instances in active feature-branch worktrees were also fixed
directly rather than deferred. Verified estate-wide: `grep -rln` for the raw GitHub URL across
`~/projects`, `~/icarus`, `~/dotfiles`, `~/digi` returns zero hits after remediation; each fixed
script still sources correctly when the local library is present, and correctly hard-fails (no
network fetch attempted) when it is absent OR present-but-corrupted. The "Accepted risk" bullet
below is annotated inline; the Block 7 grade narrative describes the PRE-remediation state and is
left as the historical record of what was reviewed and graded.

**Remediation update (mk.bash#78877, 2026-08-03)**: MK-S1-CUE-ARGV-DISCLOSURE disposition recorded
as a documented warning (the finding's own accepted alternative to a redaction pass). `mk.Cue`'s
docstring and the README's Utility Functions section both now carry an explicit security warning
mirroring the existing `--trace` warning's style; no redaction was implemented (a deny-list
redaction can never be complete, and no known consumer currently passes secrets through `mk.Cue`).

**Remediation update (mk.bash#78879, 2026-08-03)**: MK-S3-VENDORED-COPY-DRIFT addressed with
`mk check-drift` (`bin/mk`'s own `check-drift` command). Investigation found the risk surface
narrower than the finding assumed: `~/.local/lib/mk.bash` is a symlink to canonical, so every
`bin/mk` consumer sources it safely and cannot drift; `era/lib/mk.bash` is the one confirmed real
vendored copy (96 lines diverged). The command diffs known vendored-copy sites against canonical
and does a best-effort estate-wide grep for any undeclared site defining `mk.HandleOptions()`.
Live-verified: flags `era/lib/mk.bash`'s existing drift, reports a symlink site as safe, and flags
a freshly-diverged test copy. No sync mechanism was built (out of scope, and each vendored copy may
have intentional local additions) -- this is detection, not automatic reconciliation.

**Scope framing note**: mk.bash is a foundational library with almost no data flows of its own
(no stores, no network calls, no telemetry, no credential handling — confirmed via full source
read). The review's substance is therefore concentrated at the boundary between mk.bash and its
consumers: what a consumer script can be induced to disclose or execute through the library's own
designed behavior, and how the library itself propagates (or fails to propagate) across the
estate.

## Block 1 — Trigger, scope, profile, priorities

**Trigger**: Phase-3 tooling sweep (icarus #70311); mk.bash is the 8th of ~14 tools.

**Scope**: mk.bash's own implementation (`mk.bash:1-320`, complete), its default behavior with
zero consumer configuration, and — because mk.bash is a sourced library rather than a standalone
executable — an exhaustive inventory of how every known consumer sources and uses it. Out of
scope: implementing any of the 4 identified remediation capabilities (review cycle, not a fix
cycle, matching prior reviews in this sweep).

**Profile**: Class H (standard professional/developer — the estate's operator).

**Class H modulations, applied throughout**:

- **Workplace-exposure priority** (custodial actor): any credential or workplace-identifying
  content passed as an argument through `mk.Cue` or exposed via `--trace` becomes visible to
  whatever captures stdout/stderr (terminal scrollback, session transcripts, CI logs).
- **Long-horizon aggregation priority** (provider actor): N/A directly — mk.bash has no provider
  exit of its own. Becomes live only through MK-S4 (a consumer's network-fetch fallback), where
  the "provider" is effectively whoever controls the fetched branch's content.
- **Moderate acceptable residual risk on availability-vs-confidentiality tradeoffs**: mk.bash's
  own design explicitly favors developer ergonomics (unquoted echo of arguments so the operator
  can see exactly what ran) over confidentiality — the same trade-off dojo's own review found in
  that tool's design.

## Block 2 — Data classes + subjects

| Data class | Subject + role |
|---|---|
| Command arguments passed through `mk.Cue` (may include credential-shaped values) | Operator — sole subject |
| Command arguments exposed via `--trace`'s global xtrace (may include credential-shaped values) | Operator — sole subject |
| mk.bash's own source code, as propagated across vendored/forked copies | Operator — sole subject; a governance artifact, not personal data |
| Code fetched and `eval`'d from the network via the curl fallback (MK-S4) | Operator — sole subject, but the CONTENT originates outside the operator's control entirely |

No third-party-data subject role applies anywhere in mk.bash's own surface — unlike era or
jeeves, mk.bash does not touch memory stores or transcripts that could carry another person's
data. (It can amplify exposure of such data if a consumer's downstream capture does — see
Block 4, MK-S1/MK-S2 "amplifiers".)

## Block 3 — Data-flow inventory

**Sources**: any command invoked via `mk.Cue`; any command run after `-x`/`--trace` is passed to
`mk.HandleOptions`; the `~/.local/lib/mk.bash` / `~/.local/bin/mk.bash` symlink targets or a
consumer's own vendored copy, at library-load time.

**Processes**: mk.bash's own 320-line script, sourced directly into the consumer's shell process
(no subprocess boundary — mk.bash functions execute with the full privilege and environment of
the invoking script).

**Stores**: none of mk.bash's own. Consumer-side stores it can feed into (session transcripts,
CI logs, era events) are named as amplifiers, not modeled as mk.bash's own surface.

**Flows**: stdout (via `mk.Cue`'s echo), stderr (via `--trace`'s xtrace, and the `mk.Debug`/
`mk.Error`/`mk.Fatal`/`mk.Info` logging helpers), and — for 5 of 8 known consumers — an HTTPS
fetch to `raw.githubusercontent.com` as a network-sourcing fallback (MK-S4).

**Exits**: none mk.bash-authored beyond the two above. Any further exit belongs to whatever the
sandboxed/invoked command itself does.

**Deletion paths**: N/A — mk.bash retains nothing of its own to delete.

**Trust boundaries**: user/machine boundary at the invoking shell (mk.bash always runs with the
operator's own privileges — no privilege boundary of its own). A SEPARATE, consumer-introduced
trust boundary exists at MK-S4's network fetch: the `binaryphile/mk.bash` GitHub account/repo is
outside the operator's control, and 5 consumers cross that boundary silently on a local-sourcing
failure.

**Derived surfaces**: `mk.Cue` (echo-and-execute), `mk.HandleOptions --trace` (global xtrace),
the network-fetch fallback (5 of 8 consumers), and cross-copy/cross-fork consistency (canonical
vs. era's fork vs. that fork's git-worktree propagation to dispatched delegate cycles).

## Block 4 — Per-property disposition

### MK-S4-CURL-EVAL-FALLBACK

- Primary property: 10 Substrate transparency/control failure

- Affected data + subject: whatever the fetched `develop`-branch content causes to execute, with
  the full privilege of the invoking shell — operator, sole subject

- Surface/DFD element: network-fetch fallback (5 of 8 known sourcing sites)

- Actor capability + access path: external attacker or compromised-provider actor, via control
  of the `binaryphile/mk.bash` GitHub account or repository; reached through the consumer's own
  bootstrap fallback, not through any action the operator takes deliberately

- Scenario + enabling condition: `task.bash/bin/mk:160-162`, `tandem-protocol/bin/mk:37-38`,
  `fluentfp/bin/mk:57-58`, and `tmux-claude/bin/mk:37-38` each contain `source
  ~/.local/lib/mk.bash 2>/dev/null || eval "$(curl -fsSL
  https://raw.githubusercontent.com/binaryphile/mk.bash/develop/mk.bash)" || { fatal }`;
  `agent-orchestration/bin/mk:539-542` carries the same fallback as a third tier, after
  `~/.local/bin/mk.bash` and `~/.local/lib/mk.bash`. The fetch targets a MUTABLE branch ref (not
  a pinned commit SHA or tag), over plain `curl -fsSL` with no signature or checksum
  verification, and the response is `eval`'d directly. It fires silently whenever local sourcing
  fails — a broken symlink, an unprovisioned fresh environment, or any sandboxed/dispatched
  context missing `~/.local`.

- User impact: a compromised `binaryphile/mk.bash` GitHub account or repository would give
  unreviewed, unverified code execution to every one of the 5 affected consumers on their next
  cold or broken-symlink invocation, with no operator awareness at the moment it fires.

- Controls + evidence: none specific to this fallback (code-confirmed: no pinning, no
  verification, no confirmation prompt anywhere in the 5 call sites). Mitigating context
  (code-confirmed): this pattern is NOT part of mk.bash's own documented boilerplate — its header
  comment recommends a hard `fatal` on sourcing failure, no network fallback at all. Individual
  consumer authors added the curl fallback themselves. Sibling consumers
  (`finances/bin/mk:122-123`, `dotfiles/mk:67`, `era/bin/evtctl:3407-3408`, `era/bin/era:1777-
  1778`) already use the safer hard-fatal pattern with no fallback, proving the safer alternative
  is viable and already precedented across the same estate.

- Assessment status + assumptions: assessed. Both primary local-sourcing paths
  (`~/.local/lib/mk.bash` and `~/.local/bin/mk.bash`) are currently healthy symlinks to canonical
  on this machine, so the fallback does not fire today under normal operation; its exposure is to
  future/fresh/degraded environments, not this machine's current steady state.

- Response or required capability: address — capability #1 (Block 8). Precedent:
  `DOJO-S7-NIX-FLAKE-PRETRUST` (dojo's own review) — ambient, pre-governance code execution
  firing before the user's own governance intent gets a chance to apply. Same 9-vs-10 reasoning:
  this is mk.bash-ecosystem substrate behavior firing ambiently on a consumer's own bootstrap
  path, not a tasked delegate exceeding its authorized bounds (property 9 would require a tasked
  delegate departing an authorized purpose/recipient/operation/disclosure boundary; nothing here
  is task-scoped).

- Residual risk + verification: residual until the fallback is removed or hardened (pin + verify).
  Verify by grepping all mk.bash-sourcing sites for `curl.*mk\.bash` and confirming zero hits, or
  — if network bootstrap is retained — confirming it fails closed against a tampered/wrong-hash
  payload.

- Tags: live

### MK-S1-CUE-ARGV-DISCLOSURE

- Primary property: 5 Data disclosure

- Affected data + subject: any argument passed through `mk.Cue`, including credential-shaped
  values — operator, sole subject

- Surface/DFD element: `mk.Cue` (echo-and-execute utility)

- Actor capability + access path: n/a as a distinct actor — the disclosure surface is
  mk.Cue's own designed behavior; any actor with read access to stdout's eventual destination
  (terminal scrollback, a captured session transcript, a CI log) inherits whatever was printed

- Scenario + enabling condition: `mk.Cue` (`mk.bash:80-87`) unconditionally echoes the full
  command plus all shell-quoted arguments to stdout before executing — that is its entire
  purpose ("Echo and Execute"). No redaction exists for credential-shaped arguments. Same defect
  class already caught elsewhere in this sweep: jeeves #78405 (argv-visible JIRA token in a
  different tool's publish scripts).

- User impact: if any consumer passes a secret via argv through `mk.Cue`, it lands in stdout in
  cleartext, typically captured by terminal scrollback, session transcripts, or CI logs.

- Controls + evidence: none within `mk.Cue` itself. Verified-within-searched-consumers (not
  estate-wide): call-site search across the 8 known consumers found no current `mk.Cue`
  invocation passing a secret via argv — era's `bin/mk` uses it only for `nix develop`/`go
  build`/`go test`/`systemctl`/`process-compose` invocations, and `mk-example` only for `git
  fetch`/`rebase`. `evtctl` itself has zero `mk.Cue` calls. This is a partial-consumer audit,
  not proof of estate-wide absence.

- Assessment status + assumptions: assessed. Distinct record from MK-S2 — different trigger
  (explicit API call vs. a global debug flag), different scope (only `mk.Cue`-wrapped calls vs.
  everything after `--trace`), and different mechanism; a fix to one does not close the other.

- Response or required capability: address — capability #2 (Block 8): env-var-pattern-based
  redaction on the echoed line, OR an explicit documented accept if redaction is judged
  disproportionate — one disposition, not both vaguely.

- Residual risk + verification: residual for any future consumer usage not covered by the current
  partial audit. Verify by calling `mk.Cue` with a credential-shaped argument and confirming it
  is not printed in cleartext, or that a documented warning exists if redaction is rejected.

- Tags: live

### MK-S2-TRACE-GLOBAL-XTRACE

- Primary property: 10 Substrate transparency/control failure

- Affected data + subject: every command argument expanded for the remainder of script execution
  after `--trace` is passed — operator, sole subject

- Surface/DFD element: `mk.HandleOptions`'s `-x`/`--trace` flag

- Actor capability + access path: n/a as a distinct actor — same disclosure-destination
  reasoning as MK-S1, but broader in scope

- Scenario + enabling condition: `mk.HandleOptions` (`mk.bash:173`) sets bare `set -x` on
  `-x`/`--trace`, enabling bash's xtrace for the ENTIRE REMAINDER of script execution — not
  scoped to mk.bash's own internals. Every subsequent command a consumer script runs, fully
  expanded, prints to stderr. Broader than MK-S1 because it is not limited to `mk.Cue`-wrapped
  calls.

- User impact: an operator debugging a failure — often exactly when secret-bearing commands are
  in play — reaches for `--trace` and gets every subsequent argument dumped to stderr. (The claim
  "operators reach for --trace exactly when debugging secret-bearing commands" is inferred/
  plausibility reasoning, not something observed in this estate's actual usage this session.)

- Controls + evidence: none — bare `set -x`, no scoping, no redaction.

- Assessment status + assumptions: assessed.

- Response or required capability: address — capability #3 (Block 8): an actual
  scoping/isolation mechanism (e.g. a redacted `PS4` or subshell-scoped xtrace) if the
  disposition is `address`; a bare documentation warning would properly be an `accept`, not an
  `address`, and must be labeled that way if that is what is ultimately proposed.

- Residual risk + verification: residual until a scoping capability exists or an explicit,
  labeled accept is recorded. Verify by confirming `--trace` no longer dumps a credential-shaped
  argument to stderr in a demonstration command, or that a documented warning exists.

- Tags: live

### MK-S3-VENDORED-COPY-DRIFT

- Primary property: 10 Substrate transparency/control failure

- Affected data + subject: the mk.bash source code itself, as it propagates (or fails to
  propagate) across the estate — operator, sole subject; a governance artifact, not personal
  data

- Surface/DFD element: cross-copy/cross-fork consistency

- Actor capability + access path: n/a — structural governance-drift concern, not a distinct actor

- Scenario + enabling condition: exhaustive inventory (`find` + symlink resolution +
  `md5sum` + `git remote -v` + `git log`) established a precise picture: `~/.local/lib/mk.bash`
  AND `~/.local/bin/mk.bash` are both symlinks to canonical (positive control — most
  `~/.local`-sourcing consumers stay in sync by construction). `era/lib/mk.bash` is the ONE
  independent, functionally-diverged fork in the estate (confirmed via diff: era added a
  JSON-output-bypass to `mk.CapLines` and simplified `mk.Each`, never upstreamed). The 8 files
  under `~/.local/share/agent-orchestrator/worktrees/*/lib/mk.bash` are NOT separate independent
  copies — each worktree directory is a real git worktree of the era repository (confirmed via
  `git remote -v`), and 7 of the 8 are byte-identical to era's current fork (confirmed via
  `md5sum`); the 8th is an older commit of the same fork lineage (confirmed via `git log -1 --
  lib/mk.bash` timestamps: 2026-06-03 vs. era's current 2026-06-22). Net: exactly ONE fork exists
  in the estate, propagating via git's ordinary worktree mechanism to dispatched delegate cycles
  — expected git behavior, not independent drift.

- User impact: no sync or comparison mechanism exists between era's fork and canonical mk.bash.
  A future canonical hygiene fix (e.g. an MK-S1 redaction capability) would not reach era or any
  of its dispatched worktrees without deliberate manual action, and there is no visibility
  signal that the fork has drifted unless someone diffs it by hand (as this review did).

- Controls + evidence: none — no sync mechanism, no drift-detection. Mitigating: the divergence
  IS git-tracked and reviewable in era's own commit history (not a silent, unversioned copy) —
  a materially better position than an untracked vendor copy would be.

- Assessment status + assumptions: assessed, with the cardinality and provenance fully resolved
  (not assumed) via the checks above.

- Response or required capability: address — capability #4 (Block 8): an inventory + diff check
  between canonical and era's fork specifically (not a general N-copy sweep, since the worktree
  files are not independent divergence points), in the spirit of era's own existing
  `cross-repo-dirty-sweep` pattern.

- Residual risk + verification: low-to-moderate — the divergence is git-tracked and bounded to
  one fork, but genuinely unsynced. Verify by running the check; intentionally diverge canonical
  further; confirm it's flagged.

- Tags: live

## Considered, not elevated to a primary record

- **`mk.Main` PATH-collision**: `mk.Main`'s dispatch (`local cmd=cmd.$1; $cmd ...`) does not
  validate that `cmd.$1` resolves to a defined shell function before invoking it. Tested
  empirically: an unmatched subcommand fails safely with bash's own `command not found` (rc=127)
  in the ordinary case. A PATH-planted executable literally named `cmd.<subcommand>` DOES
  silently execute (demonstrated with a throwaway PATH-prepended test binary) — but this requires
  the attacker to already control PATH or plant a matching executable; an ordinary consumer
  argument alone is insufficient. Classified as PATH-collision/injection — STRIDE-shaped
  (tampering via PATH manipulation), not a distinctly sovereignty-shaped harm per the guide's own
  boundary (§10: UserSov "snaps next to security review, never replaces it").

- **`mk.WithGlob`/`mk.Glob` state-restore-on-failure**: both save, mutate, and restore ambient
  shell glob state around an `eval`. Tested empirically, two conditions: under the errexit strict
  mode mk.bash's own header documents as required usage, a failing `eval` correctly kills the
  whole invoking script rather than leaving corrupted state behind (the "silent corrupted
  continuation" scenario does NOT occur under documented/conformant usage). Without errexit (a
  consumer violating mk.bash's own documented contract), a failing `eval` DOES leave glob state
  silently altered with no restoration and no error. A real but conditional reliability issue,
  contingent on non-conformant consumer usage — no data crosses a sovereignty boundary, only
  ambient shell-expansion behavior is affected. Noted for completeness, not elevated.

## Disposition matrix

Surface (rows) × property (columns, 1–11). Every cell is a `RECORD-ID`, `N/A`, or `unknown`.

| Surface | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `mk.Cue` echo-and-execute | N/A | N/A | N/A | N/A | MK-S1-CUE-ARGV-DISCLOSURE | N/A | N/A | N/A | N/A | N/A | N/A |
| `--trace` global xtrace | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | MK-S2-TRACE-GLOBAL-XTRACE | N/A |
| Network-fetch fallback (5 of 8 consumers) | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | MK-S4-CURL-EVAL-FALLBACK | N/A |
| Cross-copy/cross-fork consistency | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | MK-S3-VENDORED-COPY-DRIFT | N/A |
| `eval`-based fp helpers (`mk.Each`/`mk.KeepIf`/`mk.Map`/`mk.WithGlob`) | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A |
| `mk.Main` dispatch | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A |

**Reasoned N/A, grouped**:

- **Properties 1 (Linkability), 2 (Identifiability), 4 (Detectability), 6 (Unawareness &
  unintervenability), 7 (Non-compliance)**: N/A everywhere — mk.bash holds no state, no
  identifiers, and makes no external policy claims; nothing to correlate, deduce identity from,
  or hold non-compliant with a stated promise. Any identity-bearing content in an
  `mk.Cue`-echoed command belongs to MK-S1's classification, not a separate finding, per the
  primary-harm rule.
- **Property 3 (Non-repudiation)**: N/A, same estate-wide reasoning every prior sweep review
  established — attribution is the declared posture for Class H work artifacts, not deniability.
- **Property 8 (Expungability failure) and 11 (Compulsion-resistance failure)**: N/A — mk.bash
  has no persistent store of its own to delete from or for a compulsion order to reach.
- **Property 9 (Delegation integrity loss) — the one property that moved during grading, closed
  to N/A with exhaustive evidence**: `mk.Each`, `mk.KeepIf`, `mk.Map`, and `mk.WithGlob` all
  construct and `eval` shell text from stdin lines or caller-supplied expressions with no
  quoting — a real primitive, code-confirmed. Call-site search across all 8 external consumers
  (task.bash, tandem-protocol, finances, fluentfp, tmux-claude, agent-orchestration, dotfiles,
  era) found ZERO calls to any of the four functions. The only call sites anywhere in the estate
  are inside mk.bash's own repo — its test suite and its `mk-example` demo, both using static,
  developer-authored arguments (`isGitRepo`, `rebaseIfUpstreamHasProgressed`), never delegate- or
  untrusted-sourced input. N/A here is evidenced by an exhaustive 8/8-consumer search, not
  inferred from an incomplete one (this property moved from a premature N/A, through an
  "unresolved candidate" state during grading, to this final evidenced N/A — see the process
  note above).
- **`mk.Main` and `mk.WithGlob`/`mk.Glob` state-restore**: both considered explicitly (see
  "Considered, not elevated" above) and classified out of the UserSov taxonomy — STRIDE-shaped
  or reliability-shaped, not sovereignty-shaped, given the guide's own security-vs-privacy
  boundary.

## Block 5 — Controls + evidence

- Control: `~/.local/lib/mk.bash` and `~/.local/bin/mk.bash` — the two primary sourcing paths
  used by 6 of 8 known consumers — are both live symlinks to canonical, so those consumers stay
  in sync automatically, by construction rather than by discipline. Evidence status:
  code-confirmed (`ls -la` on both paths).

- Control: mk.bash's own documented boilerplate recommends a hard `fatal` on sourcing failure,
  with no network fallback — the safer pattern several sibling consumers (`finances`, `dotfiles`,
  `era`) already follow. Evidence status: documentation-confirmed (mk.bash's own header comment)
  plus code-confirmed (4 sibling consumers' actual source lines).

- Control: mk.bash has no telemetry, no network call of its own initiative, and no credential
  file access anywhere in its 320 lines. Evidence status: code-confirmed (full source read plus a
  repo-wide grep for logging/outbound-call patterns).

- Control: era's forked `lib/mk.bash` is git-tracked and reviewable in era's own commit history
  — not a silent, unversioned vendor copy. Evidence status: code-confirmed (`git log`).

No internal contradictions were found among these controls. The controls that exist are
positional (symlinks, documentation) rather than mechanized (no automated enforcement or
detection for any of the 4 threat records).

## Block 6 — Assumptions, deferrals, accepted risks

Assumed: the `binaryphile/mk.bash` GitHub account and repository are not currently compromised —
not independently verified this session (out of scope for a local-estate review); MK-S4's
severity is contingent on this assumption eventually being violated, not on a currently-realized
compromise.

Deferred: mechanism selection for all 4 remediation capabilities (redaction pattern, xtrace
scoping, fallback removal/pinning, fork-diff tooling) — per the guide's own non-goal and this
review's own out-of-scope discipline; protocol/gate integration — icarus #70312.

- Accepted risk (implicit, until MK-S1/MK-S2 remediation lands): any consumer that DOES pass a
  secret via argv through `mk.Cue` or debugs with `--trace` active discloses that secret to
  stdout/stderr today. Owner: operator. Rationale: no current known consumer usage does this
  (partial-consumer audit); the risk is prospective, not realized. Revisit trigger: any future
  consumer usage that does pass secret-shaped arguments through either surface.

- Accepted risk (until MK-S4 remediation lands) — **REMEDIATED 2026-08-03, see the
  Remediation update note above this document's scope framing (mk.bash#78891)**: 5 consumers
  retained a network-fetch fallback to a mutable, unverified branch ref. Owner: operator.
  Rationale: did not fire under this machine's then-current healthy-symlink state; was
  genuinely residual for degraded/fresh environments. Revisit trigger (now closed): any
  dispatched, sandboxed, or fresh-provisioned context where `~/.local` is not guaranteed
  present. Residual, NOT covered by the remediation: active feature-branch worktrees created
  before the fix landed on main still carry the pre-fix pattern until they rebase/merge.

## Block 7 — Grade triplet (self-assessment)

```
Grade: A-           (payload complete across all 8 blocks; 4 threat records with exhaustive,
                     evidence-labeled support; a 7×11 disposition matrix with extensive reasoned-
                     N/A coverage; property 9 closed with an 8/8-consumer exhaustive search, not
                     an incomplete one; cross-vendor graded through 3 rounds to APPROVE, Grade
                     A- — matches the cross-vendor grader's own assessment, not a self-inflated
                     number.)
Posture: B-          (mk.bash's own surface is genuinely clean — no stores, no telemetry, no
                     credential handling. But real gaps exist one level up the call stack: 5 of
                     8 consumers retain an unauthenticated network-fetch fallback (MK-S4, the
                     most severe finding in this sweep's mk.bash review), mk.Cue and --trace both
                     lack any redaction, and one fork exists with no sync mechanism to canonical.
                     None are currently realized/exploited on this machine's steady state, but
                     none are mitigated either.)
Remediation: B+      (4 capability-first remediation entries below, each covering exactly one
                     "address"-response record; MK-S4's fix — remove the fallback, adopt the
                     hard-fatal pattern 4 sibling consumers already use — is cheap and already
                     precedented in the same estate; MK-S1/MK-S2/MK-S3 remediations require new
                     capability-building work but at a well-scoped, single-property altitude
                     each.)
```

## Block 8 — Remediation capabilities + verification

- Capability: remove the curl-eval network-fetch fallback from the 5 affected consumers
  (`task.bash`, `tandem-protocol`, `fluentfp`, `tmux-claude`, `agent-orchestration`), replacing
  it with the hard-fatal pattern 4 sibling consumers already use. If network-bootstrap capability
  is genuinely wanted for some deployment scenario, pin to a specific commit SHA and verify a
  checksum/signature before `eval`, never a mutable branch ref. Verification: grep all mk.bash-
  sourcing sites for `curl.*mk\.bash` and confirm zero hits; for any retained network-bootstrap
  capability, confirm it fails closed against a tampered/wrong-hash payload. (mk.bash #78891)

- Capability: env-var-pattern-based redaction on `mk.Cue`'s echoed line, choosing one disposition
  — redaction OR a documented, explicit accept — not both vaguely. Illustrative mechanism
  (non-binding): a deny-list of common credential-shaped variable-name and value patterns,
  applied before the `printf -v output` echo. Verification: call `mk.Cue` with a credential-
  shaped argument (e.g. `--token=abc123`) and confirm it is not printed in cleartext, or that a
  documented warning exists if redaction is rejected as disproportionate. (mk.bash #78877)

- Capability: an actual scoping or isolation mechanism for `--trace`'s xtrace, if the disposition
  is `address` (a bare documentation warning is properly an `accept`, and must be labeled that
  way if that is what's ultimately proposed). Illustrative mechanism (non-binding): a
  redacted `PS4` or subshell-scoped xtrace limited to mk.bash's own internals. Verification:
  confirm `--trace` no longer dumps a credential-shaped argument to stderr in a demonstration
  command, or that a documented warning exists. (mk.bash #78878)

- Capability: an inventory + diff check between canonical mk.bash and era's specific forked
  copy (not a general N-copy sweep — the worktree files are git-worktree propagations of that
  ONE fork, not independent divergence points), in the spirit of era's own existing
  `cross-repo-dirty-sweep` pattern. Verification: run the check; intentionally diverge canonical
  further; confirm the check flags it. (mk.bash #78879)
