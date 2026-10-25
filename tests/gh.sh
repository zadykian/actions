# shellcheck shell=bash
# The cases of tests/gh, the fake gh, as the checks read and write through it.

# same checks that the command after $1 prints $1.
same() {
    local out
    out=$("${@:2}" 2>&1) || true
    [ "$out" = "$1" ] || fail "${*:2} printed: $out"
}

setup answers-gh-api
answer repos/o/r/pulls/1/commits '[{"sha": "a"}, {"sha": "b"}]' '[{"sha": "c"}]'
answer 'repos/o/r/pulls?state=open' '[{"number": 2}]'
same $'a\nb' gh api 'repos/o/r/pulls/1/commits?per_page=100' --jq '.[].sha'
same $'a\nb\nc' gh api --paginate 'repos/o/r/pulls/1/commits?per_page=100' --jq '.[].sha'
same 2 gh api -X GET repos/o/r/pulls -f state=open -f per_page=100 --jq '.[].number'
same "$HEAD_SHA main" gh api repos/o/r/pulls/1 --jq '"\(.head.sha) \(.base.ref)"'
same '[]' gh api repos/o/r/issues/1/comments
same 'gh: Not Found (HTTP 404): the case answers no repos/o/r/x' gh api repos/o/r/x
answer repos/o/r/pulls/1 "$(pull '{"title": "fix: x", "head": {"ref": "fix"}}')"
same "fix: x fix $HEAD_SHA" gh api repos/o/r/pulls/1 --jq '"\(.title) \(.head.ref) \(.head.sha)"'

setup logs-the-writes
gh api -X PATCH repos/o/r/issues/comments/5 --input - <<<'{"body": "Edited."}' >/dev/null
gh api repos/o/r/issues/1/comments -f body=New. >/dev/null
wrote PATCH repos/o/r/issues/comments/5 Edited.
wrote POST repos/o/r/issues/1/comments New.
writes 2

setup refuses-a-write
refuse POST repos/o/r/issues/1/comments
same 'gh: Resource not accessible by integration (HTTP 403)' \
    gh api repos/o/r/issues/1/comments -f body=x
refuse GET repos/o/r/pulls/1 404
same 'gh: Not Found (HTTP 404)' gh api repos/o/r/pulls/1
writes 0
