---
name: hf-setup
description: Guide a user from "large files that do not belong in git" to a working Hugging Face Hub repo, with optional manifest-pinned download glue for the consuming repo. Use for hosting model weights, sharing trained checkpoints, a git LFS alternative, or files over ~50 MB. Starts read-only by probing prerequisites, then asks whether the run is full setup or configure-only.
---

# Goal

Walk a user from "I have large files that don't belong in git" to a working Hugging Face Hub repository that hosts those files, with optional code-side glue for reproducible downloads at build or runtime. Most actions happen in the HF web UI or via the `hf` CLI on the user's machine. The skill's job is to ask the right questions, detect existing state before suggesting new things, recommend defaults with rationale, and scaffold the integration when wanted.

# When NOT to use

* Files under ~50 MB that churn infrequently: plain `git` with a binary entry in `.gitattributes` is simpler.
* The user needs a private artifact bucket without git semantics: HF Hub is overkill; use S3, R2, B2, or GitHub Releases.
* The files must not leave a self-hosted boundary: HF is hosted; consider self-hosted Forgejo or Gitea plus LFS, or DVC with a private remote.
* The repo and auth already exist: go straight to `hf-upload` or `hf-download`.

# Procedure

Seven phases, Phase 0 to Phase 6. Phase 0 is read-only probing plus user-driven prerequisite onboarding, Phase 1 and Phase 2 are Q&A only, and the first action that mutates remote state or writes a file in the consumer repo is gated immediately before it. Skip a phase when context or a successful probe already answered its questions, but never invent answers. Each `AskUserQuestion` call lists 2 to 4 mutually exclusive options with concrete tradeoffs; the user can always type a custom answer.

**Two layers of `AskUserQuestion` are required and they are NOT interchangeable.**

* *Design-stage prompts* (owner, repo type, repo name, license, visibility, layout, and the Phase 0c run scope) pick *what* the setup should look like and *what subset* of phases this invocation runs. Skipping one is fine when context already answered it.
* *Execution-stage gates* pick *now is the time to do it* and fire immediately before any operation that creates remote state, modifies the local token cache, or writes or edits a file in the consumer repo. Each pairs an action verb with `abort`. Skipping one is NEVER fine. The full list:
  * Phase 3f: **create** / **abort** (CLI `hf repos create` only; the web UI path is user-driven and has no Claude-side gate).
  * Phase 5b: owned by `hf-upload` step 5 (**upload** / **edit** / **abort**); this skill delegates rather than re-asking.
  * Phase 6a: **write** for a brand-new manifest YAML, **edit** for an existing one.
  * Phase 6b: **write** / **abort** for a brand-new `fetch_weights.py`.
  * Phase 6c: **patch** / **abort** per consumer file, only when Claude does the edit.
  * Phase 6d: **append** / **abort** against the existing `.gitignore` (via `Edit`, never `Write`).

## Phase 0: Pre-flight checks and prerequisite onboarding

This phase NEVER changes a file, the local token cache, or any remote state. It detects what is already in place and walks the user through whatever is missing.

### 0a. Probe environment and account

Run the three read-only probes as three independent `Bash` calls in a single tool-batch so they run concurrently:

```bash
which hf || echo "hf-missing"
```
```bash
python3 -c "import huggingface_hub; print(huggingface_hub.__version__)" 2>/dev/null || python -c "import huggingface_hub; print(huggingface_hub.__version__)" 2>&1 || echo "lib-missing"
```

The `python3 || python` chain is deliberate: POSIX systems expose `python3`, Windows installs usually expose only `python`. Whichever name succeeded in this probe is the interpreter every later `python` snippet in this skill family means; substitute it consistently.
```bash
hf auth whoami --format agent 2>&1 | head -n 1
```

Probe 3 depends on probe 1: if probe 1 returns `hf-missing`, treat probe 3's output as "Invalid user token" by definition and go to 0b for the CLI install. Batching all three still saves the `python3` round-trip when `hf` is absent.

Render the result inline as a checklist:

```
prereq check:
  [x|.] hf CLI installed     : <version> or hf-missing
  [x|.] huggingface_hub lib  : <version> or lib-missing
  [x|.] logged in            : user=<name> orgs=<...> or Invalid user token
```

`--format` accepts `auto|human|agent|json|quiet`, and the default `auto` picks `human` on a TTY. Pin it to `agent` so the shape does not change between the user's shell and a captured Bash subprocess. Read the user name and org list out of that output rather than matching an exact string; if the shape ever surprises you, re-run with `--format json` and parse that instead of guessing.

This `whoami` capture is shared with the rest of the skill; do not re-run it in Phase 2 unless the user changed identity in between (logged out, switched org, swapped tokens).

### 0b. Guide the user through missing prerequisites

For each unchecked box, render the canonical fix the user runs on their own machine.

* **`hf` CLI missing** (`hf-missing`): the CLI ships inside the `huggingface_hub` library, so there is nothing separate to install; recommend `pip install -U huggingface_hub` inside whichever virtualenv or conda env the user wants it in. For a system Python that refuses, suggest `pipx install huggingface_hub` or `uv tool install huggingface_hub`. After install, ask the user to confirm, then re-run probe 0a.
* **`huggingface_hub` lib missing** (`lib-missing`): same `pip install -U huggingface_hub`. The Python API is what `hf-upload`, `hf-download`, and the scaffolded `fetch_weights.py` all import; missing it blocks both the CLI and Phase 5/6.
* **Not logged in** (`Invalid user token` or empty `whoami`): defer the actual login to Phase 4, which has the full token-creation flow. Phase 1 and Phase 2 are still safe to run while logged out; only Phase 3a (listing private repos), Phase 3f, and Phase 5b need an authenticated session.
* **No HF account at all**: direct to `https://huggingface.co/join`. Wait for the user to confirm signup before re-running probe 0a; never assume signup completed because time passed.

If any prerequisite is missing, STOP here, surface the missing-pieces list, and wait for the user to report each fix. Re-enter Phase 0 after each fix; never flip a box from `.` to `[x]` without a fresh probe.

### 0c. Confirm the scope of this run via `AskUserQuestion`

Once 0a reports all boxes checked (or the user explicitly opts in to a discovery-only pass despite gaps), ask with three options:

* **full setup** (offer ONLY when every prereq is green): proceed through Phase 1 to Phase 6 with every execution gate intact. "Full setup" approves the *pipeline*, not the *individual mutations*.
* **configure-only** (always offered): run Phase 1 and Phase 2 only, then STOP before Phase 3. Refines the design (modules in scope, owner, repo type, name candidate, license, visibility, layout) without creating remote state or touching any file. Ends with a written recommendation the user can re-enter from later.
* **abort**: STOP.

## Phase 1: Establish context

Phase 0 already detected the account state, so this phase covers what is being hosted and at what scope. Read the conversation first; do not re-ask anything already answered. Otherwise gather these, one `AskUserQuestion` per group:

1. **What files?** Approximate sizes, formats, count, churn rate. Affects repo type and quota planning.
2. **Consuming repo?** Where the files will be loaded from (a GitHub repo, a CI pipeline, a robot, an unrelated workstation). Decides whether Phase 6 runs.
3. **Who uses them?** Solo developer, small team, public release. Affects org-vs-personal and visibility.
4. **Scope of this setup?** Brand-new repo (Phase 3 creates), supplement to a repo the user already owns (Phase 3a reuses, Phase 5b adds to it), or a fresh sibling in an existing per-project family. Decides whether Phase 3f runs at all.
5. **Which module(s) and artifact(s)?** The named components being hosted (`perception/button_cls`, `arm/grip_policy`, `voice/wakeword`). Drives the Phase 3c name candidate and the Phase 6a manifest keys. Capture every module in scope NOW so later phases do not re-litigate scope creep mid-flow.

## Phase 2: Resolve owner (user vs organization)

Reuse Phase 0a's `whoami` capture; re-probe only if the user changed identity since. If Phase 0 reported `Invalid user token` AND the user chose **configure-only**, the ownership decision can still proceed against the username the user names verbally; the auth-required calls all live in Phase 3a, Phase 3f, and Phase 5b, which gate themselves.

Decide the owner via `AskUserQuestion`:

* **Personal account `<username>`**: simpler, fewer concepts. Right for solo experiments, scratch work, single-maintainer projects.
* **Existing organization `<org-name>`**: project-level ownership, multi-admin, survives personnel changes, separate quota pool. Right for team projects with a shared GitHub repo.
* **Create new organization**: when the project has a stable identity and likely more than one contributor over its lifetime. The user creates it at `https://huggingface.co/organizations/new`; wait for confirmation, then re-run `hf auth whoami --format agent` to verify membership.

Org naming heuristic: derive from the project or company name. If the consuming code repo is `acme/foo-bot`, suggest org `acme` or `foo-bot-team`. Lowercase, hyphens. Confirm with the user; do not auto-create.

## Phase 3: Create or reuse the HF repo

### 3a. Detect existing repos

Check both listings under the owner, since either type could already exist:

```bash
# Model repos:
python -c "from huggingface_hub import HfApi; print([r.id for r in HfApi().list_models(author='<owner>')])"
# Dataset repos:
python -c "from huggingface_hub import HfApi; print([r.id for r in HfApi().list_datasets(author='<owner>')])"
```

If a repo for this purpose already exists, ask via `AskUserQuestion` whether to reuse it or create a fresh one. Never silently push into an existing repo; its contents could be unrelated.

### 3b. Choose repo type

Repo type is set at creation and immutable afterward. Use `AskUserQuestion` to pick once. The HF "New" menu shows several entries; only some are storage:

| Entry | Use for | Notes |
|---|---|---|
| **Model** | ML weights (`.pt`, `.bin`, `.safetensors`, `.onnx`, `.gguf`, `.ckpt`) | Default `.gitattributes` already LFS-tracks ML extensions; visible in model search; supports inference widget metadata. Default for ML weights. |
| **Dataset** | Training data, evaluation sets, labeled corpora | Different default `.gitattributes` tuned for data formats; surfaces in dataset search. |
| **Space** | Runnable Gradio or Streamlit demos | A hosted runtime, not static storage. Skip for hosting. |
| **Bucket** | Generic large-blob storage without git semantics | Object-storage style; no commit history, so manifest pinning is impossible. Skip when reproducible pinning is required. |
| Article, Collection, Access Token | Not storage | Article = blog post; Collection = grouping pointer; Access Token routes to token settings. Skip. |

Binary weights or checkpoints: **Model**. Training data, rosbags, large CSVs: **Dataset**. Bucket only when version history is genuinely irrelevant.

### 3c. Pick a name

The Phase 1 Q5 module list is the primary input: collapse it into a `<scope>` reflecting which modules the repo will host. Combine with the consuming repo's package layout when those names diverge (rare but possible).

Convention `<scope>-<purpose>`:

* `<owner>/<project>-models`: all models for one project in one repo. Fits when Q5 listed one module or the user wants a single combined repo.
* `<owner>/<project>-<module>-models`: per-module split when Q5 listed two or more modules and Q4 said "fresh sibling in an existing family" (`acme/foo-bot-perception-models`, `acme/foo-bot-arm-models`).
* `<owner>/<project>-<dataset>-data`: for datasets.

Naming character rules: lowercase ASCII letters, digits, and `-` only. No underscores (HF convention; some tools confuse `_` with separators). Stay well under 96 chars.

Render the candidate(s) inline. If two or more are equally good, surface them via `AskUserQuestion`; otherwise confirm the single best candidate before creation. Never invent a `<scope>` that does not trace back to a Q5 module name unless the user explicitly approves a custom value.

### 3d. License

Set a license at creation, even for private repos; an empty license is harder to add retroactively across team licensing reviews. Use `AskUserQuestion`:

* **Apache-2.0** (default for ML model weights): de facto standard; the explicit patent grant and reciprocal-termination clause matter when artifacts end up in commercial products, and a private repo may flip public later.
* **MIT** when the user has a repo-wide MIT convention and prefers it. Shorter, broadly compatible, no patent grant.
* **CC-BY-4.0** for datasets (de facto standard for data sharing).
* **Other** (CC-BY-NC, OpenRAIL, custom) only on explicit request. These have known compatibility quirks with commercial or downstream-fine-tune use; flag the quirk before the user picks.

### 3e. Visibility

Decide via `AskUserQuestion`:

* **Public**: anyone can `hf_hub_download` without auth. Best for community models, published research weights, open datasets.
* **Private**: requires authenticated download. Free private storage is 100 GB per account or org (as of this writing; verify the current quota at `https://huggingface.co/pricing` before planning around it). Default for proprietary, pre-release, or sensitive artifacts. Every consuming machine (CI, robots, teammates) will need a read token, which becomes Phase 4 and Phase 6e work.

### 3f. Create the repo

Render the resolved spec inline as a fenced block:

```
owner   : <owner>
name    : <name>
type    : model | dataset | space
license : <license-id>
visible : public | private
```

If Claude runs the CLI, ask via `AskUserQuestion` (**create** / **abort**) before invoking it. If the user prefers the web UI there is no Claude-side gate; the user clicks through `https://huggingface.co/new` and confirms back in the conversation. Either way, a created repo occupies the owner's namespace under that name, and even immediate deletion leaves the slug reserved for a cooldown window, so a wrong name costs more than the bandwidth of the first push.

Web UI is easier the first time (visual confirmation, license dropdown, type descriptions). CLI for repeats:

```bash
hf repos create <owner>/<name> --type model    # add --private as needed
```

`hf repos` and `hf repo` are aliases for the same command group and both work; prefer the plural for consistency with the rest of this skill. Do not tell the user the singular is deprecated: as of `huggingface_hub` 1.17 both print identical help with no deprecation notice.

After creation, confirm at `https://huggingface.co/<owner>/<name>`; the auto-generated `.gitattributes` and `README.md` should be there.

The CLI path sets NO license: `hf repos create` has no license flag, so the Phase 3d choice must be applied afterwards by adding `license: <id>` to the YAML metadata block at the top of the repo's `README.md` (web UI "Edit model card", or a follow-up `hf-upload` commit). The web UI create form sets it directly via its license dropdown. Do not report Phase 3 complete while the license field is still empty.

## Phase 4: Authentication

### 4a. Token strategy

HF supports fine-grained tokens. Recommend a two-token split from the start:

* **Dev token (Write)**: scoped to the new repo, persisted on the workstation via `hf auth login`. Used for pushing files, updating README, managing settings. Created in 4b.
* **Deploy token (Read-only)**: scoped to the same repo, distributed to CI, robots, or teammates. Used for downloads only. Created in Phase 6e, kept separate so leaked deploy credentials cannot push.

### 4b. Create the dev token

Direct the user to `https://huggingface.co/settings/tokens` -> `Create new token`:

* Type: **Fine-grained** (not classic; classic tokens read every repo the user can read).
* Permissions -> Organization permissions (if org) or Repo permissions (if personal): select the new repo.
* Check `Write access to contents/settings of selected repos` (this auto-checks Read).
* Name: `<repo-name>-dev` (for example `acme-foo-bot-models-dev`); names are operator-facing labels, so pick something searchable.
* Save the `hf_...` value once; the UI shows it only on creation.

If the user belongs to an org but the org does not appear in the fine-grained permissions UI, the org admin must enable fine-grained tokens for that org under org settings. Surface this before they retry.

### 4c. Log in on the workstation

```bash
hf auth login             # add --force to re-login when a token is already cached
```

The credential-helper choice defaults to `--no-add-to-git-credential`, so doing nothing is already the smaller-blast-radius option:

* `--add-to-git-credential`: pick this only if the user might `git clone https://huggingface.co/<owner>/<repo>` over git HTTPS. Stores the token in `~/.git-credentials`.
* `--no-add-to-git-credential` (default): the `hf` CLI and the Python lib read the token from the HF cache and need nothing else.

The CLI's own help advertises `hf auth login --token $HF_TOKEN`. Do NOT recommend that form interactively: it puts the token into shell history and into the process list where any local user can read it. Have the user run bare `hf auth login` and paste at the prompt. The `--token` form is for CI, where the value comes from a secret store and the shell is ephemeral.

Verify with `hf auth whoami --format agent`; expect `user=<username> orgs=<list>`. On `Invalid user token` the paste failed; ask the user to re-run `hf auth login --force`.

### 4d. CLI rename note

`huggingface_hub` renamed `huggingface-cli` to `hf` in its 1.0 release. Older tutorials and Stack Overflow answers still use the old name; substitute when reading them. The Python API is unchanged. Full mapping in `references/cli-reference.md`. Do not assert specific minor versions anywhere in this skill: the library ships fast enough that any pinned number rots, and every behaviour described here is reachable from "install the current release".

## Phase 5: First upload

### 5a. Decide HF in-repo layout

Use `AskUserQuestion` if ambiguous; otherwise pick the simpler option and confirm.

* **Flat** (`<repo>/<filename>`): simplest, right when the repo holds one logical artifact class.
* **Subdirs** (`<repo>/<group>/<filename>`): when one repo holds multiple categories (`perception/`, `arm/`, `voice/`). Group by what the consuming code calls the artifact, not by file format.

If the consuming code expects flat on-disk paths (common for ROS, CLI tools, training scripts) but subdirs are clearer on HF, the Phase 6 downloader flattens by basename. Document the choice in the manifest so future readers do not confuse the two layouts.

**Basename collision warning**: with subdirs on HF, no two artifacts may share a basename across subdirs, or the basename-flatten would silently overwrite the loser. The `hf-download` reference script includes a collision check up front; rely on it.

### 5b. Upload via atomic commit

Invoke the `hf-upload` skill, passing forward the context established here so it short-circuits its own prerequisite probes: `repo_id` from 3c, `repo_type` from 3b, current auth from 4c, and the planned layout from 5a. `hf-upload` owns the `create_commit` template, the operation-pattern shapes, sha256 timing, its own execution gate, and failure-mode handling.

### 5c. Record the commit SHA

`hf-upload` prints `info.oid` and `info.commit_url`; record both. The OID becomes the `hf_revision` pin in Phase 6a.

If the user reused an existing repo in 3a and skipped 5b entirely, recover the current main SHA retroactively:

```python
from huggingface_hub import HfApi
api = HfApi()
sha = [b.target_commit for b in
       api.list_repo_refs("<owner>/<repo>", repo_type="model").branches
       if b.name == "main"][0]
print(sha)
```

## Phase 6 (optional): Manifest-pinned integration

Read `.claude/skills/hf-setup/references/manifest-integration.md` (repo-relative) and follow it. It covers the manifest YAML, the `fetch_weights.py` scaffold, runtime sha256 verification in the consumer, the `.gitignore` rule, and the deploy token plus build / CI wiring, each with its execution gate.

Skip the phase entirely when the user only wants to host files for manual browsing or ad-hoc download.

# Reference: `hf` CLI cheat sheet

The old-to-new CLI command mapping, the most-used commands, and the no-browser repo-state probe live in `.claude/skills/hf-setup/references/cli-reference.md` (repo-relative). Read it when rendering CLI commands for the user or probing HF state. Python API for atomic multi-file commits: see `hf-upload`. Python API for downloads: see `hf-download`.

# Rationale

* **Two-token split**: prevents leaked deploy credentials from also being write-capable. Minor extra setup, large reduction in blast radius.
* **Apache-2.0 default for ML weights**: the patent grant matters more often than people expect when artifacts end up in commercial systems.
* **Per-module HF repos** (`<project>-<module>-models`) over one giant `<project>-models`: smaller diff surface, independent versioning, finer access control, and one bad commit in one module does not pollute other modules' history.
* **Manifest with full SHA plus per-file sha256** over branch tags or short SHAs: branches move, sha256 is immutable, drift becomes detectable instead of insidious.
* **Basename-flatten on download**: decouples HF layout from on-disk conventions, so HF can reshape in-repo paths without breaking the consumer's launch files. The collision check is the price of that decoupling.
* **`hf_hub_download` to cache plus `shutil.copyfile` to target**, rather than `local_dir=`: the HF cache is shared across checkouts on the same machine, so the same file is not stored N times.
* **Fine-grained tokens over classic**: classic personal tokens read every repo the user can read.
* **`hf auth whoami --format agent`**: single-line and stable across TTY modes, so the same probe works in a Bash subprocess and in the user's shell.

# Hard rules

* NEVER enter Phase 1 or later before Phase 0 has either reported every prerequisite green AND Phase 0c was answered **full setup**, OR Phase 0c was answered **configure-only** (in which case the run stops after Phase 2). A fresh invocation defaults to inspection, not creation; silently promoting a logged-in workstation to "full setup" because the probes happen to be green is the exact blind execution this rule blocks.
* NEVER invoke `pip install`, `pipx`, `uv tool`, `hf auth login`, or any HF web signup from inside this skill. Phase 0b only renders the command for the user to run; the user re-confirms each fix before 0a re-probes. The skill must never modify the user's interpreter, shell profile, or token cache without an in-person decision.
* NEVER display, log, or write a user-pasted HF token into chat, scratch files, or committed configs. It lives only at `~/.cache/huggingface/token` and in CI secret stores.
* Design-stage prompts NEVER substitute for execution-stage gates. Each gate in the Procedure intro list MUST fire immediately before its mutation. Blind scaffolding (writing or editing a consumer-repo file without first rendering the proposed content or diff inline and getting action-verb approval) is the failure mode this rule blocks.
* NEVER suggest `git lfs install` in the consumer code repo. HF Hub uses LFS on its own side; the consumer does not need LFS configured to use `hf_hub_download`.
* NEVER pin `hf_revision` to `main`, a branch name, or a short SHA. Full 40-character commit SHA only.
* NEVER commit downloaded artifacts into the consumer repo. Add the download target to `.gitignore` at the same time as wiring up the fetcher; never one without the other.
* NEVER repurpose a Write token for deployment. Create a separate fine-grained Read token even when it feels like an extra step.
* NEVER trigger an HF download from a consumer node's runtime startup path. Build-time `fetch_weights.py` and runtime `verify_pinned_weight` are deliberately separate: fetch may use network and fail recoverably; verify is fatal on missing with no fallback. Collapsing them masks "operator forgot the bootstrap step" failures and adds blocking network I/O to a startup hot path.
* When the user has an existing HF account, org, or repo, detect it first (`hf auth whoami --format agent`, `list_models(author=...)`, `list_datasets(author=...)`, `repo_info`) and confirm reuse vs new-create. Do not suggest a new name on top of unknown existing state.
