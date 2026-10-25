# make lint, the gates that CI's lint job runs. Any finding fails a gate, warnings included; make
# -k lint runs every gate past a failure. Each gate is a target of its own. shell takes FILES, every
# script of the tree where it is empty: make shell FILES=tools/run. tools/run runs each tool at the
# version and SHA-256 it pins.
FILES =

.PHONY: lint lint-file lint-tree actionlint zizmor shell

lint: actionlint zizmor shell

# What the lint plugin's hooks run here: the gates of the files Claude edited, and every gate at
# the end of its turn. A workflow or an action's metadata goes through actionlint and zizmor too.
lint-file:
	@$(MAKE) --no-print-directory shell FILES='$(FILES)' \
		$(if $(filter .github/% action.yml %/action.yml,$(FILES)),actionlint zizmor)
lint-tree: lint

# The workflows, their shell scripts through the pinned ShellCheck.
actionlint:
	shellcheck="$$(tools/run -path shellcheck)" && \
		tools/run actionlint -shellcheck="$$shellcheck" -pyflakes=

# The workflows, the actions' metadata and dependabot.yml, with the online audits where GH_TOKEN
# is set, as in CI.
zizmor:
	tools/run zizmor .

# The shell scripts, found by their extension or their shebang, as shfmt -f finds them, since
# tools/run has no extension. -x follows a script's source directives into the files it sources.
shell:
	@set -ef; scripts=$$(tools/run shfmt -f $(or $(FILES),.)); [ -z "$$scripts" ] || { \
		tools/run shellcheck -x $$scripts && tools/run shfmt -i 4 -d $$scripts; }
