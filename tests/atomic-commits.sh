# shellcheck shell=bash
# The cases of atomic-commits/check.sh, on the commits of pull request #1.
# Backticks quote the report's Markdown here, never a command.
# shellcheck disable=SC2016

# commits answers the commits of pull request #1, one of each message $@, in pages of 100. The
# Nth's SHA is N seven times over, as 1111111. It has one parent, and changes no file, as the pull
# request changes none.
commits() {
    local list pages
    list=$(jq -nc '[$ARGS.positional | to_entries[] |
        {sha: ("\(.key + 1)" * 7), parents: [{}], commit: {message: .value}}]' --args "$@")
    mapfile -t pages < <(jq -c 'range(0; length; 100) as $i | .[$i:$i + 100]' <<<"$list")
    answer repos/o/r/pulls/1/commits "${pages[@]}"
    for sha in $(jq -r '.[].sha' <<<"$list"); do
        answer "repos/o/r/commits/$sha" '{"files": []}'
    done
    answer repos/o/r/pulls/1/files '[]'
}

# atomic runs the check with two globs of the default exclude, and the VAR=VALUE arguments over
# them.
atomic() {
    check atomic-commits EXCLUDE=$'**/go.sum\n**/vendor/**' "$@"
}

setup passes-clean-commits
commits 'feat(x): add y' $'fix(a/b.c): mend z\n\nThe body says why.\n\nRefs: #1'
atomic
warnings 0
summarizes 'No findings remain'

setup warns-on-a-header-off-the-form
commits 'Add y' 'feat(X): add y' 'feat:  add y' 'feet: add y' 'feat: add z'
atomic
for subject in '1111111 Add y' '2222222 feat(X): add y' '3333333 feat:  add y' '4444444 feet'; do
    warns "Commit \`$subject"
done
warns 'Commit `1111111 Add y`: the header is not `type(scope)!: description`.'
warnings 4
summarizes 'its type one of `feat fix refactor perf test docs style build ci chore revert`'
summarizes 'GIT_EDITOR="cp /tmp/msg.txt" \
    git rebase -i --update-refs main'

setup warns-on-a-header-over-72-characters
commits "feat: $(printf 'a%.0s' {1..67})" "feat: $(printf 'é%.0s' {1..66})"
atomic
warns 'Commit `1111111 feat: aaaa'
warns 'the header is 73 characters long.'
warnings 1

setup warns-on-the-description
commits 'feat: Add y' 'feat: add y.' 'feat(api): ETag the responses' 'fix: Éclair y' \
    'fix: mend Élan'
atomic
warns 'Commit `1111111 feat: Add y`: the description `Add y` starts uppercase.'
warns 'Commit `2222222 feat: add y.`: the description `add y.` ends with a period.'
warns '3333333 feat(api): ETag the responses`: the description `ETag the responses` starts'
warns '4444444 fix: Éclair y`: the description `Éclair y` starts uppercase.'
warnings 4

setup warns-on-a-body-with-no-blank-line
commits $'feat: add y\nThe body.' $'feat: add z\n\nThe body.' $'feat: add w\n \nThe body.'
atomic
warns 'Commit `1111111 feat: add y`: line 2 is `The body.`, not blank.'
warnings 1

# Trailers and URLs may run past 72 characters, but not a line of `Token: value` short of the last
# paragraph, nor the last paragraph where a line of it is no trailer.
setup warns-on-a-wide-body
wide=$(printf 'w%.0s' {1..73})
commits "feat: add y

$wide
See https://example.test/$wide

Co-Authored-By: A $wide <a@example.test>
Refs: #1
  $wide" "feat: add z

Refs: $wide

Not a trailer: $wide
Refs: #2"
atomic
warns "Commit \`1111111 feat: add y\`: line 3 is 73 characters long: \`$wide\`."
warns 'Commit `2222222 feat: add z`: line 3 is 79 characters long'
warns 'Commit `2222222 feat: add z`: line 5 is 88 characters long'
warnings 3

setup warns-on-a-breaking-change-marked-one-way
answer repos/o/r/pulls/1 "$(pull '{"title": "feat!: drop y"}')"
commits 'feat!: drop y' $'feat: drop z\n\nBREAKING CHANGE: z is gone.' \
    $'feat(x)!: drop w\n\nBREAKING-CHANGE: w is gone.' \
    $'feat!: drop v\n\nWhy.\n\nBREAKING CHANGE: v is gone.\nRefs: #1'
atomic
warns 'Commit `1111111 feat!: drop y`: the header has `!`, but no `BREAKING CHANGE:` footer.'
warns 'Commit `2222222 feat: drop z`: a `BREAKING CHANGE:` footer, but no `!` in the header.'
warnings 2

# The Refs footer is a trailer of the last paragraph.
setup warns-on-a-revert-with-no-refs
commits 'revert: feat: add y' $'revert: feat: add z\n\nIt broke w.\n\nRefs: 1111111' \
    $'revert: feat: add v\n\nRefs: 2222222\n\nIt broke w.'
atomic
warns 'Commit `1111111 revert: feat: add y`: no `Refs:` footer names the reverted commit.'
warns 'Commit `3333333 revert: feat: add v`: no `Refs:` footer'
warnings 2

setup warns-on-a-fixup-or-wip-commit
commits 'fixup! feat: add y' 'squash! feat: add y' 'amend! feat: add y' 'WIP' 'wip: Add y.' \
    'wipe the cache'
atomic
for sha in 1111111 2222222 3333333 4444444 5555555; do
    warns "title=atomic-commits%3A A fixup or WIP commit::Commit \`$sha"
done
warns 'Commit `1111111 fixup! feat: add y` is temporary: its header starts `fixup!`.'
warns 'Commit `6666666 wipe the cache`: the header is not'
warnings 6
summarizes 'GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash --update-refs main'

setup warns-once-on-a-merge-commit
answer repos/o/r/pulls/1 "$(pull '{"base": {"ref": "feat/x-1"}}')"
answer repos/o/r/pulls/1/commits '[{"sha": "abcdef0123", "parents": [{}, {}],
    "commit": {"message": "Merge branch '\''main'\'' into feat"}}]'
answer repos/o/r/pulls/1/files '[]'
atomic
warns "Commit \`abcdef0 Merge branch 'main' into feat\` is a merge commit, of 2 parents."
warnings 1
summarizes 'git fetch origin && git rebase --update-refs origin/feat/x-1'

# GitHub lists 250 commits at most, in pages of 100.
setup reads-every-page-and-notes-the-cap
answer repos/o/r/pulls/1 "$(pull '{"commits": 300}')"
mapfile -t subjects < <(seq -f 'feat: add %g' 249)
commits "${subjects[@]}" 'Add the last'
atomic
warns 'Commit `2502502 Add the last`: the header is not'
warns '#1 has 300 commits, and GitHub lists the first 250 alone: the check skipped the other 50.'
warnings 2

# The paths that EXCLUDE matches count for nothing, and a body that says mechanical exempts all.
setup warns-on-a-large-commit
commits 'feat: add y' 'feat: add z' $'refactor: rename w\n\nA Mechanical rename.' 'feat: add v'
answer repos/o/r/commits/1111111 '{"files": [{"filename": "a", "additions": 60, "deletions": 41}]}'
answer repos/o/r/commits/2222222 '{"files": [{"filename": "a", "additions": 50, "deletions": 50},
    {"filename": "go.sum", "additions": 500, "deletions": 0},
    {"filename": "x/vendor/y.go", "additions": 500, "deletions": 0}]}'
answer repos/o/r/commits/3333333 '{"files": [{"filename": "a", "additions": 300, "deletions": 0}]}'
answer repos/o/r/commits/4444444 \
    '{"files": [{"filename": "a", "additions": 100, "deletions": 0}]}' \
    '{"files": [{"filename": "b", "additions": 1, "deletions": 0}]}'
atomic
warns 'Commit `1111111 feat: add y` changes 101 lines, and its body does not say `mechanical`.'
warns 'Commit `4444444 feat: add v` changes 101 lines'
warnings 2
atomic EXCLUDE=go.sum
warns 'Commit `2222222 feat: add z` changes 600 lines'
warnings 3

setup warns-on-a-large-pull-request
commits 'feat: add y'
answer repos/o/r/pulls/1/files '[{"filename": "a", "additions": 200, "deletions": 0}]' \
    '[{"filename": "b", "additions": 51, "deletions": 50},
    {"filename": "go.sum", "additions": 900, "deletions": 0}]'
atomic
warns '#1 changes 301 lines against `main`.'
warnings 1

setup warns-on-the-title
commits 'feat: add y'
answer repos/o/r/pulls/1 "$(pull '{"title": "Add a check."}')"
atomic
warns 'The PR title is not a Conventional Commits header::The PR title `Add a check.`: the header'
warnings 1
answer repos/o/r/pulls/1 "$(pull '{"title": "feat: Add a check."}')"
atomic
warns 'The PR title `feat: Add a check.`: the description `Add a check.` starts uppercase.'
warns 'The PR title `feat: Add a check.`: the description `Add a check.` ends with a period.'
warnings 2
summarizes "gh pr edit 1 --title '<type>(<scope>): <description>'"

setup warns-on-a-breaking-commit-under-a-title-with-no-bang
commits $'feat!: drop y\n\nBREAKING CHANGE: y is gone.' 'feat: add z' \
    $'refactor(x)!: move w\n\nBREAKING-CHANGE: w moved.'
atomic
warns 'The PR title `feat: add a check` has no `!`, but it holds breaking commits:'
warns 'commits: `1111111 feat!: drop y`, `3333333 refactor(x)!: move w`.'
warnings 1
answer repos/o/r/pulls/1 "$(pull '{"title": "feat!: drop y"}')"
atomic
warnings 0
