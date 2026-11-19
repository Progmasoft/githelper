<!-- SPDX-FileCopyrightText: 2026 Progmasoft <support@progmasoft.com> -->
<!-- SPDX-License-Identifier: MIT-0 -->

# Architecture

| Package | What it does |
| --- | --- |
| `cmd/githelper` | The entry point. |
| `internal/githelper` | The commands, built with Cobra (`cli.go`); the workflows of `update`, `push`, `sync`, `start`, `status` (`workflow.go`) and of `start --from`, `merge`, `init`, `repo` (`branches.go`); index hygiene for generated and private paths (`hygiene.go`); the scope of a commit (`scope.go`). |
| `internal/console` | How a Git command shows as a step, with its output and its time. |

Every workflow reaches Git through the `gitRunner` interface (`git.go`), which runs `git` with its arguments directly
and never through a shell. The tests replace it with a scripted repository, so each workflow is checked command by
command without a real repository.

The guards:

- nothing is committed on the default branch, except the first commit of an empty repository (`init`);
- a push never forces;
- `sync` and `merge` need a clean work tree and do not push;
- generated output and `.claude/`, `.codex/` are removed from the index before and after staging.
