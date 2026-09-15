---
name: py-env-setup
description: Create or adopt a Python environment for the current repo: a dedicated conda env named <repo>_env_py3XX by default, with the Python version probed at runtime and chosen by the user, a root-level environment.yml as the reproducible spec, and pip dependencies wired in from a root-level requirements.txt when the project installs packages that way; can instead reuse an existing machine-wide env. Use for "set up a python env", "create a conda env for this repo", "install requirements.txt into a fresh env", "this project needs python", or the repo-init step-6f handoff. Probes read-only first; every mutation is gated; never touches shell profiles or existing envs.
---

# Goal

Give the current repository a working, reproducible Python environment: either a dedicated conda env whose spec lives at the repo root as `environment.yml` (the community-standard location, so any machine can recreate it with one command and tools like Binder or IDEs auto-detect it), with the project's pip dependencies flowing in from a root-level `requirements.txt` when the project installs packages that way, or an explicit adoption of an env that already exists on this machine.

# When NOT to use

* The project does not need Python: nothing here applies; say so and stop.
* The user wants extra packages installed into an env that already exists: that is dependency management, not env setup; render the `conda install` / `pip install` command for the user and stop. Installing the repo's own `requirements.txt` into the env this run creates IS in scope (steps 6 and 7), because it is part of building that env.
* The user wants venv/uv/poetry instead of conda: valid tools, but out of this skill's scope; render the equivalent one-liner for their chosen tool and stop rather than guessing a full workflow.

# Procedure

Run every command in this skill through the `Bash` tool; the redirections and heredocs used across this skill family are POSIX syntax and break under PowerShell.

Every file path in this skill means the repo toplevel, not the session's working directory: `environment.yml` and `requirements.txt` are the root-level files even when the session started in a subdirectory. Shell state does not persist between Bash calls, so each command that touches a file recomputes `ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"` and uses `"$ROOT/<file>"`.

1. **Probe, read-only.** Run in parallel:
   * `conda --version 2>/dev/null || echo conda-missing`
   * `conda env list 2>/dev/null` (existing envs, consumed by steps 3 and 5).
   * `ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; basename "$ROOT"; ls "$ROOT/environment.yml" "$ROOT/requirements.txt" 2>/dev/null` (repo name, fuel for the env name; spec already present at the root?; pip requirements present at the root? That last answer picks the step-6 spec variant.)

   **conda missing in Bash**: before concluding it is absent, retry through PowerShell: `powershell.exe -NoProfile -Command "conda --version"`. A hit means conda exists but is initialized only for PowerShell/cmd (common on Windows); say so and run every later conda command in this skill through the `PowerShell` tool instead of `Bash`. Only when both probes miss, render the install pointer for the user to run themselves (recommend Miniforge, `https://conda-forge.org/download/`, which defaults to the conda-forge channel) and STOP. Never install conda, and never run its installer, from this skill.

   **Spec already present**: read it, render its `name:`, its `python=` pin, and whether its `pip:` block references `requirements.txt`. When it does and the root has no `requirements.txt`, STOP before any solve: pip would fail only after the full conda download, so the user adds the file or edits the spec first. Otherwise ask whether this run should recreate that env (`conda env create -f environment.yml`, skip to step 7 with the existing spec) or redesign the spec (continue at step 2). Never silently overwrite a hand-written spec.

2. **Confirm the need.** When the repo shows no Python footprint (no `*.py`, `pyproject.toml`, `requirements.txt`, or `environment.yml` anywhere) AND the user did not explicitly ask for Python, surface that observation and confirm before proceeding; "possible future need" is a valid answer, but it must be the user's answer.

3. **Choose the strategy** via `AskUserQuestion`:
   * **dedicated env (Recommended)**: a fresh conda env owned by this repo, named per step 5, spec committed at the root `environment.yml`, with the root `requirements.txt` wired into it when the project has one (step 6). Isolation from other projects; reproducible on any machine.
   * **reuse an existing env**: pick one from the step-1 `conda env list` output (options from the list, free text for others). The env stays shared property: this skill writes no `environment.yml` for it, because a spec that names a shared machine-wide env would misrepresent ownership and break `conda env create` reproducibility, and it installs nothing into it. When step 1 found a `requirements.txt`, render `conda run --live-stream -n <env-name> python -m pip install -r requirements.txt` for the user to run themselves. An entry that `conda env list` shows with an empty name column (created with `-p`) is addressed with `-p <prefix>` in place of `-n <env-name>`, here and in step 8. Skip steps 4 to 7, verify per step 8, then report per step 9 (minus the spec parts).
   * **abort**: STOP; nothing has been created.

4. **Pick the Python version.** Do NOT hardcode one in this skill; it would rot. Probe what is actually available (`conda search "python>=3.10" 2>/dev/null | tail -n 30` or equivalent), then ask via `AskUserQuestion` with 2 to 4 minor versions as options:
   * Mark as recommended the newest minor that is mature enough for broad ecosystem support (roughly: released at least ~6 months ago with wide package availability), not the newest available.
   * Include the newest available as a separate option, labeled with the tradeoff (bleeding edge; some packages may lag).
   * The user's choice wins, including a custom-typed version.

5. **Name the env**: `<repo>_env_py3XX` (for example `foo-bot_env_py312`), where `<repo>` is the step-1 basename with characters conda forbids in env names (`/`, space, `:`, `#`) replaced by `-`. If the name already exists in `conda env list`, say so and ask for an alternative or the reuse path; NEVER remove or overwrite the existing env.

6. **Write the spec.** The step-1 probe picks the variant: a root `requirements.txt` present means the pip variant, absent means the conda variant. Render the full proposed root-level `environment.yml` inline (for the pip variant on a repo that has no `requirements.txt` yet, also the proposed header-only `requirements.txt`: one comment line, no packages), then gate via `AskUserQuestion`: **write** (the rendered variant; the recommended option) / **switch variant** (re-render the other variant, then ask again; switching to pip on a repo without `requirements.txt` adds the header-only file to the same write) / **abort** (STOP; nothing has been written). When `environment.yml` already exists the option reads **edit** instead of **write**, the change goes through `Edit` preserving unrelated entries, and the diff is rendered first. An existing `requirements.txt` is only referenced, never rewritten.

   Conda variant:
   ```yaml
   name: <env-name>
   channels:
     - conda-forge
   dependencies:
     - python=3.XX
     # add project packages here; pip-only deps go under a "- pip:" block
   ```
   pip variant:
   ```yaml
   name: <env-name>
   channels:
     - conda-forge
   dependencies:
     - python=3.XX
     - pip
     # conda-only packages go here; everything else lives in requirements.txt
     - pip:
         - -r requirements.txt
   ```
   On the pip variant conda runs pip in the directory of the file it was given, provided that directory is writable, so the `-r requirements.txt` reference resolves whatever the caller's working directory is, and `pip install -r requirements.txt` keeps working for venv users, CI images, and Dockerfiles. The two lists coexist: conda-only packages (CUDA toolkits, geospatial stacks, anything without a wheel) go under `dependencies:`, everything else in `requirements.txt`. A `pyproject.toml` project joins the pip variant by listing `-e .` inside `requirements.txt` when the user asks for it; the spec itself always reads `-r requirements.txt`. `conda-forge` over `defaults`: community-maintained, no commercial-use licensing surprises, and the same channel Miniforge ships with. Keep the initial spec minimal; dependency growth belongs to the project's own commits, in `requirements.txt` on the pip variant.

7. **Create the env.** Render the exact command, then ask via `AskUserQuestion` (**create** / **abort**):
   ```
   conda env create -f environment.yml
   ```
   (From the repo root a bare `conda env create` finds the file on its own; the explicit `-f` keeps the rendered command unambiguous.) Run it through `Bash` as `conda env create -f "$ROOT/environment.yml"` with a generous timeout (solver plus downloads can take minutes); when the solve may exceed the tool's 10-minute ceiling (slow network, heavy spec), run it in the background instead and report once it completes. On failure, surface conda's output verbatim and stop; do not fall back to a different channel or version silently, and never add `-y`/`--yes` (or `--force` on older conda) to the command: on a prefix that already exists that flag deletes the env without asking, and a fresh name needs no confirmation flag at all. On the pip variant a pip failure happens after the conda solve, so the env usually exists but is incomplete: confirm with `conda env list`, say so, and render the pip-only retry for the user to run once they have fixed `requirements.txt`, `conda run --live-stream -n <env-name> python -m pip install -r requirements.txt` (`conda env update -f environment.yml` also works but re-solves the whole spec first). Do not remove anything.

8. **Verify.** `conda run -n <env-name> python --version` (`-p <prefix>` for a nameless env) must print the chosen version. For an env this run created on the pip variant, also run `conda run -n <env-name> python -m pip check`, which exits non-zero when the installed set has unmet or conflicting requirements; never run it against a reused env, which this skill did not modify. Mismatch or error: surface verbatim.

9. **Report.** Show the env name, the verified Python version, the spec path (plus `requirements.txt` on the pip variant), the activation command (`conda activate <env-name>`), and the follow-ups: commit `environment.yml` (and a newly created `requirements.txt`) via `/git-commit` when ready, and evolve dependencies by editing the yml, or `requirements.txt` on the pip variant, then running `conda env update -f environment.yml`, which re-runs the `pip:` block too. On the reuse path, report only the env name, verified version, activation command, and the rendered pip command when a `requirements.txt` exists; there is no spec to commit.

# Rationale

* **Dedicated env per repo as the default**: cross-project contamination is the single most common conda failure mode; the `<repo>_env_py3XX` name makes ownership and Python line visible in `conda env list` at a glance.
* **Spec at the repo root as `environment.yml`**: the community-standard location; a bare `conda env create` finds it, and Binder, repo2docker, and IDE env detection auto-discover it, none of which works from a subdirectory. The env itself is machine-local and disposable; the yml is the durable artifact. The reuse path deliberately writes no spec, because a shared env is not this repo's to describe.
* **`requirements.txt` referenced from the spec, never copied into it**: pip users, CI images, and Dockerfiles already read that file with `pip install -r requirements.txt`, and conda's `pip:` block accepts the same `-r` reference, so one list serves both worlds. Duplicating the packages into the yml would create two sources of truth that drift on the first edit.
* **Spec variant picked by the probe, overridable at the gate**: whether the root has a `requirements.txt` already answers how the project installs packages, so the skill renders that answer instead of asking a separate question, and the step-6 gate's **switch variant** option covers the exceptions (a pip project whose file does not exist yet, or a project that keeps an unrelated `requirements.txt`).
* **Version probed and asked, never pinned in this skill**: any number written here would be stale within a release cycle; the recommendation logic (mature minor over newest) survives releases.
* **conda-forge channel**: avoids the Anaconda `defaults` channel's commercial licensing terms and matches the Miniforge install this skill recommends.

# Hard rules

* NEVER install conda, run its installer, or modify shell profiles (`conda init`, `.bashrc`, PowerShell profiles). Environment-manager installation is the user's, done outside this skill.
* NEVER remove, rename, recreate, or install packages into an existing env, and NEVER pass `-y`/`--yes` (or `--force` on older conda) to `conda env create`, since on an existing prefix it deletes that env silently. A name collision means ask, not overwrite; the reuse path adopts an env as-is, and a `requirements.txt` install into it is rendered for the user, not run. The only package installs this skill runs are the ones `conda env create` performs while building the env this run creates.
* NEVER hardcode a Python version in this skill or pick one for the user. Probe, recommend with the stated maturity heuristic, and let the user decide.
* NEVER write the env spec anywhere other than the root `environment.yml`, and NEVER `Write` over an existing spec or an existing `requirements.txt`; redesigns go through `Edit` with the diff rendered first, and an existing `requirements.txt` is only referenced, never rewritten.
* NEVER add packages to `environment.yml` or `requirements.txt` beyond what the user named. The Python pin, plus on the pip variant the `pip` entry and the `-r requirements.txt` reference, is the correct initial state.
* NEVER proceed past a failed create or verify; surface conda's output verbatim and let the user decide.
* This skill does NOT commit. Landing `environment.yml` and `requirements.txt` in git belongs to `/git-commit`.
