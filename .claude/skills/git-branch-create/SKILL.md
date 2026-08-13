---
name: git-branch-create
description: Create a short-lived branch (feature/*, bugfix/*, hotfix/*, release/*) named per the repo's .gitmessage rules and cut from the correct base, after an AskUserQuestion confirmation. Use when starting a new feature, fix, hotfix, or release, or when asked how to name a branch. Never fetches or pulls; base refreshes route to /git-pull.
---

# Goal

Create a properly-named local branch off the correct base, following the repo's `.gitmessage` branch-management spec.

# When NOT to use

* The user wants the base refreshed from origin first: route to `/git-pull <base>`, then re-run this skill.
* The user wants the new branch published: that is `git-push`.
* The user wants a long-lived line (`main`, `develop`, `support/*`): out of scope, refuse per Hard rules.

# Prerequisites

Resolve the branch name and the base before step 1, in this priority order. Whatever the source, the resulting name still passes step 5 validation and the step 7 gate.

1. **Caller-supplied**: another skill invoked this one and passed arguments, for example `git-commit` step 3f passing `<name> base=<ref>`. Take the candidate name and the base verbatim.
2. **User text in the current turn** ("start a feature branch for X", "branch off main"): parse the type, name, and base from it.
3. **Neither**: ask via `AskUserQuestion` at steps 3 and 4.

When the caller is `git-commit`'s rescue path, the supplied base is always the current HEAD, so step 6 takes the "HEAD already equals base" path and no checkout happens. Do NOT substitute `main` or `develop` for a caller-supplied base; see Hard rules.

# Procedure

Run every command in this skill through the `Bash` tool; the redirections used across this skill family are POSIX syntax and break under PowerShell.

1. **Read the spec.** Read `.gitmessage` at the repo root for the allowed branch types, the naming variant in use, and the protected-branch list. Fall back to the defaults below when it is absent.

2. **Gather state.** Run in parallel:
   * `git symbolic-ref --short -q HEAD` (current branch; empty output means detached)
   * `git branch --list` (existing local branches; avoid name collisions)
   * `git status --short` (dirty check consumed by step 6)

3. **Choose the branch type and its base.** The default base follows the `Workflow:` line in `.gitmessage`'s "Workflow Variant" section; when no variant is declared, or the line carries an unrecognized value (such as the shipped `<not recorded>` placeholder), assume `git-flow`. If the user did not say which type, ask via `AskUserQuestion`:

   | Type | Purpose | Base under `git-flow` | Base under `github-flow` / `trunk-solo` |
   |---|---|---|---|
   | `feature/*` | new functionality | `develop` | `main` |
   | `bugfix/*` | non-urgent defect fix for the next release | `develop` | `main` |
   | `hotfix/*` | urgent fix against production | `main` | `main` |
   | `release/*` | release stabilization | `develop` | `main` |

   A caller-supplied `base=` from the Prerequisites always overrides this table. `support/*` is a long-lived maintenance line for a previous major and is NOT creatable here; see Hard rules. Under `trunk-solo` branches are optional rather than mandatory, but an explicit invocation of this skill means the user wants one, so proceed normally.

4. **Choose the naming variant** per `.gitmessage`'s "Branch Naming" section:
   * Variant A: `<type>/<issue-id>-<short-desc>` (an issue tracker is the source of truth)
   * Variant B: `<type>/<scope>/<short-desc>` (work organized by module or package)
   * Variant C: `<type>/<short-desc>` (PR titles carry the context)

   Read the section's `Adopted:` line first; when it names a variant, use it. When it is `<not recorded>` or absent, infer the dominant variant from `git branch -a --list 'feature/*' 'bugfix/*' 'hotfix/*'`; if still ambiguous, ask.

5. **Validate the name** against `.gitmessage`'s "Naming Character Rules":
   * Lowercase ASCII letters, digits, and `-` only inside path segments.
   * `/` strictly as the type or scope separator.
   * No spaces, underscores, uppercase, accents, or non-ASCII.
   * Total length 60 characters or fewer.

6. **Verify the base.** Confirm it exists locally (`git rev-parse --verify <base>`).

   **Unborn stop.** On a zero-commit repository (`git symbolic-ref` names a branch but `git rev-parse --verify <base>` resolves nothing), STOP and route to `/git-commit` for the repository's first commit. Two tested reasons: no base can resolve, so `git checkout -b <name> <base>` is fatal; and the no-base form `git checkout -b <name>` "succeeds" by moving the unborn symref, which makes the original trunk cease to exist. The bootstrap commit lands on the trunk via `git-commit`'s explicit opt-in; branches come after it.
   * **HEAD already equals base**: the working tree is preserved across branch creation regardless of dirty state; no extra prompt is needed.
   * **HEAD differs from base AND `git status --short` is non-empty**: `git checkout <base>` would either carry the uncommitted edits onto the base branch (when `<base>` does not modify the same paths) or refuse outright (when it does). Both are bad surprises, so ask via `AskUserQuestion` with exactly two options:
     * **commit-first (Recommended)**: STOP and hand off to `/git-commit` so the pending edits land on the current branch; re-run this skill from step 1 afterwards.
     * **abort**: STOP. The user keeps the pending edits and decides separately.

7. **Show the plan and confirm via `AskUserQuestion`** (**create** / **abort**). Render the exact command sequence first. Proceed only on an explicit **create** (a bare "create" / "yes create" / "go ahead" typed in the current turn counts; ambiguous replies do not).
   * **HEAD already equals base**:
     ```
     git checkout -b <type>/<short-desc> <base>
     ```
   * **HEAD differs from base** (clean tree only; step 6 already STOPPED otherwise):
     ```
     git checkout <base>
     git checkout -b <type>/<short-desc> <base>
     ```

8. **Create the branch.** Execute the approved plan verbatim. Report the new branch name and the next step: make commits, then `/git-push` when ready to publish.

# Rationale

* **No fetch or pull inside this skill.** It keeps the scope to branch creation and prevents moving the base ref without a per-operation confirmation. `/git-pull <base>` carries its own gate for that.
* **No "switch anyway" option at step 6.** `git checkout --` and `git reset --hard` are forbidden by the Hard rules, and silent stashing is out of scope.
* **The step-7 gate stays even though `git branch -D` makes creation cheap to undo**, because a mistyped branch name lingers in tooling. It is the cheapest safety net against typos.

# Hard rules

* NEVER create a branch with a protected name: `main`, `develop`, or anything matching `support/*`.
* NEVER create a branch in a zero-commit repository. The step-6 unborn stop routes to `/git-commit` for the bootstrap commit first.
* NEVER substitute a different base for a caller-supplied one. A caller that hands over a dirty working tree (`git-commit` step 3f) has already chosen the only base that avoids a checkout; overriding it with `main` or `develop` forces step 6 to hand back to `/git-commit`, and the two skills ping-pong without progressing.
* NEVER `git fetch`, `git pull`, or otherwise refresh the base ref from inside this skill. Route to `/git-pull <base>`, which gates the fetch and fast-forward itself.
* NEVER discard uncommitted work to switch bases. Offer `/git-commit` first; `git reset --hard` and `git checkout --` are forbidden as shortcuts.
* NEVER skip the step 7 `AskUserQuestion`.
* NEVER push the branch. Publishing belongs to `git-push`.
* If the user's proposed name violates the naming rules, suggest a corrected version and confirm via `AskUserQuestion` before using it.
