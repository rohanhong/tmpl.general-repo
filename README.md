# 🧰 General Repository Template

A general-purpose starting point for new repositories, shipped as
`tmpl.general-repo`: portable git hygiene files plus a family of Claude Code
skills that run the git workflow, project bootstrap and scaffolding, Python
environment setup, and Hugging Face Hub artifact hosting behind explicit
confirmation gates.

## 📦 Contents

| Path | Purpose |
|---|---|
| `.gitattributes` | LF normalization, language-aware diff headers, binary markers, `git archive` excludes |
| `.gitignore` | OS, editor, language, and infrastructure ignore rules; add project rules under `# Project-local` |
| `.gitmessage` | Commit message format, workflow variants, branch types and naming, protected branches, tags |
| `LICENSE` | MIT license covering the template files |
| `.claude/skills/git-*` | Branch, commit, fetch, pull, push, merge, tag, and delete skills |
| `.claude/skills/repo-init` | One-time bootstrap of a fresh copy, with optional project scaffolding |
| `.claude/skills/py-env-setup` | Dedicated conda env per repo with a root-level `environment.yml` as the spec |
| `.claude/skills/hf-*` | Hugging Face Hub setup, upload, and download skills for large artifacts |

## 🚀 Quick Start

1. Copy the template files into your new project, create the repo from this
   template on your forge, or clone the template directly. A direct clone
   keeps the template's own history and origin remote; `/repo-init` detects
   that and offers to detach.
2. In a Claude Code session, run `/repo-init`. It verifies the files, runs
   `git init` when needed, wires `git config commit.template .gitmessage`, and
   asks-then-records the workflow variant and branch-naming variant in
   `.gitmessage`.
3. Without Claude, the manual equivalent is:

   ```bash
   # cloned copies first: rm -rf .git   (drops the template's history and
   # remote; or keep them and run `git remote rename origin template`)
   git init -b main
   git config commit.template .gitmessage
   # then edit .gitmessage: set the `Workflow:` line and the `Adopted:` line
   ```

## 🔀 Workflow Variants

`.gitmessage` is the normative source. One variant per repository, recorded on
its `Workflow:` line:

| Variant | Trunks | Protected | Intended for |
|---|---|---|---|
| `git-flow` | `main` + `develop` | `main`, `develop`, `support/*` | Team repos with release cycles |
| `github-flow` | `main` | `main`, `support/*` | Team repos, PR-based |
| `trunk-solo` | `main` | none (rewrite still forbidden) | Single-maintainer repos |

The template ships with `Workflow: <not recorded>`. Every skill treats an
unrecognized value as undeclared and falls back to `git-flow`, the strictest
variant, until a real choice is recorded (run `/repo-init`, or edit the line).
The same applies to the `Adopted:` branch-naming line.

This template repository itself is maintained trunk-solo, but the shipped line
stays unrecorded on purpose so each consumer repo makes its own choice. When
working on the template itself, answer `trunk-solo` and skip recording.

## 🧩 Skill Family

Each skill owns one operation and hands off to its neighbors by name. All of
them draft messages inline (never to a file), refuse history rewrites, add no
AI co-authors, and gate irreversible actions behind an explicit confirmation.

| Skill | Owns |
|---|---|
| `git-branch-create` | Cut a named short-lived branch from the right base |
| `git-commit` | Stage, draft per `.gitmessage`, confirm, commit via heredoc; mixed sets go through a batch plan drafted up front, approved in one bulk pass, committed consecutively |
| `git-fetch` | Refresh remote state and report ahead/behind (no gate; read-only) |
| `git-pull` | Fast-forward only; hands divergence to `git-merge` |
| `git-merge` | `--no-ff` merge with a drafted merge commit |
| `git-push` | Publish a branch; enforces the protected-branch set |
| `git-tag` | Annotated version tags; optional per-tag push |
| `git-branch-delete` | Remove merged branches locally and optionally on origin |
| `repo-init` | First-session bootstrap; optional scaffolding (dirs, references/, CLAUDE.md, remote, identity) |
| `py-env-setup` | Conda env creation or adoption, spec at the root `environment.yml` |
| `hf-setup` | HF Hub account, repo, token, and manifest onboarding |
| `hf-upload` | One atomic HF commit; returns the SHA for manifest pinning |
| `hf-download` | Pinned-revision downloads with sha256 verification |

The commit and merge message rules live in one normative file:
`.claude/skills/git-commit/references/message-spec.md`.

## 🖥️ Windows Note

The skills run their commands through Claude Code's Bash tool (Git Bash on
Windows) because they use POSIX redirections and heredocs. PowerShell is not a
supported shell for the command snippets inside the skills, with one
exception: `py-env-setup` falls back to the PowerShell tool for conda
commands when conda is initialized only for PowerShell/cmd.
