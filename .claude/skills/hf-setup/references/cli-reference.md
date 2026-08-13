# `hf` CLI cheat sheet

Loaded from `hf-setup/SKILL.md`. Read this file when rendering CLI commands for the user or probing HF state without a browser. The Hard rules in `SKILL.md` remain in force throughout.

## Old (deprecated) to new mapping

For users with old-tutorial muscle memory:

| Old | New |
|---|---|
| `huggingface-cli login` | `hf auth login` |
| `huggingface-cli whoami` | `hf auth whoami` |
| `huggingface-cli logout` | `hf auth logout` |
| `huggingface-cli repo create <name>` | `hf repos create <owner>/<name> --type <type>` |
| `huggingface-cli upload ...` | `hf upload ...` |
| `huggingface-cli download ...` | `hf download ...` |

## Most-used commands

```bash
hf auth whoami --format agent        # parseable single line: user=... orgs=...
hf auth login [--force]              # paste a token; --force forces re-login
hf repos create <owner>/<name> --type model [--private]
hf upload <repo> <local> <remote> --commit-message "..."
hf download <repo> <remote> --local-dir <dir>
```

Python API for atomic multi-file commits: see `hf-upload`. Python API for downloads: see `hf-download`.

## Probe HF state without a browser

```python
from huggingface_hub import HfApi
api = HfApi()
info = api.repo_info("<owner>/<repo>", repo_type="model", files_metadata=True)
print("private:", info.private, "HEAD:", info.sha)
for s in info.siblings:
    lfs = getattr(s, "lfs", None)
    oid = (lfs.get("sha256") if isinstance(lfs, dict)
           else getattr(lfs, "sha256", None) if lfs else None)
    print(f"  {s.rfilename}  lfs_sha256={oid}")
```

`files_metadata=True` is required to populate the LFS OID field; without it `s.lfs` is `None` even for LFS-tracked files.
