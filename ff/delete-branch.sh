#!/bin/bash
# Deletes the branch of pull request $PR, which fast-forward.sh landed on $MAIN, where $GH_REPO
# deletes merged pull requests' branches: GitHub does so after a merge of its own or a person's
# push, but not after a push with GITHUB_TOKEN, as fast-forward.sh's is. As GitHub does, it first
# moves the open pull requests into the branch onto $MAIN, since deleting a branch closes them. A
# branch it leaves gets a warning.

set -euo pipefail

# leave warns that the branch stays, for the reason $*, and exits.
leave() {
    echo "::warning::$branch stays: $*"
    exit 0
}

# GraphQL gives the setting to whoever may read the repository; REST hides it from a reader.
query="{ repository(owner: \"${GH_REPO%%/*}\", name: \"${GH_REPO#*/}\") { deleteBranchOnMerge } }"
delete="$(gh api graphql -f query="$query" --jq .data.repository.deleteBranchOnMerge)"
[ "$delete" = true ] || exit 0
pr="$(gh api "repos/$GH_REPO/pulls/$PR" --jq '[.head.repo.full_name, .head.ref, .head.sha] | @tsv')"
IFS=$'\t' read -r repo branch sha <<<"$pr"
# A fork's branch is its owner's.
[ "$repo" = "$GH_REPO" ] || exit 0
# GitHub marks the pull request merged a moment after the push: the branch goes once it has.
merged=false
for _ in $(seq 30); do
    merged="$(gh api "repos/$GH_REPO/pulls/$PR" --jq .merged)"
    [ "$merged" = false ] || break
    sleep 2
done
[ "$merged" = true ] || leave "GitHub has not marked #$PR merged."
open="$(gh api -X GET "repos/$GH_REPO/pulls" -f state=open -f head="${GH_REPO%%/*}:$branch" \
    --jq length)"
[ "$open" = 0 ] || leave "an open pull request comes from it."
[ "$(git ls-remote origin "refs/heads/$branch" | cut -f 1)" = "$sha" ] ||
    leave "it has moved on from $sha."
into="$(gh api -X GET "repos/$GH_REPO/pulls" -f state=open -f base="$branch" -f per_page=100 \
    --paginate --jq '.[].number')"
for number in $into; do
    gh api -X PATCH "repos/$GH_REPO/pulls/$number" -f base="$MAIN" >/dev/null
done
git push --force-with-lease="refs/heads/$branch:$sha" origin --delete "refs/heads/$branch" ||
    leave "GitHub refused to delete it."
