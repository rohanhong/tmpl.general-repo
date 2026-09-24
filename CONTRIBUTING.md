# Contributing

<p><b>English</b> | <a href="docs/i18n/CONTRIBUTING.zh-CN.md">简体中文</a></p>

Thanks for helping improve the General Repository Template. This guide covers
how to propose a change and what a change must satisfy before it is merged.

By taking part you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
Report security problems privately as described in [SECURITY.md](SECURITY.md),
never in a public issue.

## Ways to Contribute

- **Report a bug**: open an issue with what you ran, what you expected, what
  happened, and your git version, shell, and agent tool.
- **Suggest a change**: open an issue first for anything larger than a small
  fix, so the approach can be agreed before you write it.
- **Send a pull request**: fixes to skills, git hygiene files, and docs are
  all welcome.

## Workflow

1. Fork the repository and clone your fork.
2. Wire up the commit template: `git config commit.template .gitmessage`.
3. Create a short-lived branch off `main`, named per the Branch Naming
   section of `.gitmessage`: `git checkout -b bugfix/repo-init-probe main`.
   Create it by hand: the template keeps its `Workflow:` line unrecorded, so
   `git-branch-create` assumes `git-flow` and looks for a `develop` branch
   this repository does not have.
4. Commit in the `.gitmessage` format, `<type>(<scope>): <subject>`, one
   logical change per commit; the `git-commit` skill drafts these for you.
5. Push to your fork and open a pull request against `main`. Describe what
   changed and why, and link the issue it resolves.

## Change Rules

- **Artifacts**: code, comments, skills, and in-repo docs are English and
  ASCII only. The README and CONTRIBUTING files and their translations are
  the exception (non-English text, and emoji in README files), as
  `AGENTS.md` (Conventions) describes.
- **Skills**: follow `AGENTS.md` (Skill authoring): valid frontmatter, the
  shared Procedure pointer line, capability terms instead of tool names,
  and POSIX shell snippets.
- **Unrecorded variants**: keep the `Workflow:` and `Adopted:` lines in
  `.gitmessage` unrecorded; every repository created from the template
  records its own. When `git-commit` offers to record a variant, skip it.
- **One source**: edit canonical files only (`AGENTS.md`, `.agents/skills`),
  never an adapter.
- **No hardcoded values**: take paths and settings from config files,
  arguments, or environment variables.
- **Docs move with the change**: when a change makes a doc inaccurate, fix it
  in the same pull request, including `README.md` and every translation in
  `docs/i18n/`.

## Before You Open a Pull Request

- [ ] Every changed shell snippet runs in a POSIX shell (Git Bash on Windows).
- [ ] No non-ASCII text outside the README and CONTRIBUTING files:
      `LC_ALL=C git grep -nI --untracked '[^[:print:][:space:]]' -- . ':!README.md' ':!CONTRIBUTING.md' ':!docs/i18n'`
      prints nothing.
- [ ] README and CONTRIBUTING files agree with their translations.
- [ ] Commit messages follow `.gitmessage`.

## License

Contributions are accepted under the repository's [MIT License](LICENSE).
