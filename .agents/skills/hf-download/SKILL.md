---
name: hf-download
description: Pull files from a Hugging Face Hub repo at a pinned 40-character revision into the HF cache or a target directory, gated by a choice question. Use for "download this model from HF", "pull these weights to my robot", "fetch the dataset", "CI needs the v2 checkpoint", or wiring a manifest-pinned fetch_weights.py. For first-time HF setup use hf-setup instead.
compatibility: Requires network access to huggingface.co, a POSIX shell (Git Bash on Windows), and Python with the huggingface_hub library; the hf CLI for the private-repo auth probe; PyYAML for the fetch_weights.py reference script.
---

# Goal

Pull files from a Hugging Face Hub repository at a pinned revision into the local cache or a chosen target directory. `snapshot_download` is the universal one-call primitive (parallel batch, glob filtering, cache or local-dir output); drop to a per-file `hf_hub_download` loop only when per-file sha256 verification or conditional skip is required.

# When NOT to use

* HF is not configured yet (no account, no repo, not logged in for a private repo): invoke `hf-setup` first, then return here once it has completed Phase 5 (its Phase 6 scaffolds `fetch_weights.py` and never hands back to this skill).
* The goal is "model in memory", not "files on disk": `transformers.AutoModel.from_pretrained` and `diffusers.DiffusionPipeline.from_pretrained` call `snapshot_download` internally and instantiate in one step.
* The user wants a one-off click-through download: the HF web UI file page has a download button.

# Prerequisites

Public repos need no auth. For private repos, verify first:

```bash
HF_HUB_DISABLE_UPDATE_CHECK=1 hf auth whoami --format agent
```

Read it by exit status. Exit 0 prints `user=<name>`, plus `orgs=<a,b,c>` only when the account belongs to an organization. A non-zero exit means not logged in (stderr `Error: Not logged in`, or `Invalid user token` for a rejected token); for first-time auth suggest `hf-setup` (its Phase 4 covers token creation and login), otherwise `hf auth login --force`. The variable suppresses the CLI's once-a-day update hint on stderr.

Gated repos (public, but behind a license or access form) also need a login: the user must first accept the terms on the repo page, and a fine-grained token additionally needs its read permission for public gated repos.

Probe the Python interpreter once, the same way `hf-setup` Phase 0a does:

```bash
python3 -c 'import huggingface_hub as h; print("python3", h.__version__)' 2>/dev/null || python -c 'import huggingface_hub as h; print("python", h.__version__)' 2>/dev/null || echo lib-missing
```

The first word printed is the interpreter name that answered (POSIX systems expose `python3`, Windows installs usually only `python`, where a bare `python3` may be a Microsoft Store stub that fails). Every snippet in this skill writes that name as the placeholder `<python>`; substitute the probed name. On `lib-missing`, suggest `hf-setup` (its Phase 0b renders the install fix).

The skill needs four concrete inputs:

1. **`repo_id`** in `<owner>/<name>` form.
2. **`repo_type`**: `model`, `dataset`, or `space` (defaults to `model` when not stated).
3. **`revision`**: the full 40-character commit SHA, never a branch name or short hash. Manifest-pinned consumers carry it in the manifest; otherwise ask or retrieve it from HF Hub's commit list.
4. **What to download**: a filename, a glob, a subdirectory, or "all".

# Procedure

Terms such as choice question, independent reads, invoke, and suggest follow AGENTS.md (Skill authoring); in a non-interactive session every gate ends this skill.

Every invocation runs the step-4 gate; in a non-interactive session (batch, CI, cloud) that gate ends the skill with the planned call reported and nothing downloaded. Unattended fetches (CI, build systems, robot bootstrap) run the scaffolded `fetch_weights.py` reference implementation instead of this skill; it intentionally contains no prompts (see Rationale).

Run Python snippets in a POSIX shell as a `<python> - <arg>... <<'PY'` heredoc, with `<python>` replaced by the Prerequisites probe result, mirroring `hf-upload`. Pass local paths (such as `local_dir`) as arguments and read them from `sys.argv[1:]`, never embedded in the heredoc text: Git Bash converts MSYS paths such as `/c/...` in arguments to native Windows programs but not inside script text, so a native Windows Python cannot use an embedded `/c/...` path. Git Bash also skips that conversion for an argument containing `'` or `*`, so convert each path before the call; the guard is a no-op where `cygpath` is absent (macOS, Linux):

```bash
D=<target-dir>
command -v cygpath >/dev/null 2>&1 && D="$(cygpath -m "$D")"
<python> - "$D" <<'PY'
import sys
local_dir = sys.argv[1]   # pass as local_dir= in the canonical recipe
PY
```

1. **Read the conversation for context.** Resolve all four Prerequisites inputs before step 2.
   * `repo_id`, `repo_type`, `revision`: if clear from prior turns or a manifest in scope, do not re-ask; otherwise ask with a choice question.
   * **File selection**: when not stated, ask with a choice question with options scoped to the situation (`single file: <name>` / `glob: *.pt` / `subdir: <path>/` / `everything`).

2. **Choose the primitive.** Default to `snapshot_download`. Drop to a per-file `hf_hub_download` loop only when one of these applies:
   * Per-file sha256 verification after download (the manifest-pinned pattern).
   * Conditional skip: do not download when a local file already matches the expected sha256.
   * Flat output layout: HF's in-repo path is nested but consumer code expects `<target>/<basename>`.

3. **Verify `revision` is a 40-character SHA**, not `main` or a branch name: `assert len(revision) == 40 and all(c in "0123456789abcdef" for c in revision)`.

4. **Confirm with a choice question before pressing go.** Render the planned call inline as a fenced code block (the exact invocation with `repo_id`, `revision`, the `allow_patterns` or per-file `filename` list, and the destination: cache only vs `local_dir=<path>`), then ask **download** / **abort**.
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
    local_dir="<target-dir>",                # optional; omit = cache only ($HF_HOME/hub, default ~/.cache/huggingface/hub/)
    token=os.environ.get("HF_TOKEN"),        # private repo needs a token; public ignores it
)
print(local_dir)
```

Key behaviours:

* **Parallel by default**: multi-threaded HTTP transfers make N files an order of magnitude faster than N serial `hf_hub_download` calls.
* **Content-addressed cache** (no `local_dir`): identical content is stored once regardless of how many consumer projects pull it. With `local_dir`, files are downloaded directly into that folder (with small metadata under `<local_dir>/.cache/huggingface/`) and are not stored in or linked from the shared cache (see `https://huggingface.co/docs/huggingface_hub/guides/download#download-files-to-a-local-folder`).
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

The canonical production pattern when a consumer repo pins HF revisions via a yaml manifest (the `hf-setup` Phase 6 convention); this block is the single maintained copy, which `hf-setup` Phase 6b copies into the consumer. It uses `hf_hub_download` per file because per-file sha256 verification and conditional skip need per-file granularity. It imports PyYAML (`yaml`). The manifest and destination paths default to `<package>/config/model_weights.yaml` and `<package>/models/` relative to the script; override them with `--config` / `--dest`, or with the `FETCH_WEIGHTS_CONFIG` / `FETCH_WEIGHTS_DEST` environment variables (the options win).

```python
#!/usr/bin/env python3
import argparse, hashlib, os, pathlib, shutil, sys
import yaml
from huggingface_hub import hf_hub_download
from huggingface_hub.errors import HfHubHTTPError, LocalEntryNotFoundError

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
# Defaults; the environment overrides them, and --config / --dest override both.
CONFIG_PATH = pathlib.Path(
    os.environ.get("FETCH_WEIGHTS_CONFIG", REPO_ROOT / "config" / "model_weights.yaml"))
DEST_DIR = pathlib.Path(os.environ.get("FETCH_WEIGHTS_DEST", REPO_ROOT / "models"))


def _sha256_of(path):
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Fetch manifest-pinned HF Hub files and verify sha256.")
    parser.add_argument("--config", type=pathlib.Path, default=CONFIG_PATH,
                        help="manifest YAML (default: %(default)s)")
    parser.add_argument("--dest", type=pathlib.Path, default=DEST_DIR,
                        help="download target directory (default: %(default)s)")
    args = parser.parse_args(argv)
    spec = yaml.safe_load(args.config.read_text(encoding="utf-8"))
    args.dest.mkdir(parents=True, exist_ok=True)

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
        target = args.dest / pathlib.Path(entry["filename"]).name
        expected = str(entry["sha256"]).lower()  # tolerate uppercase digests
        if target.exists() and _sha256_of(target) == expected:
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
        except (LocalEntryNotFoundError, OSError) as err:
            # Offline (no network, or HF_HUB_OFFLINE set) with the file not in
            # cache, or a local I/O failure; not an HfHubHTTPError subclass.
            print(f"[fetch_weights] {name}: {err}", file=sys.stderr)
            return 1
        shutil.copyfile(src, target)
        if _sha256_of(target) != expected:
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
| `HfHubHTTPError 401` | Token missing or expired (private or gated repo) | `hf auth login --force`; verify with the Prerequisites `whoami` probe |
| `GatedRepoError` (401 or 403) | Gated repo: terms not accepted, access request pending, or a fine-grained token without the public-gated-repos read permission | Accept the terms on the repo page with the same account, wait for approval if required, or enable that token permission |
| `HfHubHTTPError 403` | Token lacks Read access on the repo | Issue a fine-grained Read token scoped to this repo |
| `HfHubHTTPError 404` on a file | Wrong `filename`, or the LFS object was purged on HF Settings -> Storage | Verify the path against `repo_info(files_metadata=True)`; if the path is right, the LFS payload is gone: re-upload or pick a fresh revision |
| `HfHubHTTPError 404` on a repo | `repo_id` typo, or private with the wrong token | Verify owner/name spelling; check visibility |
| `HfHubHTTPError 429` | Request-count rate limit over a 5-minute window (separate buckets for API calls and file resolves; anonymous requests get the lowest quota) | Always pass a token; current `huggingface_hub` releases wait for the reset and retry automatically; otherwise spread requests out (see `https://huggingface.co/docs/hub/rate-limits`) |
| `LocalEntryNotFoundError` | No network, or offline mode, and the file is not in cache | Restore network or unset `HF_HUB_OFFLINE` |
| `RevisionNotFoundError` | Wrong or mistyped commit SHA, or a commit that no longer exists (for example after a history squash) | Verify against the repo's commit list (`HfApi().list_repo_commits(repo_id)`); a valid SHA on any branch resolves |
| Network timeout mid-transfer | Slow or spotty connection | Re-run; LFS transfers resume from the cached partial |

All `HfHubHTTPError` instances expose `.response.status_code` and a body; surface both verbatim before suggesting a fix.

# Rationale

* **Skill always gated, scaffolded script ungated.** This skill writes to local disk on a human's behalf, so step 4 gives the user a chance to spot a wrong revision or an unintended overwrite; with no user to answer, the gate ends the run instead of guessing. The generated `fetch_weights.py` runs from CI, build systems, and robot bootstrap, where a prompt would block automation; its gate sits one level up, at scaffolding time in `hf-setup` Phase 6b.
* **`hf_hub_download` to cache plus `shutil.copyfile` to target**, rather than `local_dir=` in the manifest pattern: the HF cache is shared across checkouts on the same machine, so the same bytes are not stored N times.
* **Full SHA pins only.** A wrong revision either 404s loudly (recoverable) or silently downloads a different version than expected (insidious); pinning explicitly removes the second case.

# Hard rules

* NEVER pass `revision="main"`, a branch name, or a short hash. Use the full 40-character commit SHA; branches move and short hashes risk ambiguity, so the pin must be immutable for drift to be detectable.
* NEVER skip the step 4 choice-question gate. In a non-interactive session it ends the skill (AGENTS.md); unattended fetches use the scaffolded `fetch_weights.py`, never this skill.
* Conversely, NEVER add interactive prompts to a scaffolded `fetch_weights.py`. The asymmetry is intentional (see Rationale).
* NEVER skip the per-file sha256 verification after download for a manifest-pinned consumer. The pin is meaningless if you do not verify what landed.
* NEVER display, log, or persist the HF token in chat, scratch files, or commit messages. It lives only in the HF token files (`$HF_HOME/token`, default `~/.cache/huggingface/token`, relocatable via `HF_TOKEN_PATH`, plus the `stored_tokens` file beside it) or in CI secret stores as `HF_TOKEN`.
* NEVER block a per-render, per-request, or per-frame hot path on a download. Pre-download during build or setup; at runtime only verify.
* NEVER recommend `git clone` + `git lfs pull` as a download path. It adds a local `git-lfs install` dependency and does not parallelize beyond one HTTP connection per file.
* If a `404 on file` surfaces despite a valid `repo_id` and `revision`, check HF's LFS storage page before assuming the path is wrong. A purged LFS object keeps the git commit resolvable while the blob is gone, and the symptom is identical to a typo.
