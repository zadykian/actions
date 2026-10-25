# shellcheck shell=bash
# The cases of tools/release, in a clone, work, of a local bare repository, origin.

# repository starts origin, and work, the current directory, with the commit chore: start on main.
repository() {
    git init -q --bare -b main "$FAKE/origin.git"
    git clone -q "$FAKE/origin.git" "$FAKE/work" 2>/dev/null
    cd "$FAKE/work" || return
    commit 'chore: start'
}

# commit pushes to main a commit of the header $1.
commit() {
    git commit -q --allow-empty -m "$1"
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
    prints "::error::$2"
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
commit 'fix: mend it'
tag v2.5.0
step "$ROOT/tools/release" v2.5.0
exits 0
grep -qF 'release create v2.5.0 --verify-tag --title v2.5.0 --notes-file' "$FAKE/calls" ||
    fail "did not release v2.5.0: $(cat "$FAKE/out")"
[ "$(cat "$FAKE/notes")" = "- chore: start ($(git rev-parse --short HEAD~))
- fix: mend it ($(git rev-parse --short HEAD))" ] || fail "the notes: $(cat "$FAKE/notes")"
