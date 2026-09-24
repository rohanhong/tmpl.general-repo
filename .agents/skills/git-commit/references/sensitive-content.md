# Sensitive-content scan

Reference for `git-commit` step 6. The pattern lists live inline in SKILL.md step 6, so the scan works even when this file is not read; this file holds the scan scope, the commands, and the reasons behind each rule. Any match STOPS the flow for per-file confirmation.

## Scan scope

The final commit set: the staged diff; in batched mode, the union of every batch's paths diffed against HEAD, plus the full content of untracked paths read directly, since `git diff HEAD` does not show them. On an unborn branch, where `HEAD` does not resolve and `git diff HEAD` is fatal, use `git diff --cached -- <paths>` for staged paths and direct reads for the rest.

Take path names from the step-1 `git status --porcelain -z -uall` listing. Without `-uall`, an untracked directory collapses to `dir/` and a `dir/key.pem` inside it never meets the filename check; without `-z`, a path with a space arrives C-quoted and a non-ASCII name as octal escapes, so neither can be matched or staged as shown.

## Commands

Filenames: match each listed path against the step-6 filename list (shell glob semantics on the last path segment), skipping the three `.env.*` exemptions.

Value-shaped content: the step-6 value regexes, joined with `|`. The pattern holds both quote kinds and a backtick, so assign it from a quoted heredoc, which passes every character through unchanged:

```sh
VALUE_RE=$(cat <<'RE'
-----BEGIN [A-Z ]*PRIVATE KEY-----|hf_[A-Za-z0-9]{30,}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]+|eyJ[A-Za-z0-9_-]{20,}|([Aa][Pp][Ii][_-]?[Kk][Ee][Yy]|[Tt][Oo][Kk][Ee][Nn]|[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]|[Ss][Ee][Cc][Rr][Ee][Tt])[A-Za-z_]*[[:space:]]*[:=][[:space:]]*(['"][^'"$][^'"]{7,}|([^'"[:space:]()<>`$.]{8,}|[^'"[:space:]()<>`$]*[.][^'"[:space:]()<>`$]*[^'"[:space:]()<>`$A-Za-z0-9_.,;][^'"[:space:]()<>`$]*)([[:space:]]|$))|sk-[A-Za-z0-9_-]{20,}
RE
)
```

Then run `grep -nE -e "$VALUE_RE"` over the diff (or the untracked file). The `-e` is required: the private-key pattern starts with `-`, and without it grep reads the pattern as an option and exits 2. The assignment and the grep run unchanged under bash and dash.

Home paths: check only the lines the commit adds. Per staged path (`$HOME_RE` holds the two step-6 home-path regexes joined with `|`):

```sh
git diff --cached -U0 -- "$p" | grep -E '^[+]' | grep -vE '^[+]{3} ' | grep -nE "$HOME_RE"
```

In batched mode use the batch's step-7 diff source in place of `git diff --cached`; for an untracked file, `grep -nE "$HOME_RE" -- "$p"`. The pipeline runs unchanged under bash and dash.

## Why the rules are shaped this way

* **Keyword assignments in any case, quoted or not.** Real leaks look like `SECRET_KEY`, `aws_secret_access_key`, `_authToken`, or `password:` in YAML, often with an unquoted value. Each keyword letter is a bracket pair instead of `grep -i`, which would also loosen the fixed-case prefixes such as `AKIA` and `hf_`. `[A-Za-z_]*` lets the keyword run on (`SECRET_KEY`, `TOKEN_URL`). An unquoted value needs 8 or more characters and must end at whitespace or the line end, and it may not contain a quote, whitespace, `(`, `)`, `<`, `>`, a backtick, or `$`: that leaves out calls (`get_token()`), lookups (`os.environ[...]`), `$VAR` and `${{ ... }}` references, and `<token>` placeholders. An unquoted value holding a `.` hits only when it also holds a character outside letters, digits, `_`, `.`, `,`, and `;`, so attribute lookups (`self.session_token`) are left out; the accepted cost is that a dotted literal made only of those characters (`Summer.2024`) is missed. A quoted value may not start with `$`, which leaves out `"$DB_PASSWORD"` and `"${{ secrets.X }}"`. `sk-` catches the common `sk-`-prefixed vendor API keys wherever they appear. `[[:space:]]` stands in for `\s`, which POSIX ERE lacks and BSD grep may reject.
* **`.env.example`, `.env.sample`, `.env.template` are exempt** from the `.env.*` filename rule: they are the committed templates that document a `.env`; their content still gets the value scan.
* **Value-shaped only.** Bare words like `token` or `secret` outside an assignment-with-literal are NOT matches; docs and code that merely handle credentials would otherwise false-positive on every commit.
* **Home paths need a real user segment.** The character class `[A-Za-z0-9._-]` excludes `<`, so a documentation placeholder such as `/home/<user>/` or `C:\Users\<user>\` never matches, while the same paths with a real name in place of `<user>` do. (This file names no such real path, so it passes its own scan.) `~/`, `$HOME`, and `%USERPROFILE%` are portable forms that name no user, so they are not triggers. With these rules the template's own tracked files (skills, instructions, READMEs and their translations, community files, and header images) produce zero hits on a consumer's first commit.
* **Added lines only for home paths.** A removed line is a fix, not a leak, and context lines were already committed.
