# actions

GitHub Actions for the rules that [zadykian/skills](https://github.com/zadykian/skills) teaches
the agent, of two kinds. The checks warn on a pull request and never block. `ff` lands a pull
request by fast-forward on a `/ff` comment, and fails, with a comment saying why, when it refuses.
[README.md](README.md) says how a repository pins them, and each action's README what it does.

## Layout

- `NAME/`: a check, which a workflow uses as `zadykian/actions/NAME@SHA`: its `action.yml`, its
  `check.sh`, and a README of what it checks, its inputs and the rules it links to.
- `ff/`: the `/ff` action: its `action.yml`, the scripts of its steps, `fast-forward.sh`,
  `close-issues.sh`, `delete-branch.sh` and `comment-refusal.sh`, and a README of what it does and
  the settings it relies on.
- `lib/report.sh`: what each `check.sh` sources to turn its findings into annotations, a job
  summary and one comment. Its header comment is its API.
- `lib/glob.sh`: `excluded PATH`, the one reading of the `exclude` inputs.
- `tests/run`: runs the cases of each `tests/NAME.sh` against `tests/gh`, the fake gh. Its header
  comment says how to write a case.
- `tools/run`: downloads the lint tools at the versions and SHA-256 sums it pins, into
  `.cache/tools`. `tools/release` checks a version tag, and publishes its release.

## Commands

```sh
make lint                          # actionlint, zizmor, ShellCheck and shfmt, as CI's lint job
make test                          # every case, as CI's test job
tests/run NAME...                  # the cases of tests/NAME.sh alone
make lint-file FILES='PATHS'       # the gates of some files, as the lint hooks run them
```

`make lint` needs curl the first time, and runs zizmor's online audits where `GH_TOKEN` is set.
`make test` needs git and jq.

## How an action is built

Every action:

- `action.yml` passes `github.repository`, the pull request's number and the inputs in `env:`,
  never as `${{ }}` in `run:`, which zizmor's template-injection audit refuses.

The checks alone:

- A check never blocks. `check.sh` exits 0 on findings and on its own errors: `report_start` traps
  them, and each ends in one warning. A case of `tests/NAME.sh` fails where it exits non-zero.
- It reads the pull request through `gh api` alone, and checks out nothing, so it runs none of the
  pull request's code. It runs on `pull_request`, of the types `opened, edited, reopened,
  synchronize`. Every check takes the inputs `token` and `comment`, and none that changes a rule:
  `check.sh` holds the skill's own values, with a link to the section that sets each.
- `check.sh` reaches `lib/` as `$GITHUB_ACTION_PATH/../lib`: the runner downloads the whole
  repository for `zadykian/actions/NAME@SHA`.
- A finding says where, quotes what is wrong, and links to the rule's section of the skill. The
  rule says how to fix it, with a command where one exists.

`ff`:

- It runs on `issue_comment`, and acts on a `/ff` comment on a pull request alone.
- Unlike a check, it goes past `gh api`: it checks out the default branch, fetches the pull
  request's head, and pushes it with git. It runs none of the pull request's code.
- It blocks: a refusal fails the job, and `comment-refusal.sh` comments why. Once the push lands,
  closing the issues and deleting the branch only warn. It takes no inputs, and uses no `lib/`.
- `tests/ff.sh` runs its scripts in a clone of a local origin. A case checks where `main` ends,
  and what the pull request is told.

## Commits and pull requests

- [atomic-commits](https://github.com/zadykian/skills/blob/main/skills/atomic-commits/SKILL.md)
  sets how commits and pull requests are cut and written.
- [writing](https://github.com/zadykian/skills/blob/main/skills/writing/SKILL.md) sets the prose.
- [banned-terms](https://github.com/zadykian/skills/blob/main/skills/banned-terms/SKILL.md) sets
  the terms kept out of names and prose.
- Commits are signed. The repository is public: no secret, employer's name, internal host or
  address goes into it.

## How changes land

[land](https://github.com/zadykian/skills/blob/main/skills/land/SKILL.md) lands each pull request
with a `/ff` comment, which `.github/workflows/fast-forward.yml` acts on. The maintainer pushes one
that changes `.github/workflows` by hand, as the workflow's token may not push it.

## Releases

- One tag, `vX.Y.Z`, versions every action at once. No file holds the version, and there is no
  changelog: each release's notes list its commits.
- After a stack lands, the maintainer pushes the annotated tag: `/flow:land PR... vX.Y.Z` gives
  the commands. `.github/workflows/release.yml` runs `tools/release` on it, which checks the tag
  and publishes the release.
- `tools/release` refuses a lightweight tag, one off `main`, and a version other than the bump
  that the commits since the previous tag call for, as [README.md](README.md#versions) says.
- A released tag is never moved or deleted, and no major tag, such as `v1`, follows the releases.
