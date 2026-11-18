<!-- SPDX-FileCopyrightText: 2026 Progmasoft <support@progmasoft.com> -->
<!-- SPDX-License-Identifier: MIT-0 -->

# githelper

githelper is a guarded Git workflow for topic branches and pull requests. It stages safely, commits the message as
written, and pushes without ever forcing, so remote history is never rewritten. It keeps generated output and the
private notes of coding agents (`.claude/`, `.codex/`) out of the index, and it refuses to commit on the default
branch.

| Command | What it does |
| --- | --- |
| `start <branch>` | Creates a topic branch from the remote default branch |
| `start <branch> --from <other>` | Creates it from another branch instead, for a pull request that builds on one not merged yet |
| `update [message]` | Stages every change, commits and pushes; `--message-file`, `--dry-run`, `--no-push` |
| `push` | Pushes existing commits without creating one |
| `sync` | Merges the remote default branch into the current branch, without pushing |
| `merge <branch>` | Merges another branch into the current topic branch, without pushing |
| `init [message]` | Makes and pushes the first commit of an empty repository, and refuses one that has a commit |
| `repo` | Prints `owner/name` of the remote, for `gh pr create --repo "$(githelper repo)"` |
| `status` | Shows the branch, its upstream, the default branch and what is uncommitted |
| `clean` | Removes generated and ignored files from the index |

A typical topic branch:

```sh
githelper start feature/name
githelper update --message-file message.txt
githelper sync          # merge the default branch, then test
githelper push
```

## Installing

```sh
go install github.com/Progmasoft/githelper/cmd/githelper@latest
```

or, from a clone, `go build -trimpath -o ~/.local/bin/githelper ./cmd/githelper`. githelper calls `git` with its
arguments directly and never builds a shell command.

## License

[MIT-0](LICENSE.txt). Progmasoft's own code is also covered by the [Progmasoft Patent Grant 1.1](PATENTS.md).
Participation follows the [Code of Conduct](CODE_OF_CONDUCT.md).
