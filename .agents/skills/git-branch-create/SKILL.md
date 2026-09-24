---
name: git-branch-create
description: Create a short-lived branch (feature/*, bugfix/*, hotfix/*, release/*) named per the repo's .gitmessage rules and cut from the correct base, after a choice-question confirmation. Use when starting a new feature, fix, hotfix, or release, or when asked how to name a branch. Never fetches or pulls; for a base refresh it suggests git-pull.
compatibility: Requires git 2.22 or later and a POSIX shell (Git Bash on Windows).
---

# Goal

Create a properly-named local branch off the correct base, following the repo's `.gitmessage` branch-management spec.

# When NOT to use

* The user wants the base refreshed from origin first: suggest `git-pull` with `<base>`, then re-run this skill.
* The user wants the new branch published: that is `git-push`.
* The user wants a long-lived line (`main`, `develop`, `support/*`): out of scope, refuse per Hard rules.

# Prerequisites

Resolve the branch name and the base before step 1, in this priority order. Whatever the source, the resulting name still passes step 5 validation and the step 7 gate.

1. **Caller-supplied**: another skill invoked this one and passed arguments, for example `git-commit` step 3f passing `<name> base=<ref>`. Take the candidate name and the base verbatim.
2. **User text in the current turn** ("start a feature branch for X", "branch off main"): parse the type, name, and base from it.
3. **Neither**: ask with a choice question at steps 3 and 4.

When the caller is `git-commit`'s rescue path, the supplied base is always the current HEAD, so step 6 takes the "HEAD already equals base" path and the dirty-tree prompt never fires (on a detached HEAD the caller passes the literal `base=HEAD`). Do NOT substitute `main` or `develop` for a caller-supplied base; see Hard rules.

# Procedure

Terms such as choice question, independent reads, invoke, and suggest follow AGENTS.md (Skill authoring); in a non-interactive session every gate ends this skill.

Run every command in this skill in a POSIX shell; the redirections used across this skill family are POSIX syntax and break under PowerShell.

1. **Read the spec.** Read `.gitmessage` at the repo root for the allowed branch types, the naming variant in use, and the protected-branch list. Fall back to the defaults below when it is absent.

2. **Gather state.** Run these independent reads:
   * `git branch --show-current` (current branch; empty output means detached)
   * `git rev-parse --verify --quiet HEAD` (empty output means the repository has no commits yet; consumed by step 6)
   * `git for-each-ref --format='%(refname)' refs/heads/ refs/remotes/origin/` (existing local and origin branches as stored; consumed by the step-5 collision check)
   * `git status --short` (dirty check consumed by step 6)

3. **Choose the branch type and its base.** The default base follows the `Workflow:` line in `.gitmessage`'s "Workflow Variant" section; when no variant is declared, or the line carries an unrecognized value (such as the shipped `<not recorded>` placeholder), assume `git-flow`. If the user did not say which type, ask with a choice question:

   | Type | Purpose | Base under `git-flow` | Base under `github-flow` / `trunk-solo` |
   |---|---|---|---|
   | `feature/*` | new functionality | `develop` | `main` |
   | `bugfix/*` | non-urgent defect fix for the next release | `develop` | `main` |
   | `hotfix/*` | urgent fix against production | `main` | `main` |
   | `release/*` | release stabilization | `develop` | `main` |

   A caller-supplied `base=` from the Prerequisites always overrides this table. `support/*` is a long-lived maintenance line for a previous major and is NOT creatable here; see Hard rules. Under `trunk-solo` branches are optional rather than mandatory, but an explicit invocation of this skill means the user wants one, so proceed normally.

4. **Choose the naming variant** per `.gitmessage`'s "Branch Naming" section:
   * Variant A: `<type>/<issue-id>-<short-desc>` (an issue tracker is the source of truth; the id is lowercased, so tracker id `PROJ-123` becomes `feature/proj-123-<short-desc>`)
   * Variant B: `<type>/<scope>/<short-desc>` (work organized by module or package)
   * Variant C: `<type>/<short-desc>` (PR titles carry the context)

   Read the section's `Adopted:` line first; when it names a variant, use it. When it is `<not recorded>` or absent, infer the dominant variant from `git branch -a --list 'feature/*' 'bugfix/*' 'hotfix/*' 'release/*' 'origin/feature/*' 'origin/bugfix/*' 'origin/hotfix/*' 'origin/release/*'` (with `-a`, a bare `feature/*` pattern matches local branches only; the `origin/` forms are what match remote-tracking branches, listed as `remotes/origin/...`); if still ambiguous, ask.

5. **Validate the name** against `.gitmessage`'s "Naming Character Rules":
   * Lowercase ASCII letters, digits, and `-` only inside path segments.
   * `/` strictly as the type or scope separator.
   * No spaces, underscores, uppercase, accents, or non-ASCII. Under Variant A this includes the issue id: suggest the lowercased form (`PROJ-123` becomes `proj-123`), never drop or reformat the id otherwise.
   * Total length 60 characters or fewer.
   * No collision. Compare the name ignoring case against the step-2 ref list: `grep -ixF -e 'refs/heads/<name>' -e 'refs/remotes/origin/<name>'` over it. An exact `refs/heads/<name>` line means the branch already exists: pick another name. Any line that differs from `refs/heads/<name>` or `refs/remotes/origin/<name>` only by case: refuse the name, because on a case-insensitive filesystem the two share one ref file (git reports `already exists` or writes into the other spelling). An exact `refs/remotes/origin/<name>` line is no collision.
   * The lowercased name is not `main` or `develop` and does not start with `support/` (see Hard rules).

6. **Verify the base.** Unless it is the literal `HEAD` (a caller passed `base=HEAD`), first require its exact spelling: `[ "$(git for-each-ref --format='%(refname)' "refs/heads/<base>")" = "refs/heads/<base>" ]` (equality, because `for-each-ref` also lists everything under a hierarchy). On a case-insensitive filesystem `rev-parse` resolves `Main` to the loose ref `main`, so it cannot prove the spelling. When the test fails but `git for-each-ref --format='%(refname:lstrip=2)' refs/heads/ | grep -ixF -e '<base>'` lists a name, STOP and report the exact spelling; if the base came from a HEAD switched to under another case (for example `git-commit` passing `Main`), suggest `git switch <exact name>` first. Then confirm the base resolves with `git rev-parse --verify --quiet <base-ref>`, where `<base-ref>` is `refs/heads/<base>` or `HEAD`. The full ref name matters: an unqualified name resolves to a same-name tag before the branch, and the new branch would silently start from the tag. When it does not resolve at all, tell the two causes apart with the step-2 `HEAD` probe; they need different answers.

   **Unborn stop.** On a zero-commit repository (`git symbolic-ref` names a branch but `git rev-parse --verify --quiet HEAD` resolves nothing), STOP and suggest `git-commit` for the repository's first commit. Two tested reasons: no base can resolve, so `git checkout -b <name> <base-ref>` is fatal; and the no-base form `git checkout -b <name>` "succeeds" by moving the unborn symref, which makes the original trunk cease to exist. The bootstrap commit lands on the trunk via `git-commit`'s explicit opt-in; branches come after it.

   **Missing base.** `HEAD` resolves but `<base>` does not: the repository has commits and only the base branch is absent locally (typical: a clone that never checked out `develop`, or the `git-flow` default applied to a repo that only has `main`). This is NOT an empty repository; do not suggest `git-commit`. STOP, report which ref is missing, then:
   * `git rev-parse --verify --quiet refs/remotes/origin/<base>` resolves: the base exists on origin only. Render `git branch --track <base> origin/<base>` for the user to run themselves (this skill never creates a protected name; see Hard rules), then re-run from step 1.
   * It does not resolve either: the declared or assumed workflow names a base this repo does not have. Suggest naming the base explicitly in the request (for example "branch off main") or fixing the `Workflow:` line in `.gitmessage` (`git-commit` step 3a and `repo-init` ask the user which variant applies and record the answer; no skill infers it, since `.gitmessage` forbids guessing).

   **Dirty-tree check** (the base resolves). HEAD equals base when the step-2 current branch name equals `<base>`, or when HEAD is detached and `<base>` is the literal `HEAD`. A different branch that merely points at the same commit does NOT count as equal.
   * **HEAD already equals base**: the working tree is preserved across branch creation regardless of dirty state; no extra prompt is needed.
   * **Ignored files**: `git status --short` hides them, and a plain `git checkout -b` silently overwrites an ignored local file (such as `.env`) that `<base>` tracks. The step-7 command carries `--no-overwrite-ignore`, so git refuses instead (`untracked working tree files would be overwritten`), creates no branch, and keeps the file; relay that error and let the user move the file.
   * **HEAD differs from base AND `git status --short` is non-empty**: `git checkout -b <name> <base-ref>` would either carry the uncommitted edits onto the new branch cut from `<base>` (when `<base>` does not modify the same paths) or refuse outright (when it does). Both are bad surprises, so ask with a choice question with exactly two options:
     * **commit-first (Recommended)**: STOP and suggest `git-commit` so the pending edits land on the current branch; re-run this skill from step 1 afterwards.
     * **abort**: STOP. The user keeps the pending edits and decides separately.

7. **Show the plan and confirm with a choice question** (**create** / **abort**). Render the exact command first. Proceed only on an explicit **create** in the current turn: choosing that option, or typing "create" / "yes create" / "go ahead", counts; ambiguous replies and earlier-turn approval do not. The plan is the same single command whether or not HEAD equals base (a differing base requires a clean tree; step 6 already STOPPED otherwise). It switches straight onto the new branch, so there is no separate `git checkout <base>`, which would also fail when `<base>` is checked out in another worktree:
   ```
   git checkout --no-overwrite-ignore -b <name> <base-ref>
   ```
   `<name>` is the full validated name in the adopted variant's shape and `<base-ref>` is the step-6 full ref (`refs/heads/<base>`, or `HEAD`).

8. **Create the branch.** Execute the approved plan verbatim. Report the new branch name and the next step: make commits, then `git-push` when ready to publish.

# Rationale

* **No fetch or pull inside this skill.** It keeps the scope to branch creation and prevents moving the base ref without a per-operation confirmation. `git-pull` with `<base>` carries its own gate for that.
* **No "switch anyway" option at step 6.** `git checkout --` and `git reset --hard` are forbidden by the Hard rules, and silent stashing is out of scope.
* **Exact names, compared ignoring case.** A case-insensitive filesystem resolves any casing to the one loose ref, so a base typed as `Main` passes `rev-parse`, and a new `Feature/X` beside `feature/x` shares its ref file; `for-each-ref` equality and case-insensitive comparison catch both.
* **`--no-overwrite-ignore`** turns git's default of overwriting ignored files into a refusal; losing a local `.env` to a tracked copy on the base is silent and unrecoverable.
* **The step-7 gate stays even though `git branch -D` makes creation cheap to undo**, because a mistyped branch name lingers in tooling. It is the cheapest safety net against typos.

# Hard rules

* NEVER create a branch with a protected name: `main`, `develop`, or anything matching `support/*`, compared ignoring case (`Main` and `Support/x` count).
* NEVER create a name that differs only by case from an existing local or origin branch, and NEVER cut from a base whose exact spelling step 6 did not confirm.
* NEVER drop `--no-overwrite-ignore` from the step-7 command.
* NEVER create a branch in a zero-commit repository. The step-6 unborn stop suggests `git-commit` for the bootstrap commit first.
* NEVER substitute a different base for a caller-supplied one. A caller that hands over a dirty working tree (`git-commit` step 3f) has already chosen the only base that avoids the step-6 dirty-tree prompt; overriding it with `main` or `develop` forces step 6 to suggest `git-commit` again, and the two skills ping-pong without progressing.
* NEVER `git fetch`, `git pull`, or otherwise refresh the base ref from inside this skill. Suggest `git-pull` with `<base>`, which gates the fetch and fast-forward itself.
* NEVER discard uncommitted work to switch bases. Offer `git-commit` first; `git reset --hard` and `git checkout --` are forbidden as shortcuts.
* NEVER skip the step 7 choice question.
* NEVER push the branch. Publishing belongs to `git-push`.
* If the user's proposed name violates the naming rules, suggest a corrected version and confirm with a choice question before using it.
