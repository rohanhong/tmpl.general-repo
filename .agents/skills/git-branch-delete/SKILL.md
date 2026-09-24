---
name: git-branch-delete
description: Delete a merged short-lived branch locally, and optionally its origin counterpart, after verifying it is fully contained in its integration base. Use for "delete this branch", "clean up feature/foo", "remove merged branches", or post-merge tidying. Refuses protected names, the current HEAD, and unmerged branches without an explicit in-turn opt-in.
compatibility: Requires git 2.22 or later and a POSIX shell (Git Bash on Windows).
---

# Goal

Remove a short-lived branch that has served its purpose, locally and optionally on `origin`, after proving the commits it carries are already reachable from its integration base. The skill deletes branch refs only; it never touches commits, the working tree, or the index.

# When NOT to use

* The branch has not been integrated yet: `git-merge` first, then return here.
* The user wants the commits gone, not just the ref: out of scope. Deleting a branch does not remove commits, and history rewriting is forbidden across this skill family.
* The branch is `main`, `develop`, or matches `support/*`: refuse per Hard rules.

# Prerequisites

Resolve these before step 1:

1. **Target branch name(s)**. Named by the user in the current turn, or handed over by `git-merge`'s success report. Never infer from "the branch I was just on". Several targets follow "Several targets" below.
2. **Integration base**: the branch the target must already be merged into. Derive it from the `Workflow:` line in `.gitmessage`'s "Workflow Variant" section: under `git-flow`, `feature/*` and `bugfix/*` integrate into `develop` while `hotfix/*` and `release/*` integrate into `main`; under `github-flow` and `trunk-solo` every short-lived type integrates into `main`. When no variant is declared, or the line carries an unrecognized value (such as the shipped `<not recorded>` placeholder), assume `git-flow`. Ask with a choice question when the mapping is still ambiguous.
3. **Scope**: local only, or local plus `origin`. Never assume; step 6 asks.

# Procedure

Terms such as choice question, independent reads, invoke, and suggest follow AGENTS.md (Skill authoring); in a non-interactive session every gate ends this skill.

Run every command in this skill in a POSIX shell; the redirections used across this skill family are POSIX syntax and break under PowerShell.

**Several targets.** Run steps 1 to 3 for every named target before asking anything; a target that stops there is reported with its reason and left out, and the rest continue. A target whose stop asks a question (step 1's exact name, step 2's base) does not block the others: collect those questions and ask them together once steps 1 to 3 have run for every target; an answered target re-runs from step 1 and rejoins the set, an unanswered one stays out with its reason. Step 4 renders every target's findings together (one row per target when shown as a table). Opt-ins stay per branch: step 5 needs one naming each unmerged branch, and the step-6 remote-commits opt-in names each remote. Step 6 asks one scope question for the set when every target offers the same options, otherwise one per target. Step 7 executes branch by branch and stops the whole run at the first failure; step 8 reports each branch, including those left out or not reached.

1. **Refuse unknown, protected, and current-HEAD targets.** Case matters: on a case-insensitive filesystem git resolves `Main` to the loose ref `main`, so `git branch -d Main` deletes `main`, and a HEAD switched to as `Feature/X` does not stop `git branch -d feature/x`.
   * **Exact name first.** Run `[ "$(git for-each-ref --format='%(refname)' "refs/heads/<branch>")" = "refs/heads/<branch>" ]` (equality, because `for-each-ref` also lists everything under a hierarchy such as `feature`). On a nonzero exit STOP: no branch has exactly that spelling. List the local names that match case-insensitively (`git for-each-ref --format='%(refname:lstrip=2)' refs/heads/ | grep -ixF -e '<branch>'`) and let the user name the exact one.
   * Compare protected names case-insensitively: if the lowercased target (`printf '%s' '<branch>' | tr '[:upper:]' '[:lower:]'`) is `main` or `develop`, or starts with `support/`, STOP.
   * Run `git branch --show-current`. If it equals the target, ignoring case, STOP and tell the user to switch to another branch first. Do NOT check out anything to enable the deletion.
   * Run `git worktree list --porcelain`. If any entry carries the line `branch refs/heads/<branch>`, ignoring case, the target is checked out in another worktree. STOP and name that worktree's path (its `worktree <path>` line); the user switches it or removes the worktree themselves.

2. **Refresh the remote counterpart, then gather state.** First run this on its own; the reads below depend on it:
   ```
   git fetch --no-tags origin +refs/heads/<branch>:refs/remotes/origin/<branch>
   ```
   It writes only `refs/remotes/origin/<branch>`, so the remote-safety reads see what origin holds now, not what this clone last fetched; a stale tracking ref hides a collaborator's newer push, which a remote delete would then destroy. Route by result:
   * Exit 0: the remote branch exists and its tracking ref is current.
   * `couldn't find remote ref` on stderr: the branch is already absent on origin. Treat `refs/remotes/origin/<branch>` as not resolving below, even when a stale copy still exists locally (this fetch does not remove it).
   * `'origin' does not appear to be a git repository`: there is no origin remote; treat the remote counterpart as absent.
   * Anything else (network, auth, proxy): surface stderr verbatim. Classification continues on local refs, the `remote` line renders `unverified (refresh failed)`, and step 6 withholds the remote option.

   Then run these independent reads. Every ref is spelled in full: an unqualified name resolves to a same-name tag before the branch, which can make an unmerged branch look merged. Later steps refer to these reads by their short range (for example `<base>..<branch>`).
   * `git rev-parse --verify --quiet refs/heads/<branch>` (exists locally; empty output means it does not).
   * `git rev-parse --verify --quiet refs/heads/<base>` (the base exists locally; empty output means it does not).
   * `git rev-parse --verify --quiet refs/remotes/origin/<branch>` (remote counterpart, may be empty, and counted as not resolving whenever the refresh reported the branch absent; its SHA is the lease value for the step-6 remote delete).
   * `git rev-parse --verify --quiet refs/remotes/origin/<base>` (remote-tracking ref of the base, may be empty).
   * `git log refs/heads/<base>..refs/heads/<branch> --oneline` (commits NOT yet in the base; empty means fully merged).
   * `git log refs/remotes/origin/<base>..refs/heads/<branch> --oneline 2>/dev/null` (commits NOT yet in the base's remote tip; meaningful only when `origin/<base>` exists).
   * `git log refs/remotes/origin/<branch>..refs/heads/<branch> --oneline 2>/dev/null` (commits never pushed; read it ONLY when `origin/<branch>` resolved above. Without that ref the range exits 128 and prints nothing, and that empty output must not be mistaken for "everything pushed").
   * `git log refs/heads/<base>..refs/remotes/origin/<branch> --oneline 2>/dev/null` (commits on the remote branch NOT in the base, for example a collaborator's push the local branch never fetched; read it ONLY when `origin/<branch>` resolved above, for the same reason as the previous line. Consumed by step 6).
   * `git rev-parse --symbolic-full-name <branch>@{upstream} 2>/dev/null` (the target's upstream in full, for example `refs/remotes/origin/<branch>`; consumed by step 3 as the ref git's `-d` safety valve compares against). The short name is correct here: the `@{upstream}` suffix already resolves `<branch>` as a branch, and `refs/heads/<branch>@{upstream}` is rejected. Decide by the exit code, never by stdout: on exit 128 there is no usable upstream, and when the configured upstream's remote-tracking ref is gone (pruned after a merged PR deleted it) git still prints the literal `<branch>@{upstream}` to stdout.
   * `git config --get branch.<branch>.merge` (exit 0 means an upstream is configured, and stdout is its remote ref; with a failed upstream read above, step 3 confirms whether that upstream was deleted on origin after an earlier push).
   * `git rev-parse refs/heads/<branch>` (tip SHA, recorded for the recovery hint in step 8).

   Treat every `git log` range above as data only when it exits 0; a failed range prints nothing, and that empty output must never be read as "fully merged" or "everything pushed". If the branch does not exist locally, surface that and stop. `<base>` must pass the step-1 exact-name test too; if it does not exist locally with that spelling, STOP before classifying: report the missing ref, and when `origin/<base>` resolves, render `git branch --track <base> origin/<base>` for the user to run themselves (as `git-branch-create` step 6 does), then re-run from step 1; otherwise ask which base the target integrates into.

3. **Classify the target.**
   * **Fully merged** (`git log <base>..<branch>` empty): safe. `git branch -d` will succeed on its own.
   * **Merged upstream only** (`git log <base>..<branch>` non-empty BUT `origin/<base>` exists and `git log origin/<base>..<branch>` is empty): every commit is already reachable from the base's remote tip; only the local `<base>` is behind. This is NOT an unmerged branch, so do not route it into the step-5 force-delete opt-in. STOP and suggest `git-pull` with `<base>` first; after that fast-forward, re-run this skill and the plain `-d` path succeeds.
   * **Unmerged** (`git log <base>..<branch>` non-empty and the upstream-only case does not apply): the listed commits exist ONLY on this branch. Deleting the ref leaves them reachable only via reflog, which expires. Requires the step-5 opt-in.
   * **Unpushed** (`origin/<branch>` does not resolve, OR `git log origin/<branch>..<branch>` is non-empty): surface the count alongside the classification. When `origin/<branch>` does not resolve, tell two shapes apart with the step-2 `branch.<branch>.merge` read. Configured: the branch was pushed once. Before reporting "upstream deleted on origin", confirm it with `git ls-remote --exit-code origin <merge-ref>` (`<merge-ref>` is that read's stdout, for example `refs/heads/<branch>`): exit 2 means origin has no such branch, so its remote counterpart was deleted since (typical after a merged PR with auto-delete, or a squash merge) and the report says "upstream deleted on origin", not "never pushed"; exit 0 means the upstream still exists on origin under that name, so report "upstream present on origin, not fetched here" instead; any other exit, surface stderr and report the upstream as unverified. Not configured: the branch was never pushed at all, so every commit it holds beyond `<base>` exists only in this clone; count those (`git log <base>..<branch>`) as the unpushed set. Unpushed plus unmerged is the most destructive combination and MUST be called out explicitly, and the never-pushed form is the worst of it because no other clone has a copy.
   * **Safety-valve prediction** (fully merged targets only). `git branch -d` does NOT check containment in `<base>`: it checks the branch's upstream when its remote-tracking ref resolves, otherwise the current HEAD, and warns when the two disagree. Take the step-2 upstream when that read exited 0 (else `HEAD`, which is also what git uses for a gone upstream) as the valve reference and run `git merge-base --is-ancestor refs/heads/<branch> <reference>` (exit 0 means contained).
     * **Contained**: `-d` passes; the step-6 plan uses `-d`.
     * **Not contained**: `-d` would refuse with "not fully merged" even though containment in `<base>` is proven. Two common shapes: HEAD is an unrelated branch and the target has no upstream; or the target's last commits were merged into `<base>` locally and never pushed, so its upstream lags its tip. The step-6 plan uses `-D` for this case and carries a reason line naming the reference and the proof (`git log <base>..<branch>` empty). Do NOT check out `<base>` to make `-d` pass; see Hard rules.

4. **Render the findings inline** before asking anything:
   ```
   branch  : <branch>            tip <short-sha>
   base    : <base>
   merged  : yes | upstream only (contained in origin/<base>; local <base> behind) | no (<n> commit(s) not in <base>)
   pushed  : yes | no (<n> commit(s) not on origin) | upstream deleted on origin | upstream present on origin, not fetched here | upstream unverified | never pushed (<n> commit(s) beyond <base> exist only here)
   remote  : origin/<branch> exists | exists, holds <n> commit(s) not in <base> | absent | unverified (refresh failed)
   valve   : -d passes (<reference> contains tip) | -D required (<reference> does not contain tip; merged into <base> verified)
   ```
   With several targets, render all of them in this one block. When not fully merged, list the unmerged commits (the step-2 `<base>..<branch>` read, capped at 10 with an overflow count) so the user sees exactly what the ref is holding. Likewise list the remote-only commits from the step-2 `git log <base>..origin/<branch>` read when it is non-empty.

5. **Unmerged opt-in.** If the branch is not fully merged, require an explicit in-turn opt-in (AGENTS.md): a current-turn reply naming the force delete and the branch, typed ("yes, force delete `<branch>`", or `-D` for that branch) or chosen as a choice-question option whose label states both (**force delete `<branch>`**, offered beside **stop, merge first**). A generic yes or an earlier turn's approval does NOT count. Without one, STOP and suggest `git-merge` first.

6. **Ask for the deletion scope and confirm.** Render the exact commands, then ask with a choice question with these three options (two when the remote option is withheld as described below):
   * **local only**: `git branch -d <branch>` (or `-D` when step 5 was opted into, or when the step-3 valve prediction says `-d` would refuse a fully merged branch; the plan renders the reason line above the command either way).
   * **local and remote**: the above, then `git push --force-with-lease=refs/heads/<branch>:<remote-sha> origin --delete <branch>`, where `<remote-sha>` is the step-2 `refs/remotes/origin/<branch>` value, spelled out in full in the rendered command. The lease makes the delete conditional: origin rejects it with `stale info` when the branch no longer points at the SHA step 2 verified. Offer this option ONLY when the step-2 refresh exited 0 and `origin/<branch>` resolved (otherwise there is nothing verified to delete). When the step-2 `<base>..origin/<branch>` read is non-empty, the remote branch holds commits that neither the base nor this clone's branch carries (typically a collaborator's push), and deleting it drops them from origin: the option requires an explicit in-turn opt-in naming the remote: offer it only under the label **local and remote, dropping <n> commit(s) on `origin/<branch>`** (never marked recommended), or accept the typed form "yes, delete `origin/<branch>` with its commits"; a generic yes or bare "delete" does not count. Otherwise leave it out and suggest `git-merge` first.
   * **abort**: STOP. Nothing is deleted.

   A bare "delete" is NOT enough to select the remote scope; remote deletion must be chosen explicitly, because it affects every other clone.

7. **Execute** the approved commands in the displayed order, local first. If the local delete fails, do NOT proceed to the remote delete. Capture output verbatim. A remote delete rejected with `stale info` means someone pushed to the branch after step 2: the remote branch stays, and the fix is to re-run from step 2 so the new commits are read and classified, never to retry with a fresh SHA.

8. **Report.** Show the deleted branch name, the tip SHA recorded in step 2, and the recovery command `git branch <branch> <tip-sha>` (valid until the reflog entry expires). State whether the remote counterpart was deleted or left in place.

# Rationale

* **Remote deletion lives here, not in `git-push`.** `git-push` is scoped to publishing commits and refuses anything that is not a fast-forward of content; a remote branch delete publishes an absence and belongs with the rest of branch lifecycle management. Keeping it here also means one skill owns the merged-check that makes the deletion safe.
* **Refresh, then lease.** The merged-check on the remote branch is only as good as the tracking ref it reads, so step 2 fetches that one ref first; the step-6 lease then closes the window between that read and the delete. The lease is allowed here despite the force-push ban because it cannot make a delete succeed that a plain delete would refuse: it only adds a condition.
* **Two-stage consent** (step 5 opt-in for unmerged, step 6 scope choice) rather than one gate: the two decisions have different blast radii. Losing unmerged local commits is recoverable from the reflog for a while; deleting the remote ref affects collaborators immediately.
* **The tip SHA is printed before deletion, not after.** After `git branch -d` the name is gone, and a user who realises the mistake a minute later needs the SHA, not a reflog lecture.
* **Exact spelling before anything else.** git's own checks compare literal ref names while a case-insensitive filesystem resolves any casing to the one loose ref, so a name typed with the wrong case can reach a protected or checked-out branch. `for-each-ref` reports the stored spelling, which makes its equality the one reliable test.
* **`-D` on a verified-merged branch is not an escalation.** git's `-d` valve compares against the upstream or HEAD, never against the integration base, so it answers a different question than this skill asks. Step 3's `git log <base>..<branch>` is the stronger check; once it is empty, the valve can only produce a false refusal. Predicting the valve up front keeps an actual `-d` refusal meaningful: it means a ref moved between the gather and the delete, not that the classification was wrong.

# Hard rules

* NEVER act on a target or base whose exact spelling step 1 did not confirm, and compare protected, current, and worktree names ignoring case, so `Main`, `DEVELOP`, and `Support/x` are protected too.
* NEVER delete `main`, `develop`, or anything matching `support/*`, locally or on origin, under any opt-in. This is independent of the workflow variant: `trunk-solo` declaring "Protected: none" relaxes who may commit to a trunk, not whether the trunk may be destroyed.
* NEVER delete the current HEAD or a branch checked out in another worktree, and NEVER check out another branch to make a deletion possible. STOP and let the user switch.
* NEVER pass `git branch -D` on a branch step 3 classified as unmerged without the step-5 explicit in-turn opt-in. The only other `-D` is the step-3 valve-prediction case on a FULLY MERGED branch, and it is rendered with its reason line in the step-6 plan before the user picks a scope.
* NEVER delete a remote branch as a side effect of a local deletion. The remote scope is a separate, explicit choice at step 6.
* NEVER delete a remote branch that holds commits not in `<base>` (step 2 `<base>..origin/<branch>` read non-empty) without the step-6 explicit in-turn opt-in naming the remote.
* NEVER delete a remote branch without first refreshing its tracking ref (step 2), and NEVER pass a force flag to `git push`. The one exception is the step-6 remote delete's `--force-with-lease=refs/heads/<branch>:<remote-sha>`, allowed ONLY on a remote branch deletion and ONLY with the explicit SHA read in step 2; a bare `--force-with-lease`, `--force`, or a `+` refspec stays forbidden.
* NEVER resolve a branch by its short name in a `rev-parse`, `log`, or `merge-base` read; spell `refs/heads/<name>` or `refs/remotes/origin/<name>` so a same-name tag cannot answer instead.
* NEVER classify a target from a `git log` range that exited non-zero, and NEVER classify at all when `<base>` does not resolve locally; step 2 STOPS first.
* NEVER delete a branch that step 3 classified as unmerged without the step-5 opt-in naming that branch, even when the user asked for a bulk cleanup; one opt-in never covers the set.
* NEVER bulk-delete by pattern (`git branch --merged | xargs git branch -d`). Enumerate the targets, render them, and confirm the set; a pattern sweep hides the one branch the user cared about.
* NEVER rewrite history, expire the reflog, or run `git gc` to "finish" a deletion.
* If a deletion fails for any reason, report it verbatim and stop. Do not escalate from `-d` to `-D` on failure: step 3 already predicted the valve, so a refusal means a ref moved since the gather. Re-run from step 2.
