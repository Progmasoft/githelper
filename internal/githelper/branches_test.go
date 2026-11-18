// SPDX-FileCopyrightText: 2026 Progmasoft <support@progmasoft.com>
// SPDX-License-Identifier: MIT-0

package githelper

import (
	"reflect"
	"strings"
	"testing"
)

func TestStartFromBuildsOnTheRemoteBranchFirst(t *testing.T) {
	git := topicRepository()
	git.captures["rev-parse --verify --quiet origin/feature/base^{commit}"] = "abc\n"
	output, err := invoke(git, "start", "feature/next", "--from", "feature/base")
	if err != nil {
		t.Fatal(err)
	}
	want := []string{"check-ref-format --branch feature/next", "fetch --prune origin", "switch --create feature/next --no-track origin/feature/base"}
	if !reflect.DeepEqual(git.runs, want) {
		t.Fatalf("runs = %#v", git.runs)
	}
	if !strings.Contains(output, "against feature/base") {
		t.Fatalf("output = %q", output)
	}

	local := topicRepository()
	local.captures["rev-parse --verify --quiet feature/base^{commit}"] = "abc\n"
	if _, err := invoke(local, "start", "feature/next", "--from", "feature/base"); err != nil {
		t.Fatal(err)
	}
	if last := local.runs[len(local.runs)-1]; last != "switch --create feature/next --no-track feature/base" {
		t.Fatalf("last run = %q", last)
	}

	missing := topicRepository()
	if _, err := invoke(missing, "start", "feature/next", "--from", "nope"); err == nil || !strings.Contains(err.Error(), `no branch or commit "nope"`) {
		t.Fatalf("err = %v", err)
	}
	for _, run := range missing.runs {
		if strings.HasPrefix(run, "switch") {
			t.Fatalf("a branch was created from nothing: %#v", missing.runs)
		}
	}
}

func TestMergeTakesAnotherBranchWithoutPushing(t *testing.T) {
	git := topicRepository()
	git.captures["rev-parse --verify --quiet origin/feature/base^{commit}"] = "abc\n"
	git.captures["rev-list --count HEAD..origin/feature/base"] = "3\n"
	output, err := invoke(git, "merge", "feature/base")
	if err != nil {
		t.Fatal(err)
	}
	want := []string{"fetch --prune origin", "merge --no-edit origin/feature/base"}
	if !reflect.DeepEqual(git.runs, want) {
		t.Fatalf("runs = %#v", git.runs)
	}
	if !strings.Contains(output, "merged 3 commit(s)") {
		t.Fatalf("output = %q", output)
	}

	current := topicRepository()
	current.captures["rev-parse --verify --quiet origin/feature/base^{commit}"] = "abc\n"
	current.captures["rev-list --count HEAD..origin/feature/base"] = "0\n"
	if output, err := invoke(current, "merge", "feature/base"); err != nil || !strings.Contains(output, "already contains") {
		t.Fatalf("err=%v output=%q", err, output)
	}

	conflict := topicRepository()
	conflict.captures["rev-parse --verify --quiet origin/feature/base^{commit}"] = "abc\n"
	conflict.captures["rev-list --count HEAD..origin/feature/base"] = "1\n"
	conflict.codes = map[string]int{"merge": 1}
	if _, err := invoke(conflict, "merge", "feature/base"); exitCode(err) != 1 || !strings.Contains(err.Error(), "conflicts") {
		t.Fatalf("err = %v", err)
	}

	onMain := topicRepository()
	onMain.captures["branch --show-current"] = "main\n"
	if _, err := invoke(onMain, "merge", "feature/base"); err == nil || len(onMain.runs) != 0 {
		t.Fatalf("merge ran on the default branch: err=%v runs=%#v", err, onMain.runs)
	}

	dirty := topicRepository()
	dirty.captures["status --short"] = " M file\n"
	if _, err := invoke(dirty, "merge", "feature/base"); err == nil || len(dirty.runs) != 0 {
		t.Fatalf("merge ran on a dirty tree: err=%v", err)
	}
}

// emptyRepository is a clone of a repository with no commit, HEAD on main.
func emptyRepository(staged ...string) *scriptedGit {
	git := topicRepository(staged...)
	delete(git.captures, "branch --show-current")
	git.captures["symbolic-ref --short HEAD"] = "main\n"
	return git
}

func TestInitMakesOnlyTheFirstCommit(t *testing.T) {
	git := emptyRepository("README.md", "LICENSE.txt")
	output, err := invoke(git, "init", "Start the repository")
	if err != nil {
		t.Fatal(err)
	}
	commands := git.mutating()
	want := []string{"add --all", "commit --file=-", "push -u origin main"}
	if !reflect.DeepEqual(commands, want) {
		t.Fatalf("commands = %#v", commands)
	}
	if git.input["commit --file=-"] != "Start the repository\n" {
		t.Fatalf("message = %q", git.input["commit --file=-"])
	}
	if !strings.Contains(output, "2") {
		t.Fatalf("output = %q", output)
	}

	existing := emptyRepository("README.md")
	existing.captures["rev-parse --verify --quiet HEAD"] = "abc\n"
	if _, err := invoke(existing, "init", "Again"); err == nil || len(existing.mutating()) != 0 {
		t.Fatalf("init ran on a repository with commits: err=%v runs=%#v", err, existing.runs)
	}

	empty := emptyRepository()
	if _, err := invoke(empty, "init", "Nothing"); err == nil || !strings.Contains(err.Error(), "nothing to commit") {
		t.Fatalf("err = %v", err)
	}
	if _, err := invoke(emptyRepository("a"), "init"); exitCode(err) != 2 {
		t.Fatalf("init without a message: err = %v", err)
	}
}

func TestRepoReadsOwnerAndNameFromTheRemote(t *testing.T) {
	for address, want := range map[string]string{
		"https://github.com/Progmasoft/catch3.git":    "Progmasoft/catch3",
		"https://github.com/Progmasoft/catch3":        "Progmasoft/catch3",
		"git@github.com:Leitwolf11/cloudflarectl.git": "Leitwolf11/cloudflarectl",
		"ssh://git@github.com/Progmasoft/outil.git":   "Progmasoft/outil",
	} {
		git := topicRepository()
		git.captures["remote get-url origin"] = address + "\n"
		output, err := invoke(git, "repo")
		if err != nil || strings.TrimSpace(output) != want {
			t.Errorf("%s: output=%q err=%v", address, output, err)
		}
		if len(git.runs) != 0 {
			t.Errorf("repo changed something: %#v", git.runs)
		}
	}
	bad := topicRepository()
	bad.captures["remote get-url origin"] = "nowhere\n"
	if _, err := invoke(bad, "repo"); err == nil {
		t.Fatal("repo read a name from nothing")
	}
}
