#!/bin/sh
# SPDX-FileCopyrightText: 2026 Progmasoft <support@progmasoft.com>
# SPDX-License-Identifier: MIT-0

# Builds githelper from this checkout and installs it, on Linux, macOS and
# the BSDs. POSIX sh only; options are case-sensitive.
#
#   install.sh            installs $HOME/.local/bin/githelper, creating the
#                         directory, and adds it to PATH in the profile of the
#                         login shell when PATH lacks it
#   install.sh -p <dir>   installs <dir>/githelper; <dir> must exist, and sudo
#                         is used when it is not writable
#   install.sh -h         shows this help

set -eu

usage() {
    cat <<'EOF'
Usage: install.sh [-p <directory>] [-h]

Builds githelper from this checkout with Go and installs it.

  (no option)      Install $HOME/.local/bin/githelper. The directory is
                   created when missing, and added to PATH in the profile of
                   your login shell when PATH does not have it.
  -p <directory>   Install <directory>/githelper. The directory must exist;
                   it is not created. When it is not writable, as /usr/bin,
                   sudo is used for the copy. PATH is not changed.
  -h               Show this help.

Options are case-sensitive.
EOF
}

fail() {
    printf 'install.sh: %s\n' "$1" >&2
    exit 1
}

target=""
while getopts ":p:h" option; do
    case "$option" in
        p) target=$OPTARG ;;
        h) usage; exit 0 ;;
        :) fail "-$OPTARG needs a directory; install.sh -h shows the options" ;;
        *) fail "no option -$OPTARG; install.sh -h shows the options" ;;
    esac
done
shift $((OPTIND - 1))
[ "$#" -eq 0 ] || fail "unexpected argument '$1'; install.sh -h shows the options"

source_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
[ -f "$source_dir/go.mod" ] || fail "run install.sh from a checkout of githelper"
command -v go >/dev/null 2>&1 || fail "Go is needed to build githelper: https://go.dev/dl/"

default=0
if [ -z "$target" ]; then
    [ -n "${HOME:-}" ] || fail "HOME is not set"
    target="$HOME/.local/bin"
    default=1
    mkdir -p -- "$target"
elif [ ! -d "$target" ]; then
    fail "$target does not exist; create it first, or leave out -p"
fi

# The build goes to a temporary file, so a failed build changes nothing.
work=$(mktemp -d "${TMPDIR:-/tmp}/githelper.XXXXXX")
trap 'rm -rf -- "$work"' EXIT HUP INT TERM
(cd -- "$source_dir" && go build -trimpath -o "$work/githelper" ./cmd/githelper)

if [ -w "$target" ]; then
    cp -- "$work/githelper" "$target/githelper.new"
    chmod 0755 "$target/githelper.new"
    mv -f -- "$target/githelper.new" "$target/githelper"
else
    command -v sudo >/dev/null 2>&1 || fail "$target is not writable and sudo is not installed"
    printf 'install.sh: %s is not writable; installing with sudo\n' "$target"
    sudo install -m 0755 "$work/githelper" "$target/githelper"
fi
printf 'installed %s/githelper\n' "$target"

case ":${PATH:-}:" in
    *":$target:"*) exit 0 ;;
esac
if [ "$default" -eq 0 ]; then
    printf 'note: %s is not in PATH\n' "$target"
    exit 0
fi

# PATH lacks $HOME/.local/bin: add it in the profile the login shell reads,
# with $HOME and $PATH written as they are, for the shell to expand.
marker="# Added by githelper's install.sh"
export_line="export PATH=\"\$HOME/.local/bin:\$PATH\""
case "$(basename -- "${SHELL:-sh}")" in
    zsh) profile="$HOME/.zprofile"; line=$export_line ;;
    bash)
        profile="$HOME/.bash_profile"
        [ -f "$profile" ] || profile="$HOME/.profile"
        line=$export_line
        ;;
    fish)
        profile="$HOME/.config/fish/conf.d/githelper.fish"
        mkdir -p -- "$(dirname -- "$profile")"
        line="fish_add_path --path \"\$HOME/.local/bin\""
        ;;
    *) profile="$HOME/.profile"; line=$export_line ;;
esac
if [ -f "$profile" ] && grep -qF -- "$marker" "$profile"; then
    printf 'note: %s adds %s to PATH already; open a new login shell\n' "$profile" "$target"
    exit 0
fi
printf '\n%s\n%s\n' "$marker" "$line" >> "$profile"
printf 'added %s to PATH in %s; open a new login shell to use it\n' "$target" "$profile"
