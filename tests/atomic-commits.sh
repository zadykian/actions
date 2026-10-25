# shellcheck shell=bash
# The cases of atomic-commits/check.sh, on the commits of pull request #1.
# Backticks quote the report's Markdown here, never a command.
# shellcheck disable=SC2016

# commits answers the commits of pull request #1, one of each message $@, in pages of 100. The
# Nth's SHA is N seven times over, as 1111111, and it has one parent.
commits() {
    local list pages
    list=$(jq -nc '[$ARGS.positional | to_entries[] |
        {sha: ("\(.key + 1)" * 7), parents: [{}], commit: {message: .value}}]' --args "$@")
    mapfile -t pages < <(jq -c 'range(0; length; 100) as $i | .[$i:$i + 100]' <<<"$list")
    answer repos/o/r/pulls/1/commits "${pages[@]}"
}

# atomic runs the check with the action's default inputs, and the VAR=VALUE arguments over them.
atomic() {
    check atomic-commits TYPES='feat fix refactor perf test docs style build ci chore revert' "$@"
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
atomic TYPES=$'feet\n  feat'
warnings 3

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
