# shellcheck shell=bash
# The cases of tools/release, in a clone, work, of a local bare repository, origin.

# repository starts origin, and work, the current directory, with the commit chore: start on main.
repository() {
    git init -q --bare -b main "$FAKE/origin.git"
    git clone -q "$FAKE/origin.git" "$FAKE/work" 2>/dev/null
    cd "$FAKE/work" || return
    commit 'chore: start'
}

# commit pushes to main a commit of the header $1, and of the body $2 where given.
commit() {
    local message=(-m "$1")
    [ -z "${2-}" ] || message+=(-m "$2")
    git commit -q --allow-empty "${message[@]}"
    git push -q origin HEAD:main
}

# tag pushes the annotated tag $1, of HEAD.
tag() {
    git tag -a "$1" -m "$1"
    git push -q origin "refs/tags/$1"
}

# refuses checks that tools/release refused the tag $1, for the reason $2, and published nothing.
refuses() {
    step "$ROOT/tools/release" "$1"
    exits 1
    grep '^::error::' "$FAKE/out" | grep -F -- "$2" >/dev/null ||
        fail "no error '$2': $(cat "$FAKE/out")"
    ! grep -qF 'release create' "$FAKE/calls" 2>/dev/null || fail "released $1"
}

setup refuses-a-tag-of-another-form
repository
for version in v1.2 1.2.3 v01.2.3 v1.2.3-rc.1; do
    refuses "$version" "$version is not a version tag, vMAJOR.MINOR.PATCH"
done
refuses v1.0.0 'origin has no tag v1.0.0.'

setup refuses-a-lightweight-tag
repository
git tag v1.0.0
git push -q origin v1.0.0
refuses v1.0.0 'v1.0.0 is a lightweight tag'

setup refuses-a-tag-off-main
repository
git commit -q --allow-empty -m 'feat: try'
git push -q origin HEAD:try
tag v1.0.0
refuses v1.0.0 "v1.0.0 tags $(git rev-parse --short=7 HEAD), which is not on main."

setup releases-the-first-tag
repository
commit 'feat(x)!: drop the old input'
commit 'refactor: move y' 'BREAKING CHANGE: y moved to z.'
commit 'feat(x): add z'
commit 'fix: mend w'
commit 'docs: describe v'
tag v2.5.0
step "$ROOT/tools/release" v2.5.0
exits 0
grep -qF 'release create v2.5.0 --verify-tag --title v2.5.0 --notes-file' "$FAKE/calls" ||
    fail "did not release v2.5.0: $(cat "$FAKE/out")"
grep -qxF -- "- fix: mend w ($(git rev-parse --short HEAD~))" "$FAKE/notes" ||
    fail "no fix: mend w with its SHA: $(cat "$FAKE/notes")"
[ "$(sed -E 's/ \([0-9a-f]+\)$//' "$FAKE/notes")" = '## Breaking changes

- feat(x)!: drop the old input
- refactor: move y

## Features

- feat(x): add z

## Fixes

- fix: mend w

## Other changes

- chore: start
- docs: describe v' ] || fail "the notes: $(cat "$FAKE/notes")"

setup releases-the-next-version
repository
tag v1.2.3
commit 'fix: mend it'
commit 'feat: add it'
tag v1.3.0
step "$ROOT/tools/release" v1.3.0
exits 0
[ "$(sed -E 's/ \([0-9a-f]+\)$//' "$FAKE/notes")" = '## Features

- feat: add it

## Fixes

- fix: mend it' ] || fail "the notes: $(cat "$FAKE/notes")"

setup bumps-the-patch-for-the-rest
repository
tag v1.2.3
commit 'docs: describe it'
commit 'fix: mend it'
tag v1.3.0
refuses v1.3.0 'v1.3.0 is not the version the commits since v1.2.3 call for, v1.2.4, for no'

setup bumps-the-minor-for-a-feature
repository
tag v1.2.3
commit 'fix: mend it'
commit 'feat: add it'
tag v1.2.4
refuses v1.2.4 'since v1.2.3 call for, v1.3.0, for a feature: delete v1.2.4, and tag v1.3.0.'

setup bumps-the-major-for-a-breaking-change
repository
tag v1.2.3
commit 'refactor: move it' 'BREAKING CHANGE: it moved.'
tag v1.3.0
refuses v1.3.0 'v1.3.0 is not the version the commits since v1.2.3 call for, v2.0.0, for a breaking'

setup bumps-the-minor-for-a-breaking-change-before-1.0
repository
tag v0.3.1
commit 'feat!: drop it'
tag v1.0.0
refuses v1.0.0 'since v0.3.1 call for, v0.4.0, for a breaking change, before 1.0: delete v1.0.0'

setup refuses-a-tag-of-no-commit
repository
tag v1.2.3
tag v1.2.4
refuses v1.2.4 'v1.2.4 adds no commit to v1.2.3.'
