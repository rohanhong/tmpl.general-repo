---
name: py-env-setup
description: Create or adopt a Python environment for the current repo: a dedicated conda env named <repo>_env_py3XX by default, with the Python version probed at runtime and chosen by the user, and a root-level environment.yml as the reproducible spec; can instead reuse an existing machine-wide env. Use for "set up a python env", "create a conda env for this repo", "this project needs python", or the repo-init step-6f handoff. Probes read-only first; every mutation is gated; never touches shell profiles or existing envs.
---

# Goal

Give the current repository a working, reproducible Python environment: either a dedicated conda env whose spec lives at the repo root as `environment.yml` (the community-standard location, so any machine can recreate it with one command and tools like Binder or IDEs auto-detect it), or an explicit adoption of an env that already exists on this machine.

# When NOT to use

* The project does not need Python: nothing here applies; say so and stop.
* The user wants packages installed into an existing env: that is dependency management, not env setup; render the `conda install` / `pip install` command for the user and stop.
* The user wants venv/uv/poetry instead of conda: valid tools, but out of this skill's scope; render the equivalent one-liner for their chosen tool and stop rather than guessing a full workflow.

# Procedure

Run every command in this skill through the `Bash` tool; the redirections and heredocs used across this skill family are POSIX syntax and break under PowerShell.

1. **Probe, read-only.** Run in parallel:
   * `conda --version 2>/dev/null || echo conda-missing`
   * `conda env list 2>/dev/null` (existing envs, consumed by steps 3 and 5).
   * `ls environment.yml 2>/dev/null` (spec already present at the repo root?).
   * `basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"` (repo name, fuel for the env name).

   **conda missing in Bash**: before concluding it is absent, retry through PowerShell: `powershell.exe -NoProfile -Command "conda --version"`. A hit means conda exists but is initialized only for PowerShell/cmd (common on Windows); say so and run every later conda command in this skill through the `PowerShell` tool instead of `Bash`. Only when both probes miss, render the install pointer for the user to run themselves (recommend Miniforge, `https://conda-forge.org/download/`, which defaults to the conda-forge channel) and STOP. Never install conda, and never run its installer, from this skill.

   **Spec already present**: read it, render its `name:` and `python=` pin, and ask whether this run should recreate that env (`conda env create -f environment.yml`, skip to step 7 with the existing spec) or redesign the spec (continue at step 2). Never silently overwrite a hand-written spec.

2. **Confirm the need.** When the repo shows no Python footprint (no `*.py`, `pyproject.toml`, `requirements.txt`, or `environment.yml` anywhere) AND the user did not explicitly ask for Python, surface that observation and confirm before proceeding; "possible future need" is a valid answer, but it must be the user's answer.

3. **Choose the strategy** via `AskUserQuestion`:
   * **dedicated env (Recommended)**: a fresh conda env owned by this repo, named per step 5, spec committed at the root `environment.yml`. Isolation from other projects; reproducible on any machine.
   * **reuse an existing env**: pick one from the step-1 `conda env list` output (options from the list, free text for others). The env stays shared property: this skill writes no `environment.yml` for it, because a spec that names a shared machine-wide env would misrepresent ownership and break `conda env create` reproducibility. Skip steps 4 to 7, verify per step 8, then report per step 9 (minus the spec parts).
   * **abort**: STOP; nothing has been created.

4. **Pick the Python version.** Do NOT hardcode one in this skill; it would rot. Probe what is actually available (`conda search "python>=3.10" 2>/dev/null | tail -n 30` or equivalent), then ask via `AskUserQuestion` with 2 to 4 minor versions as options:
   * Mark as recommended the newest minor that is mature enough for broad ecosystem support (roughly: released at least ~6 months ago with wide package availability), not the newest available.
   * Include the newest available as a separate option, labeled with the tradeoff (bleeding edge; some packages may lag).
   * The user's choice wins, including a custom-typed version.

5. **Name the env**: `<repo>_env_py3XX` (for example `foo-bot_env_py312`), where `<repo>` is the step-1 basename with characters conda forbids in env names (`/`, space, `:`, `#`) replaced by `-`. If the name already exists in `conda env list`, say so and ask for an alternative or the reuse path; NEVER remove or overwrite the existing env.

6. **Write the spec.** Render the full proposed root-level `environment.yml` inline, then gate: **write** / **abort** for a new file (`Write`), **edit** / **abort** when the file exists (`Edit`, preserving unrelated entries):
   ```yaml
   name: <env-name>
   channels:
     - conda-forge
   dependencies:
     - python=3.XX
     # add project packages here; pip-only deps go under a "- pip:" block
   ```
   `conda-forge` over `defaults`: community-maintained, no commercial-use licensing surprises, and the same channel Miniforge ships with. Keep the initial spec minimal; dependency growth belongs to the project's own commits.

7. **Create the env.** Render the exact command, then ask via `AskUserQuestion` (**create** / **abort**):
   ```
   conda env create -f environment.yml
   ```
   (From the repo root a bare `conda env create` finds the file on its own; the explicit `-f` keeps the rendered command unambiguous.)
   Run it through `Bash` with a generous timeout (solver plus downloads can take minutes); when the solve may exceed the tool's 10-minute ceiling (slow network, heavy spec), run it in the background instead and report once it completes. On failure, surface conda's output verbatim and stop; do not retry with `--force`, and do not fall back to a different channel or version silently.

8. **Verify.** `conda run -n <env-name> python --version` must print the chosen version. Mismatch or error: surface verbatim.

9. **Report.** Show the env name, the verified Python version, the spec path, the activation command (`conda activate <env-name>`), and the two follow-ups: commit `environment.yml` via `/git-commit` when ready, and evolve dependencies by editing the yml then running `conda env update -f environment.yml`. On the reuse path, report only the env name, verified version, and activation command; there is no spec to commit.

# Rationale

* **Dedicated env per repo as the default**: cross-project contamination is the single most common conda failure mode; the `<repo>_env_py3XX` name makes ownership and Python line visible in `conda env list` at a glance.
* **Spec at the repo root as `environment.yml`**: the community-standard location; a bare `conda env create` finds it, and Binder, repo2docker, and IDE env detection auto-discover it, none of which works from a subdirectory. The env itself is machine-local and disposable; the yml is the durable artifact. The reuse path deliberately writes no spec, because a shared env is not this repo's to describe.
* **Version probed and asked, never pinned in this skill**: any number written here would be stale within a release cycle; the recommendation logic (mature minor over newest) survives releases.
* **conda-forge channel**: avoids the Anaconda `defaults` channel's commercial licensing terms and matches the Miniforge install this skill recommends.

# Hard rules

* NEVER install conda, run its installer, or modify shell profiles (`conda init`, `.bashrc`, PowerShell profiles). Environment-manager installation is the user's, done outside this skill.
* NEVER remove, rename, `--force`-recreate, or install packages into an existing env. A name collision means ask, not overwrite; the reuse path adopts an env as-is.
* NEVER hardcode a Python version in this skill or pick one for the user. Probe, recommend with the stated maturity heuristic, and let the user decide.
* NEVER write the env spec anywhere other than the root `environment.yml`, and NEVER `Write` over an existing spec; redesigns go through `Edit` with the diff rendered first.
* NEVER add packages to the spec beyond what the user named. An empty dependency list plus the Python pin is the correct initial state.
* NEVER proceed past a failed create or verify; surface conda's output verbatim and let the user decide.
* This skill does NOT commit. Landing `environment.yml` in git belongs to `/git-commit`.
