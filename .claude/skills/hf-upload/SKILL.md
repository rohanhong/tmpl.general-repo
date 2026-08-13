---
name: hf-upload
description: Run one atomic Hugging Face Hub commit mixing adds, replaces, and deletes, then return the commit SHA and URL for version pinning. Use for "upload this to HF", "push this weight to huggingface", "replace v1 with v2 on the hub", "delete the old file on HF", or bumping a manifest-pinned revision. Gated by AskUserQuestion. For first-time HF setup use hf-setup instead.
---

# Goal

Run one atomic HF Hub commit covering any combination of add, replace, delete, or rename operations, then return the commit SHA and URL for follow-up steps (manifest sync, README updates, deploy notifications). `HfApi.create_commit` is the only upload primitive that handles multi-file atomicity, mixed op types, and SHA capture in one call; CLI `hf upload` and git push are convenience shells around subsets of it.

# When NOT to use

* HF is not configured yet (no account, no repo, not logged in): invoke `hf-setup` first, then return here at its Phase 5.
* The user is contributing to a public repo via PR review: use `hf upload --create-pr` or the web UI's "Open Pull Request". This skill commits straight to `main`.
* The user explicitly wants an ordinary local git workflow: valid but heavier (needs `git-lfs` locally plus a full clone). Only walk that path on an explicit request.

# Prerequisites

Verify before any upload action:

```bash
hf auth whoami --format agent
```

Expected: `user=<name> orgs=<a,b,c>`. On `Invalid user token` or no output, have the user run `hf auth login` (or `--force` if a stale token is cached). For first-time auth, defer to `hf-setup` Phase 4.

The skill also needs three concrete inputs, from explicit prior context or `AskUserQuestion`:

1. **`repo_id`** in `<owner>/<name>` form.
2. **`repo_type`**: `model`, `dataset`, or `space`.
3. **For each operation**: the local path (for adds) and the `path_in_repo` (always). For a replace, `path_in_repo` must exactly match the existing HF path.

# Procedure

1. **Read the conversation for context.** When invoked as a sub-skill from `hf-setup` Phase 5b, the caller passes `repo_id` (Phase 3c), `repo_type` (Phase 3b), and the in-repo layout convention (Phase 5a) forward; reuse them as-is. Otherwise ask via `AskUserQuestion` for anything unclear. Authentication is verified once at Prerequisites and is not re-probed here.

2. **Enumerate the operation set.** Apply the layout convention to construct each `path_in_repo`, then list every file that will be touched, one bullet per planned op, as `add <local-path> -> <path_in_repo>`, `replace <path_in_repo> with <local-path>`, `delete <path_in_repo>`, `copy <src_path_in_repo> -> <path_in_repo>`, or `rename <old_path_in_repo> -> <new_path_in_repo>`. Show the list inline as a fenced code block. Keep multi-op uploads in one list so the user reviews the entire atomic commit at once.

3. **If a consumer manifest will pin this upload, plan sha256 capture** (`sha256sum <local-path>` through the `Bash` tool; PowerShell's equivalent is `Get-FileHash -Algorithm SHA256 <local-path>`). Otherwise skip. The hash is needed for the manifest, not for the upload, so the timing is a trade-off:
   * **Default (files under ~1 GB)**: compute now, so the hash appears in the step-5 gate render and the user can spot drift between intent and actual bytes.
   * **Large-file path (multi-GB weights the user may abort on)**: defer sha256 to after step-5 approval and before step 6. Document the deferral inline so the step-8 follow-up knows to compute then.

4. **Draft the `commit_message` inline.** One short imperative sentence summarizing the step-2 operation set (`add button_cls v2 weight`, `replace yolo11s-seg with v3 + drop v1`, `bump README + delete obsolete fp16 weights`). Hold it in chat as a fenced block. For a manifest-version bump, name the artifact and version so future readers can scan history without cross-referencing the manifest.

5. **Confirm via `AskUserQuestion` before pressing go.** Render the step-2 operation list, the step-4 message draft, and the step-3 sha256 capture (when computed) as one fenced block, then ask **upload** / **edit** / **abort**.
   * **upload**: proceed to step 6 with the listed ops and the drafted message.
   * **edit**: apply the user's free-text changes (drop an op, change a `path_in_repo`, swap a local path, rewrite the message), re-render, re-ask. Loop until approved or aborted.
   * **abort**: STOP. Nothing is uploaded.
   * If the list contains any `CommitOperationDelete`, prepend a single-line WARNING above the rendered list naming each deletion target.
   * A bare "upload" / "yes upload" / "go ahead" typed in the current turn counts as confirmation; ambiguous replies do not.

6. **Run `create_commit`** with the Reference recipe, `operations` matching the approved step-2 list verbatim and `commit_message` substituting the approved step-4 draft verbatim. One `CommitOperationAdd` per add or replace, one `CommitOperationDelete` per delete, all in the same `operations` list.

7. **Capture `info.oid` and `info.commit_url`.** The OID is the 40-character HF commit SHA; the URL is the human-clickable commit page.

8. **Follow-up.** If the consumer repo pins HF revisions via a manifest (the `hf-setup` Phase 6 pattern), sync `hf_revision` plus the relevant per-file `sha256` entries and commit the yaml in git. Otherwise the upload is complete.

# Reference: canonical recipe

```python
from huggingface_hub import HfApi, CommitOperationAdd, CommitOperationCopy, CommitOperationDelete

api = HfApi()
info = api.create_commit(
    repo_id="<owner>/<repo>",
    repo_type="model",        # or "dataset" / "space"
    operations=[
        # add or replace (same path -> replace, new path -> add)
        CommitOperationAdd(path_in_repo="<remote-path>", path_or_fileobj="<local-path>"),
        # server-side copy, LFS-stored files only (no local bytes, no re-upload)
        CommitOperationCopy(src_path_in_repo="<old-path>", path_in_repo="<new-path>"),
        # delete
        CommitOperationDelete(path_in_repo="<remote-path>"),
        # ... any number of any op type, all atomic ...
    ],
    commit_message="<concise message>",
)
print("OID:", info.oid)           # 40-char HF commit SHA -> manifest hf_revision
print("URL:", info.commit_url)    # browser-clickable commit page
```

Behaviours to know:

* **Atomicity**: if any op fails, the whole commit is rejected; HF never lands a half-applied state.
* **LFS routing is HF-side**: files matching the repo's default `.gitattributes` LFS patterns (`*.pt`, `*.bin`, `*.safetensors`, `*.onnx`, ...) auto-route to LFS storage. The consumer repo needs no `git lfs install` and no local clone.

# Reference: operation patterns

| User intent | `operations` list shape |
|---|---|
| Add or replace (any N) | `[CommitOperationAdd(...), ...]`; an existing `path_in_repo` means replace, a new path means add |
| Delete | `[CommitOperationDelete(path_in_repo=...)]` |
| Rename an LFS-stored file | `[CommitOperationCopy(src_path_in_repo=old, path_in_repo=new), CommitOperationDelete(old)]` in one list; server-side, multi-GB weights are not re-uploaded |
| Rename a non-LFS file | `[CommitOperationDelete(old), CommitOperationAdd(new, local)]` in one list; `CommitOperationCopy` only works on LFS-stored files |
| Mixed atomic release | freely mix all three op types in the same list |

`path_in_repo` is always required.

# Reference: add a weight and bump the manifest

Run this block through the `Bash` tool: `sha256sum` and the heredoc are POSIX-shell constructs. Owner, repo, and package names below are placeholders; substitute the ones resolved in the Procedure.

```bash
# 1. Hash locally first (the manifest needs it)
sha256sum /path/to/new_weight.pt
# -> abcdef1234... (record this)

# 2. Upload
python - <<'PY'
from huggingface_hub import HfApi, CommitOperationAdd
api = HfApi()
info = api.create_commit(
    repo_id="acme/foo-bot-models",
    repo_type="model",
    operations=[
        CommitOperationAdd(
            path_in_repo="new_weight.pt",
            path_or_fileobj="/path/to/new_weight.pt",
        ),
    ],
    commit_message="add new_weight v1",
)
print("OID:", info.oid)
print("URL:", info.commit_url)
PY
# -> OID: 4268c2a3b3...
# -> URL: https://huggingface.co/acme/foo-bot-models/commit/4268c2a3...

# 3. Update the consumer manifest (only if the consumer pins HF revisions)
#    Edit <package>/config/model_weights.yaml:
#      hf_revision: 4268c2a3b3190ada3545886d395efba0ffda5f5a
#      weights.<name>.sha256: abcdef1234...

# 4. Verify locally (plain `python` on Windows)
python3 <package>/scripts/fetch_weights.py
# Expect: downloaded -> ... then sha256 OK

# 5. Commit the yaml change in the consumer git repo (separate workflow)
```

# Failure modes

| Error | Cause | Action |
|---|---|---|
| `HfHubHTTPError 401` | Token missing, expired, or revoked | `hf auth login --force`; verify with `hf auth whoami --format agent` |
| `HfHubHTTPError 403` | Token scope lacks Write on this repo | Token is Read-only or scoped elsewhere; create a Write token at `https://huggingface.co/settings/tokens` |
| `HfHubHTTPError 404` | `repo_id` does not exist, or is private and the token has no access | Verify spelling and visibility; check org membership via `hf auth whoami --format agent` |
| `HfHubHTTPError 413` | Single file exceeds HF's per-file hard limit (50 GB as of this writing) | Split or compress; no workaround above the per-file limit |
| LFS storage quota exceeded | Owner's private storage past the free tier (100 GB as of this writing) | Upgrade the plan or delete unused LFS objects via Settings -> Storage |
| `FileNotFoundError` on a local path | Wrong local path | Check `path_or_fileobj`; absolute paths are safest |

All `HfHubHTTPError` instances expose `.response.status_code` and a body; surface both verbatim before suggesting a fix.

# Rationale

* **`create_commit` over CLI or git push**: it is the only path that applies N>1 files atomically, accepts delete and rename ops, and returns the commit SHA directly.
* **The gate is per-operation, not per-invocation**: a wrong `path_in_repo` on a replace does not fail, it silently creates a duplicate file, so the rendered op list is the only place that mistake is catchable before it lands.

# Hard rules

* NEVER invent `repo_id`, `path_in_repo`, or local paths. Ask via `AskUserQuestion` when unclear.
* NEVER skip the step 5 `AskUserQuestion` gate. The atomic `create_commit` is the irreversible action this skill produces. With any `CommitOperationDelete` present, the WARNING line MUST name each deletion target verbatim.
* NEVER write `commit_message` to a file on disk. It is held inline in chat and flows into `create_commit` via its Python kwarg only, mirroring the no-file discipline of `git-commit` and `git-merge`.
* NEVER run the commit before `hf auth whoami --format agent` returns a valid `user=...` line.
* NEVER display, log, or persist the HF token in chat, scratch files, or commit messages. It lives only at `~/.cache/huggingface/token` or in CI secret stores.
* NEVER paraphrase or abbreviate `info.oid`. The full 40-character SHA is the version pin downstream consumers depend on.
* NEVER recommend `git clone` + `git push` for an upload `create_commit` can do.
* For a manifest-pinned consumer (the `hf-setup` Phase 6 convention), the upload is NOT complete until the manifest is bumped with the new `hf_revision` and per-file `sha256`. Surface this as a required follow-up, not an optional one.
