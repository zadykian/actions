# shellcheck shell=bash
# The cases of lib/report.sh, through a check that sources it.

# probe runs a check.sh of the lines of stdin, between report_start probe and report_finish, with
# the VAR=VALUE arguments. It declares the rule a, and fails the case where the check exits
# non-zero.
probe() {
    {
        printf '#!/bin/bash\nset -euo pipefail\n. %q\nreport_start probe\n' "$ROOT/lib/report.sh"
        printf "rule a 'Rule A' https://example.test/a 'Fix A.'\n"
        cat
        printf 'report_finish\n'
    } >"$FAKE/check.sh"
    chmod +x "$FAKE/check.sh"
    step "$@" "$FAKE/check.sh"
    [ "$STATUS" = 0 ] || fail "the check exited with $STATUS: $(cat "$FAKE/out")"
}

setup annotates
probe <<'CHECK'
finding a 'The title says 100% done.' src/x.go 12
finding a 'Quoted: a, b.' 'a,b:c.txt'
finding a $'Two\r\nlines.'
CHECK
rule_a='The rule: https://example.test/a'
warns "::warning title=probe%3A Rule A,file=src/x.go,line=12::The title says 100%25 done.%0A$rule_a"
warns "::warning title=probe%3A Rule A,file=a%2Cb%3Ac.txt::Quoted: a, b.%0A$rule_a"
warns "::warning title=probe%3A Rule A::Two%0D%0Alines.%0A$rule_a"
warnings 3

setup annotates-ten-at-most
probe <<'CHECK'
for i in $(seq 12); do finding a "Finding $i."; done
CHECK
warnings 10
warns "::Finding 10.%0A$rule_a%0A2 more findings not annotated."
! grep -qF 'Finding 11.' "$FAKE/out" || fail "annotated the 11th finding"

setup warns-on-an-error
probe <<'CHECK'
false
finding a 'Never found.'
CHECK
warns '::warning::probe could not check #1: check.sh:6: false exited with 1'
warnings 1

setup warns-on-an-unset-variable
probe <<<"echo \"\$UNSET\""
warns '::warning::probe could not check #1: the check exited with 1'
prints 'UNSET: unbound variable'

setup warns-on-an-undeclared-rule
probe <<<"finding c 'No rule c.'"
warns '::warning::probe could not check #1: no rule c is declared, for the finding: No rule c.'

setup warns-as-the-check-says
probe <<<"cannot_check 'GitHub lists no commit.'"
warns '::warning::probe could not check #1: GitHub lists no commit.'
warnings 1

setup warns-on-another-event
probe PR= GITHUB_EVENT_NAME=push </dev/null
warns '::warning::probe checks a pull request, and the push event has none: run it on pull_request.'
warnings 1
