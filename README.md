<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset=".github/assets/banner-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset=".github/assets/banner-light.svg">
  <img alt="tmpl.general-repo" src=".github/assets/banner-light.svg" width="640">
</picture>

<h1>🧰 General Repository Template</h1>

<p><b>Git hygiene, agent instructions, and gated agent skills, ready for any new repository.</b></p>

<p>
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/github/license/rohanhong/tmpl.general-repo"></a>
  <a href="https://github.com/rohanhong/tmpl.general-repo/commits/main"><img alt="Last commit" src="https://img.shields.io/github/last-commit/rohanhong/tmpl.general-repo"></a>
  <a href="https://github.com/rohanhong/tmpl.general-repo/stargazers"><img alt="Stars" src="https://img.shields.io/github/stars/rohanhong/tmpl.general-repo?style=flat"></a>
  <a href="https://github.com/rohanhong/tmpl.general-repo/generate"><img alt="Use this template" src="https://img.shields.io/badge/use%20this-template-2ea44f?logo=github"></a>
  <a href="https://agents.md"><img alt="AGENTS.md" src="https://img.shields.io/badge/AGENTS.md-ready-24292f"></a>
  <a href="https://agentskills.io"><img alt="Agent Skills" src="https://img.shields.io/badge/Agent%20Skills-open%20format-8250df"></a>
  <!-- Reserved badges: uncomment when the service exists.
  <a href="https://github.com/rohanhong/tmpl.general-repo/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/rohanhong/tmpl.general-repo/ci.yml?branch=main"></a>
  <a href="https://github.com/rohanhong/tmpl.general-repo/releases"><img alt="Release" src="https://img.shields.io/github/v/release/rohanhong/tmpl.general-repo"></a>
  -->
</p>

<p>🌐 <b>English</b> | <a href="docs/i18n/README.zh-CN.md">简体中文</a></p>

</div>

A starting point for new repositories. It ships portable git configuration
and one tool-neutral set of agent instructions (`AGENTS.md`) and skills
(`.agents/skills`) that any AI coding agent can use. The skills run the git
workflow, project bootstrap, project documents, Python environments, and Hugging
Face Hub hosting, and they stop for your confirmation before anything that is
hard to undo.

## ✨ Highlights

- 🔧 **Git hygiene out of the box**: line endings, diff drivers, ignore rules,
  and a commit convention with three workflow variants.
- 🤖 **One source for every agent tool**: instructions and skills live in open
  locations; other tools get thin adapters, never copies.
- 🛡️ **Safe by default**: skills gate irreversible actions, never rewrite
  history, and add no AI co-authors.
- 🌱 **Grows with the project**: `repo-init` bootstraps a fresh copy, and
  `repo-docs` writes a README and community files like these.

## 🚀 Quick Start

> [!NOTE]
> The skills need git 2.22 or later and a POSIX shell (Git Bash on Windows).

1. Create your repository with **Use this template**, or copy or clone this
   one. A clone keeps the template's history; `repo-init` offers to detach it.
2. In an agent session, run the `repo-init` skill (for example `/repo-init`).
   It wires up git, records your workflow choices, offers optional
   scaffolding, and offers to have `repo-docs` rewrite the template's README,
   community files, and license for your project.

<details>
<summary>Manual setup without an agent</summary>

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

</details>

## 📦 What's Inside

| Path | Purpose |
|---|---|
| `.gitattributes` | LF normalization, diff drivers, binary markers, archive excludes (off until `repo-init` enables them) |
| `.gitignore` | OS, editor, language, and infrastructure rules; add yours under `# Project-local` |
| `.gitmessage` | Commit format, workflow variants, branch naming, tags |
| `AGENTS.md` | Agent instructions, the canonical layout, and the adapter rule |
| `.agents/skills/` | The skills below |
| `CLAUDE.md`, `.claude/skills` | Claude Code adapters: an `@AGENTS.md` import and a link to `.agents/skills` |
| `.github/assets/` | README images |
| `.github/settings.yml` | Record of the GitHub About panel (description, website, topics); GitHub does not read it, so apply changes by hand |
| `docs/i18n/` | Translations of the README and the Contributing guide |
| `LICENSE` `CONTRIBUTING.md` `CODE_OF_CONDUCT.md` `SECURITY.md` | Legal and community files; `repo-docs` rewrites them, and the settings record, for your project |

| Group | Skills | What they do |
|---|---|---|
| 🌿 Git | `git-branch-create` `git-commit` `git-fetch` `git-pull` `git-merge` `git-push` `git-tag` `git-branch-delete` | Branch, commit, sync, merge, publish, and tag per `.gitmessage` |
| 🏗️ Setup | `repo-init` `repo-docs` `py-env-setup` | Bootstrap a copy, write the README and community files, create a conda env |
| 🤗 HF Hub | `hf-setup` `hf-upload` `hf-download` | Host large artifacts with pinned, verified revisions |

## 🔀 Workflow Variants

`.gitmessage` is the normative source; each repository records one variant on
its `Workflow:` line.

| Variant | Trunks | Protected | Intended for |
|---|---|---|---|
| `git-flow` | `main` + `develop` | `main`, `develop`, `support/*` | Team repos with release cycles |
| `github-flow` | `main` | `main`, `support/*` | Team repos, PR-based |
| `trunk-solo` | `main` | none (rewrite still forbidden) | Single-maintainer repos |

The template ships the line unrecorded, so skills assume `git-flow`, the
strictest, until you record a choice with `repo-init`. This template itself
is maintained `trunk-solo` but keeps the line unrecorded; when working on it,
answer **template itself** at the `repo-init` provenance question, then
`trunk-solo`, and skip recording.

## 🔄 Updating

- **Kept the template history** (`repo-init` answer **keep history**, with
  the template remote renamed to `template`): `git fetch template`, then run
  `git-merge` with source `template/main`.
- **Fresh start**: replace `.agents/skills/` with the newer template's copy,
  then review `git status` and `git diff` before committing, since local
  skill edits are lost. Also compare `AGENTS.md`, `.gitattributes`, and
  `.gitmessage` with the newer template.
- **README and community files**: run `repo-docs` again to bring them up
  to the current layout.

## 🪟 Windows

> [!IMPORTANT]
> Skills adapters are symbolic links. Enable Developer Mode (or use
> administrator rights) and run `git config --global core.symlinks true`
> before cloning; otherwise Claude Code and other tools that read only
> `.claude/skills` find no skills. `repo-init` reports broken links and gives
> the fix; AGENTS.md (Layout) has the details.

Agents whose default shell is PowerShell run each skill snippet through Git
Bash, as AGENTS.md (Skill authoring) describes.

## 📚 Documentation

| Topic | Where |
|---|---|
| Agent instructions, layout, adapters, skill authoring | [`AGENTS.md`](AGENTS.md) |
| Commit format, workflow variants, branch naming, tags | [`.gitmessage`](.gitmessage) |
| Each skill's procedure and rules | [`.agents/skills/<name>/SKILL.md`](.agents/skills) |
| Commit message reading used by the skills | [`message-spec.md`](.agents/skills/git-commit/references/message-spec.md) |

## 🤝 Contributing

Issues and pull requests are welcome. Read the [Contributing guide](CONTRIBUTING.md)
for the workflow and change rules.

## 🔗 Resources

- [AGENTS.md](https://agents.md): the open format for agent instructions.
- [Agent Skills](https://agentskills.io): the open format for skills.
- [Conventional Commits](https://www.conventionalcommits.org): the basis of the commit format.
- [Choose a License](https://choosealicense.com) and [Contributor Covenant](https://www.contributor-covenant.org): sources for the legal and community files.

## ⚖️ Legal

- **License**: [MIT](LICENSE)
- **Code of Conduct**: [Contributor Covenant 3.0](CODE_OF_CONDUCT.md)
- **Security**: report vulnerabilities privately per [SECURITY.md](SECURITY.md)
<!-- - **Terms of Service**: [TERMS.md](TERMS.md) (add when the project runs a hosted service) -->

## ⭐ Star History

<a href="https://www.star-history.com/#rohanhong/tmpl.general-repo&Date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=rohanhong/tmpl.general-repo&type=Date&theme=dark">
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=rohanhong/tmpl.general-repo&type=Date">
    <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=rohanhong/tmpl.general-repo&type=Date" width="600">
  </picture>
</a>
