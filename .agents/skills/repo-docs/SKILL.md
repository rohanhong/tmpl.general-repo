---
name: repo-docs
description: >-
  Create or upgrade the repository's front-page documents: README.md (banner or logo, badges, language switcher, concise sections ending in Documentation, Contributing, Resources, Legal, Star History), CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md, LICENSE (MIT, Apache-2.0, proprietary, or any SPDX license), and TERMS.md, with translations in docs/i18n/. Use for "write a README", "add a license", "add a code of conduct / security policy / contributing guide", "translate the README", "add badges", or from repo-init step 7. Every write is gated; never commits.
compatibility: Requires git 2.22 or later, a POSIX shell (Git Bash on Windows), and network access to raw.githubusercontent.com, contributor-covenant.org, and api.github.com. Rendered badges and charts load from img.shields.io and api.star-history.com.
---

# Goal

Leave the repository with the documents GitHub shows as tabs on its home page (README, Code of conduct, Contributing, License, Security), each following the standard in `references/`: a README a reader grasps in one screen, legal texts taken verbatim from their canonical sources, and community files that name real contacts. Existing documents keep every fact they hold; only their shape changes.

# When NOT to use

* A one-line fix in an otherwise fine document (a typo, a changed command): edit it directly, then update the same line in each translation.
* A documentation site, CHANGELOG, issue templates, or a privacy policy: out of scope; name the gap and stop.
* Choosing a license for a legal or commercial situation: this skill writes the file the user picks; it gives no legal advice.

# Procedure

Terms such as choice question, independent reads, invoke, and suggest follow AGENTS.md (Skill authoring); in a non-interactive session every gate ends this skill.

Run every command in this skill in a POSIX shell. Repository paths are relative to the toplevel; each command recomputes `ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"` and runs from there, because shell state may not persist between commands. `<skill-dir>` is the skill directory (AGENTS.md, Skill authoring): this skill's `references/` and `scripts/` resolve against it, never against the repository (a repository may have its own unrelated `references/`); quote it in commands. `$D` is this run's scratch directory outside the repository, `D="${TMPDIR:-/tmp}/repo-docs-$(printf %s "$ROOT" | cksum | cut -d' ' -f1)"`; every command that removes something under it writes `"${D:?}"`, so an unset `D` stops the command instead of reaching another path. Step 8 empties it, and step 12 removes it, except after a step-11 failure, when it keeps the saved originals. Read each reference file at the step that names it: `layout.md`, `badges.md`, `logo.md`, `licenses.md`, `community.md`.

1. **Probe, read-only.** Run the probe below as written, under `sh`, so a glob that matches nothing is safe in zsh too; then read the `Project` and `Commands` sections of `AGENTS.md`.
   ```
   sh <<'EOF'
   ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$ROOT" || exit 1
   echo "== documents (root, .github/, docs/, docs/i18n/)"
   for d in . .github docs docs/i18n; do ls -a "$d" 2>/dev/null | grep -iE '^(readme|contributing|code_of_conduct|security|license|licence|copying|terms|notice)' | sed "s|^|$d/|"; done
   echo "== header images"; ls .github/assets 2>/dev/null
   echo "== template residue"
   grep -lE 'tmpl\.general-repo|General Repository Template' README* CONTRIBUTING* CODE_OF_CONDUCT* SECURITY* .github/*.md docs/*.md docs/i18n/*.md .github/assets/* 2>/dev/null
   echo "== copyright lines"; for f in LICENSE* LICENCE* COPYING* NOTICE*; do [ -f "$f" ] || continue; echo "-- $f"; grep -iE -m 3 '^[[:space:]]*copyright[[:space:]]' "$f"; done
   echo "== origin"; git remote get-url origin 2>/dev/null
   echo "== user.name"; git config user.name
   echo "== ci"; ls .github/workflows 2>/dev/null; ls .gitlab-ci.yml 2>/dev/null
   echo "== ecosystem"
   for f in pyproject.toml setup.py environment.yml requirements.txt .python-version package.json Cargo.toml go.mod pom.xml build.gradle build.gradle.kts CMakeLists.txt Dockerfile codecov.yml .codecov.yml .pre-commit-config.yaml mkdocs.yml .readthedocs.yaml *.csproj; do [ -e "$f" ] && echo "$f"; done
   echo "== tags"; git tag --list 'v*' --sort=-v:refname 2>/dev/null | head -n 3
   true
   EOF
   ```
   Parse the repository path from the origin URL in any form (`https://host/<path>.git`, `git@host:<path>.git`, `ssh://git@host/<path>`), dropping a trailing `.git`: on GitHub it is `<owner>/<repo>`; on GitLab it may hold subgroups (`group/sub/repo`), and the last segment is `<repo>`. When the host is GitHub, check visibility with `curl -s -o /dev/null -w '%{http_code}\n' https://api.github.com/repos/<owner>/<repo>`: 200 means public (dynamic badges and Star History are available); 404 means private or absent (static badges, no Star History); any other result (rate limit, redirect, no network) is unknown, so ask the user. Report a short summary.

2. **Pick the scope** with two multi-select choice questions asked together, preselecting what is missing or is template residue: "documents": **README**, **CONTRIBUTING**, **CODE_OF_CONDUCT**, **SECURITY**; "legal": **LICENSE**, **TERMS** (hosted services only). Nothing selected ends the skill.
   * **Template residue.** A file the probe lists under "template residue", in a repository that is not the template itself (when unsure, ask). When any residue exists, the repository is a template copy, and its LICENSE is also residue unless the user says the copyright line shown by the probe is theirs; show that line in the question (when the probe found none, as with an Apache-2.0 text whose holder is in `NOTICE` or nowhere, say so and ask who holds it). The translations of a residue file are residue too, whether or not the probe matched them, and so are `.github/assets/` files the probe matched.
   * **Location.** GitHub reads these files from `.github/`, the root, then `docs/`, in that order. A document that already lives in `.github/` or `docs/` is upgraded where it is, unless the user agrees to move it to the root (a planned move); never create a root copy that another location would shadow or duplicate. Links to a document point at its actual location.
   * **Modes.** For each selected file, state one: **create** (absent, or residue), **upgrade** (a project version exists; reshape it and keep every fact), or **sync** (up to date; only translations or switchers change).
   * **Non-English originals.** When an existing README or CONTRIBUTING is not in English, ask its locale (for example `zh-CN` or `zh-TW`; nothing detects it reliably), then ask **keep original** (move it to `docs/i18n/<NAME>.<locale>.md` as that language's translation, links rewritten per `references/layout.md`, and draft the English original from it) or **retranslate** (draft the English original from it, then translate that; the original is replaced). Translations found elsewhere (for example a root `README.<locale>.md`) are planned moves to `docs/i18n/` with links rewritten; each such file is kept, unless the user asks for a fresh translation. When two planned moves, or a move and an existing file, target the same path, ask which to keep; the other is listed for deletion.

3. **Gather the facts.** Read `references/layout.md`, and `references/community.md` when CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, or TERMS is in scope. Collect the project name, a one-line tagline, a two to four sentence intro, three to five highlights, setup and test commands, docs links, and resource links from the existing files, `AGENTS.md`, the manifests, and the conversation. Ask for what is still missing in one free-text message. Ask for the two contacts from `references/community.md` in the same message when CONTRIBUTING, CODE_OF_CONDUCT, or SECURITY is in scope, or right after step 4 when LICENSE is in scope (a proprietary choice there may drop some of those files). Anything still unknown stays a visible `<placeholder>`.

4. **License** (when in scope). Read `references/licenses.md`, then ask with a choice question: **MIT**, **Apache-2.0**, **Proprietary**, **other license** (a typed SPDX id, for example `GPL-3.0-or-later`, `BSD-3-Clause`, `MPL-2.0`); give each option's one-line tradeoff and mark none recommended. Settle the holder and year per `references/licenses.md` (a residue LICENSE takes the user's holder; an existing project license keeps its holder unless the user opts in to a change). For Apache-2.0, also ask **add NOTICE** / **skip**. For Proprietary, ask whether CONTRIBUTING and CODE_OF_CONDUCT stay in scope. Replacing a license that is not residue needs the explicit in-turn opt-in described in `references/licenses.md`.

5. **Header image** (README in scope). Read `references/logo.md`, then ask with a choice question: **static pixel text** (recommended when no logo exists), **animated pixel text**, **logo prompt**, **custom or none**. When a logo that is not residue already exists, offer **keep current** first and fold **logo prompt** into the free-text answer; residue banners count as no logo. For pixel text, settle the text (default: the repository name) and the palette. The text must hold at least one letter or digit and nothing but letters, digits, space, and `. - _ / : ! ?`; check it now and ask again when it does not.

6. **Badges** (README in scope). Read `references/badges.md` and build the recommended set in the order it gives (License first), capped at about eight. In **upgrade** mode start from the README's existing badges: keep them, fix any that are wrong or point at a missing service, and add catalog badges the evidence supports. Render it with the reserved list, then ask with a choice question: **recommended** (found set shown, the rest reserved in an HTML comment), **minimal** (license plus at most two others), **custom** (the user names badges to add or drop).

7. **Languages** (README or CONTRIBUTING in scope). English files are canonical. Ask with a multi-select choice question which translations to keep or add: **Simplified Chinese (zh-CN)** (recommended; preselect it on a first run), **Traditional Chinese (zh-TW)**, **Japanese (ja)**; the user may type other locales. Existing translations are kept unless the user drops them. The chosen set applies to both README and CONTRIBUTING.

8. **Fetch canonical texts.** First run `ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; D="${TMPDIR:-/tmp}/repo-docs-$(printf %s "$ROOT" | cksum | cut -d' ' -f1)"; rm -rf "${D:?}" && mkdir -p "$D"`, so no file from an earlier run survives. Then download the license text (and `COPYING` when `references/licenses.md` calls for it) and the Code of Conduct into `$D` with the commands in `references/licenses.md` and `references/community.md`. A failed, empty, or unchecked download stops that file: report it, and never substitute a remembered text. When a later edit changes the license, re-run only the license fetch command (never this step's reset, which would delete the other texts), and remove a `COPYING` the new license no longer needs with `rm -f "${D:?}/COPYING"`; a changed conduct contact needs only a new fill, not a new fetch. Nothing in the repository changes here.

9. **Draft the English files.** Draft every in-scope English file per the references. In **create** mode render each file in full (for fetched texts, render the filled lines and the source URL instead of the whole body); in **upgrade** mode render the diff plus every section, link, or image that moved or was removed, with the reason. Also render the plan, which step 11 follows exactly: every planned move with its link rewrites (a link whose target also moves in this plan points at the target's new path), every file written (English files, translations, header images, fetched texts), and every file to delete (residue or dropped files that nothing in this run writes again). Then ask with a choice question: **approve** / **edit** (take changes, re-render, ask again) / **abort** (nothing written). Nothing is written yet.

10. **Draft the translations.** For each chosen locale, translate the approved `README.md` and `CONTRIBUTING.md` (when in scope) per the translation rules in `references/layout.md`, skipping a translation the step-2 **keep original** or kept-file answer covers. When the set of languages changed, also render the updated switcher line of every existing file. Render each file in full, then ask **write all** / **edit** / **abort** (nothing written). With no translation work, ask **write all** / **abort** over the step-9 plan instead.

11. **Write.** On **write all**, follow the plan in this order, so no write lands on a file before that file has been moved or saved:
    1. Copy every file the plan moves, replaces, or deletes into `$D/orig/`, keeping its relative path.
    2. Make the planned moves from those copies, rewriting links as planned, and remove each source path.
    3. Write the English files and move into place each fetched text the plan lists (only those); then write the translations and switcher changes.
    4. Create the header images (below).
    5. Delete the files the plan lists for deletion, and only those; never delete a path this run has written.
    On any failure, stop, keep `$D`, and report what was written, moved, and deleted, with the path of `$D/orig/`; then ask **restore originals** (copy them back over the partial result) / **keep as is**. In a non-interactive session, report and leave `$D` in place.
    * **Pixel text**: run the command; add `--animate` to both script calls for the animated option.
      ```
      ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$ROOT" && mkdir -p .github/assets &&
        sh "<skill-dir>/scripts/pixel-banner.sh" --text "<text>" --out .github/assets/banner-light.svg --from "<light-from>" --to "<light-to>" &&
        sh "<skill-dir>/scripts/pixel-banner.sh" --text "<text>" --out .github/assets/banner-dark.svg --from "<dark-from>" --to "<dark-to>"
      ```
    * **Logo prompt**: fill the prompt template in `references/logo.md` and give it to the user in a fenced block. The logo block in `README.md` stays in an HTML comment until the file exists; tell the user the exact path and to uncomment it (or re-run this skill).
    * **Custom**: copy a local file into `.github/assets/` under the name the README uses; link a URL directly.
    * **Keep current** and **none**: nothing to do.

12. **Report.** List the files written, moved, and deleted, each file's mode, the license, the badges shown and reserved, and every placeholder left (logo file, missing facts). On GitHub, when `SECURITY.md` points at private vulnerability reporting, remind the owner to enable it (Settings, Security). Unless step 11 failed, remove the scratch directory: `ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; D="${TMPDIR:-/tmp}/repo-docs-$(printf %s "$ROOT" | cksum | cut -d' ' -f1)"; rm -rf "${D:?}"`. When another skill invoked this one, return to it and leave the commit to it; otherwise suggest `git-commit`, since these documents belong in one commit.

# Rationale

* **One screen first, fixed ending.** High-star projects keep the header to logo, title, tagline, badges, and links, reach a working command within a few scrolls, and close with contributing, community, legal, and star-history material. `references/layout.md` records the survey.
* **Canonical texts are fetched, not written.** GitHub detects licenses by exact text, and a paraphrased code of conduct is no longer the Contributor Covenant. Fetching at run time keeps the texts current and the skill small; failing closed when offline avoids a wrong legal text.
* **Draft everything, then write once, in a fixed order.** Every file is approved before any is written. Saving originals and making moves before writes means a new file never overwrites a document that was meant to move, and deleting last, never a path just written, means a residue file and its replacement at the same path cannot cancel each other.
* **Residue follows the copy, not a string.** A template copy's LICENSE, translations, and banners may not contain the template's name, but they came with the copy, so one confirmed residue file marks them all for review; the user confirms the copyright line rather than the skill guessing whose name it is.
* **Badges report facts.** A badge for a missing service renders as "not found" and reads as a broken project; reserving it in a comment keeps the slot without the noise.
* **English canonical where GitHub looks, translations in `docs/i18n/`.** GitHub finds community files and the README only in `.github/`, the root, or `docs/`; collecting translations in one directory keeps the root short as languages are added. The switcher uses HTML links so it renders the same inside the centered header.
* **Two banner files through `<picture>`.** GitHub picks the `<source>` by the viewer's GitHub theme; an SVG with an internal color-scheme query follows the operating system instead.
* **Images in `.github/assets/`.** It keeps the root clean. When a consumer enables the archive excludes, `.github/` leaves `git archive` output, so README images show only on the forge, which is where READMEs are read.

# Hard rules

* NEVER invent facts: features, numbers, commands, URLs, contacts, response times, or badges for services the probe did not find. Unknowns stay visible `<placeholder>` text or reserved comments.
* NEVER write a license or code-of-conduct text from memory; fetch it or stop.
* NEVER publish an email address, a personal name, or another contact the user did not give for that purpose; a residue copyright line is replaced, never carried into a consumer's files.
* NEVER change another party's copyright line without an explicit in-turn opt-in.
* NEVER drop content from an existing document without listing it in the step-9 plan, never delete or move a file the plan did not list, and never delete anything before every write has succeeded.
* NEVER write in the repository outside the in-scope documents, their translations in `docs/i18n/`, `NOTICE` and `COPYING` (when `references/licenses.md` calls for them), and `.github/assets/`; downloads and saved originals stay in `$D`.
* NEVER upload images to external hosts; header images live in the repository or come from a URL the user gave.
* NEVER commit, branch, or push; suggest `git-commit`, or leave it to the invoking skill.
* README and CONTRIBUTING files and their translations may use non-English text, and README files may use emoji; every other file this skill writes stays ASCII.
