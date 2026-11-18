#!/bin/sh
# SPDX-FileCopyrightText: 2026 Progmasoft <support@progmasoft.com>
# SPDX-License-Identifier: MIT-0

# Builds githelper from this checkout and installs it, on Linux, macOS and
# the BSDs. POSIX sh only; options are case-sensitive.
#
#   install.sh            installs $HOME/.local/bin/githelper, creating the
#                         directory, and adds it to PATH in the profile of the
#                         login shell when PATH lacks it
#   install.sh -p <dir>   installs <dir>/githelper; <dir> must exist, sudo is
#                         used when it is not writable, and <dir> is added to
#                         PATH the same way
#   install.sh -h         shows this help

set -eu

usage() {
    cat <<'EOF'
Usage: install.sh [-p <directory>] [-h]

Builds githelper from this checkout with Go and installs it.

  (no option)      Install $HOME/.local/bin/githelper. The directory is
                   created when missing.
  -p <directory>   Install <directory>/githelper. The directory must exist;
                   it is not created. When it is not writable, as /usr/bin,
                   sudo is used for the copy.
  -h               Show this help.

Either way, the directory is added to PATH when PATH does not have it, in the
profile your login shell reads: bash ~/.bash_profile (or ~/.profile when there
is no ~/.bash_profile), zsh ~/.zprofile, fish ~/.config/fish/conf.d/githelper.fish,
dash and ksh ~/.profile; any other shell ~/.profile.

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

# PATH lacks the directory: add it in the profile the login shell reads. The
# default is written as $HOME/.local/bin, for the shell to expand; a -p
# directory as it is, quoted.
if [ "$default" -eq 1 ]; then
    entry="\$HOME/.local/bin"
else
    entry=$(printf '%s' "$target" | sed 's/[\\"$`]/\\&/g')
fi
marker="# Added by githelper's install.sh: $target"
case "$(basename -- "${SHELL:-sh}")" in
    bash)
        profile="$HOME/.bash_profile"
        [ -f "$profile" ] || profile="$HOME/.profile"
        line="export PATH=\"$entry:\$PATH\""
        ;;
    zsh)
        profile="$HOME/.zprofile"
        line="export PATH=\"$entry:\$PATH\""
        ;;
    fish)
        profile="$HOME/.config/fish/conf.d/githelper.fish"
        mkdir -p -- "$(dirname -- "$profile")"
        if [ "$default" -eq 1 ]; then
            line="fish_add_path --path \"\$HOME/.local/bin\""
        else
            # fish expands nothing inside single quotes; only \ and ' are escaped.
            quoted=$(printf '%s' "$target" | sed "s/[\\\\']/\\\\&/g")
            line="fish_add_path --path '$quoted'"
        fi
        ;;
    dash | ksh | mksh | ksh93 | *)
        # dash and ksh read ~/.profile as login shells, as POSIX sh does.
        profile="$HOME/.profile"
        line="export PATH=\"$entry:\$PATH\""
        ;;
esac
if [ -f "$profile" ] && grep -qxF -- "$marker" "$profile"; then
    printf 'note: %s adds %s to PATH already; open a new login shell\n' "$profile" "$target"
    exit 0
fi
printf '\n%s\n%s\n' "$marker" "$line" >> "$profile"
printf 'added %s to PATH in %s; open a new login shell to use it\n' "$target" "$profile"
