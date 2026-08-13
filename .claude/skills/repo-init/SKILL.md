---
name: repo-init
description: Bootstrap a repository created from this template: verify the template files, run git init or detach a direct clone from the template's history and remote, point git config commit.template at .gitmessage, ask-then-record the workflow and branch-naming variants, then optionally scaffold the project (common directories, a references/ area for read-only external repos, CLAUDE.md, origin remote wiring, README/LICENSE identity, a Python env via py-env-setup). Use for "set up this repo", "initialize from the template", "apply the template", or a first session in a fresh copy. Read-only probing first; every mutation has its own gate.
---

# Goal

Take a fresh copy of this template from "files on disk" to "configured repository": a git repo exists, `git commit` loads `.gitmessage` as its template, the `Workflow:` and `Adopted:` lines reflect decisions the user actually made, and any project scaffolding the user opted into (directories, references area, CLAUDE.md, remote, identity files) is in place. A consumer copy leaves this skill with no template residue: no template history, no template remote, and no template identity in README or LICENSE.

# When NOT to use

* The repo is already configured (step 1 reports all green) and the user wants no scaffolding: report that and stop.
* The user wants to make a commit, branch, or push: the matching `git-*` skill owns each of those.
* The user only wants a Python environment: `py-env-setup` directly.
* The template files themselves are missing (no `.gitmessage` at the root): this skill configures, it does not fetch. Tell the user to copy the template files in first (or create the repo from the template again) and stop.

# Procedure

Run every command in this skill through the `Bash` tool; the redirections used across this skill family are POSIX syntax and break under PowerShell.

1. **Probe, read-only.** Run in parallel:
   * `ls .gitmessage .gitattributes .gitignore 2>/dev/null` and `ls .claude/skills 2>/dev/null` (template files present?).
   * `git rev-parse --is-inside-work-tree 2>/dev/null` (already a git repo?).
   * `git rev-parse --show-toplevel 2>/dev/null` (WHICH repo; see the nested-repo stop below).
   * `git config --get commit.template 2>/dev/null` (template wired up?).
   * `grep -E '^#\s*Workflow:' .gitmessage 2>/dev/null` (workflow variant recorded?).
   * `grep -E '^#\s*Adopted:' .gitmessage 2>/dev/null` (naming variant recorded?).
   * `git remote get-url origin 2>/dev/null` (origin present, and its URL; consumed by steps 2 and 6e).

   **Nested-repo stop.** When `--is-inside-work-tree` is true but `--show-toplevel` is NOT the current directory, the template copy sits inside some parent repository. STOP and explain: `git init` here would nest repos, and `git config commit.template` would write into the PARENT repo's configuration. The user must either extract the copy to its own directory or confirm they really are configuring that parent repo (in which case they re-run this skill from its toplevel).

   Render a checklist:
   ```
   repo-init check:
     [x|.] template files present : .gitmessage .gitattributes .gitignore .claude/skills
     [x|.] git repository         : yes | no
     [x|.] commit.template set    : <value> | unset
     [x|.] Workflow variant       : git-flow | github-flow | trunk-solo | not recorded
     [x|.] naming variant         : Variant A | Variant B | Variant C | not recorded
   ```
   When every box is checked, report the summary, still route step 2 (provenance costs one look at the origin URL, and a repo with its own history is a no-op there), then skip steps 3 to 5 and continue at step 6 so the optional scaffolding is still offered. Skipping step 2 on a green checklist would let a manually-configured template clone keep the template's history and remote forever.

2. **Repository provenance.** Route by what step 1 found:
   * **Not a repo**: ask via `AskUserQuestion` (**init** / **abort**), rendering the exact command first: `git init -b main`. The `-b` flag needs git 2.28+; on older git render `git init && git branch -m main` instead. On **abort**, stop; the remaining steps all assume a repository.
   * **A clone of the template** (the step-1 origin URL contains the template's distribution name `tmpl.general-repo`, or the user says the copy came from cloning the template): the `.git` directory carries the TEMPLATE's commit history and its origin remote, which a consumer project must not inherit. Render the evidence (origin URL, `git log --oneline -5`, and the total commit count from `git rev-list --count HEAD`), then ask via `AskUserQuestion`:
     * **fresh start (Recommended)**: `rm -rf .git`, then `git init -b main`. Deletes the inherited template history and remote; every working file stays untouched. This is the one deliberately destructive action in this skill, so the question text itself MUST restate exactly what is deleted, INCLUDING any commits the user has made on top of the clone. When the rendered log shows commits beyond the template's own, do not proceed until the user confirms those commits are disposable.
     * **keep history**: the user wants to pull template updates later, or their own commits must survive. Keep `.git` as-is, and offer a gated `git remote rename origin template`, freeing the `origin` name for the project's own remote. After the rename, treat `origin` as absent for the rest of this run, so 6a offers the remote wiring even though the step-1 probe predates the rename. Pulling template updates later is a manual flow: the user runs `git fetch template` themselves, then invokes `/git-merge` with source=`template/main`; `git-fetch` and `git-pull` are origin-only by design and will not do it.
     * **abort**: STOP.
   * **A repo with its own project history**: nothing to do; continue.

3. **Wire the commit template (only when unset or pointing elsewhere).** Render the exact command, then ask via `AskUserQuestion` (**set** / **skip**):
   ```
   git config commit.template .gitmessage
   ```
   Local repo config, not `--global`: the template travels with the repo, and other checkouts opt in themselves. If `commit.template` is already set to a different path, show the current value in the question; **set** overwrites it for this repo only.

4. **Resolve and record the workflow variant.** Read the `Workflow:` line in `.gitmessage`.
   * The template ships with `Workflow: <not recorded>`, which every skill treats as undeclared (assume `git-flow`, the strictest). Whether the line is a real variant, the placeholder, or absent, ask via `AskUserQuestion` which of the three variants applies (`git-flow` / `github-flow` / `trunk-solo`), with no option marked recommended and each option's tradeoff taken from `.gitmessage`'s own descriptions. Skip the question ONLY when the user already stated the variant in the current conversation.
   * Then ask **record** / **skip**: on **record**, update the `Workflow:` line via `Edit` so downstream skills (`git-commit`, `git-push`, `git-branch-create`, `git-branch-delete`, `git-fetch`) read the decided value. On **skip**, warn that an undeclared variant makes those skills assume `git-flow`, the strictest.

5. **Resolve the branch-naming variant.** Ask via `AskUserQuestion` which of `.gitmessage`'s "Branch Naming" variants the repo adopts (A: issue-id, B: scope, C: plain short-desc), unless already stated. Record the answer by updating the section's `Adopted:` line via `Edit` (the template ships it as `Adopted: <not recorded>`; set it to, for example, `Adopted: Variant B`), behind its own **record** / **skip** gate. `git-branch-create` step 4 and `git-commit` step 3e read this line instead of guessing.

6. **Optional scaffolding.** Two layers, mirroring `hf-setup`: 6a picks WHAT to scaffold (design), 6b to 6f each render their exact content or command and gate it (execution). Skip 6a entirely when the user already named what they want in the current conversation.

   a. **Select scope** via one `AskUserQuestion` call carrying TWO multi-select questions (a single question tops out at 4 options, so the five items split by kind; offer only items not already present):
      * Question "files and directories": **common directories** (docs/, config/, scripts/), **references area** (read-only external repos, git-ignored), **CLAUDE.md** (project instructions for Claude Code sessions).
      * Question "integrations": **origin remote** (only when step 1 found no `origin`), **python environment** (hands off to `py-env-setup`).
      Nothing selected in either question means step 6 is done; continue at step 7.

   b. **Common directories.** Ask via multi-select `AskUserQuestion` which of `docs/`, `config/`, `scripts/` to create (the user can type additional names). git does not track empty directories, so each created directory gets a `.gitkeep` placeholder. Render the resulting `mkdir` plus `.gitkeep` plan inline; the multi-select answer is the gate, since it names exactly what will be created. Skip any directory that already exists.

   c. **References area.** Render both new files inline, then ask **create** / **abort**:
      * New file `references/README.md`:
        ```markdown
        # Reference Repositories

        Read-only copies of external repositories kept for consultation.
        Nothing here is called, imported, built, or depended on by this
        project, and everything except this README is ignored by git.

        To add one: clone or copy it into this directory, then record it
        below with the commit hash so future readers know exactly which
        snapshot was consulted.

        | Name | Source URL | Commit | Date added | Why it is here |
        |---|---|---|---|---|
        ```
      * New file `references/.gitignore`:
        ```
        # Read-only reference material; only this file and README.md are tracked.
        *
        !.gitignore
        !README.md
        ```
        The `*` plus re-include pair is deliberate: ignoring everything by default makes cloned repos (including their `.git` directories) invisible to the parent repo, so they cannot become accidental gitlinks, while the two `!` lines keep the README and this ignore file themselves tracked. A nested `.gitignore` scopes to its own directory by definition, so nothing else in the tree is affected; the root `.gitignore` is NOT touched, the area is self-contained and portable, and no `.gitkeep` is needed because the directory always holds two tracked files.

   d. **CLAUDE.md.** Draft a minimal project-instructions file from what the conversation establishes (project name, one-line purpose); leave explicit placeholders where nothing is known. Render the full content, then ask **write** / **abort**:
      ```markdown
      # <Project Name>

      <One-line description of the project.>

      ## Commands

      <Build / test / run commands, once established.>

      ## Conventions

      - Commits and branching follow `.gitmessage` (see its `Workflow:` line).
      - Use the git-* skills for git operations.
      ```

   e. **Origin remote (only when absent).** Take the URL from the user (ask as free text if not already given), render `git remote add origin <url>`, then ask **add** / **abort**. Verify with `git remote -v` and include it in the step-9 report. Adding the remote never pushes anything; publishing stays with `git-push`.

   f. **Python environment.** Invoke the `py-env-setup` skill, which owns its own probing, version recommendation, and gates. Do not duplicate any of its questions here.

7. **Project identity (consumer copies only).** When README.md still carries the template's own title (`General Repository Template`) or LICENSE still carries the template author's copyright line, this copy is presenting itself as the template rather than as the user's project. Offer, each behind its own gate:
   * **README rewrite**: draft a project README skeleton (title from the project name, one-line description, empty Usage section), render it fully, ask **rewrite** / **keep**. On **rewrite**, replace via `Write`.
   * **LICENSE holder**: show the current copyright line and ask whether to update the holder name (free text); on confirmation, change that line via `Edit`. When the user keeps the template's MIT license terms, only the holder line changes; swapping the license itself is out of scope, so point to choosealicense.com and stop at the reminder.
   Skip this step only when the user says this repo IS the template itself. A working-directory basename of `tmpl.general-repo` is NOT sufficient evidence, because a default `git clone` keeps that name; when step 2 detached a template clone, always treat the repo as a consumer project, and when in doubt, ask.

8. **Optional first commit.** When step 2 created a brand-new repo, or steps 6 to 7 created new files, offer (single yes/no question) to land the pending files by handing off to `/git-commit`. Never commit from inside this skill.

9. **Report.** Re-render the step-1 checklist with the new state, state how step 2 resolved the repo's provenance (initialized fresh, detached from the template, history kept, or untouched), name the recorded variants explicitly, list what was scaffolded (and what was offered but declined), and list the natural next steps: `/git-branch-create` for the first branch (or straight to `/git-commit` under `trunk-solo`), `git branch develop` once the first commit exists when the recorded variant is `git-flow` (user-run, one-time bootstrap of the integration trunk; `git-branch-create` deliberately refuses trunk names), `git remote add origin <url>` when still absent, and `/py-env-setup` when the project needs Python but 6f was not taken.

# Rationale

* **Configure-only, never fetch.** Template acquisition (GitHub "Use this template", a copy, a clone) happens before any Claude session; conflating acquisition with configuration would need network and ownership decisions this skill cannot verify.
* **The shipped `Workflow: <not recorded>` makes the undecided state explicit.** Every skill treats it as undeclared and falls back to `git-flow`, the strictest, so a consumer repo that never runs this skill inherits safety rather than permissiveness. Asking once here is what makes the line trustworthy for every downstream skill.
* **Local `commit.template` config over `--global`**: a machine-wide template would leak this repo's conventions into unrelated repositories.
* **Scaffolding is opt-in per item, not a bundle.** A docs-only repo needs no `scripts/`; a repo with no external reading needs no `references/`. The 6a selection keeps the default outcome identical to the pre-scaffolding skill: nothing is created unasked.
* **`references/` over `third_party/`, `external/`, or `vendor/`**: those names carry build-layout semantics (code the project embeds, builds, or ships). This directory is pure reading material with zero calls and zero dependencies, so the name says "reference", and the tracked README carries the provenance (source, commit hash, date, purpose) that a build manifest would otherwise hold.

# Hard rules

* NEVER run `git init` inside an existing repository or a subdirectory of one, and NEVER configure from inside a parent repo's subdirectory. `git rev-parse --show-toplevel` differing from the current directory is the signal; the step-1 nested-repo stop handles it. The single exception is the step-2 **fresh start**, which first removes the inherited template `.git` entirely, behind its own gate.
* NEVER run `rm -rf .git` outside the step-2 fresh-start path, never without its gate, and never when the history is the user's own project work rather than the template's.
* NEVER set `--global` git config from this skill. Repo-local only.
* NEVER overwrite `.gitmessage`, `.gitattributes`, or the root `.gitignore` wholesale; in fact this skill never modifies the root `.gitignore` at all (the references area ships its own nested `references/.gitignore`). `.gitmessage` changes are the `Edit`-based line updates in steps 4 and 5. Every other write (`.gitkeep`, `references/README.md`, `references/.gitignore`, `CLAUDE.md`, the step-7 README rewrite, the LICENSE holder line) renders its exact content or diff first and sits behind its own gate.
* NEVER scaffold anything not selected in step 6a (or named by the user), and NEVER re-create or overwrite an item that already exists; surface it and move on.
* NEVER pick a workflow or naming variant for the user. The shipped placeholder is not an answer; only an in-conversation answer gets recorded.
* NEVER commit, branch, or push from this skill. The only remote-state changes permitted are the step-6e `git remote add origin` and the step-2 `git remote rename origin template`, each behind its own gate; neither publishes anything.
* NEVER duplicate `py-env-setup`'s questions or run conda commands here. Step 6f is a handoff, not an inline implementation.
