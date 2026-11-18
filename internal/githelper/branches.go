// SPDX-FileCopyrightText: 2026 Progmasoft <support@progmasoft.com>
// SPDX-License-Identifier: MIT-0

package githelper

import (
	"fmt"
	"io"
	"net/url"
	"strings"
)

// resolveBase names the commit a branch name stands for: the remote branch
// when the remote has one, the local branch otherwise.
func resolveBase(runner gitRunner, name string) (string, error) {
	for _, candidate := range []string{remoteName + "/" + name, name} {
		if _, err := runner.Capture("rev-parse", "--verify", "--quiet", candidate+"^{commit}"); err == nil {
			return candidate, nil
		}
	}
	return "", failf("no branch or commit %q, on %s or here", name, remoteName)
}

// startFrom creates a topic branch from another branch, for a pull request
// that builds on one that is not merged yet.
func startFrom(runner gitRunner, output io.Writer, name, from string) error {
	if code, err := runner.Run(nil, true, "check-ref-format", "--branch", name); err != nil {
		return err
	} else if code != 0 {
		return exitError{code: 2, message: fmt.Sprintf("error: %q is not a valid branch name", name)}
	}
	if err := requireCleanWorkTree(runner, "start"); err != nil {
		return err
	}
	if err := run(runner, "git fetch failed", "fetch", "--prune", remoteName); err != nil {
		return err
	}
	base, err := resolveBase(runner, from)
	if err != nil {
		return err
	}
	if err := run(runner, "the branch could not be created; it may already exist",
		"switch", "--create", name, "--no-track", base); err != nil {
		return err
	}
	fmt.Fprintf(output, "on new branch %s from %s; open its pull request against %s\n", name, base, from)
	return nil
}

// merge brings another branch into the current topic branch, such as the
// branch a stacked pull request builds on. Like sync, it does not push.
func merge(runner gitRunner, output io.Writer, name string) error {
	branch, err := currentBranch(runner)
	if err != nil {
		return err
	}
	if err := refuseDefaultBranch(runner, branch, "merging"); err != nil {
		return err
	}
	if err := requireCleanWorkTree(runner, "merge"); err != nil {
		return err
	}
	if err := run(runner, "git fetch failed", "fetch", "--prune", remoteName); err != nil {
		return err
	}
	source, err := resolveBase(runner, name)
	if err != nil {
		return err
	}
	behind, err := captureLine(runner, "rev-list", "--count", "HEAD.."+source)
	if err != nil {
		return err
	}
	if behind == "0" {
		fmt.Fprintf(output, "%s already contains %s\n", branch, source)
		return nil
	}
	code, err := runner.Run(nil, false, "merge", "--no-edit", source)
	if err != nil {
		return err
	}
	if code != 0 {
		return exitError{code: code, message: "error: the merge stopped on conflicts; resolve them, commit with `githelper update`, or run `git merge --abort`"}
	}
	fmt.Fprintf(output, "merged %s commit(s) from %s; test the result, then run `githelper push`\n", behind, source)
	return nil
}

// initialCommit makes the first commit of an empty repository, on the branch
// HEAD names, and pushes it. Protected-branch rules cannot apply before a
// branch exists, so this is the one commit allowed on the default branch, and
// only while the repository has no commit at all.
func initialCommit(runner gitRunner, output io.Writer, message string) error {
	if strings.TrimSpace(message) == "" {
		return exitError{code: 2, message: "error: the commit message is empty"}
	}
	if _, err := runner.Capture("rev-parse", "--verify", "--quiet", "HEAD"); err == nil {
		return failf("the repository has commits already; `githelper init` makes only the first one")
	}
	branch, err := captureLine(runner, "symbolic-ref", "--short", "HEAD")
	if err != nil || branch == "" {
		return failf("cannot tell which branch the first commit goes on")
	}
	if err := cleanIndex(runner); err != nil {
		return err
	}
	if err := run(runner, "git add --all failed", "add", "--all"); err != nil {
		return err
	}
	if err := cleanIndex(runner); err != nil {
		return err
	}
	paths, err := stagedPaths(runner)
	if err != nil {
		return err
	}
	if len(paths) == 0 {
		return failf("nothing to commit")
	}
	fmt.Fprint(output, describeScope(paths))
	code, err := runner.Run([]byte(normalizeMessage(message)), false, "commit", "--file=-")
	if err != nil {
		return err
	}
	if code != 0 {
		return exitError{code: code, message: "error: git commit failed"}
	}
	return pushBranch(runner, branch)
}

// repositoryName reads `owner/name` from the URL of the remote, for
// `gh pr create --repo`, so a pull request of a fork cannot go to the
// repository it was forked from.
func repositoryName(runner gitRunner) (string, error) {
	address, err := captureLine(runner, "remote", "get-url", remoteName)
	if err != nil || address == "" {
		return "", failf("%s has no URL", remoteName)
	}
	path := ""
	if parsed, err := url.Parse(address); err == nil && parsed.Host != "" {
		path = parsed.Path
	} else if _, rest, found := strings.Cut(address, ":"); found {
		// The scp form: git@github.com:owner/name.git.
		path = rest
	}
	path = strings.TrimSuffix(strings.Trim(path, "/"), ".git")
	parts := strings.Split(path, "/")
	if len(parts) < 2 || parts[len(parts)-2] == "" || parts[len(parts)-1] == "" {
		return "", failf("cannot read owner/name from %s", address)
	}
	return parts[len(parts)-2] + "/" + parts[len(parts)-1], nil
}
