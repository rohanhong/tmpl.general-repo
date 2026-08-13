---
name: hf-download
description: Pull files from a Hugging Face Hub repo at a pinned 40-character revision into the HF cache or a target directory, gated by an AskUserQuestion. Use for "download this model from HF", "pull these weights to my robot", "fetch the dataset", "CI needs the v2 checkpoint", or wiring a manifest-pinned fetch_weights.py. For first-time HF setup use hf-setup instead.
---

# Goal

Pull files from a Hugging Face Hub repository at a pinned revision into the local cache or a chosen target directory. `snapshot_download` is the universal one-call primitive (parallel batch, glob filtering, cache or local-dir output); drop to a per-file `hf_hub_download` loop only when per-file sha256 verification or conditional skip is required.

# When NOT to use

* HF is not configured yet (no account, no repo, not logged in for a private repo): invoke `hf-setup` first, then return here at its Phase 6.
* The goal is "model in memory", not "files on disk": `transformers.AutoModel.from_pretrained` and `diffusers.DiffusionPipeline.from_pretrained` call `snapshot_download` internally and instantiate in one step.
* The user wants a one-off click-through download: the HF web UI file page has a download button.

# Prerequisites

Public repos need no auth. For private repos, verify first:

```bash
hf auth whoami --format agent
```

Expected: `user=<name> orgs=<a,b,c>`. On `Invalid user token` or no output, the user is not logged in; defer first-time auth to `hf-setup` Phase 4, otherwise `hf auth login --force`.

The skill needs four concrete inputs:

1. **`repo_id`** in `<owner>/<name>` form.
2. **`repo_type`**: `model`, `dataset`, or `space` (defaults to `model` when not stated).
3. **`revision`**: the full 40-character commit SHA, never a branch name or short hash. Manifest-pinned consumers carry it in the manifest; otherwise ask or retrieve it from HF Hub's commit list.
4. **What to download**: a filename, a glob, a subdirectory, or "all".

# Procedure

This procedure governs the **interactive** invocation (a user in conversation asking Claude to download). The scaffolded `fetch_weights.py` reference implementation runs unattended in CI or robot bootstrap and intentionally contains no prompts; see Rationale.

Run Python snippets through the `Bash` tool as a `python - <<'PY'` heredoc (`python3` on POSIX, plain `python` on Windows), mirroring `hf-upload`.

1. **Read the conversation for context.** Resolve all four Prerequisites inputs before step 2.
   * `repo_id`, `repo_type`, `revision`: if clear from prior turns or a manifest in scope, do not re-ask; otherwise ask via `AskUserQuestion`.
   * **File selection**: when not stated, ask via `AskUserQuestion` with options scoped to the situation (`single file: <name>` / `glob: *.pt` / `subdir: <path>/` / `everything`).

2. **Choose the primitive.** Default to `snapshot_download`. Drop to a per-file `hf_hub_download` loop only when one of these applies:
   * Per-file sha256 verification after download (the manifest-pinned pattern).
   * Conditional skip: do not download when a local file already matches the expected sha256.
   * Flat output layout: HF's in-repo path is nested but consumer code expects `<target>/<basename>`.

3. **Verify `revision` is a 40-character SHA**, not `main` or a branch name: `assert len(revision) == 40 and all(c in "0123456789abcdef" for c in revision)`.

4. **Confirm via `AskUserQuestion` before pressing go.** Render the planned call inline as a fenced code block (the exact invocation with `repo_id`, `revision`, the `allow_patterns` or per-file `filename` list, and the destination: cache only vs `local_dir=<path>`), then ask **download** / **abort**.
   * When `local_dir=<path>` is set and the target directory already contains files, the rendered block MUST include a one-line note listing the existing entries that would be overwritten (matched by basename against the planned download).
   * A bare "download" / "yes download" / "go ahead" typed in the current turn counts as confirmation; ambiguous replies do not.
   * **abort**: STOP. Nothing is written to disk.

5. **Run the call** with arguments matching the approved step-4 rendering verbatim.

6. **Capture the return value.** `snapshot_download` returns the directory containing the downloaded files; `hf_hub_download` returns the path to a single file inside the HF cache.

7. **(Manifest-pinned consumers only)** Verify per-file sha256 against the manifest. Skip otherwise.

# Reference: canonical recipe

```python
from huggingface_hub import snapshot_download
import os

local_dir = snapshot_download(
    repo_id="<owner>/<repo>",
    repo_type="model",                       # or "dataset" / "space"
    revision="<40-char SHA>",                # full SHA, never main / branch / short hash
    allow_patterns=["*.pt"],                 # glob filter; omit for everything
    # ignore_patterns=["*.md"],              # optional reverse filter
    local_dir="<target-dir>",                # optional; omit = cache only at ~/.cache/huggingface/hub/
    token=os.environ.get("HF_TOKEN"),        # private repo needs a token; public ignores it
)
print(local_dir)
```

Key behaviours:

* **Parallel by default**: multi-threaded HTTP transfers make N files an order of magnitude faster than N serial `hf_hub_download` calls.
* **Content-addressed cache**: identical content is stored once regardless of how many consumer projects pull it; symlinks (or copies, per filesystem) materialize files at `local_dir`.
* **Resumable**: interrupted LFS transfers resume without re-downloading cached bytes.
* **Idempotent**: repeat calls hit the cache; only first-time pulls and changed revisions trigger network I/O.

# Reference: operation patterns

The non-obvious shapes; "fetch one file" and "fetch everything" follow from the canonical recipe by setting `allow_patterns`.

| User intent | Call shape |
|---|---|
| Manifest-pinned with per-file sha256 verify | loop `hf_hub_download` per manifest entry + sha256 compare |
| Flat output (HF nested, consumer wants flat) | `hf_hub_download` per file, then `shutil.copyfile(src, target / pathlib.Path(remote_path).name)`; `snapshot_download` mirrors HF's nested layout under `local_dir` |
| Inspect HF state without downloading | `HfApi().repo_info(repo_id, repo_type=..., files_metadata=True)` returns the file list with LFS sha256 OIDs |
| Existing model into a runtime library | `AutoModel.from_pretrained("<repo>", revision="<sha>")`, `DiffusionPipeline.from_pretrained`; both call `snapshot_download` internally |

# Reference: fetch_weights.py (manifest-pinned pull)

The canonical production pattern when a consumer repo pins HF revisions via a yaml manifest (the `hf-setup` Phase 6 convention). It uses `hf_hub_download` per file because per-file sha256 verification and conditional skip need per-file granularity.

```python
#!/usr/bin/env python3
import hashlib, os, pathlib, shutil, sys
import yaml
from huggingface_hub import hf_hub_download
from huggingface_hub.errors import HfHubHTTPError

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
CONFIG_PATH = REPO_ROOT / "config" / "model_weights.yaml"
DEST_DIR = REPO_ROOT / "models"


def _sha256_of(path):
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main():
    spec = yaml.safe_load(CONFIG_PATH.read_text())
    DEST_DIR.mkdir(parents=True, exist_ok=True)

    # Basename collision guard: flat layout on disk means two manifest entries
    # with the same basename would silently overwrite each other.
    basenames = [pathlib.Path(e["filename"]).name for e in spec["weights"].values()]
    dupes = sorted({b for b in basenames if basenames.count(b) > 1})
    if dupes:
        print(f"[fetch_weights] manifest basename collisions: {dupes}", file=sys.stderr)
        return 1

    token = os.environ.get("HF_TOKEN")
    # Explicit: hf_hub_download defaults repo_type to model, so a dataset repo
    # 404s here in a way that looks exactly like a wrong filename.
    repo_type = spec.get("hf_repo_type", "model")
    for name, entry in spec["weights"].items():
        target = DEST_DIR / pathlib.Path(entry["filename"]).name
        if target.exists() and _sha256_of(target) == entry["sha256"]:
            print(f"[fetch_weights] {name}: cached")
            continue
        try:
            src = hf_hub_download(
                repo_id=spec["hf_repo"],
                filename=entry["filename"],
                revision=spec["hf_revision"],
                repo_type=repo_type,
                token=token,
            )
        except HfHubHTTPError as err:
            # 404 often means the LFS object was purged on HF (Settings ->
            # Storage -> Manage LFS Files) even though the git commit itself
            # still resolves. Re-upload or pick a fresh revision.
            print(f"[fetch_weights] {name}: {err}", file=sys.stderr)
            return 1
        shutil.copyfile(src, target)
        if _sha256_of(target) != entry["sha256"]:
            print(f"[fetch_weights] {name}: sha256 drift", file=sys.stderr)
            return 1
        print(f"[fetch_weights] {name}: downloaded")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

# Failure modes

| Error | Cause | Action |
|---|---|---|
| `HfHubHTTPError 401` | Token missing or expired (private repo only) | `hf auth login --force`; verify with `hf auth whoami --format agent` |
| `HfHubHTTPError 403` | Token lacks Read access on the repo | Issue a fine-grained Read token scoped to this repo |
| `HfHubHTTPError 404` on a file | Wrong `filename`, or the LFS object was purged on HF Settings -> Storage | Verify the path against `repo_info(files_metadata=True)`; if the path is right, the LFS payload is gone: re-upload or pick a fresh revision |
| `HfHubHTTPError 404` on a repo | `repo_id` typo, or private with the wrong token | Verify owner/name spelling; check visibility |
| `HfHubHTTPError 429` | Bandwidth rate limit on the token's namespace | Back off; HF per-namespace bandwidth quotas apply |
| `LocalEntryNotFoundError` | Offline mode and the file is not in cache | Restore network or unset `HF_HUB_OFFLINE` |
| `RevisionNotFoundError` | Wrong commit SHA, or a revision on a non-main branch | Verify against `HfApi().list_repo_refs(repo_id)` |
| Network timeout mid-transfer | Slow or spotty connection | Re-run; LFS transfers resume from the cached partial |

All `HfHubHTTPError` instances expose `.response.status_code` and a body; surface both verbatim before suggesting a fix.

# Rationale

* **Interactive gated, scaffolded script ungated.** This skill writes to local disk on a human's behalf, so step 4 gives the user a chance to spot a wrong revision or an unintended overwrite. The generated `fetch_weights.py` runs from CI, build systems, and robot bootstrap, where a prompt would block automation; its gate sits one level up, at scaffolding time in `hf-setup` Phase 6b.
* **`hf_hub_download` to cache plus `shutil.copyfile` to target**, rather than `local_dir=` in the manifest pattern: the HF cache is shared across checkouts on the same machine, so the same bytes are not stored N times.
* **Full SHA pins only.** A wrong revision either 404s loudly (recoverable) or silently downloads a different version than expected (insidious); pinning explicitly removes the second case.

# Hard rules

* NEVER pass `revision="main"`, a branch name, or a short hash. Use the full 40-character commit SHA; branches move and short hashes risk ambiguity, so the pin must be immutable for drift to be detectable.
* NEVER skip the step 4 `AskUserQuestion` gate when this skill is invoked interactively.
* Conversely, NEVER add interactive prompts to a scaffolded `fetch_weights.py`. The asymmetry is intentional (see Rationale).
* NEVER skip the per-file sha256 verification after download for a manifest-pinned consumer. The pin is meaningless if you do not verify what landed.
* NEVER display, log, or persist the HF token in chat, scratch files, or commit messages. It lives only at `~/.cache/huggingface/token` or in CI secret stores as `HF_TOKEN`.
* NEVER block a per-render, per-request, or per-frame hot path on a download. Pre-download during build or setup; at runtime only verify.
* NEVER recommend `git clone` + `git lfs pull` as a download path. It adds a local `git-lfs install` dependency and does not parallelize beyond one HTTP connection per file.
* If a `404 on file` surfaces despite a valid `repo_id` and `revision`, check HF's LFS storage page before assuming the path is wrong. A purged LFS object keeps the git commit resolvable while the blob is gone, and the symptom is identical to a typo.
