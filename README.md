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

The install scripts build githelper from a checkout with Go and install it. In a clone of this repository:

| Command | Where githelper goes | Path |
| --- | --- | --- |
| `./install.sh` | `$HOME/.local/bin/githelper`, the directory created when missing | added to `PATH` in the profile of the login shell when missing |
| `./install.sh -p <dir>` | `<dir>/githelper`; `<dir>` must exist, and `sudo` is used when it is not writable, as `/usr/bin` | not changed |
| `install.cmd` | `%USERPROFILE%\.local\bin\githelper.exe`, the folders created when missing | added to the user Path when missing |
| `install.cmd /globalenv` | the same | added to the machine Path; needs an administrator |
| `install.cmd /path<dir>`, `/path:<dir>` | `<dir>\githelper.exe`; `<dir>` must exist | user Path, or machine Path with `/globalenv` |
| `Install-Githelper.ps1` | as `install.cmd` | as `install.cmd` |
| `Install-Githelper.ps1 -GlobalEnvironment` | as `install.cmd /globalenv` | machine Path |
| `Install-Githelper.ps1 -Path <dir>`, with or without `-GlobalEnvironment` | as `install.cmd /path` | user or machine Path |

`install.sh` is POSIX `sh`, for Linux, macOS and the BSDs; `Install-Githelper.ps1` needs PowerShell 7. Their help is
`install.sh -h`, `install.cmd /?` or `install.cmd /HELP`, and `Install-Githelper.ps1 -Help`. The options of
`install.sh` and `install.cmd` are case-sensitive, except `/HELP`; those of `Install-Githelper.ps1` are not.

With Go alone: `go install github.com/Progmasoft/githelper/cmd/githelper@latest`. githelper calls `git` with its
arguments directly and never builds a shell command.

## License

[MIT-0](LICENSE.txt). Progmasoft's own code is also covered by the [Progmasoft Patent Grant 1.1](PATENTS.md).
Participation follows the [Code of Conduct](CODE_OF_CONDUCT.md).
