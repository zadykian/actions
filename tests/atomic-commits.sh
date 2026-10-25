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
