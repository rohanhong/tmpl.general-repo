# Commit message specification

The single normative copy of the message rules for the skill family: `git-commit` applies the "Standard commit message" section, `git-merge` applies the "Merge commit message" section. Neither SKILL.md restates these rules, so there is no second copy to drift. `.gitmessage` at the repo root is the user-facing template for the same conventions; when the two disagree, fix the drift in the same change set.

## Standard commit message (`git-commit`)

* **Header (line 1)** in the form `<type>(<scope>): <subject>`:
  * `<type>` is exactly one entry from `.gitmessage`'s allowed list (`feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`, `merge`, `deps`, `config`, `env`, `ui`, `security`).
  * `<scope>` is the narrowest stable identifier (package, directory, or component) whose contract changed. When the change legitimately spans scopes, prefer one broader scope (for example `repo`) over a comma list, and tell the user the commit may be worth splitting.
  * `<subject>` is imperative mood, no trailing period, target 50 characters, hard limit 72. Describe outcome (`enable X by default`), not mechanics (`change line 80`).
* **Line 2** is blank.
* **Body** is one bullet per logical change, each prefixed with `- `. Each bullet:
  * MUST be a SINGLE physical line; do NOT wrap inside a bullet.
  * References concrete files or symbols so a reader can locate the change.
  * Explains the why when non-obvious; for pure renames or formatting, why may be absent.
  * Groups co-edits that exist only to keep things in sync (for example "sync README to match the new launch default").
  * Skips incidental whitespace or auto-formatter churn.
* **Footer block** (optional, separated from the body by one blank line). Include ONLY when the user named one of these in the current turn:
  * `Closes #<id>` / `Fixes #<id>` / `Refs #<id>`.
  * `BREAKING CHANGE: <message>`.
  * `Co-authored-by: <name> <email>` (only for a real human collaborator the user named; never an AI agent).
* The message ends after the last meaningful line. Do not include the `.gitmessage` template comment lines.

## Merge commit message (`git-merge`)

Same shape as the standard message; the only differences are the fixed header type and the theme-based body.

* **Header (line 1)** in the form `merge(<scope>): integrate <source> into <target>`. Imperative mood, no trailing period, target 50 characters, hard limit 72. The type is literally `merge`; pick `<scope>` per `git-merge` step 8.
* **Line 2** is blank.
* **Body** is one concise bullet per major theme being integrated, each prefixed with `- `. Each bullet:
  * MUST be a SINGLE physical line; do NOT wrap inside a bullet.
  * Summarizes a group of related commits from `git log <target>..<source> --oneline`, naming the affected component when one stands out.
  * Explains the why when non-obvious.
  * Skips trivial commits (formatting touch-ups, typo fixes) that carry no semantic weight.
  * For a tiny back-merge (a single commit integrated), one bullet restating that commit's outcome is enough.
* **Footer block**: same rules as the standard message above.
* The message ends after the last meaningful line. Do not include the `.gitmessage` template comment lines.
