# shellcheck shell=bash
# The cases of ff, the /ff action: its scripts run in work, a clone of origin, a local bare
# repository. Each case checks where main ends, and what becomes of the pull request, its issues
# and its branch.

# commit commits in seed, changing the file $1, and pushes the branch $2.
commit() {
    mkdir -p "$(dirname "$FAKE/seed/$1")"
    echo "$1" >>"$FAKE/seed/$1"
    git -C "$FAKE/seed" add .
    git -C "$FAKE/seed" commit -qm "$1"
    git -C "$FAKE/seed" push -q origin "HEAD:refs/heads/$2"
}

# at prints the commit of the branch $1 in origin, or nothing where origin has no $1.
at() {
    git -C "$FAKE/origin.git" rev-parse --verify -q "refs/heads/$1" || true
}

# opened answers pull request #1 in the state $1, into the base $2, from feat at $head in the
# repository $3, o/r where omitted. GitHub has marked it merged, for delete-branch.sh.
opened() {
    answer repos/o/r/pulls/1 "$(pull "$(printf '{"state": "%s", "merged": true,
        "base": {"ref": "%s"}, "head": {"sha": "%s", "repo": {"full_name": "%s"}}}' \
        "$1" "$2" "$head" "${3:-o/r}")")"
}

# graphql answers o/r as GraphQL gives it: it deletes merged branches where $1 is true, and #1
# closes the issues of the JSON array $2.
graphql() {
    answer graphql "$(printf '{"data": {"repository": {"deleteBranchOnMerge": %s, "pullRequest":
        {"closingIssuesReferences": {"nodes": %s}}}}}' "$1" "$2")"
}

# start starts origin with main and feat, a commit ahead, at $head, and work, a clone of it. gh
# answers for #1, from feat into main, which alice commented, who may push. o/r keeps merged
# branches, and #1 closes no issue.
start() {
    git init -q --bare -b main "$FAKE/origin.git"
    git clone -q "$FAKE/origin.git" "$FAKE/seed" 2>/dev/null
    commit README main
    git -C "$FAKE/seed" switch -qc feat
    commit feat feat
    git clone -q "$FAKE/origin.git" "$FAKE/work"
    head=$(at feat)
    answer repos/o/r/collaborators/alice/permission '{"user": {"permissions": {"push": true}}}'
    opened open main
    graphql false '[]'
}

# ff runs ff's script $1 in work, with the env that action.yml gives it, and adds its output to
# out.
ff() {
    (cd "$FAKE/work" && COMMENTER=alice MAIN=main "$ROOT/ff/$1.sh") >>"$FAKE/out" 2>&1 </dev/null
}

# land runs ff's scripts as action.yml's steps do: fast-forward.sh, then close-issues.sh and
# delete-branch.sh, or comment-refusal.sh where it fails. STATUS is fast-forward.sh's, and before
# is main's commit before it. The case fails where another script fails.
land() {
    before=$(at main) STATUS=0
    : >"$FAKE/out"
    ff fast-forward || STATUS=$?
    if [ "$STATUS" = 0 ]; then
        ff close-issues || fail "close-issues.sh failed: $(cat "$FAKE/out")"
        ff delete-branch || fail "delete-branch.sh failed: $(cat "$FAKE/out")"
    else
        ff comment-refusal || fail "comment-refusal.sh failed: $(cat "$FAKE/out")"
    fi
}

# lands checks that the run moved main to $head, and commented nothing.
lands() {
    exits 0
    [ "$(at main)" = "$head" ] || fail "main is not at feat's head"
    ! grep -q '^pr comment' "$FAKE/calls" || fail "commented: $(cat "$FAKE/calls")"
}

# refuses checks that the run failed with main where it was, and commented the text $1.
refuses() {
    exits 1
    [ "$(at main)" = "$before" ] || fail "main moved"
    wrote POST repos/o/r/issues/1/comments "$1"
}

setup lands
start
land
lands

setup no-push
start
answer repos/o/r/collaborators/alice/permission '{"user": {"permissions": {"push": false}}}'
land
refuses '@alice cannot push to o/r.'

setup closed
start
opened closed main
land
refuses '#1 is closed.'

setup other-base
start
opened open dev
land
refuses '#1 is into dev, not main.'

setup behind
start
git -C "$FAKE/seed" switch -q main
commit later main
land
refuses '#1 does not start from the head of main: rebase it onto main.'

setup workflows
start
commit .github/workflows/ci.yml feat
head=$(at feat)
opened open main
land
refuses '#1 changes .github/workflows, which GITHUB_TOKEN may not push:'

setup push-refused
start
printf '#!/bin/sh\necho "a rule refuses it" >&2\nexit 1\n' >"$FAKE/origin.git/hooks/pre-receive"
chmod +x "$FAKE/origin.git/hooks/pre-receive"
land
refuses 'a rule refuses it'

setup run-failed
start
refuse GET repos/o/r/pulls/1 404
land
refuses "\`/ff\` did not move main: The run failed."
