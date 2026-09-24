---
name: repo-init
description: >-
  Bootstrap a repository created from this template: verify the template files, run git init or detach a template clone, wire commit.template to .gitmessage, record the workflow and branch-naming variants, optionally scaffold (common directories, a references/ area, the AGENTS.md project section, archive excludes, origin remote, a Python env via py-env-setup), and hand template documents and LICENSE to repo-docs. Use for "set up this repo", "initialize from the template", or a first session in a fresh copy. Every mutation is gated.
compatibility: Requires git 2.22 or later and a POSIX shell (Git Bash on Windows).
---

# Goal

Take a fresh copy of this template from "files on disk" to "configured repository": a git repo exists, `git commit` loads `.gitmessage` as its template, the `Workflow:` and `Adopted:` lines reflect decisions the user actually made, and any project scaffolding the user opted into is in place. A consumer copy leaves this skill with no template residue: no template history, no template remote, and no template identity in README, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, their translations, header images, or LICENSE.

# When NOT to use

* The repo is already configured (step 1 reports all green) and the user wants no scaffolding: report that and stop.
* The user wants to make a commit, branch, or push: the matching `git-*` skill owns each of those; suggest it.
* The user only wants a Python environment: suggest `py-env-setup`.
* The user only wants a README, license, or community file written or updated: suggest `repo-docs`.
* The template files themselves are missing (no `.gitmessage` at the root): this skill configures, it does not fetch. Tell the user to copy the template files in first (or create the repo from the template again) and stop.

# Procedure

Terms such as choice question, independent reads, invoke, and suggest follow AGENTS.md (Skill authoring); in a non-interactive session every gate ends this skill.

Run every command in this skill in a POSIX shell. Reference files live under `references/` in the skill directory (AGENTS.md, Skill authoring); read each at the step that names it: `references/adapter-links.md` (steps 1 and 2), `references/references-area.md` (6c), `references/origin-remote.md` (6e), and `references/rationale.md` when the user asks why the skill works this way.

1. **Probe, read-only.** Run these independent reads:
   * `ls .gitmessage .gitattributes .gitignore AGENTS.md 2>/dev/null` and `ls .agents/skills 2>/dev/null` (template files present?).
   * The adapter and archive probe below.
   * `git rev-parse --is-inside-work-tree 2>/dev/null` (already a git repo?).
   * `git rev-parse --show-toplevel 2>/dev/null` (WHICH repo, for the report).
   * `git rev-parse --show-prefix 2>/dev/null` (empty exactly when the current directory is the toplevel; see the nested-repo stop below).
   * `git config --get commit.template 2>/dev/null` (template wired up?).
   * `grep -E '^#\s*Workflow:' .gitmessage 2>/dev/null` (workflow variant recorded?).
   * `grep -E '^#\s*Adopted:' .gitmessage 2>/dev/null` (naming variant recorded?).
   * `git remote get-url origin 2>/dev/null` (origin present, and its URL; consumed by steps 2 and 6e).

   Adapter and archive probe; run it as written, under `sh`, so an unmatched glob is safe in zsh too:
   ```
   sh <<'EOF'
   if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
     ex=$(git check-attr export-ignore -- .gitmessage)
     case "$ex" in *": set") echo "archive excludes: on";; *) echo "archive excludes: off";; esac
     git ls-files -s | awk '$1=="120000"{print $4}' | while read -r l; do
       t=$(git cat-file -p ":$l" | tr -d '\r\n')
       case "$t" in *.agents/skills) ;; *) continue;; esac
       [ "$(git cat-file -s ":$l")" -eq "${#t}" ] || echo "malformed: $l"
       { [ -L "$l" ] && [ -e "$l" ]; } || echo "broken: $l"
       case "$ex" in *": set")
         d=${l%%/*}
         case "$(git check-attr export-ignore -- "$d/")" in *": set") ;; *) echo "not export-ignored: $d/";; esac;;
       esac
     done
   else
     echo "archive excludes: n/a (not a git repository)"
   fi
   for f in .[!.]*/skills; do
     [ -f "$f" ] && [ ! -L "$f" ] || continue
     case "$(tr -d '\r\n' < "$f")" in *.agents/skills) ;; *) continue;; esac
     [ "$(git ls-files -s -- "$f" 2>/dev/null | cut -d' ' -f1)" = 120000 ] && continue
     if [ "$(grep -c '' "$f")" -eq 1 ]; then echo "unregistered: $f"; else echo "malformed: $f"; fi
   done
   EOF
   ```
   **Nested-repo stop.** When `--is-inside-work-tree` is true but `--show-prefix` is non-empty, the current directory sits inside a parent repository, not at its toplevel. STOP and explain: `git init` here would nest repos, and `git config commit.template` would write into the PARENT repo's configuration. The user either extracts the copy to its own directory or, to configure that parent repo, re-runs this skill from its toplevel.

   Render a checklist:
   ```
   repo-init check:
     [x|.] template files present : .gitmessage .gitattributes .gitignore AGENTS.md .agents/skills
     [x|.] adapter links          : ok | broken: <paths> | unregistered: <paths> | malformed: <paths> | not export-ignored: <dirs>
     [x|.] archive excludes       : on | off (template default; see 6g) | n/a
     [x|.] git repository         : yes | no
     [x|.] commit.template set    : <value> | unset
     [x|.] Workflow variant       : git-flow | github-flow | trunk-solo | not recorded
     [x|.] naming variant         : Variant A | Variant B | Variant C | not recorded
   ```
   When the probe prints a link state, read `references/adapter-links.md` before reporting it. `broken` links and `not export-ignored` directories are report-only: give the user the fix that file names. This skill repairs only `unregistered` paths and single-line `malformed` links, at the end of step 2.

   When every box is checked, report the summary, still run step 2 (a repo with its own history is a no-op there), then skip steps 3 to 5 and continue at step 6 so the optional scaffolding is still offered. A step-2 fresh start replaces `.git` and its config, so after one, re-run this probe and decide the skip from the new result.

2. **Repository provenance.** Branch on what step 1 found:
   * **Not a repo**: ask with a choice question (**init** / **abort**), rendering the exact command first: `git init -b main`. The `-b` flag needs git 2.28+; on older git render `git init && git symbolic-ref HEAD refs/heads/main` instead. On **abort**, stop; the remaining steps all assume a repository.
   * **A clone of the template** (the step-1 origin URL contains the template's distribution name `tmpl.general-repo`, or the user says the copy came from cloning the template): the `.git` directory carries the TEMPLATE's commit history and its origin remote, which a consumer project must not inherit. The same URL test also matches the template's own repository and any fork maintained as a template, so this branch never assumes a consumer project. Render the evidence: the origin URL, `git log --oneline -5`, the total commit count from `git rev-list --count HEAD`, the local-only commits from `git log --branches --tags HEAD --not --remotes --oneline` (reachable only from a local branch, tag, or detached HEAD), `git stash list`, `git worktree list --porcelain` (every `worktree` entry after the first is a linked worktree), the local branch and tag names origin lacks, and the submodule repositories stored inside `.git` with their local-only commits:
     ```
     sh <<'EOF'
     r=$(GIT_TERMINAL_PROMPT=0 git ls-remote --refs origin 'refs/heads/*' 'refs/tags/*') || { echo "origin unreachable: count every local branch and tag name as local-only"; exit 0; }
     { printf '%s\n' "$r" | sed 's/^/R /'; git for-each-ref --format='L %(refname)' refs/heads refs/tags; } | awk '$1=="R"{s[$3]=1;next} !($2 in s){print "local-only name: " $2}'
     m="$(git rev-parse --git-common-dir)/modules"
     if [ -d "$m" ]; then find "$m" -type d -name objects | while read -r o; do d=${o%/objects}; [ -f "$d/HEAD" ] || continue; echo "submodule repository inside .git: ${d#"$m"/}"; git --git-dir="$d" log --oneline --branches --tags HEAD --not --remotes | sed 's/^/  local-only: /'; done; fi
     EOF
     ```
     Then ask with a choice question. Mark **fresh start** as recommended only when the conversation has already ruled out the template-itself case (for example the user said they cloned the template to start a new project); otherwise mark no option recommended:
     * **fresh start**: `rm -rf .git`, then `git init -b main` (older git: the fallback above). Deletes the inherited template history and remote; every working file stays untouched. This is the one deliberately destructive action in this skill, so the question text itself MUST restate exactly what is deleted, INCLUDING every local-only commit on any branch, tag, or detached HEAD, every local-only branch or tag name, every stash entry, the git data of every linked worktree (those directories are left orphaned, no longer usable as worktrees), and every submodule repository stored inside `.git` with its local-only commits. Afterwards re-run the step-1 probe (see its skip rule): the new `.git` has no `origin`, so 6a offers the remote wiring. When the local-only log, the local-only names, or the stash list is non-empty, or a linked worktree or submodule repository exists, do not proceed until the user confirms those are disposable.
     * **keep history**: the user wants to pull template updates later, or their own commits must survive. Keep `.git` as-is, and offer a gated `git remote rename origin template`, freeing the `origin` name for the project's own remote. After the rename, treat `origin` as absent for the rest of this run, so 6a offers the remote wiring. For later template updates, the user runs `git fetch template`, then suggest `git-merge` with source `template/main`.
     * **template itself**: this repository IS the template, or a fork the user maintains as a template. Proceed as keep history WITHOUT the rename offer (`origin` already is the project's own remote), and step 7 treats the repo as the template itself.
     * **abort**: STOP.
   * **A repo with its own project history**: nothing to do; continue.

   **Register adapter links.** Whenever a repository exists after the branching above, re-run the probe, and read `references/adapter-links.md` before a register or repair gate. For each `unregistered:` path, render the commands and ask **register** / **skip** (on **skip**, warn that the next `git add` of that path commits it as a regular file):
   ```
   tr -d '\r\n' < <path> > <path>.tmp && mv <path>.tmp <path>
   git update-index --add --cacheinfo "120000,$(tr -d '\r\n' < <path> | git hash-object -w --stdin),<path>"
   ```

   For each `malformed:` path that is a tracked link, check `git cat-file -p :<path> | grep -c ''`. When it prints `1` (one line plus trailing line breaks), render the stripped target and the commands below, then ask **repair** / **skip**; any other count, and every `malformed:` plain file, is report-only:
   ```
   [ -L <path> ] || { tr -d '\r\n' < <path> > <path>.tmp && mv <path>.tmp <path>; }
   git update-index --cacheinfo "120000,$(git cat-file -p :<path> | tr -d '\r\n' | git hash-object -w --stdin),<path>"
   ```
   After a repair on a symlink-aware checkout, the link on disk reports as `broken`; `rm <path> && git checkout -- <path>` restores it.

3. **Wire the commit template (only when unset or pointing elsewhere).** Render the exact command, then ask with a choice question (**set** / **skip**):
   ```
   git config commit.template .gitmessage
   ```
   Local repo config, not `--global`. When `commit.template` is set to a different path, show it in the question; **set** overwrites it for this repo only.

4. **Resolve and record the workflow variant.** Read the `Workflow:` line in `.gitmessage`.
   * The template ships `Workflow: <not recorded>` (skills then assume `git-flow`). Whatever the line holds, ask with a choice question which variant applies (`git-flow` / `github-flow` / `trunk-solo`; none recommended; tradeoffs from `.gitmessage`), unless the user already stated it in this conversation.
   * Then ask **record** / **skip**: after a step-2 **template itself** answer, mark **skip** as recommended and say that a recorded line ships to every consumer of the template. On **record**, update the `Workflow:` line as an in-place edit so downstream skills (`git-commit`, `git-push`, `git-merge`, `git-branch-create`, `git-branch-delete`, `git-fetch`) read the decided value. On **skip**, warn that an undeclared variant makes those skills assume `git-flow`, the strictest.

5. **Resolve the branch-naming variant.** Ask with a choice question which of `.gitmessage`'s "Branch Naming" variants the repo adopts (A: issue-id, B: scope, C: plain short-desc), unless already stated. Record the answer by updating the section's `Adopted:` line as an in-place edit (the template ships it as `Adopted: <not recorded>`; set it to, for example, `Adopted: Variant B`), behind its own **record** / **skip** gate, with the same **template itself** recommendation as step 4. `git-branch-create` step 4 and `git-commit` step 3e read this line instead of guessing.

6. **Optional scaffolding.** Two layers: 6a picks WHAT to scaffold (design), 6b to 6g each render their exact content or command and gate it (execution). Skip 6a entirely when the user already named what they want in the current conversation.

   a. **Select scope** with TWO multi-select choice questions asked together (a choice question tops out at 4 options, so the six items split by kind; offer only items not already present):
      * Question "files and directories": **common directories** (config/, scripts/, and docs/ when absent), **references area** (read-only external repos, git-ignored), **project instructions** (fill the Project and Commands sections of `AGENTS.md`; offered while its placeholders remain), **archive excludes** (enable the `.gitattributes` export-ignore lines; consumer copies only, so not when step 2 resolved to **template itself** or the user has said this repo is the template, and only while step 1 reports `archive excludes: off`).
      * Question "integrations": **origin remote** (only when `origin` is absent; see step 2), **python environment** (invokes `py-env-setup`).
      Nothing selected in either question means step 6 is done; continue at step 7.

   b. **Common directories.** Ask with a multi-select choice question which of `docs/`, `config/`, `scripts/` to create, offering only those that do not exist yet (the template ships `docs/` for its translations; the user can type additional names). git does not track empty directories, so each created directory gets a `.gitkeep` placeholder. Render the resulting `mkdir` plus `.gitkeep` plan inline; the multi-select answer is the gate, since it names exactly what will be created. Skip any directory that already exists.

   c. **References area.** Render both new repo-root files inline (`references/README.md` and `references/.gitignore` at the repository root, exactly as given in this skill's own `references/references-area.md`), then ask **create** / **abort**. The root `.gitignore` is NOT touched.

   d. **Project instructions.** Edit only `AGENTS.md` (the single instruction source), never an adapter file. Replace its `<Project name ...>` and `<Build / test / run ...>` placeholders from what the conversation establishes; keep a placeholder wherever nothing is known. Render the diff, then ask **write** / **abort**; on **write**, apply as an in-place edit, leaving every other section untouched.

   e. **Origin remote (only when absent).** Settle the transport and take the URL per `references/origin-remote.md` (the URL form gives the transport; with no URL yet, ask for the host, probe both readiness signals, then ask **HTTPS** / **SSH**). Render `git remote add origin <url>`, then ask **add** / **abort**. Verify with `git remote -v` and include it in the step-9 report. Adding the remote never pushes anything; publishing stays with `git-push`.

   f. **Python environment.** Invoke `py-env-setup`, which owns its own probing, version recommendation, and gates. Do not duplicate any of its questions here.

   g. **Archive excludes.** The template ships every `export-ignore` line in `.gitattributes` commented out; a consumer project wants them on. Render the lines that will change (`grep -nE '^# [^ ]+ +export-ignore$' .gitattributes`) and the exact command, then ask **enable** / **skip**:
      ```
      sed -E 's/^# ([^ ]+ +export-ignore)$/\1/' .gitattributes > .gitattributes.tmp && mv .gitattributes.tmp .gitattributes
      ```
      On **enable**, run it and verify that `git check-attr export-ignore -- .gitmessage` reports `set`; the step-9 checklist then also checks every adapter directory.

7. **Project identity (consumer copies only).** When README, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, a translation in `docs/i18n/`, or a header image in `.github/assets/` still carries the template's own title (`General Repository Template`) or distribution name (`tmpl.general-repo`), this copy is presenting itself as the template rather than as the user's project; its LICENSE then usually still carries the template author's copyright line too (show that line). Name the files found, then ask **rewrite** / **keep**. On **rewrite**, invoke `repo-docs`, which owns these documents, the license choice and holder, the translations, and the header images under its own gates; do not duplicate its questions here.
   Skip this step only when the user says this repo IS the template itself (including a step-2 **template itself** answer). A working-directory basename of `tmpl.general-repo` is NOT sufficient evidence, because a default `git clone` keeps that name; when step 2 detached a template clone, always treat the repo as a consumer project, and when in doubt, ask.

8. **Optional first commit.** When step 2 created a brand-new repo, or steps 6 to 7 created new files, ask with a choice question (**commit** / **skip**) whether to land the pending files; on **commit**, invoke `git-commit`.

9. **Report.** Re-render the step-1 checklist, state how step 2 resolved provenance (initialized fresh, detached, history kept, template itself, or untouched), name the recorded variants, list what was scaffolded or declined, and list next steps: suggest `git-branch-create` (or `git-commit` directly under `trunk-solo`); under `git-flow`, `git branch develop` after the first commit (user-run; `git-branch-create` refuses trunk names); `git remote add origin <url>` when still absent; suggest `py-env-setup` when Python is needed but 6f was not taken.

# Hard rules

* NEVER run `git init` inside an existing repository or a subdirectory of one, and NEVER configure from inside a parent repo's subdirectory. A non-empty `git rev-parse --show-prefix` is the signal, never a text comparison of `--show-toplevel` with `pwd`; the step-1 nested-repo stop handles it. The single exception is the step-2 **fresh start**, which first removes the inherited template `.git` entirely, behind its own gate.
* NEVER run `rm -rf .git` outside the step-2 fresh-start path, never without its gate, and never when the history is the user's own project work rather than the template's, including the template's own repository or a fork the user maintains (the step-2 **template itself** answer).
* NEVER set `--global` git config from this skill. Repo-local only.
* NEVER overwrite `.gitmessage` or `.gitattributes` wholesale, and never modify the root `.gitignore`. `.gitmessage` changes are the in-place line updates in steps 4 and 5; `.gitattributes` changes are the step-6g uncommenting, which changes only the matched lines. The only index changes are the step-2 adapter-link registration and repair, which stage but never commit; the one worktree write they make is stripping line breaks from that adapter file itself. Every other write renders its exact content or diff first and sits behind its own gate.
* NEVER scaffold anything not selected in step 6a (or named by the user), and NEVER re-create or overwrite an item that already exists; surface it and move on.
* NEVER pick a workflow or naming variant for the user. The shipped placeholder is not an answer; only an in-conversation answer gets recorded.
* NEVER commit, branch, or push from this skill. The only remote-state changes permitted are the step-6e `git remote add origin` and the step-2 `git remote rename origin template`, each behind its own gate; neither publishes anything.
* NEVER duplicate `py-env-setup`'s questions or run conda commands here. Step 6f invokes that skill; it is not an inline implementation.
