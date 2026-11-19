<!-- SPDX-FileCopyrightText: 2026 Progmasoft <support@progmasoft.com> -->
<!-- SPDX-License-Identifier: MIT-0 -->

# Development

githelper needs Go.

```sh
go vet ./...
go test ./...
gofmt -l .
./install.sh            # or install.cmd, Install-Githelper.ps1
```

CI runs go vet, the tests and gofmt on Linux, Windows and macOS; runs `install.sh` on Linux and macOS (with
ShellCheck) and both Windows scripts on Windows; and checks the workflows with zizmor and actionlint.
