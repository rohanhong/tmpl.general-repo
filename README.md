# 🧰 General Repository Template

A general-purpose starting point for new repositories, shipped as
`tmpl.general-repo`: portable git hygiene files plus a family of agent
skills that run the git workflow, project bootstrap and scaffolding, Python
environment setup, and Hugging Face Hub artifact hosting behind explicit
confirmation gates. Instructions and skills are tool-neutral: one canonical
copy serves any AI agent tool, and tools that do not read the open-convention
locations get thin adapters instead of copies.

## 📦 Contents

| Path | Purpose |
|---|---|
| `.gitattributes` | LF normalization, language-aware diff headers, binary markers, symlink types, and `git archive` excludes (shipped commented out so source downloads of the template keep its files; `repo-init` enables them in a consumer repo) |
| `.gitignore` | OS, editor, language, and infrastructure ignore rules; add project rules under `# Project-local` |
| `.gitmessage` | Commit message format, workflow variants, branch types and naming, protected branches, tags |
| `LICENSE` | MIT license covering the template files |
| `AGENTS.md` | Single source of agent instructions; its Layout section defines the canonical locations and the adapter rule |
| Tool adapters | Root instruction files that only import `AGENTS.md`, and `.<tool>/skills` symbolic links to `.agents/skills`, for tools that do not read the canonical locations (shipped for Claude Code; see AGENTS.md, Layout, to add one for another tool such as Gemini CLI or Kiro) |
| `.agents/skills/git-*` | Branch, commit, fetch, pull, push, merge, tag, and delete skills |
| `.agents/skills/repo-init` | One-time bootstrap of a fresh copy, with optional project scaffolding |
| `.agents/skills/py-env-setup` | Dedicated conda env per repo with a root-level `environment.yml` as the spec; a root-level `requirements.txt`, when present, is wired in through the spec |
| `.agents/skills/hf-*` | Hugging Face Hub setup, upload, and download skills for large artifacts |

## 🚀 Quick Start

The skills need git 2.22 or later (they use `git branch --show-current`) and
a POSIX shell (Git Bash on Windows).

1. Copy the template files into your new project, create the repo from this
   template on your forge, or clone the template directly. A direct clone
   keeps the template's own history and origin remote; `repo-init` detects
   that and offers to detach.
2. In an agent session, invoke the `repo-init` skill (for example
   `/repo-init` in tools with slash commands, or by asking for it by name).
   It verifies the files, runs `git init` when needed, restores skills
   adapter links that a copy turned into plain files, wires
   `git config commit.template .gitmessage`, and asks-then-records the
   workflow variant and branch-naming variant in `.gitmessage`.
3. Without an agent, the manual equivalent is:

   ```bash
   # cloned copies first: rm -rf .git   (drops the template's history and
   # remote; or keep them and run `git remote rename origin template`)
   git init -b main   # git 2.28+; older git: git init && git symbolic-ref HEAD refs/heads/main
   git config commit.template .gitmessage
   # then edit .gitmessage: set the `Workflow:` line and the `Adopted:` line
   # optional: enable the archive excludes in .gitattributes
   sed -E 's/^# ([^ ]+ +export-ignore)$/\1/' .gitattributes > .gitattributes.tmp &&
     mv .gitattributes.tmp .gitattributes
   # skills adapters that arrived as plain files: register them as links
   # (runs under sh, so zsh's error on a glob that matches nothing does
   # not apply)
   sh <<'EOF'
   for f in .[!.]*/skills; do
     [ -f "$f" ] && [ ! -L "$f" ] && [ "$(grep -c '' "$f")" -eq 1 ] || continue
     case "$(tr -d '\r\n' < "$f")" in *.agents/skills) ;; *) continue;; esac
     tr -d '\r\n' < "$f" > "$f.tmp" && mv "$f.tmp" "$f"
     git update-index --add --cacheinfo \
       "120000,$(tr -d '\r\n' < "$f" | git hash-object -w --stdin),$f"
   done
   EOF
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
variant, until a real choice is recorded (run the `repo-init` skill, or edit
the line). The `Adopted:` branch-naming line has no strictest fallback: while
it is unrecorded, `git-branch-create` infers the variant from existing
branches and asks when they leave it ambiguous, and `git-commit` infers it the
same way, then falls back to Variant C.

This template repository itself is maintained trunk-solo, but the shipped line
stays unrecorded on purpose so each consumer repo makes its own choice. When
working on the template itself, answer **template itself** at the `repo-init`
provenance question, then `trunk-solo`, and skip recording.

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
| `repo-init` | First-session bootstrap; optional scaffolding (dirs, references/, AGENTS.md project section, remote, identity) |
| `py-env-setup` | Conda env creation or adoption, spec at the root `environment.yml`, pip deps via `requirements.txt` when present |
| `hf-setup` | HF Hub account, repo, token, and manifest onboarding |
| `hf-upload` | One atomic HF commit; returns the SHA for manifest pinning |
| `hf-download` | Pinned-revision downloads with sha256 verification |

`.gitmessage` is normative for commit and merge messages;
`.agents/skills/git-commit/references/message-spec.md` is the skills'
detailed reading of it and defers to `.gitmessage` on any conflict.

## 🔄 Updating Skills

To pick up skill fixes from a newer template:

- **Kept the template history** (`repo-init` answer **keep history**, with
  the template remote renamed to `template`): run `git fetch template`, then
  invoke the `git-merge` skill with source `template/main`.
- **Fresh start** (template history dropped): replace your `.agents/skills/`
  directory with the one from a newer copy of the template rather than
  copying over it, so files removed upstream disappear. Review the result
  with `git status -- .agents/skills` (new and deleted files) and `git diff`
  before committing, since local edits to a skill are lost. Also compare
  AGENTS.md's Skill authoring section, and the `.gitattributes` and
  `.gitmessage` layouts that `repo-init` relies on, with the newer template.

## 🖥️ Windows Note

Skills adapters are symbolic links, which need Developer Mode (Settings,
System, For developers) or administrator rights. Before cloning, enable one
of them and run `git config --global core.symlinks true` (or clone with
`git clone -c core.symlinks=true <url>`); otherwise git writes each link as a
plain text file and the tool reading it finds no skills. To repair an
existing checkout, enable Developer Mode or use administrator rights, run
`git config core.symlinks true` in it, then run `rm <link> && git checkout --
<link>` for each broken link that `repo-init` reports. A copy of the template
files (not a clone) made without symlink support carries the links as plain
files; `repo-init` registers them as links before the first commit, or use
the `git update-index` line from the manual steps above.

The skills run their commands in a POSIX shell (Git Bash on Windows) because
they use POSIX redirections and heredocs. An agent whose default shell is
PowerShell runs each snippet through Git Bash, as AGENTS.md (Skill authoring,
POSIX shell) describes. The one PowerShell exception is `py-env-setup`, which
runs conda commands through PowerShell when conda is initialized only in the
PowerShell profile.
