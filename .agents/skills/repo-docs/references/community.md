# Community files

Loaded from `repo-docs/SKILL.md` before drafting `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, or `TERMS.md`. The template repository's own files (in the template itself, not in a copy made from it) are worked examples.

## Placement

GitHub reads community health files from `.github/`, the repository root, or `docs/`, in that order of precedence. New files go to the root, where readers browsing the tree see them; an existing file stays where it is unless the user agrees to move it (`SKILL.md` step 2), and links point at its actual location. When `README.md`, `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `LICENSE`, and `SECURITY.md` exist, GitHub shows them as tabs above the README on the repository home page, in that order, and lists them under the repository's Community Standards.

Only `README` and `CONTRIBUTING` get translations (`docs/i18n/CONTRIBUTING.<locale>.md`, with the same switcher as the README). `CODE_OF_CONDUCT.md` and `SECURITY.md` stay English only; the Contributor Covenant's own attribution section already links its official translations. The English files stay where GitHub reads them: the root, unless the file already lives in `.github/` or `docs/`.

## Contacts

Settle two contacts once, in one question, and reuse them in every file:

* **Security reports**: on a public GitHub repository, GitHub private vulnerability reporting, `https://github.com/<owner>/<repo>/security/advisories/new`. The owner must enable it (Settings, Security, Private vulnerability reporting); say so in the step-12 report. Elsewhere, an address the user gives for this purpose.
* **Conduct reports**: a private channel the user chooses: a team address, a form, or, when the user wants no address published, a public issue that only requests contact and holds no incident details, in which the maintainer asks how the reporter prefers to be reached; add the forge's own abuse report for content on the forge, and say that it reaches the forge's staff, not the maintainer. Check that the channel really exists: a GitHub profile often shows no contact at all. Never publish an email address the user did not give for this purpose.

## CODE_OF_CONDUCT.md

Contributor Covenant 3.0. Fetch it; never write it from memory:

```sh
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; D="${TMPDIR:-/tmp}/repo-docs-$(printf %s "$ROOT" | cksum | cut -d' ' -f1)"
rm -f "${D:?}/CODE_OF_CONDUCT.md" "${D:?}/coc.src" &&
  curl -fsSL -o "$D/coc.src" https://www.contributor-covenant.org/version/3/0/code_of_conduct/code_of_conduct.md &&
  sed "s/$(printf '\342\200\231')/'/g" "$D/coc.src" | sed '/./,$!d' > "$D/CODE_OF_CONDUCT.md" &&
  [ -s "$D/CODE_OF_CONDUCT.md" ] && rm -f "${D:?}/coc.src" && echo fetched &&
  { LC_ALL=C grep -n "$(printf '[^\t -~]')" "$D/CODE_OF_CONDUCT.md"; case $? in 0) echo "non-ASCII left";; 1) echo "ascii ok";; *) echo "check failed";; esac; }
```

The two `sed` passes replace typographic apostrophes (U+2019) with `'` and drop leading blank lines. Without the `fetched` line, report it and stop. When the last line says `non-ASCII left`, report the listed characters rather than writing them: upstream added something new. `check failed` also stops the file. Then:
* Replace `**[NOTE: describe your means of reporting here.]**` with the conduct contact, as a sentence that completes "To report a possible violation, ...".
* Remove the paragraph starting `**[NOTE: The remedies and repairs outlined below` when the project adopts the enforcement ladder as written; otherwise replace it with the project's own policy.

## SECURITY.md

```markdown
# Security Policy

## Supported Versions

| Version | Supported |
|---|---|
| <latest release line or `main`> | Yes |
| <older lines> | No |

## Reporting a Vulnerability

Please do not report security problems in public issues, discussions, or pull requests.
Report them privately: <security contact link or address>.
Include the affected component and version, steps to reproduce, the impact, and a suggested fix if you have one.

## What to Expect

- An acknowledgement within <n> days.
- Updates as the report is triaged and fixed.
- Coordinated disclosure once a fix is released, with credit unless you prefer otherwise.

## Scope

In scope: <what counts>. Out of scope: <third-party dependencies, reported upstream>.
```

Fill the versions table from tags and releases; a project without releases supports only the default branch. Ask for the response time; never promise one the user did not give.

## CONTRIBUTING.md

Sections, in order; keep each short and specific to the project:

1. Title and language switcher (the README's form, with `|`, but without the emoji).
2. One-line thanks, plus pointers to `CODE_OF_CONDUCT.md` and `SECURITY.md` (security issues never go to public issues).
3. **Ways to Contribute**: bug reports (what to include), proposals (issue first for larger changes), pull requests.
4. **Development Setup**: prerequisites and the setup, build, and test commands from `AGENTS.md` (Commands) or the manifests; placeholders where unknown. Omit it when the project has nothing to build or run, as in the template itself, and fold any setup step into Workflow.
5. **Workflow**: fork, branch, commit, and pull request steps. In a repository with `.gitmessage`, name its branch naming and commit format and the `git-*` skills.
6. **Change Rules**: style, tests, docs-move-with-the-change, and any rules from `AGENTS.md`.
7. **Before You Open a Pull Request**: a short checklist of commands and checks.
8. **License**: contributions are accepted under the repository license (link `LICENSE`). Omit for proprietary repositories.

## TERMS.md (hosted services only)

Only for a project that runs a service people sign up for or use online; a library or tool shipped as code needs none. Write a skeleton for the user's lawyer, never final terms, and say so at the top of the file in an HTML comment:

```markdown
<!-- Draft skeleton; have it reviewed by a qualified lawyer before publishing. -->
# Terms of Service

Last updated: <date>

1. Acceptance of Terms
2. The Service
3. Accounts
4. Acceptable Use
5. Your Content
6. Fees and Payment (if any)
7. Termination
8. Disclaimers
9. Limitation of Liability
10. Governing Law: <jurisdiction>
11. Changes to These Terms
12. Contact: <address>
```

A service that collects personal data usually also needs a privacy policy; name that gap in the report, but do not draft one unless asked.
