# Phase 4: Token creation, login, and CLI rename

Loaded from `hf-setup/SKILL.md` Phase 4. Read this file when walking the user through the Phase 4b dev token and the Phase 4c login. The Hard rules in `SKILL.md` remain in force throughout; the user runs every command here on their own machine.

## 4b. Create the dev token

Direct the user to `https://huggingface.co/settings/tokens` -> `Create new token`:

* Type: **Fine-grained** (not classic; classic tokens read every repo the user can read).
* Permissions -> Organization permissions (if org) or Repo permissions (if personal): select the new repo.
* Check `Write access to contents/settings of selected repos` (this auto-checks Read).
* Name: `<repo-name>-dev` (for example `acme-foo-bot-models-dev`); names are operator-facing labels, so pick something searchable.
* Save the `hf_...` value once; the UI shows it only on creation.

If the user belongs to an org but the org does not appear in the fine-grained permissions UI, the org admin must enable fine-grained tokens for that org under org settings. Surface this before they retry.

## 4c. Login options

The credential-helper choice defaults to `--no-add-to-git-credential`, so doing nothing is already the smaller-blast-radius option:

* `--add-to-git-credential`: pick this only if the user might `git clone https://huggingface.co/<owner>/<repo>` over git HTTPS. Stores the token in `~/.git-credentials`.
* `--no-add-to-git-credential` (default): the `hf` CLI and the Python lib read the token from the HF cache and need nothing else.

The CLI's own help advertises `hf auth login --token $HF_TOKEN`. Do NOT recommend that form interactively: it puts the token into shell history and into the process list where any local user can read it. Have the user run bare `hf auth login` and paste at the prompt. The `--token` form is for CI, where the value comes from a secret store and the shell is ephemeral.

## 4d. CLI rename note

`huggingface_hub` renamed `huggingface-cli` to `hf`; current releases keep a `huggingface-cli` entry point that only prints a deprecation notice and exits. Older tutorials and Stack Overflow answers still use the old name; substitute when reading them. The Python API is unchanged. Full mapping in `cli-reference.md` (this directory). Do not assert specific minor versions anywhere in this skill: the library ships fast enough that any pinned number rots, and every behaviour described here is reachable from "install the current release".
