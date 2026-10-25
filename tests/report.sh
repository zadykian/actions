# shellcheck shell=bash
# The cases of lib/report.sh, through a check that sources it.

# probe runs a check.sh of the lines of stdin, between report_start probe and report_finish, with
# the VAR=VALUE arguments. It declares the rules a and b, and fails the case where the check exits
# non-zero.
probe() {
    {
        printf '#!/bin/bash\nset -euo pipefail\n. %q\nreport_start probe\n' "$ROOT/lib/report.sh"
        printf "rule a 'Rule A' https://example.test/a 'Fix A.'\n"
        printf "rule b 'Rule B' https://example.test/b 'Fix B.'\n"
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
warns "::Finding 10.%0A$rule_a%0AThe job summary holds 2 more findings."
! grep -qF 'Finding 11.' "$FAKE/out" || fail "annotated the 11th finding"

setup summarizes
probe <<'CHECK'
finding a 'The title says 100% done.' src/x.go 12
finding a $'Two\nlines.'
CHECK
summarizes "### probe

This check warns and does not block the merge. It found 2 findings as of \`0123456\`.
"
summarizes "#### Rule A

The rule: https://example.test/a

- \`src/x.go:12\`: The title says 100% done.
- Two
  lines.

How to fix it:

Fix A."
! grep -qF 'Rule B' "$GITHUB_STEP_SUMMARY" || fail "the summary has a section for Rule B"

setup summarizes-a-clean-check
probe </dev/null
summarizes "merge. No findings remain as of \`0123456\`."
warnings 0

marker='<!-- zadykian/actions:probe -->'
old=$(jq -nc --arg body "$marker"$'\nOld.' '[{id: 5, body: $body}]')
setup comments
probe <<<"finding a 'Found.'"
wrote POST repos/o/r/issues/1/comments "$marker
### probe"
writes 1

setup edits-the-comment
answer repos/o/r/issues/1/comments '[{"id": 4, "body": "Looks good."}]' "$old"
probe <<<"finding a 'Found.'"
wrote PATCH repos/o/r/issues/comments/5 '- Found.'
writes 1

setup edits-the-comment-to-clean
answer repos/o/r/issues/1/comments "$old"
probe </dev/null
wrote PATCH repos/o/r/issues/comments/5 "No findings remain as of \`0123456\`."
writes 1

setup comments-nothing-clean
probe </dev/null
writes 0

setup comments-nothing-when-told
probe COMMENT=false <<<"finding a 'Found.'"
writes 0
! grep -qF issues/1/comments "$FAKE/calls" || fail "read the comments"

setup warns-on-a-refused-comment
refuse POST repos/o/r/issues/1/comments
probe <<'CHECK'
for i in $(seq 12); do finding a "Finding $i."; done
CHECK
refused='could not comment on #1, so the job summary alone holds the report: Resource not'
warns "::warning::probe $refused accessible by integration (HTTP 403)"
warns "::Finding 9.%0A$rule_a%0AThe job summary holds 3 more findings."
warnings 10
summarizes '- Finding 12.'

setup cuts-a-long-comment
probe <<'CHECK'
pad=$(printf '%090d' 0)
for i in $(seq 700); do finding a "Finding $i: $pad."; done
CHECK
cut='[the job summary](https://github.com/o/r/actions/runs/7) holds all of it._'
jq -e --arg cut "$cut" '.input.body | length < 65536 and endswith($cut)' "$FAKE/writes" \
    >/dev/null || fail "the comment is not cut: $(tail -c 300 "$FAKE/writes")"

setup warns-on-an-error
probe <<'CHECK'
false
finding a 'Never found.'
CHECK
warns '::warning::probe could not check #1: check.sh:7: false exited with 1'
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
