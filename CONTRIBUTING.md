# Contributing

Tigris is POSIX shell that runs as root, so the bar is readability and
evidence. The [roadmap](ROADMAP.md) carries the principles; this file
carries the mechanics.

## Checks

- One check does one thing. Read the documentation of the thing being
  checked and write from that; never copy from another auditor.
- Every finding needs a stable id, a severity, and an explanation in
  `doc/` (see `doc/apache.txt` for a recent example). `sh
  tests/explain_check.sh` fails on any id without one.
- No check ships without a test. Fixture-driven checks take the command
  or the tree as a setting (`Tiger_Sysctl_Root`, `Tiger_SSHD_Cmd`),
  package-manager checks plant their problems in a real container; see
  `tests/` and the roadmap's engineering section.
- Tigris is read-only and offline by default: a check changes nothing
  and touches no network unless the administrator asked.
- Quote everything, `mktemp` every temporary file, never `eval` data
  read from the system, never source a file the system owns (read it as
  text).

## Running the tests

```sh
for t in tests/*_check.sh; do sh "$t"; done   # fixtures, no root needed
sudo sh tests/smoke.sh                        # full run on this machine
```

`sh -n` over the tree and ShellCheck run in CI; keep both clean. The
`[ $TESTEXEC file ]` idiom is a known ShellCheck blind spot: write new
tests so the analyser can parse them.

## Commits

- One logical change per commit, in the style already in the log:
  `area: what changed`, one line, then a body if the why is not
  obvious. No attribution trailers.
- Tick the roadmap in the same commit that ships the item, and recount
  any number the change moves (finding ids, check scripts, CI jobs).
- Every release records wall time, CPU and peak memory on the reference
  machine; a change that makes them worse needs a reason stated in the
  commit.

## Issues and pull requests

Bugs go through the issue templates; noise counts as a bug, so a false
positive is reported like any other wrong finding. Security problems
follow [SECURITY.md](SECURITY.md), never the public tracker. Pull
requests should arrive with tests passing and the roadmap ticked; small
and reviewable beats large and complete.
