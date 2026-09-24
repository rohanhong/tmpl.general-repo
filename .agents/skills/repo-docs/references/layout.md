# README layout

Loaded from `repo-docs/SKILL.md` before drafting a README and its settings record. The template repository's own `README.md` (in the template itself, not in a copy made from it) is a worked example of this layout.

## Survey basis

A survey of high-star READMEs (astral-sh/uv and ruff, oven-sh/bun, ollama, excalidraw, vitejs/vite, denoland/deno, langgenius/dify, lobehub/lobe-chat, microsoft/vscode, AutoGPT, zed) found:

* Header: a centered logo (often a `<picture>` with light and dark sources), then a one-line tagline, a badge row, and a link row. Language switchers sit right under the header.
* Badges: plain shields.io `flat` style, ordered version, build, chat or community, license. This layout puts License first instead, since the user-facing license is the one badge every repository has (`badges.md`).
* Body order: intro, features, install or quick start, usage or docs, then contributing, community or resources, star history, security, and license near the end. Tools keep READMEs short (roughly 150 to 400 lines) and move depth to docs; callouts use GitHub alerts (`> [!NOTE]`), long optional material sits in `<details>`.
* Emoji in headings is a style split; where used, it is one emoji per `##` heading.

## Skeleton

Everything above the intro sits in one centered block. Keep the blank lines around the HTML: GitHub needs them to render Markdown after the block.

```html
<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset=".github/assets/banner-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset=".github/assets/banner-light.svg">
  <img alt="<project name>" src=".github/assets/banner-light.svg" width="640">
</picture>

<h1><emoji> <Project Name></h1>

<p><b><one-line tagline></b></p>

<p>
  <a href="<link>"><img alt="<label>" src="<badge url>"></a>
  <!-- Reserved badges: uncomment when the service exists.
  <a href="<link>"><img alt="<label>" src="<badge url>"></a>
  -->
</p>

<p><emoji globe> <b>English</b> | <a href="docs/i18n/README.<locale>.md"><endonym></a></p>

</div>
```

Header rules:

* Logo block: see `logo.md`. With no image, the block is omitted; a logo still waiting for its file stays inside an HTML comment.
* Title: the project's proper name, with one emoji that fits the project.
* Tagline: one sentence, bold, no period needed; it says what the project is, not how it is built.
* Badge row: see `badges.md`. One badge per line so diffs stay readable.
* Switcher: a globe emoji, then every language in the same order in every README; the current language is bold and unlinked, the others link to their files; separate entries with ` | `. Label each language with its own name (endonym), never its English name. Omit the switcher when there is only `README.md`.

## Body

Section order; each `##` heading starts with one emoji. Drop optional sections that have nothing real to say.

1. Intro (no heading): two to four sentences; what it is, who it is for, why it helps.
2. Highlights or Features: three to five bullets, each a bold key phrase and one short clause, each led by one emoji.
3. Quick Start: prerequisites as a `> [!NOTE]` alert, then numbered steps with copyable commands. Manual or alternative paths go in `<details>`.
4. Usage (optional): the smallest useful example, or a link to the docs.
5. Project structure or What's Inside (optional): one table, only top-level entries a user touches.
6. Configuration, Updating, platform notes (optional): a few bullets or one alert each.

The README always ends with these sections, in this order:

7. Documentation: a short table or list linking the docs site or the in-repo docs a user reads next.
8. Contributing: one or two lines linking the contributing guide at its actual location (the reader's language version in a translation). A proprietary project states its contribution policy instead.
9. Resources: three to six external links that help (specifications, related projects, community channels), one line each.
10. Legal: one bullet each, in this order, for what exists: License (name and link; the badge also shows it), Code of Conduct, Security (link `SECURITY.md`), Terms of Service (link `TERMS.md`, hosted services only; otherwise keep the bullet in an HTML comment), then any privacy or trademark policy.
11. Star History (public GitHub repositories only): the chart below. A proprietary or private repository omits it.

Star History chart. star-history.com's own snippet (copied from the site, carrying a `sealed_token` on its `/chart` URLs) is preferred when the user supplies it; otherwise use this form, which works without a token:

```html
<a href="https://www.star-history.com/#<owner>/<repo>&Date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=<owner>/<repo>&type=Date&theme=dark">
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=<owner>/<repo>&type=Date">
    <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=<owner>/<repo>&type=Date" width="600">
  </picture>
</a>
```

## Writing rules

* Aim for one screen before the first command and roughly 150 to 200 lines overall; long material goes to docs, `<details>`, or a linked file.
* Prefer tables for listings, bullets for choices, numbered steps for procedures. No nested lists deeper than one level.
* State facts once. Keep exact rules in their normative files (for example `.gitmessage`) and link to them instead of copying.
* Use GitHub alerts for the one or two things a reader must not miss; not for decoration.
* Commands and paths in code spans or fenced blocks with a language tag.
* Keep emoji to headings, highlight bullets, group labels in a table's first column, and the switcher.

## Translations

* Translations live in `docs/i18n/`, one `<NAME>.<locale>.md` per document and language (for example `docs/i18n/README.zh-CN.md`, `docs/i18n/README.ja.md`, `docs/i18n/CONTRIBUTING.zh-CN.md`); the English originals stay where GitHub reads them (the root, unless a file already lives in `.github/` or `docs/`). BCP 47 tags: `zh-CN`, `zh-TW`, `ja`, `ko`, `es`, `fr`, `de`, `pt-BR`, `ru`.
* The same rules apply to `CONTRIBUTING`.
* Links: GitHub resolves relative links from the file's own directory. In a translation, prefix every repository path with `../../` (images, `LICENSE`, `AGENTS.md`, the English original, `../../.github/CONTRIBUTING.md` when that file lives in `.github/`); links to other translations in `docs/i18n/` stay bare file names. In a root file, links to translations start with `docs/i18n/`. Moving a file into `docs/i18n/` rewrites its links the same way, and a link whose target moves in the same run points at the target's new path (a kept Chinese original that was `README.md` is now `README.zh-CN.md`, not the new English `README.md`).
* Same structure, order, images, badges, and links as `README.md`. A kept original or kept existing translation (`SKILL.md` step 2) is the exception: it keeps its own structure, and only its switcher and links change, until the user asks for a fresh translation. Translate the title, tagline, headings, prose, table text, alert text, and `<summary>` text; keep code blocks, commands, paths, URLs, badge markup, and HTML comments unchanged.
* Keep the proper name recognizable: a descriptive name (such as "General Repository Template") may be translated; a coined name, code name, product name, or command stays as is.
* Write each paragraph and list item of a Chinese, Japanese, or Korean translation on one line: GitHub renders a line break inside a paragraph as a space, which shows up between CJK characters. Put a space between CJK text and adjacent Latin words or code spans.
* The English file is canonical. Change the translations in the same change set as the English file (AGENTS.md, Conventions).

## Settings record

`.github/settings.yml` records the GitHub About panel in the Settings App format (https://github.com/repository-settings/app). GitHub does not read it; the owner applies it by hand, or installs that app to sync it (the app lets anyone who can push to the default branch change these settings, so that choice stays with the owner). The template repository's own file (in the template itself, not in a copy made from it) is a worked example.

* Keys, under `repository:`: `description` (the README tagline, at most 350 characters), `homepage` (the project website, or `""`), `topics`, and `is_template` (`true` only when the repository is itself a template for others to copy).
* `topics`: one comma-separated string drawn from the gathered facts, never invented; at most 20, each made of lowercase letters, digits, and hyphens, starting with a letter or digit, at most 50 characters (the GitHub limits).
* A trailing comment records the "Include in the home page" toggles, which the Settings App cannot manage. Create mode records Releases and Packages shown, Deployments hidden.
* Upgrade mode keeps the existing values and their form (a topics list stays a list) unless the user changes them in step 9. In every mode, other Settings App keys (labels, branch protection) and their comments stay unchanged.
* Use `>-` block scalars for `description` and `topics` when they wrap (AGENTS.md, Skill authoring).
* The header comment states that GitHub does not read the file and how to apply it. The template's own file also carries a note naming the template, so the step-1 residue probe finds it in a copy; a rewrite drops that note.
