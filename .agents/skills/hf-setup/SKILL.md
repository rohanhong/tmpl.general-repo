---
name: hf-setup
description: Guide a user from "large files that do not belong in git" to a working Hugging Face Hub repo, with optional manifest-pinned download glue for the consuming repo. Use for hosting model weights, sharing trained checkpoints, a git LFS alternative, or files over ~50 MB. Starts read-only by probing prerequisites, then asks whether the run is full setup or configure-only.
compatibility: Requires network access to huggingface.co, a POSIX shell (Git Bash on Windows), Python with the huggingface_hub library, and the hf CLI; the user completes account, token, and web UI steps in a browser.
---

# Goal

Walk a user from "I have large files that don't belong in git" to a working Hugging Face Hub repository that hosts those files, with optional code-side glue for reproducible downloads at build or runtime. Most actions happen in the HF web UI or via the `hf` CLI on the user's machine. The skill's job is to ask the right questions, detect existing state before suggesting new things, recommend defaults with rationale, and scaffold the integration when wanted.

# When NOT to use

* Files under ~50 MB that churn infrequently: plain `git` with a binary entry in `.gitattributes` is simpler.
* The user needs storage without git semantics, such as an HF Bucket: this skill family supports only Model and Dataset repos, whose commit SHAs allow pinning; use a Bucket by hand, or S3, R2, B2, or GitHub Releases.
* The files must not leave a self-hosted boundary: HF is hosted; consider self-hosted Forgejo or Gitea plus LFS, or DVC with a private remote.
* The repo and auth already exist: invoke `hf-upload` or `hf-download` instead.

# Procedure

Terms such as choice question, independent reads, invoke, and suggest follow AGENTS.md (Skill authoring); in a non-interactive session every gate ends this skill.

This skill depends on two sibling skills installed beside it: `hf-upload`, invoked at Phase 5b, and `hf-download`, whose `fetch_weights.py` reference Phase 6b copies from `../hf-download/SKILL.md` (relative to this skill's directory). If either is missing, stop before the phase that needs it and report.

Seven phases, Phase 0 to Phase 6. Phase 0 is read-only probing plus user-driven prerequisite onboarding, Phase 1 and Phase 2 are Q&A only, and the first action that mutates remote state or writes a file in the consumer repo is gated immediately before it. Skip a phase when context or a successful probe already answered its questions, but never invent answers.

**Two layers of choice questions are required and they are NOT interchangeable.**

* *Design-stage prompts* (owner, repo type, repo name, license, visibility, layout, and the Phase 0c run scope) pick *what* the setup should look like and *what subset* of phases this invocation runs. Skipping one is fine when context already answered it.
* *Execution-stage gates* pick *now is the time to do it* and fire immediately before any operation that creates remote state, modifies the local token cache, or writes or edits a file in the consumer repo. Each pairs an action verb with `abort`. Skipping one is NEVER fine. The full list:
  * Phase 3f: **create** / **abort** (CLI `hf repos create` only; the web UI path is user-driven and has no agent-side gate).
  * Phase 5b: owned by `hf-upload` step 5 (**upload** / **edit** / **abort**); this skill invokes `hf-upload` rather than re-asking.
  * Phase 6a: **write** for a brand-new manifest YAML, **edit** for an existing one.
  * Phase 6b: **write** / **abort** for a brand-new `fetch_weights.py`.
  * Phase 6c: **patch** / **abort** per consumer file, only when the agent does the edit.
  * Phase 6d: **append** / **abort** against the existing `.gitignore` (as an in-place edit, never a wholesale rewrite).

Reference files live under `references/` in this skill's directory; paths below are relative to the skill root. Read each at the phase that names it:

* `references/prerequisites.md` at Phase 0: probe 3 output shape and the per-prerequisite install fixes.
* `references/repo-design.md` at Phase 2, Phase 3, and Phase 5a: owner options, repo types, naming conventions, license and visibility options, creation details, in-repo layout.
* `references/auth.md` at Phase 4: dev token steps, login options, CLI rename note.
* `references/manifest-integration.md` at Phase 6: manifest, downloader, runtime verification, `.gitignore`, deploy token and CI wiring.
* `references/cli-reference.md` whenever rendering `hf` CLI commands or probing HF state without a browser. Python API for atomic multi-file commits: see `hf-upload`. Python API for downloads: see `hf-download`.

## Phase 0: Pre-flight checks and prerequisite onboarding

This phase NEVER changes a file, the local token cache, or any remote state. It detects what is already in place and walks the user through whatever is missing.

### 0a. Probe environment and account

Run these independent reads:

```bash
command -v hf || echo hf-missing
```
```bash
python3 -c 'import huggingface_hub as h; print("python3", h.__version__)' 2>/dev/null || python -c 'import huggingface_hub as h; print("python", h.__version__)' 2>/dev/null || echo lib-missing
```
```bash
HF_HUB_DISABLE_UPDATE_CHECK=1 hf auth whoami --format agent
```

Probe 2 prints the interpreter name that answered, then the library version (POSIX systems expose `python3`; Windows usually only `python`, where a bare `python3` may be a failing Microsoft Store stub). Every later snippet in this skill family writes the interpreter as the placeholder `<python>`; substitute the name probe 2 printed. Pass local paths to `<python>` as command-line arguments, never embedded in `-c` or heredoc source text: Git Bash converts MSYS paths such as `/c/...` in arguments to native Windows programs but not inside script text, and not in an argument containing `'` or `*`; so first run `command -v cygpath >/dev/null 2>&1 && P="$(cygpath -m "$P")"` on each path variable (a no-op without `cygpath`, as on macOS and Linux).

If probe 1 returns `hf-missing`, treat probe 3 as "not logged in" by definition and go to 0b for the CLI install.

Read probe 3 by exit status, never by piping it through `head` (that hides the status): exit 0 means logged in and prints `user=<name>` (plus `orgs=<...>` for organization members), non-zero means not logged in. Read `references/prerequisites.md` now for the full output shape and the `--format agent` pin.

Render the result inline as a checklist:

```
prereq check:
  [x|.] hf CLI installed     : <version> or hf-missing
  [x|.] huggingface_hub lib  : <version> or lib-missing
  [x|.] logged in            : user=<name> [orgs=<...>] or not logged in (<stderr line>)
```

This `whoami` capture is shared with the rest of the skill; do not re-run it in Phase 2 unless the user changed identity in between (logged out, switched org, swapped tokens).

### 0b. Guide the user through missing prerequisites

For each unchecked box, render the canonical fix the user runs on their own machine: for `hf-missing` and `lib-missing`, the fixes in `references/prerequisites.md`.

* **Not logged in** (non-zero probe 3): not a blocker. Phase 4 runs the full token-creation flow and the login before anything that needs a session. While logged out, Phase 3a lists public repos only and Phase 3f takes the web UI path; Phase 5b runs after Phase 4.
* **No HF account at all**: direct to `https://huggingface.co/join`. Wait for the user to confirm signup before re-running probe 0a; never assume signup completed because time passed.

If the CLI, the library, or the account is missing, STOP here, surface the missing-pieces list, and wait for the user to report each fix. Re-enter Phase 0 after each fix; never flip a box from `.` to `[x]` without a fresh probe. Being logged out alone does not stop the run.

### 0c. Confirm the scope of this run with a choice question

Once 0a reports the CLI and library boxes checked and the user has an account (or the user explicitly opts in to a discovery-only pass despite gaps), ask with three options:

* **full setup** (offer ONLY when the CLI, the library, and the account are in place; the login box may be unchecked because Phase 4 performs the login): proceed through Phase 1 to Phase 6 with every execution gate intact. "Full setup" approves the *pipeline*, not the *individual mutations*.
* **configure-only** (always offered): run Phase 1 and Phase 2 only, then STOP before Phase 3. Refines the design (modules in scope, owner, repo type, name candidate, license, visibility, layout) without creating remote state or touching any file. Ends with a written recommendation the user can re-enter from later.
* **abort**: STOP.

## Phase 1: Establish context

Phase 0 already detected the account state, so this phase covers what is being hosted and at what scope. Read the conversation first; do not re-ask anything already answered. Otherwise gather these, one choice question per group:

1. **What files?** Approximate sizes, formats, count, churn rate. Affects repo type and quota planning.
2. **Consuming repo?** Where the files will be loaded from (a GitHub repo, a CI pipeline, a robot, an unrelated workstation). Decides whether Phase 6 runs.
3. **Who uses them?** Solo developer, small team, public release. Affects org-vs-personal and visibility.
4. **Scope of this setup?** Brand-new repo (Phase 3 creates), supplement to a repo the user already owns (Phase 3a reuses, Phase 5b adds to it), or a fresh sibling in an existing per-project family. Decides whether Phase 3f runs at all.
5. **Which module(s) and artifact(s)?** The named components being hosted (`perception/button_cls`, `arm/grip_policy`, `voice/wakeword`). Drives the Phase 3c name candidate and the Phase 6a manifest keys. Capture every module in scope NOW so later phases do not re-litigate scope creep mid-flow.

## Phase 2: Resolve owner (user vs organization)

Reuse Phase 0a's `whoami` capture; re-probe only if the user changed identity since. If Phase 0 reported not logged in, the ownership decision proceeds against the username and org names the user states; Phase 4c's `whoami` confirms them before any upload.

Decide the owner with a choice question: **Personal account `<username>`**, **Existing organization `<org-name>`**, or **Create new organization**. Read `references/repo-design.md` now for each option's tradeoff, the org naming heuristic, and the membership check after the user creates an org. Confirm any org name with the user; do not auto-create.

## Phase 3: Create or reuse the HF repo

### 3a. Detect existing repos

Check both listings under the owner, since either type could already exist:

```bash
# Model repos:
<python> -c "from huggingface_hub import HfApi; print([r.id for r in HfApi().list_models(author='<owner>')])"
# Dataset repos:
<python> -c "from huggingface_hub import HfApi; print([r.id for r in HfApi().list_datasets(author='<owner>')])"
```

Logged out, these calls return public repos only, so a private repo for this purpose stays invisible: ask the user whether one exists before treating the namespace as empty.

If a repo for this purpose already exists, ask with a choice question whether to reuse it or create a fresh one. Never silently push into an existing repo; its contents could be unrelated.

### 3b. Choose repo type

Read `references/repo-design.md` now; it holds the type table and the option lists for 3b to 3e. Repo type is set at creation and immutable afterward, so ask with a choice question to pick once between the only two types this skill family supports end to end. Binary weights or checkpoints: **Model**. Training data, rosbags, large CSVs: **Dataset**. Never offer Space (an app runtime, not storage) or Bucket (no commits, so no `hf-upload` commit and no SHA pin); see When NOT to use.

### 3c. Pick a name

The Phase 1 Q5 module list is the primary input: collapse it into a `<scope>` and apply the `<scope>-<purpose>` convention and character rules in `references/repo-design.md` (lowercase ASCII letters, digits, and `-` only).

Render the candidate(s) inline. If two or more are equally good, surface them with a choice question; otherwise confirm the single best candidate before creation. Never invent a `<scope>` that does not trace back to a Q5 module name unless the user explicitly approves a custom value.

### 3d. License

Set a license at creation, even for private repos; an empty license is harder to add retroactively across team licensing reviews. Ask with a choice question using the options in `references/repo-design.md`: **Apache-2.0** (default for ML model weights), **MIT**, **CC-BY-4.0** (datasets), or **Other** only on explicit request, with its compatibility quirk flagged before the user picks.

### 3e. Visibility

Decide with a choice question between **Public** and **Private**, using the options and the private-storage quota note in `references/repo-design.md`. Private is the default for proprietary, pre-release, or sensitive artifacts; every consuming machine then needs a read token, which becomes Phase 4 and Phase 6e work.

### 3f. Create the repo

Render the resolved spec inline as a fenced block:

```
owner   : <owner>
name    : <name>
type    : model | dataset
license : <license-id>
visible : public | private
```

If the agent runs the CLI, ask with a choice question (**create** / **abort**) before invoking it. If the user prefers the web UI there is no agent-side gate; the user clicks through `https://huggingface.co/new` and confirms back in the conversation. Either way, a wrong name is costly: see the slug note in `references/repo-design.md`.

The web UI is the only path when probe 3 reported not logged in: the Phase 4 dev token is scoped to this repo, so it cannot exist before the repo does. Offer the CLI path only when probe 3 succeeded with a token already allowed to create repos under `<owner>` (a token scoped to selected repos is not):

```bash
hf repos create <owner>/<name> --type <model|dataset>    # add --private as needed
```

Confirm the result at `https://huggingface.co/<owner>/<name>`. The CLI path sets NO license (`hf repos create` has no license flag); apply the Phase 3d choice afterwards as described in `references/repo-design.md`. Do not report Phase 3 complete while the license field is still empty.

## Phase 4: Authentication

### 4a. Token strategy

HF supports fine-grained tokens. Recommend a two-token split from the start:

* **Dev token (Write)**: scoped to the new repo, persisted on the workstation via `hf auth login`. Used for pushing files, updating README, managing settings. Created in 4b.
* **Deploy token (Read-only)**: scoped to the same repo, distributed to CI, robots, or teammates. Used for downloads only. Created in Phase 6e, kept separate so leaked deploy credentials cannot push.

### 4b. Create the dev token

Read `references/auth.md` now. Walk the user through creating a **Fine-grained** token (never classic) with Write access to contents and settings of the new repo only, named `<repo-name>-dev`, following its step list. The value is shown only once, on creation.

### 4c. Log in on the workstation

```bash
hf auth login             # add --force to re-login when a token is already cached
```

Keep the default `--no-add-to-git-credential` unless the user will `git clone` over HTTPS (see `references/auth.md`). Have the user run bare `hf auth login` and paste at the prompt; do NOT recommend `hf auth login --token $HF_TOKEN` interactively (it leaks the token into shell history and the process list; that form is for CI only).

Verify with the Phase 0a probe 3 command; expect exit 0 and `user=<username>`, plus `orgs=<list>` when the account belongs to an organization. Confirm that the owner chosen in Phase 2 is the user or one of the listed orgs. On a non-zero exit whose stderr contains `Invalid user token` the paste failed; ask the user to re-run `hf auth login --force`.

### 4d. CLI rename note

`huggingface-cli` is the deprecated name of `hf`; see `references/auth.md` and the mapping in `references/cli-reference.md`.

## Phase 5: First upload

### 5a. Decide HF in-repo layout

Ask with a choice question if ambiguous (**Flat** `<repo>/<filename>` or **Subdirs** `<repo>/<group>/<filename>`); otherwise pick the simpler option and confirm. Read the layout notes in `references/repo-design.md` first: they cover when each fits, the Phase 6 basename flatten, and the basename collision warning.

### 5b. Upload via atomic commit

Invoke the `hf-upload` skill, passing forward the context established here so it short-circuits its own prerequisite probes: `repo_id` from 3c, `repo_type` from 3b, current auth from 4c, and the planned layout from 5a. `hf-upload` owns the `create_commit` template, the operation-pattern shapes, sha256 timing, its own execution gate, and failure-mode handling.

### 5c. Record the commit SHA

`hf-upload` prints `info.oid` and `info.commit_url`; record both. The OID becomes the `hf_revision` pin in Phase 6a.

If the user reused an existing repo in 3a and skipped 5b entirely, recover the current main SHA retroactively (`<repo_type>` is the Phase 3b choice; a dataset repo queried as `model` returns 404):

```python
from huggingface_hub import HfApi
api = HfApi()
sha = [b.target_commit for b in
       api.list_repo_refs("<owner>/<repo>", repo_type="<repo_type>").branches
       if b.name == "main"][0]
print(sha)
```

## Phase 6 (optional): Manifest-pinned integration

Read `references/manifest-integration.md` now and follow it. It covers the manifest YAML, the `fetch_weights.py` scaffold, runtime sha256 verification in the consumer, the `.gitignore` rule, and the deploy token plus build / CI wiring, each with its execution gate.

Skip the phase entirely when the user only wants to host files for manual browsing or ad-hoc download.

# Rationale

Read `references/rationale.md` when the user questions a default (token split, license, repo split, SHA pins, flatten, cache use, probe shape).

# Hard rules

* NEVER enter Phase 1 or later before Phase 0 has either reported the CLI, library, and account in place (the login may still be pending for Phase 4) AND Phase 0c was answered **full setup**, OR Phase 0c was answered **configure-only** (in which case the run stops after Phase 2). A fresh invocation defaults to inspection, not creation; green probes never imply **full setup**.
* NEVER invoke `pip install`, `pipx`, `uv tool`, `brew`, the standalone `hf` installer, `hf auth login`, or any HF web signup from inside this skill. Phase 0b only renders the command for the user to run; the user re-confirms each fix before 0a re-probes. The skill must never modify the user's interpreter, shell profile, or token cache without an in-person decision.
* NEVER display, log, or write a user-pasted HF token into chat, scratch files, or committed configs. It lives only in the HF token files (`$HF_HOME/token`, default `~/.cache/huggingface/token`, relocatable via `HF_TOKEN_PATH`, plus the `stored_tokens` file beside it that `hf auth login` fills; both are plaintext) and in CI secret stores.
* Design-stage prompts NEVER substitute for execution-stage gates. Each gate in the Procedure intro list MUST fire immediately before its mutation. Blind scaffolding (writing or editing a consumer-repo file without first rendering the proposed content or diff inline and getting action-verb approval) is the failure mode this rule blocks.
* NEVER suggest `git lfs install` in the consumer code repo. HF Hub uses LFS on its own side; the consumer does not need LFS configured to use `hf_hub_download`.
* NEVER pin `hf_revision` to `main`, a branch name, or a short SHA. Full 40-character commit SHA only.
* NEVER commit downloaded artifacts into the consumer repo. Add the download target to `.gitignore` at the same time as wiring up the fetcher; never one without the other.
* NEVER repurpose a Write token for deployment. Create a separate fine-grained Read token even when it feels like an extra step.
* NEVER trigger an HF download from a consumer node's runtime startup path. Build-time `fetch_weights.py` (network, recoverable) and runtime `verify_pinned_weight` (fatal on missing, no fallback) stay separate; collapsing them masks a skipped bootstrap step and blocks startup on network I/O.
* When the user has an existing HF account, org, or repo, detect it first (the Phase 0a probe 3 `whoami`, `list_models(author=...)`, `list_datasets(author=...)`, `repo_info`) and confirm reuse vs new-create. Do not suggest a new name on top of unknown existing state.
