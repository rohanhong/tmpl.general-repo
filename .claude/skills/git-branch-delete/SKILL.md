---
name: git-branch-delete
description: Delete a merged short-lived branch locally, and optionally its origin counterpart, after verifying it is fully contained in its integration base. Use for "delete this branch", "clean up feature/foo", "remove merged branches", or post-merge tidying. Refuses protected names, the current HEAD, and unmerged branches without an explicit in-turn opt-in.
---

# Goal

Remove a short-lived branch that has served its purpose, locally and optionally on `origin`, after proving the commits it carries are already reachable from its integration base. The skill deletes branch refs only; it never touches commits, the working tree, or the index.

# When NOT to use

* The branch has not been integrated yet: `git-merge` first, then return here.
* The user wants the commits gone, not just the ref: out of scope. Deleting a branch does not remove commits, and history rewriting is forbidden across this skill family.
* The branch is `main`, `develop`, or matches `support/*`: refuse per Hard rules.

# Prerequisites

Resolve these before step 1:

1. **Target branch name(s)**. Named by the user in the current turn, or handed over by `git-merge`'s success report. Never infer from "the branch I was just on".
2. **Integration base**: the branch the target must already be merged into. Derive it from the `Workflow:` line in `.gitmessage`'s "Workflow Variant" section: under `git-flow`, `feature/*` and `bugfix/*` integrate into `develop` while `hotfix/*` and `release/*` integrate into `main`; under `github-flow` and `trunk-solo` every short-lived type integrates into `main`. When no variant is declared, or the line carries an unrecognized value (such as the shipped `<not recorded>` placeholder), assume `git-flow`. Ask via `AskUserQuestion` when the mapping is still ambiguous.
3. **Scope**: local only, or local plus `origin`. Never assume; step 6 asks.

# Procedure

Run every command in this skill through the `Bash` tool; the redirections used across this skill family are POSIX syntax and break under PowerShell.

1. **Refuse protected and current-HEAD targets.**
   * If the target is `main`, `develop`, or matches `support/*`, STOP.
   * Run `git symbolic-ref --short -q HEAD`. If the target equals the current branch, STOP and tell the user to switch to another branch first. Do NOT check out anything to enable the deletion.

2. **Gather state.** Run in parallel:
   * `git rev-parse --verify --quiet <branch>` (exists locally; empty output means it does not).
   * `git rev-parse --verify --quiet origin/<branch>` (remote counterpart, may be empty).
   * `git rev-parse --verify --quiet origin/<base>` (remote-tracking ref of the base, may be empty).
   * `git log <base>..<branch> --oneline` (commits NOT yet in the base; empty means fully merged).
   * `git log origin/<base>..<branch> --oneline 2>/dev/null` (commits NOT yet in the base's remote tip; meaningful only when `origin/<base>` exists).
   * `git log origin/<branch>..<branch> --oneline 2>/dev/null` (commits never pushed; read it ONLY when `origin/<branch>` resolved above. Without that ref the range exits 128 and prints nothing, and that empty output must not be mistaken for "everything pushed").
   * `git rev-parse --abbrev-ref --symbolic-full-name <branch>@{upstream} 2>/dev/null` (the target's configured upstream, for example `origin/<branch>`; exit 128 with no output means none. This is the ref git's `-d` safety valve compares against, consumed by step 3).
   * `git rev-parse <branch>` (tip SHA, recorded for the recovery hint in step 8).

   If the branch does not exist locally, surface that and stop.

3. **Classify the target.**
   * **Fully merged** (`git log <base>..<branch>` empty): safe. `git branch -d` will succeed on its own.
   * **Merged upstream only** (`git log <base>..<branch>` non-empty BUT `origin/<base>` exists and `git log origin/<base>..<branch>` is empty): every commit is already reachable from the base's remote tip; only the local `<base>` is behind. This is NOT an unmerged branch, so do not route it into the step-5 force-delete opt-in. STOP and recommend `/git-pull <base>` first; after that fast-forward, re-run this skill and the plain `-d` path succeeds.
   * **Unmerged** (`git log <base>..<branch>` non-empty and the upstream-only case does not apply): the listed commits exist ONLY on this branch. Deleting the ref leaves them reachable only via reflog, which expires. Requires the step-5 opt-in.
   * **Unpushed** (`origin/<branch>` does not resolve, OR `git log origin/<branch>..<branch>` is non-empty): surface the count alongside the classification. A branch with no remote counterpart was never pushed at all, so every commit it holds beyond `<base>` exists only in this clone; count those (`git log <base>..<branch>`) as the unpushed set. Unpushed plus unmerged is the most destructive combination and MUST be called out explicitly, and the never-pushed form is the worst of it because no other clone has a copy.
   * **Safety-valve prediction** (fully merged targets only). `git branch -d` does NOT check containment in `<base>`: it checks the branch's configured upstream when one exists, otherwise the current HEAD, and warns when the two disagree. Take the step-2 upstream (else `HEAD`) as the valve reference and run `git merge-base --is-ancestor <branch> <reference>` (exit 0 means contained).
     * **Contained**: `-d` passes; the step-6 plan uses `-d`.
     * **Not contained**: `-d` would refuse with "not fully merged" even though containment in `<base>` is proven. Two common shapes: HEAD is an unrelated branch and the target has no upstream; or the target's last commits were merged into `<base>` locally and never pushed, so its upstream lags its tip. The step-6 plan uses `-D` for this case and carries a reason line naming the reference and the proof (`git log <base>..<branch>` empty). Do NOT check out `<base>` to make `-d` pass; see Hard rules.

4. **Render the findings inline** before asking anything:
   ```
   branch  : <branch>            tip <short-sha>
   base    : <base>
   merged  : yes | upstream only (contained in origin/<base>; local <base> behind) | no (<n> commit(s) not in <base>)
   pushed  : yes | no (<n> commit(s) not on origin) | never pushed (<n> commit(s) beyond <base> exist only here)
   remote  : origin/<branch> exists | absent
   valve   : -d passes (<reference> contains tip) | -D required (<reference> does not contain tip; merged into <base> verified)
   ```
   When not fully merged, list the unmerged commits (`git log <base>..<branch> --oneline`, capped at 10 with an overflow count) so the user sees exactly what the ref is holding.

5. **Unmerged opt-in.** If the branch is not fully merged, require an explicit opt-in typed by the user in the current turn ("yes, force delete `<branch>`", or the user typing `-D` themselves). Prior-turn approval does NOT carry over. Without one, STOP and recommend `/git-merge` first.

6. **Ask for the deletion scope and confirm.** Render the exact commands, then ask via `AskUserQuestion` with three options:
   * **local only**: `git branch -d <branch>` (or `-D` when step 5 was opted into, or when the step-3 valve prediction says `-d` would refuse a fully merged branch; the plan renders the reason line above the command either way).
   * **local and remote**: the above, then `git push origin --delete <branch>`.
   * **abort**: STOP. Nothing is deleted.

   A bare "delete" is NOT enough to select the remote scope; remote deletion must be chosen explicitly, because it affects every other clone.

7. **Execute** the approved commands in the displayed order, local first. If the local delete fails, do NOT proceed to the remote delete. Capture output verbatim.

8. **Report.** Show the deleted branch name, the tip SHA recorded in step 2, and the recovery command `git branch <branch> <tip-sha>` (valid until the reflog entry expires). State whether the remote counterpart was deleted or left in place.

# Rationale

* **Remote deletion lives here, not in `git-push`.** `git-push` is scoped to publishing commits and refuses anything that is not a fast-forward of content; `git push origin --delete` publishes an absence and belongs with the rest of branch lifecycle management. Keeping it here also means one skill owns the merged-check that makes the deletion safe.
* **Two-stage consent** (step 5 opt-in for unmerged, step 6 scope choice) rather than one gate: the two decisions have different blast radii. Losing unmerged local commits is recoverable from the reflog for a while; deleting the remote ref affects collaborators immediately.
* **The tip SHA is printed before deletion, not after.** After `git branch -d` the name is gone, and a user who realises the mistake a minute later needs the SHA, not a reflog lecture.
* **`-D` on a verified-merged branch is not an escalation.** git's `-d` valve compares against the upstream or HEAD, never against the integration base, so it answers a different question than this skill asks. Step 3's `git log <base>..<branch>` is the stronger check; once it is empty, the valve can only produce a false refusal. Predicting the valve up front keeps an actual `-d` refusal meaningful: it means a ref moved between the gather and the delete, not that the classification was wrong.

# Hard rules

* NEVER delete `main`, `develop`, or anything matching `support/*`, locally or on origin, under any opt-in. This is independent of the workflow variant: `trunk-solo` declaring "Protected: none" relaxes who may commit to a trunk, not whether the trunk may be destroyed.
* NEVER delete the current HEAD, and NEVER check out another branch to make a deletion possible. STOP and let the user switch.
* NEVER pass `git branch -D` on a branch step 3 classified as unmerged unless the user typed `-D` or an explicit force-delete request in the current turn. The only other `-D` is the step-3 valve-prediction case on a FULLY MERGED branch, and it is rendered with its reason line in the step-6 plan before the user picks a scope.
* NEVER delete a remote branch as a side effect of a local deletion. The remote scope is a separate, explicit choice at step 6.
* NEVER delete a branch that step 3 classified as unmerged without the step-5 opt-in, even when the user asked for a bulk cleanup.
* NEVER bulk-delete by pattern (`git branch --merged | xargs git branch -d`). Enumerate the targets, render them, and confirm the set; a pattern sweep hides the one branch the user cared about.
* NEVER rewrite history, expire the reflog, or run `git gc` to "finish" a deletion.
* If a deletion fails for any reason, report it verbatim and stop. Do not escalate from `-d` to `-D` on failure: step 3 already predicted the valve, so a refusal means a ref moved since the gather. Re-run from step 2.
