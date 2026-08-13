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
hf_repo_type: model               # model | dataset | space; MUST match the Phase 3b choice
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

Compute sha256 with `sha256sum <local-file>` through the `Bash` tool (PowerShell's equivalent is `Get-FileHash -Algorithm SHA256 <local-file>`). This is already done during Phase 5b if you followed the order.

**Gate.** Choose the verb by target state: **write** / **abort** when the path does not exist (new file via `Write`), **edit** / **abort** when it already exists (in-place change via `Edit`, preserving unrelated lines). Render either the full proposed content (new file) or the resulting diff (existing file) inline before asking. Never run `Write` against an existing `model_weights.yaml`; that would clobber hand-tuned entries.

## 6b. Downloader script

Lift the canonical `fetch_weights.py` reference implementation from the `hf-download` skill (per-file `hf_hub_download` loop, basename collision guard, sha256-keyed conditional skip, `shutil.copyfile` flatten to a single directory, and the `HfHubHTTPError` comment documenting LFS-object purge as a common 404 cause). Adapt the path constants (`REPO_ROOT`, `CONFIG_PATH`, `DEST_DIR`) to the consumer's layout and reuse the Phase 6a manifest format verbatim.

Do NOT invoke the `hf-download` skill from here. Its interactive gate is for one-off downloads and does not apply to a script that runs unattended in CI or robot bootstrap; the scaffolded script intentionally contains no prompts. This skill's gate sits one level up, at scaffolding time, not inside the generated code.

**Gate.** Render the full proposed file content inline (plus a diff when the target already exists), then ask **write** / **abort**. Only on **write** invoke `Write` against `<consumer-repo>/<package>/scripts/fetch_weights.py` (or whatever name the consumer's conventions prefer).

## 6c. Runtime verification (recommended)

In the consumer code (the ROS node, the training script, the CLI tool), re-verify sha256 at startup before loading the artifact. This catches:

* Operator forgot to run `fetch_weights.py` after pulling code that bumped the manifest.
* Disk file silently corrupted (rare but real on SD-card-backed robots).
* Someone manually edited or replaced the file.

Verification reuses the Phase 6a manifest, preserving the single source of truth. Symbol names match the `hf-download` reference implementation, so `_sha256_of` and `CONFIG_PATH` must be imported from the scaffolded `fetch_weights.py` (or duplicated in the consumer module) rather than assumed to be in scope. Substitute the consumer's logger for `log_fatal`:

```python
def verify_pinned_weight(path):
    spec = yaml.safe_load(CONFIG_PATH.read_text())
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
    if _sha256_of(pathlib.Path(path)) != entry["sha256"]:
        log_fatal(f"Pinned weight sha256 drift: {path}. Re-run fetch_weights.py.")
        sys.exit(1)
```

`log_fatal` is a stand-in: `rospy.logfatal` in a ROS node, `logging.critical` in plain Python, the project's existing fatal logger elsewhere.

**Call-site convention.** Invoke `verify_pinned_weight(resolved_path)` after path resolution and before the model is instantiated (or any file handle is opened). Two anchors that work in practice:

1. Immediately after `resolve_model_path()` (or the equivalent path helper) returns, before the path reaches the model constructor.
2. Inside the optional-feature gate when the weight is controlled by a config flag, so verification runs only when the feature is enabled.

Both keep verification on the same code path as model loading, so a missing or drifted weight surfaces in the same line range an operator already inspects when a node fails to start. For a consumer with an optional lazy-loaded weight, gate `verify_pinned_weight` on the enable flag: a manifest-listed path makes missing-or-drift fatal, while a custom non-manifest path returns silently and preserves the existing lazy-skip behaviour.

**Gate.** Only when Claude is doing the edit on the user's behalf: render the per-file diff inline, then ask **patch** / **abort**, one gate per consumer file. Do not batch unrelated files behind a single prompt. When the user is editing themselves and only wants the pattern, no gate is required because Claude writes nothing.

## 6d. `.gitignore` the download target

Downloaded files must not be committed to the consumer repo; that would defeat the point of using HF. Add the destination directory to the consumer repo's `.gitignore`, documenting the why so a future reader does not re-add the files thinking the rule is mistaken:

```text
# Model weights are pulled from Hugging Face Hub by scripts/fetch_weights.py
# (see config/model_weights.yaml). Do not commit the downloaded files.
models/
```

**Gate.** Render the planned diff inline (append at the end of the existing file unless a clearly related block already exists), then ask **append** / **abort**. Only on **append** invoke `Edit` against `<consumer-repo>/.gitignore`. Never run `Write` against an existing `.gitignore`; `Edit` preserves unrelated rules.

## 6e. Deploy token and build / CI integration

Create the Read-only deploy token deferred from Phase 4a:

* `https://huggingface.co/settings/tokens` -> `Create new token` -> **Fine-grained**.
* Permissions: Read access to contents of the new repo only. Do not check any Write permission.
* Name: `<repo-name>-deploy` (an operator-facing label distinguishing it from the dev token).
* Save the value once; distribute via the channels below.

Wire the download into whatever orchestrates the consumer:

* **catkin / ROS**: register `fetch_weights.py` in `catkin_install_python`; call it from a bootstrap script before `catkin_make`, or have the launch system invoke it as a precondition.
* **Python package**: add a `make fetch` target, a `setup.py` postinstall hook, or call it lazily from `__init__`.
* **Docker image**: run `fetch_weights.py` in a `RUN` step with `--secret id=hf_token` so the token does not bake into a layer.
* **CI**: store the deploy token as a CI secret exported as `HF_TOKEN`; the fetcher's `os.environ.get("HF_TOKEN")` picks it up.
* **Robot deploy**: write the deploy token to `/etc/environment` or a systemd unit's `EnvironmentFile=`. Never check it into the robot's deployment repo.

**Timing contract.** `fetch_weights.py` must run to success at least once before any launch, test, or runtime model load. Two acceptable placements: a bootstrap step before the project's build command (`pip install -e .`, `catkin_make`, `cargo build`, whatever applies) so the build fails fast when weights cannot be fetched, or the process supervisor invoking it as a system precondition before starting the consumer. The two-phase split (build-time fetch with network, runtime verify without) is the contract; collapsing them is prohibited by the Hard rules in `SKILL.md`.

The skill's job ends when the user can run `fetch_weights.py` on a fresh checkout and see all weights download, verify sha256, and the consumer code start without `verify_pinned_weight` complaining. Confirm that end-to-end before declaring success.
