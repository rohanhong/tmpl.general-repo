# Rationale

Loaded from `hf-setup/SKILL.md`. Read this file when the user questions one of the skill's defaults. The Hard rules in `SKILL.md` remain in force throughout.

* **Two-token split**: prevents leaked deploy credentials from also being write-capable. Minor extra setup, large reduction in blast radius.
* **Apache-2.0 default for ML weights**: the patent grant matters more often than people expect when artifacts end up in commercial systems.
* **Per-module HF repos** (`<project>-<module>-models`) over one giant `<project>-models`: smaller diff surface, independent versioning, finer access control, and one bad commit in one module does not pollute other modules' history.
* **Manifest with full SHA plus per-file sha256** over branch tags or short SHAs: branches move, sha256 is immutable, drift becomes detectable instead of insidious.
* **Basename-flatten on download**: decouples HF layout from on-disk conventions, so HF can reshape in-repo paths without breaking the consumer's launch files. The collision check is the price of that decoupling.
* **`hf_hub_download` to cache plus `shutil.copyfile` to target**, rather than `local_dir=`: the HF cache is shared across checkouts on the same machine, so the same file is not stored N times.
* **Fine-grained tokens over classic**: classic personal tokens read every repo the user can read.
* **`HF_HUB_DISABLE_UPDATE_CHECK=1 hf auth whoami --format agent`, read by exit status**: single-line and stable across TTY modes, so the same probe works in a non-interactive shell subprocess and in the user's shell; the variable keeps the daily update hint out of the capture.
