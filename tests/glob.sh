# shellcheck shell=bash
# The cases of lib/glob.sh: which paths each glob of EXCLUDE matches.

# shellcheck source=lib/glob.sh
. "$ROOT/lib/glob.sh"

# globs checks each line `GLOB PATH... [! PATH...]` of stdin: GLOB matches each PATH before the !,
# and none after it.
globs() {
    local words path matches
    while read -ra words; do
        matches=true
        for path in "${words[@]:1}"; do
            if [ "$path" = '!' ]; then
                matches=false
            elif EXCLUDE=${words[0]} excluded "$path"; then
                $matches || fail "${words[0]} matches $path"
            else
                ! $matches || fail "${words[0]} does not match $path"
            fi
        done
    done
}

setup globs
globs <<'GLOBS'
*.go main.go .go ! cmd/main.go main.go.txt
docs/*.md docs/a.md ! docs/x/a.md docs.md
?.txt a.txt ! ab.txt x/a.txt
**/go.sum go.sum a/go.sum a/b/go.sum ! ago.sum go.sum.txt a/go.sumx
**/*.Designer.cs Form.Designer.cs ui/Form.Designer.cs ! Form.Designer.csx ui/FormDesigner.cs
a/**/b a/b a/x/b a/x/y/b ! a/xb ab
**/vendor/** vendor/a vendor/a/b.go x/vendor/y/z ! vendor vendor.go x/avendor/y
** a a/b/c
[ab].txt a.txt b.txt ! c.txt ab.txt
[!ab].txt c.txt ! a.txt /.txt
[]a]x ]x ax ! bx
a+b(c){2}|^$[.txt a+b(c){2}|^$[.txt ! aab.txt
GLOBS

# An input's lines, as YAML gives them, and an empty input.
setup a-glob-a-line
EXCLUDE=$'\n  **/go.sum  \n\n\t**/vendor/**\n'
for path in a/go.sum vendor/x; do excluded "$path" || fail "the list keeps $path"; done
! excluded main.go || fail "the list excludes main.go"
! EXCLUDE='' excluded go.sum || fail "an empty list excludes go.sum"
