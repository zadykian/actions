# atomic-commits

Warns on a pull request whose commits, size or title break the rules of the
[atomic-commits][skill] skill. It never blocks the merge: it annotates the pull request, writes a
job summary and keeps one comment of its report up to date, and its job passes.

## Usage

`.github/workflows/rules.yml`:

```yaml
name: rules

on:
  pull_request:
    types: [opened, edited, reopened, synchronize]

permissions: {}

jobs:
  rules:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: zadykian/actions/atomic-commits@SHA # vX.Y.Z
```

Pin it by the full hash of a version tag's commit, as the repository's
[README](../README.md#versions) says. `pull-requests: write` lets it comment, and the `edited` type checks the title again once
it changes. It reads the pull
request through GitHub's API alone and checks out nothing, so it runs none of the pull request's
code.

## What it checks

Each finding names the commit, or the pull request, and quotes what is wrong. It links to the
rule's section of the skill, and says how to fix it, with the skill's commands for rewording a
commit.

Each commit's message, as [section 3][s3] sets it:

- `header`: the header is `type(scope)!: description`, its type one of `types` and its scope
  lowercase.
- `header-length`: the header is 72 characters at most.
- `description`: the description starts lowercase, and ends without a period.
- `body-blank`: line 2, between the header and the body, is blank.
- `body-width`: each line of the body is 72 characters at most. A trailer and a line that holds a
  URL may be longer. The trailers are the message's last paragraph of `Token: value` lines, as git
  reads them, such as `Co-Authored-By:` and `Refs:`.
- `breaking`: a breaking change has both of its marks, or neither: a `!` before the header's colon,
  and a `BREAKING CHANGE:` or `BREAKING-CHANGE:` footer.
- `revert`: a `revert:` commit has a `Refs:` trailer, which names the reverted commit.

Each commit's place in the branch:

- `fixup`: no commit is temporary, as [section 2][s2] says: its header starts neither `fixup!`,
  `squash!` nor `amend!`, nor the word WIP.
- `merge`: no commit merges another branch in, as [section 6][s6] keeps a stack by rebase.

Either finding is the commit's only one, as its fix folds the commit in or drops it.

The sizes, as [the hard rules][rules] set them:

- `commit-size`: a commit changes `max-commit-lines` lines at most, its insertions and deletions in
  the paths that `exclude` does not match. A purely mechanical commit, such as a rename, may be
  larger where its body says `mechanical`.
- `pr-size`: the pull request changes `max-pr-lines` lines at most against its base, in the paths
  that `exclude` does not match.

The pull request's title, as [section 6][s6] sets it:

- `pr-title`: the title is a Conventional Commits header, as `header`, `header-length` and
  `description` check one, since a squash merge turns it into the commit that lands.
- `pr-breaking`: where a commit is breaking, the title has a `!` too.

GitHub lists the first 250 commits of a pull request alone. Past them, the `commit-count` finding
says how many commits the check skipped.

## Inputs

- `token`, `${{ github.token }}` by default: reads the pull request, and comments on it.
- `comment`, `true` by default: `false` leaves the report to the annotations and the job summary.
- `types`, `feat fix refactor perf test docs style build ci chore revert` by default: the types
  that a header may take, separated by spaces.
- `max-commit-lines`, `100` by default: the changed lines that a commit may hold.
- `max-pr-lines`, `300` by default: the changed lines that the pull request may hold against its
  base.
- `exclude`: globs of the paths that no count of changed lines takes in, one a line, as git's
  `:(glob)` pathspecs match them. Its default is the list of [section 7][s7]: lockfiles, generated
  code and vendored dependencies.

## What it cannot check

It reads what GitHub's API says of the commits, and runs none of their code. So it cannot check
that each commit builds and passes the tests on its own, or that it holds one logical change, as
[the hard rules][rules] say. The review of each commit checks those.

[skill]: https://github.com/zadykian/skills/blob/main/skills/atomic-commits/SKILL.md
[rules]: https://github.com/zadykian/skills/blob/main/skills/atomic-commits/SKILL.md#hard-rules
[s2]: https://github.com/zadykian/skills/blob/main/skills/atomic-commits/SKILL.md#2-shape-each-commit
[s3]: https://github.com/zadykian/skills/blob/main/skills/atomic-commits/SKILL.md#3-commit-messages-conventional-commits-100
[s6]: https://github.com/zadykian/skills/blob/main/skills/atomic-commits/SKILL.md#6-stack-mechanics-git--238
[s7]: https://github.com/zadykian/skills/blob/main/skills/atomic-commits/SKILL.md#7-verify
