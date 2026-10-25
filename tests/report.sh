# shellcheck shell=bash
# The cases of lib/report.sh, through a check that sources it.

# probe runs a check.sh of the lines of stdin, between report_start probe and report_finish. It
# declares the rule a, and fails the case where the check exits non-zero.
probe() {
    {
        printf '#!/bin/bash\nset -euo pipefail\n. %q\nreport_start probe\n' "$ROOT/lib/report.sh"
        printf "rule a 'Rule A' https://example.test/a 'Fix A.'\n"
        cat
        printf 'report_finish\n'
    } >"$FAKE/check.sh"
    chmod +x "$FAKE/check.sh"
    step "$FAKE/check.sh"
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
