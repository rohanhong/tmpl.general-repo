---
name: hf-upload
description: Run one atomic Hugging Face Hub commit mixing adds, replaces, and deletes, then return the commit SHA and URL for version pinning. Use for "upload this to HF", "push this weight to huggingface", "replace v1 with v2 on the hub", "delete the old file on HF", or bumping a manifest-pinned revision. Gated by a choice question. For first-time HF setup use hf-setup instead.
compatibility: Requires network access to huggingface.co, a POSIX shell (Git Bash on Windows), Python with the huggingface_hub library, and the hf CLI (for the auth probe).
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
HF_HUB_DISABLE_UPDATE_CHECK=1 hf auth whoami --format agent
```

Read it by exit status. Exit 0 prints `user=<name>`, plus `orgs=<a,b,c>` only when the account belongs to an organization. A non-zero exit means not logged in (stderr `Error: Not logged in`, or `Invalid user token` for a rejected token): have the user run `hf auth login` (or `--force` if a stale token is cached). For first-time auth, suggest `hf-setup` (its Phase 4 covers token creation and login). The variable suppresses the CLI's once-a-day update hint on stderr.

Probe the Python interpreter once, the same way `hf-setup` Phase 0a does:

```bash
python3 -c 'import huggingface_hub as h; print("python3", h.__version__)' 2>/dev/null || python -c 'import huggingface_hub as h; print("python", h.__version__)' 2>/dev/null || echo lib-missing
```

The first word printed is the interpreter name that answered (POSIX systems expose `python3`, Windows installs usually only `python`, where a bare `python3` may be a Microsoft Store stub that fails). Every snippet in this skill writes that name as the placeholder `<python>`; substitute the probed name. On `lib-missing`, suggest `hf-setup` (its Phase 0b renders the install fix). When invoked from `hf-setup`, reuse its probe result instead.

Pass local paths to Python as command-line arguments (`sys.argv`), never embedded in heredoc or `-c` source text: Git Bash converts MSYS paths (`/c/...`) in arguments to native Windows programs, not inside script text, and skips arguments containing `'` or `*`, so convert each path variable right before the call with `command -v cygpath >/dev/null 2>&1 && P="$(cygpath -m "$P")"` (a no-op on macOS and Linux, where `cygpath` is absent), as the snippets below do.

The skill also needs three concrete inputs, from explicit prior context or a choice question:

1. **`repo_id`** in `<owner>/<name>` form.
2. **`repo_type`**: `model`, `dataset`, or `space`.
3. **For each operation**: the local path (for adds) and the `path_in_repo` (always). For a replace, `path_in_repo` must exactly match the existing HF path.

# Procedure

Terms such as choice question, independent reads, invoke, and suggest follow AGENTS.md (Skill authoring); in a non-interactive session every gate ends this skill.

1. **Read the conversation for context.** When invoked as a sub-skill from `hf-setup` Phase 5b, the caller passes `repo_id` (Phase 3c), `repo_type` (Phase 3b), and the in-repo layout convention (Phase 5a) forward; reuse them as-is. Otherwise ask with a choice question for anything unclear. Authentication is verified once at Prerequisites and is not re-probed here.

2. **Enumerate the operation set.** Apply the layout convention to construct each `path_in_repo`, then list every file that will be touched, one bullet per planned op, as `add <local-path> -> <path_in_repo>`, `replace <path_in_repo> with <local-path>`, `delete <path_in_repo>`, `copy <src_path_in_repo> -> <path_in_repo>`, or `rename <old_path_in_repo> -> <new_path_in_repo>`. Show the list inline as a fenced code block. Keep multi-op uploads in one list so the user reviews the entire atomic commit at once.

   `copy` and `rename` need no local bytes: current `huggingface_hub` releases copy LFS-stored sources server-side and download and re-upload regular (non-LFS) sources inside the same `create_commit`. Under each `rename` bullet, show the expansion step 6 will send (`copy` + `delete`) so the delete it implies is visible in the gate.

   **Resolve the list against the repo** (read-only) with the Reference: pre-gate checks listing snippet. Pass `del:<path>` per delete (a trailing `/` marks a folder), `src:<path>` per copy or rename source, and `dst:<path>` per add, replace, copy, or rename target. Then, per output line:
   * `INVALID`: the path is empty, `/`, or `.`, or has an empty, `.`, or `..` segment or a backslash, so it could reach the repo root or an unintended path. STOP and ask for a corrected path; never send it.
   * `EXPAND <folder> <file>`: replace the folder delete with one `delete <file>` bullet per line; step 6 sends those per-file deletes, never the folder. On `EMPTY`, drop the op and tell the user.
   * `EXISTS` on a `dst`: the op overwrites that file; mark its bullet `REPLACE` (an add becomes `replace`, a copy or rename target gets `(REPLACE existing)`).
   * `ABSENT` on a `del`, a `src`, or the `dst` of a replace: the path is wrong; ask for a correction.
   * Keep `sha` for step 6 and `private` for step 5. Any edit to the list reruns this resolution.

3. **If a consumer manifest will pin this upload, plan sha256 capture** with the portable one-liner below (lowercase hex on every platform; macOS ships no `sha256sum`). Otherwise skip.

   ```bash
   P=<local-path>
   command -v cygpath >/dev/null 2>&1 && P="$(cygpath -m "$P")"
   <python> -c 'import hashlib,sys;h=hashlib.sha256();f=open(sys.argv[1],"rb");[h.update(b) for b in iter(lambda:f.read(1<<20),b"")];print(h.hexdigest())' "$P"
   ```
 The hash is needed for the manifest, not for the upload, so the timing is a trade-off:
   * **Default (files under ~1 GB)**: compute now, so the hash appears in the step-5 gate render and the user can spot drift between intent and actual bytes.
   * **Large-file path (multi-GB weights the user may abort on)**: defer sha256 to after step-5 approval and before step 6. Document the deferral inline so the step-8 follow-up knows to compute then.

4. **Draft the `commit_message` inline.** One short imperative sentence summarizing the step-2 operation set (`add button_cls v2 weight`, `replace yolo11s-seg with v3 + drop v1`, `bump README + delete obsolete fp16 weights`). Hold it in chat as a fenced block. For a manifest-version bump, name the artifact and version so future readers can scan history without cross-referencing the manifest.

5. **Confirm with a choice question before pressing go.**

   First run the sensitive-content scan over every local file of an add or replace (Reference: pre-gate checks). This depends on the sibling `git-commit` skill: build the filename list and the value and home-path regexes from `../git-commit/SKILL.md` step 6 as `../git-commit/references/sensitive-content.md` (Commands) shows; if that skill is missing, stop and report. Match the filename list against each local and each `path_in_repo` basename. The snippet treats a file with a NUL byte in its first 64 KiB as binary and skips its content; list such files in the render as `not scanned (binary)`. On any hit, STOP and ask per file with a choice question: **keep** / **drop from the plan** / **abort**, showing the file and line numbers, never the matched text. When `private` is `False`, say the repo is PUBLIC, anyone can download the file, and Hub history keeps it after a later delete; **keep** then needs an explicit in-turn opt-in naming the file and `repo_id` (`yes, upload <file> to public <repo_id>`).

   Then render the step-2 operation list, the step-4 message draft, and the step-3 sha256 capture (when computed) as one fenced block, then ask **upload** / **edit** / **abort**.
   * **upload**: proceed to step 6 with the listed ops and the drafted message.
   * **edit**: apply the user's free-text changes (drop an op, change a `path_in_repo`, swap a local path, rewrite the message), re-render, re-ask. Loop until approved or aborted.
   * **abort**: STOP. Nothing is uploaded.
   * If the list contains any `CommitOperationDelete` (a `delete` op, each file of an expanded folder, or the old path of a `rename`), prepend a WARNING above the rendered list naming each deletion target. If any bullet is `REPLACE`, add a WARNING naming each replaced `path_in_repo`.
   * A bare "upload" / "yes upload" / "go ahead" typed in the current turn counts as confirmation; ambiguous replies do not.

6. **Run `create_commit`** with the Reference recipe, `operations` matching the approved step-2 list verbatim and `commit_message` substituting the approved step-4 draft verbatim. Map every op type: one `CommitOperationAdd` per add or replace, one `CommitOperationDelete` per delete (per expanded file, never a folder path), one `CommitOperationCopy` per copy, and for each rename the `CommitOperationCopy` + `CommitOperationDelete` pair from the operation-patterns table, all in the same `operations` list. Pass `parent_commit=<sha>` from step 2, so the commit fails instead of acting on a branch that moved after the listing; on that failure, rerun step 2 and the gate. Keep one commit to roughly 100 operations: HF recommends that ceiling, and a longer commit can hit the server's 60-second timeout while still landing server-side (see Failure modes).

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
        # add or replace (same path -> replace, new path -> add); run from a
        # heredoc, take <local-path> from sys.argv (see Prerequisites)
        CommitOperationAdd(path_in_repo="<remote-path>", path_or_fileobj="<local-path>"),
        # copy: server-side for LFS-stored sources; regular files are re-uploaded by the client
        CommitOperationCopy(src_path_in_repo="<old-path>", path_in_repo="<new-path>"),
        # delete
        CommitOperationDelete(path_in_repo="<remote-path>"),
        # ... any number of any op type, all atomic ...
    ],
    commit_message="<concise message>",
    parent_commit="<sha from step 2>",
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
| Rename (any file) | `[CommitOperationCopy(src_path_in_repo=old, path_in_repo=new), CommitOperationDelete(old)]` in one list; LFS-stored sources are copied server-side (multi-GB weights are not re-uploaded), regular files are re-uploaded by the client |
| Mixed atomic release | freely mix all three op types in the same list |

`path_in_repo` is always required.

# Reference: pre-gate checks

Listing (read-only; `<rev>` is the branch the commit targets, `main` by default). It prints `sha=<40-hex> private=<True|False>`, then one line per argument:

```bash
<python> - <owner>/<repo> <repo_type> <rev> del:<path> src:<path> dst:<path> <<'PY'
import sys
sys.stdout.reconfigure(encoding="utf-8")
from huggingface_hub import HfApi
repo_id, repo_type, rev = sys.argv[1:4]
api = HfApi()
info = api.repo_info(repo_id, repo_type=repo_type, revision=rev)
print("sha=%s private=%s" % (info.sha, info.private))
files = set(api.list_repo_files(repo_id, repo_type=repo_type, revision=info.sha))
for arg in sys.argv[4:]:
    kind, _, p = arg.partition(":")
    folder = kind == "del" and p.endswith("/")
    segs = (p[:-1] if folder else p).split("/")
    if not p or "\\" in p or any(s in ("", ".", "..") for s in segs):
        print("INVALID", arg)
    elif folder:
        hits = sorted(f for f in files if f.startswith(p))
        print("\n".join("EXPAND %s %s" % (p, f) for f in hits) or "EMPTY " + p)
    else:
        print("EXISTS" if p in files else "ABSENT", arg)
PY
```

Sensitive-content scan (POSIX shell; set `VALUE_RE` and `HOME_RE` from `git-commit` first, see step 5). It prints `BINARY <file>` or `HIT <file> <line>`, never the matched text:

```bash
for f in <local-path>...; do
  z=$(dd if="$f" bs=65536 count=1 2>/dev/null | tr -dc '\000' | wc -c)
  if [ "$z" -ne 0 ]; then echo "BINARY $f"; continue; fi
  grep -nE -e "$VALUE_RE" -e "$HOME_RE" -- "$f" | cut -d: -f1 | while read -r n; do echo "HIT $f $n"; done
done
```

`references/rationale.md` explains why these checks exist and their limits.

# Reference: add a weight and bump the manifest

Run this block in a POSIX shell: the heredoc is a POSIX-shell construct. `<python>` is the interpreter name from the Prerequisites probe, and the local path reaches Python as an argument (see Prerequisites). Owner, repo, and package names below are placeholders; substitute the ones resolved in the Procedure.

```bash
# 0. Local path, converted for native Windows Python (no-op without cygpath)
P=/path/to/new_weight.pt
command -v cygpath >/dev/null 2>&1 && P="$(cygpath -m "$P")"

# 1. Hash locally first (the manifest needs it; the step-3 one-liner)
<python> -c 'import hashlib,sys;h=hashlib.sha256();f=open(sys.argv[1],"rb");[h.update(b) for b in iter(lambda:f.read(1<<20),b"")];print(h.hexdigest())' "$P"
# -> abcdef1234... (record this)

# 2. Upload (sys.argv: local path, then the step-2 sha)
<python> - "$P" "<sha>" <<'PY'
import sys
from huggingface_hub import HfApi, CommitOperationAdd
api = HfApi()
info = api.create_commit(
    repo_id="acme/foo-bot-models",
    repo_type="model",
    operations=[
        CommitOperationAdd(
            path_in_repo="new_weight.pt",
            path_or_fileobj=sys.argv[1],
        ),
    ],
    commit_message="add new_weight v1",
    parent_commit=sys.argv[2],
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

# 4. Verify locally
<python> <package>/scripts/fetch_weights.py
# Expect: downloaded -> ... then sha256 OK

# 5. Commit the yaml change in the consumer git repo (separate workflow)
```

# Failure modes

| Error | Cause | Action |
|---|---|---|
| `HfHubHTTPError 401` | Token missing, expired, or revoked | `hf auth login --force`; verify with the Prerequisites `whoami` probe |
| `HfHubHTTPError 403` | Token scope lacks Write on this repo | Token is Read-only or scoped elsewhere; create a Write token at `https://huggingface.co/settings/tokens` |
| `HfHubHTTPError 404` | `repo_id` does not exist, or is private and the token has no access | Verify spelling and visibility; check org membership via the Prerequisites `whoami` probe |
| `HfHubHTTPError 413` | Single file exceeds HF's per-file hard limit (500 GB as of this writing; HF recommends under 200 GB per file, see `https://huggingface.co/docs/hub/storage-limits`) | Split or compress; no workaround above the per-file limit |
| Timeout on a commit with many operations | More than roughly 100 ops in one `create_commit`; the server may still complete it after the client times out | Check the repo's commit list before retrying; split into commits of about 100 ops, or use `HfApi().upload_large_folder` for a whole folder |
| LFS storage quota exceeded | Owner's private storage past the free tier (100 GB as of this writing) | Upgrade the plan or delete unused LFS objects via Settings -> Storage |
| `HfHubHTTPError` on a commit that passed `parent_commit` | The branch moved after the step-2 listing | Rerun step 2 and the step-5 gate; never drop `parent_commit` to force it through |
| `FileNotFoundError` on a local path | Wrong local path | Check `path_or_fileobj`; absolute paths are safest |

All `HfHubHTTPError` instances expose `.response.status_code` and a body; surface both verbatim before suggesting a fix.

# Rationale

`references/rationale.md` holds the reasons behind the design, the pre-gate checks, and their limits.

# Hard rules

* NEVER invent `repo_id`, `path_in_repo`, or local paths. Ask with a choice question when unclear.
* NEVER skip the step 5 choice-question gate. The atomic `create_commit` is the irreversible action this skill produces. With any `CommitOperationDelete` present, a rename's old path and each expanded folder file included, the WARNING MUST name each deletion target verbatim; with any `REPLACE` bullet, it MUST name each replaced path.
* NEVER send a `CommitOperationDelete` for a folder path (trailing `/`) or for any path step 2 marked `INVALID`.
* NEVER upload a file with a sensitive-content hit without that file's step-5 answer (an explicit in-turn opt-in when the repo is public).
* NEVER add an AI tool, model, agent, or vendor attribution to the `commit_message`.
* NEVER write `commit_message` to a file on disk. It is held inline in chat and flows into `create_commit` via its Python kwarg only, mirroring the no-file discipline of `git-commit` and `git-merge`.
* NEVER run the commit before the Prerequisites `whoami` probe exits 0 with a `user=...` line.
* NEVER display, log, or persist the HF token in chat, scratch files, or commit messages. It lives only in the HF token files (`$HF_HOME/token`, default `~/.cache/huggingface/token`, relocatable via `HF_TOKEN_PATH`, plus the `stored_tokens` file beside it) or in CI secret stores.
* NEVER paraphrase or abbreviate `info.oid`. The full 40-character SHA is the version pin downstream consumers depend on.
* NEVER recommend `git clone` + `git push` for an upload `create_commit` can do.
* For a manifest-pinned consumer (the `hf-setup` Phase 6 convention), the upload is NOT complete until the manifest is bumped with the new `hf_revision` and per-file `sha256`. Surface this as a required follow-up, not an optional one.
