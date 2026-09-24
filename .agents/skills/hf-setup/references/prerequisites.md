# Phase 0: Probe output and prerequisite fixes

Loaded from `hf-setup/SKILL.md` Phase 0. Read this file when reading the Phase 0a probe results and when rendering a Phase 0b fix. The Hard rules in `SKILL.md` remain in force throughout; in particular this skill only renders these commands for the user to run and never runs an installer or `hf auth login` itself.

## Reading probe 3 (`hf auth whoami`)

Exit 0 prints one stdout line of space-separated `key=value` pairs: `user=<name>`, plus `orgs=<a,b>` only when the account belongs to an organization, plus `endpoint=<url>` only for a non-default Hub endpoint. A non-zero exit means not logged in: stderr reads `Error: Not logged in` when no token is cached, or contains `Invalid user token` when the cached or `HF_TOKEN` token is rejected. `HF_HUB_DISABLE_UPDATE_CHECK=1` suppresses the CLI's once-a-day `Hint: A new version ...` stderr line, which otherwise prints before the result.

`--format` accepts `auto|human|agent|json|quiet`, and the default `auto` switches between `human` and `agent` depending on the environment. Pin it to `agent` so the shape does not change between the user's shell and a captured shell subprocess. Read the user name and org list out of that output rather than matching an exact string; if the shape ever surprises you, re-run with `--format json` and parse that instead of guessing.

## Phase 0b fixes per unchecked box

* **`hf` CLI missing** (`hf-missing`): the CLI ships inside the `huggingface_hub` library; recommend `pip install -U huggingface_hub` inside whichever virtualenv or conda env the user wants it in. For a system Python that refuses, suggest `pipx install huggingface_hub` or `uv tool install huggingface_hub`. The CLI also ships as a standalone install (`curl -LsSf https://hf.co/cli/install.sh | bash`) and as `brew install hf`; those provide the CLI only, so the library box still needs its own fix. After install, ask the user to confirm, then re-run probe 0a.
* **`huggingface_hub` lib missing** (`lib-missing`): same `pip install -U huggingface_hub`, into the interpreter the consumer code will use. The Python API is what `hf-upload`, `hf-download`, and the scaffolded `fetch_weights.py` all import; missing it blocks Phase 5 and Phase 6 (a standalone or brew `hf` CLI keeps working without it).
