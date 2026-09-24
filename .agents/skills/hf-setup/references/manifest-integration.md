# Phase 6 (optional): Manifest-pinned integration

Loaded from `hf-setup/SKILL.md` Phase 6. Read this file only when the consumer repo needs reproducible, pinned downloads. The Hard rules in `SKILL.md` remain in force throughout; the execution gates below are the Phase 6 half of the gate list stated in the Procedure intro there.

Skip this phase entirely if the user only wants to host files for manual browsing or ad-hoc download. Use it when:

* The files are pulled by deterministic code (CI, robot startup, training pipeline).
* Drift between expected and actual artifacts would be a silent failure.
* Multiple machines (developers, robots, CI) must agree on which version they have.

## 6a. Manifest YAML

Draft `<consumer-repo>/<package>/config/model_weights.yaml` (adapt the path to the consumer's layout). Render the full file content inline first, including the resolved `hf_repo`, the 40-character `hf_revision` from Phase 5c, and one entry per weight with its sha256:

```yaml
# Manifest pinning HF Hub artifacts to a specific commit.
# Updating: push to HF, then bump hf_revision + per-file sha256 in this yaml.
hf_repo: <owner>/<repo>
hf_repo_type: model               # model | dataset; MUST match the Phase 3b choice
hf_revision: <40-char commit SHA from Phase 5c>
# The `weights` key is historical: it holds every pinned artifact, including
# datasets, rosbags, and CSVs when hf_repo_type is `dataset`.
weights:
  <logical-name-1>:
    filename: <HF in-repo path>     # may be nested
    sha256: <hex digest of local file>
  <logical-name-2>:
    filename: <...>
    sha256: <...>
```

Compute sha256 in a POSIX shell with the probed interpreter (`<python>`, the name Phase 0a probe 2 printed), which prints lowercase hex on every platform (macOS ships no `sha256sum`, and other tools differ in case and output format):

```bash
P=<local-file>
command -v cygpath >/dev/null 2>&1 && P="$(cygpath -m "$P")"   # Git Bash leaves a path with ' or * unconverted; no-op elsewhere
<python> -c 'import hashlib,sys;h=hashlib.sha256();f=open(sys.argv[1],"rb");[h.update(b) for b in iter(lambda:f.read(1<<20),b"")];print(h.hexdigest())' "$P"
```

Record the digest in lowercase; `fetch_weights.py` compares case-insensitively anyway. This is already done during Phase 5b if you followed the order.

**Gate.** Choose the verb by target state: **write** / **abort** when the path does not exist (new file), **edit** / **abort** when it already exists (in-place edit, preserving unrelated lines). Render either the full proposed content (new file) or the resulting diff (existing file) inline before asking. Never overwrite an existing `model_weights.yaml` wholesale; that would clobber hand-tuned entries.

## 6b. Downloader script

Copy the canonical `fetch_weights.py` reference implementation from `../hf-download/SKILL.md` (relative to the `hf-setup` skill directory; section `Reference: fetch_weights.py`), the single maintained copy (per-file `hf_hub_download` loop, basename collision guard, sha256-keyed conditional skip, `shutil.copyfile` flatten to a single directory, and the `HfHubHTTPError` comment documenting LFS-object purge as a common 404 cause). Set the default paths (`REPO_ROOT`, `CONFIG_PATH`, `DEST_DIR`) to match the consumer's layout and reuse the Phase 6a manifest format verbatim. The script reads overrides at run time, so no caller edits it: `--config` / `--dest`, or the `FETCH_WEIGHTS_CONFIG` / `FETCH_WEIGHTS_DEST` environment variables (the options win). It imports PyYAML (`yaml`) besides `huggingface_hub`; add both to the consumer's dependencies. It reads the manifest with `read_text(encoding="utf-8")`; keep that argument, since the platform default (such as cp936 on a Chinese Windows) fails on non-ASCII manifest comments.

Do NOT invoke the `hf-download` skill from here. Its interactive gate is for one-off downloads and does not apply to a script that runs unattended in CI or robot bootstrap; the scaffolded script intentionally contains no prompts. This skill's gate sits one level up, at scaffolding time, not inside the generated code.

**Gate.** Render the full proposed file content inline (plus a diff when the target already exists), then ask **write** / **abort**. Only on **write** create `<consumer-repo>/<package>/scripts/fetch_weights.py` (or whatever name the consumer's conventions prefer).

## 6c. Runtime verification (recommended)

In the consumer code (the ROS node, the training script, the CLI tool), re-verify sha256 at startup before loading the artifact. This catches:

* Operator forgot to run `fetch_weights.py` after pulling code that bumped the manifest.
* Disk file silently corrupted (rare but real on SD-card-backed robots).
* Someone manually edited or replaced the file.

Verification reuses the Phase 6a manifest, preserving the single source of truth. Symbol names match the `hf-download` reference implementation, so `_sha256_of` and `CONFIG_PATH` (plus the standard `os`, `sys`, `pathlib`, and `yaml` imports) must be imported from the scaffolded `fetch_weights.py` (or duplicated in the consumer module) rather than assumed to be in scope. `CONFIG_PATH` honors `FETCH_WEIGHTS_CONFIG` but not the fetcher's `--config` option; use the environment variable when both must read a non-default manifest. Substitute the consumer's logger for `log_fatal`:

```python
def verify_pinned_weight(path):
    spec = yaml.safe_load(CONFIG_PATH.read_text(encoding="utf-8"))
    entry = next(
        (v for v in spec["weights"].values()
         if os.path.basename(v["filename"]) == os.path.basename(path)),
        None,
    )
    if entry is None:
        return  # not manifest-listed; caller's responsibility
    if not os.path.exists(path):
        log_fatal(f"Pinned weight missing: {path}. Run fetch_weights.py.")
        sys.exit(1)
    if _sha256_of(pathlib.Path(path)) != str(entry["sha256"]).lower():
        log_fatal(f"Pinned weight sha256 drift: {path}. Re-run fetch_weights.py.")
        sys.exit(1)
```

`log_fatal` is a stand-in: `rospy.logfatal` in a ROS node, `logging.critical` in plain Python, the project's existing fatal logger elsewhere.

**Call-site convention.** Invoke `verify_pinned_weight(resolved_path)` after path resolution and before the model is instantiated (or any file handle is opened). Two anchors that work in practice:

1. Immediately after `resolve_model_path()` (or the equivalent path helper) returns, before the path reaches the model constructor.
2. Inside the optional-feature gate when the weight is controlled by a config flag, so verification runs only when the feature is enabled.

Both keep verification on the same code path as model loading, so a missing or drifted weight surfaces in the same line range an operator already inspects when a node fails to start. For a consumer with an optional lazy-loaded weight, gate `verify_pinned_weight` on the enable flag: a manifest-listed path makes missing-or-drift fatal, while a custom non-manifest path returns silently and preserves the existing lazy-skip behaviour.

**Gate.** Only when the agent is doing the edit on the user's behalf: render the per-file diff inline, then ask **patch** / **abort**, one gate per consumer file. Do not batch unrelated files behind a single prompt. When the user is editing themselves and only wants the pattern, no gate is required because the agent writes nothing.

## 6d. `.gitignore` the download target

Downloaded files must not be committed to the consumer repo; that would defeat the point of using HF. Add the destination directory to the consumer repo's `.gitignore`, documenting the why so a future reader does not re-add the files thinking the rule is mistaken:

```text
# Model weights are pulled from Hugging Face Hub by <package>/scripts/fetch_weights.py
# (see <package>/config/model_weights.yaml). Do not commit the downloaded files.
/<package>/models/
```

Anchor the rule to the default `DEST_DIR` path relative to the consumer repo root (leading `/`, path from the repo root to the directory; `/models/` when the package sits at the repo root): a bare `models/` would also ignore every unrelated `models/` directory, including source packages of that name.

**Gate.** Render the planned diff inline (append at the end of the existing file unless a clearly related block already exists), then ask **append** / **abort**. Only on **append** edit `<consumer-repo>/.gitignore` in place. Never overwrite an existing `.gitignore` wholesale; an in-place edit preserves unrelated rules.

## 6e. Deploy token and build / CI integration

Create the Read-only deploy token deferred from Phase 4a:

* `https://huggingface.co/settings/tokens` -> `Create new token` -> **Fine-grained**.
* Permissions: Read access to contents of the new repo only. Do not check any Write permission.
* Name: `<repo-name>-deploy` (an operator-facing label distinguishing it from the dev token).
* Save the value once; distribute via the channels below.

Wire the download into whatever orchestrates the consumer:

* **catkin / ROS**: register `fetch_weights.py` in `catkin_install_python`; call it from a bootstrap script before `catkin_make`, or have the launch system invoke it as a precondition.
* **Python package**: add a `make fetch` target or a documented bootstrap step run before tests and launch. Do not use a `setup.py` postinstall hook (it does not run for wheel installs) or a lazy call from `__init__` (a runtime-startup download, which the Hard rules in `SKILL.md` forbid).
* **Docker image**: expose the token to one `RUN` step as a build secret so it does not bake into a layer: `RUN --mount=type=secret,id=hf_token,env=HF_TOKEN python3 scripts/fetch_weights.py` in the Dockerfile, built with `docker build --secret id=hf_token,env=HF_TOKEN .` (see `https://docs.docker.com/build/building/secrets/`). A bare `--secret id=hf_token` only mounts a file at `/run/secrets/hf_token`, which the fetcher does not read. Never pass the token through `ARG` or `ENV`.
* **CI**: store the deploy token as a CI secret exported as `HF_TOKEN`; the fetcher's `os.environ.get("HF_TOKEN")` picks it up.
* **Robot deploy**: put `HF_TOKEN=<token>` in a root-owned, mode `0600` file referenced by the fetching systemd unit's `EnvironmentFile=`. Never use `/etc/environment`, which is world-readable, and never check the token into the robot's deployment repo.

**Timing contract.** `fetch_weights.py` must run to success at least once before any launch, test, or runtime model load. Two acceptable placements: a bootstrap step before the project's build command (`pip install -e .`, `catkin_make`, `cargo build`, whatever applies) so the build fails fast when weights cannot be fetched, or the process supervisor invoking it as a system precondition before starting the consumer. The two-phase split (build-time fetch with network, runtime verify without) is the contract; collapsing them is prohibited by the Hard rules in `SKILL.md`.

The skill's job ends when the user can run `fetch_weights.py` on a fresh checkout and see all weights download, verify sha256, and the consumer code start without `verify_pinned_weight` complaining. Confirm that end-to-end before declaring success.
