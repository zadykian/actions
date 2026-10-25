#!/bin/bash
# Pushes the head commit of pull request $PR to $MAIN, the default branch of $GH_REPO, for
# $COMMENTER, who commented /ff. It runs in a checkout of $GH_REPO: git pushes with the
# credentials that actions/checkout keeps, gh with $GH_TOKEN. A refusal leaves its reason in
# $RUNNER_TEMP/refusal, for report.sh to comment.

set -euo pipefail

# refuse leaves its arguments as the reason of the refusal, and exits with status 1.
refuse() {
    printf '%s\n' "$*" >"$RUNNER_TEMP/refusal"
    echo "::error::$(head -n 1 "$RUNNER_TEMP/refusal")"
    exit 1
}

# Anyone may comment; the push is made for those who could make it themselves.
push="$(gh api "repos/$GH_REPO/collaborators/$COMMENTER/permission" \
    --jq .user.permissions.push)"
[ "$push" = true ] || refuse "@$COMMENTER cannot push to $GH_REPO."
pr="$(gh api "repos/$GH_REPO/pulls/$PR" --jq '[.state, .base.ref, .head.sha] | @tsv')"
IFS=$'\t' read -r state base sha <<<"$pr"
[ "$state" = open ] || refuse "#$PR is $state."
[ "$base" = "$MAIN" ] || refuse "#$PR is into $base, not $MAIN."
# The pull request's head by its hash, which a fork's commits have here too.
git fetch --no-tags origin "$sha" "+refs/heads/$MAIN:refs/remotes/origin/$MAIN"
if ! git merge-base --is-ancestor "origin/$MAIN" "$sha"; then
    refuse "#$PR does not start from the head of $MAIN: rebase it onto $MAIN."
fi
if ! git diff --quiet "origin/$MAIN" "$sha" -- .github/workflows; then
    refuse "#$PR changes .github/workflows, which GITHUB_TOKEN may not push:" \
        "push it yourself, \`git push origin $sha:$MAIN\`."
fi
# The ruleset's reasons, if it refuses, are in what git prints.
if ! git push origin "$sha:refs/heads/$MAIN" 2>"$RUNNER_TEMP/push"; then
    cat "$RUNNER_TEMP/push" >&2
    refuse "$(printf 'GitHub refused the push of %s to %s:\n\n~~~\n%s\n~~~' \
        "$sha" "$MAIN" "$(cat "$RUNNER_TEMP/push")")"
fi
