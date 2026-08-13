---
name: git-merge
description: Merge a source branch into a target with `git merge --no-ff`, always producing a merge commit whose message is drafted inline per .gitmessage and committed via a heredoc. Use for "merge X into Y", "merge X", or a git-pull divergence handoff. Local only, with no push, pull, rebase, branch cleanup, or conflict auto-resolution.
---

# Goal

Run a single `git merge --no-ff <source>` against the current HEAD, then commit the merge with a `.gitmessage`-compliant message drafted inline. Every merge generates a merge commit, so the source branch's topology stays visible in `git log --graph`.

The only network calls are read-only per-ref `git fetch origin <ref>` refreshes scoped to the local-side refs in the merge, skipped entirely when the repo has no `origin` remote. When an eligible local ref is stale or diverged relative to `origin`, the skill renders the findings inline and asks before continuing.

# When NOT to use

* The branch only needs to catch up with its own remote and has no local commits: `git-pull` fast-forwards without a merge commit.
* The user wants remote state inspected broadly: `git-fetch`.
* The user wants the merge result published: `git-push`.
* The source branch is already merged and only needs removing: `git-branch-delete`.
* The repo declares `trunk-solo` in `.gitmessage` and the user simply wants their work on the trunk: committing directly on `main` is that variant's sanctioned path, so `git-commit` is the whole answer and no merge is involved.

# Procedure

Run every command in this skill through the `Bash` tool; the redirections and heredocs used across this skill family are POSIX syntax and break under PowerShell.

1. **Resolve source and target.**
   * **Explicit form** ("merge X into Y" / "merge X to Y" / "merge X onto Y"): source=X, target=Y.
   * **Single-branch form** ("merge X"): source=X, target=current HEAD (matching plain `git merge X` semantics).
   * **No-arg form** ("merge"): STOP and ask via `AskUserQuestion` for both. Do not guess.
   * If `source == target`, refuse with a one-line explanation.

2. **Align HEAD with target.** Run `git symbolic-ref --short -q HEAD` (empty output means detached; an unborn zero-commit branch prints its name normally) and `git status --short` in parallel. This status capture is the single canonical read and is reused by step 7.
   * HEAD already equals the target: proceed to step 3.
   * Tree dirty (status non-empty): STOP and offer `git-commit`, so `git checkout` cannot carry uncommitted edits across branches.
   * Tree clean and HEAD differs from target: ask via `AskUserQuestion` with three options:
     * **checkout**: run `git checkout <target>`, then proceed to step 3. On failure, surface the verbatim error and stop.
     * **abort**: STOP; no git state has been modified.
     * **choose**: take an alternate target name as free text, then re-run step 2 with it. The same three options reappear until the user picks **checkout** or **abort**.

3. **Verify remote state (targeted fetch).** First run `git remote`. When the output does not list `origin` (a local-only repo, common under `trunk-solo`), skip steps 3 and 4 entirely and note "no origin remote; merging local refs as-is" in the step-9 plan.

   Classify each side of the merge as a *local* ref (`main`, `feature/foo`) or an *already-remote-tracking* ref (matching `origin/*`). Target is always local because step 2 aligned HEAD with it; source may be either form, since `git-pull` hands off divergence cases with `source=origin/<branch>`.

   Collect the local-side refs only: `<target>` always, plus `<source>` when it does not start with `origin/`. If the collected list is empty (both sides already remote-tracking, unusual but possible), skip the fetch entirely; those refs ARE the remote and need no refresh. Otherwise fetch each collected ref with its own command, one call per ref:
   ```
   git fetch origin <local-side-ref>
   ```
   Per-ref calls are deliberate: `git fetch origin <ref>` exits 128 with `couldn't find remote ref` when the ref has no counterpart on `origin`, and a combined multi-ref call fails as a whole even when the other ref exists. A never-pushed local branch is the normal case for a feature merge, not an error. Route each ref's outcome:
   * Exit 0: tracking ref refreshed; the ref is eligible for the step-4 check.
   * Exit 128 with `couldn't find remote ref`: record that ref as "no remote tracking" for step 4 and proceed.
   * Any other non-zero exit (network, auth, proxy): surface stderr verbatim and STOP.

   This is read-only against the working tree.

4. **Decide based on remote divergence.** Run the check only for local-side refs whose step-3 fetch succeeded (exit 0). A ref recorded as "no remote tracking" is skipped even when a stale `origin/<X>` lingers locally from before the remote branch was deleted; comparing against that stale ref would misreport divergence. Skip any side that is already a remote-tracking ref: it IS the remote. In the common `git-pull` handoff (source=`origin/<branch>`, target=`<branch>`), only the target is checked.

   For each eligible ref run `git rev-list --left-right --count <branch>...origin/<branch>` in parallel, then classify:
   * **0 / 0**: local matches remote; no action.
   * **N / 0** (local ahead): unpublished commits; informational only.
   * **0 / N** (local behind): STALE. Merging here lands the merge commit on a stale tip and forces a follow-up integration before the next push.
   * **M / N** (diverged): merging would miss remote commits on that branch.

   If any eligible ref is stale or diverged, render the per-ref findings inline (ahead / behind counts plus `git log <branch>..origin/<branch> --oneline` capped at 10 lines per ref, so the user sees what would be missed) and ask via `AskUserQuestion`:
   * **abort (Recommended)**: STOP. Suggest `/git-pull <stale-branch>` to refresh it, then re-run this skill.
   * **proceed anyway**: continue with the local refs as-is, and record the choice so step 12 repeats the warning.

   In the `git-pull` handoff case the target is usually diverged by construction; this prompt is the explicit reconfirmation point and is NOT skipped on the assumption that the user already saw the divergence in git-pull's report.

5. **Gather state.** Run in parallel:
   * `git rev-parse --verify <source> 2>/dev/null` (source must resolve; surface the verbatim error if not).
   * `git log <target>..<source> --oneline 2>/dev/null` (commits the merge will land).
   * `git diff --stat <target>..<source>` (fuel for the merge-commit body).
   * `git log -1 --format='%H %s'` (so a hook failure can be diagnosed against the last commit).

   Do NOT re-run `git status --short`; step 2 already captured it.

6. **Refuse on no-op.** If `git log <target>..<source>` is empty, STOP and tell the user there is nothing to merge.

7. **Refuse on dirty tree.** If the step-2 status capture is non-empty, STOP and offer `git-commit` first. Do NOT stash; merging over a dirty tree entangles unrelated edits into the merge commit.

8. **Plan the merge.** Compose the draft per the Reference section below. Pick `<scope>` per `.gitmessage`:
   * `feature/<scope>/<desc>` source: use `<scope>`.
   * Otherwise infer the dominant scope from `git diff --stat <target>..<source>`; fall back to `repo` for cross-area integrations (for example back-merging `main` into a feature branch).

9. **Show the plan and confirm.**
   * Display the commits about to land (`git log <target>..<source> --oneline`) and the exact two-command sequence from step 10.
   * Render the drafted merge commit message as a fenced code block immediately above the question.
   * Ask via `AskUserQuestion`: **merge** / **edit** / **abort**.
     * **merge**: proceed to step 10 with the current draft.
     * **edit**: apply the user's free-text edits, re-render the draft inline, re-ask. Loop until approved or aborted.
     * **abort**: stop. No git state has been modified.
   * A bare "merge" / "yes merge" / "go ahead" typed in the current turn counts as confirmation; ambiguous replies do not.

10. **Run the merge.** Always run, in sequence:
    ```
    git merge --no-ff --no-commit <source>
    git commit -F - <<'COMMIT_MSG_EOF'
    <approved message substituted verbatim, preserving the blank line between header and body>
    COMMIT_MSG_EOF
    ```
    The quoted heredoc terminator prevents shell expansion of the body; if the draft contains a line equal to `COMMIT_MSG_EOF`, pick a fresh terminator (for example `COMMIT_MSG_EOF_2`) absent from that body. Run this through the `Bash` tool, not PowerShell, so the heredoc is valid. If `git merge --no-ff --no-commit` fails, do NOT proceed to `git commit`; handle per step 11.

11. **Handle failures. Do NOT retry blindly.**
    * **Conflicts** (`git diff --name-only --diff-filter=U` non-empty): list the conflicted files and STOP. Tell the user to resolve them; once resolved, ask this skill to finish (the approved draft is still in the conversation and the same step-10 heredoc commits it), or they can run `git merge --abort` themselves to back out.
    * **Hook failure on the commit step**: the merge index is still in place and the approved draft is still in the conversation. Surface stderr verbatim and stop. After the user fixes the issue, re-run the step-10 `git commit -F -` heredoc with the still-approved draft.
    * **Other**: surface verbatim and stop.

12. **Report success.** Show:
    * The new target tip (`git log -1 --format='%h %s'`), which is the merge commit.
    * `git log --oneline --graph -5 <target>` so the user can confirm the topology.
    * When `<source>` is a short-lived branch that is now fully contained in `<target>`, one line offering `/git-branch-delete <source>` as the optional next step. Offer it, never run it.
    * When `<target>` is `main` and `<source>` matches `release/*` or `hotfix/*`, one line offering `/git-tag` for the release or patch tag that `.gitmessage`'s flow requires on this merge commit. Offer it, never run it.
    * When step 4 was answered with **proceed anyway**, repeat the stale or diverged finding verbatim and recommend `/git-pull <branch>` plus a follow-up integration before the next push, so the warning is not silently lost.

# Reference: merge commit message specification

The full specification lives in `.claude/skills/git-commit/references/message-spec.md` (repo-relative). Read it and apply its "Merge commit message" section. That file is the single normative copy for this skill and `git-commit`, so neither SKILL.md restates the rules and there is no second copy to drift.

# Hard rules

* NEVER write the merge commit message to a file on disk (no `tmp/commit_msg.txt`, no `.git/COMMIT_EDITMSG` pre-population, no scratch file under the repo root, system tmp, or `/var/tmp`). The message lives only in the chat conversation and the heredoc that feeds `git commit -F -`.
* `git checkout` is permitted ONLY in the step-2 approve path, and never against a path that was not named as the resolved target or the user-supplied alternate.
* NEVER `git push`, `git pull`, or `git rebase`. The only network calls permitted are the step-3 per-ref targeted fetches, scoped to the local-side refs in the merge, with no `--force`, `--prune`, or `--tags`. A broader remote sweep belongs to `git-fetch`.
* NEVER delete or modify the source branch after merging. Cleanup belongs to `git-branch-delete`; offer it in the step-12 report, never run it.
* NEVER auto-resolve conflicts, run `git merge --abort`, or run `git reset --hard` to recover from a failed merge. Surface the obstruction and let the user decide.
* NEVER use `--force`, `--strategy=ours`, `--strategy-option=theirs`, or any flag that hides conflicts.
* NEVER pass `--ff` or `--ff-only`, and NEVER omit `--no-ff`. Fast-forward is out of scope for this skill.
* NEVER pass `--no-verify` or `--no-gpg-sign` on the `git commit` that follows `git merge --no-ff --no-commit`.
* NEVER add `Generated with Claude Code`, `Co-Authored-By: Claude`, `Co-Authored-By: Anthropic`, or any AI, agent, or assistant attribution. Do not invent co-authors. The message MUST follow `.gitmessage`, stay in concise bullet form, and stay human-authored.
* NEVER skip the step 9 confirmation, and NEVER skip the step 4 prompt when remote divergence is detected. Proceeding silently against a stale ref is the exact failure mode that prompt prevents.
* This skill does NOT commit unrelated edits, push, pull, rebase, or clean up branches. When those are needed, surface the situation and suggest the matching skill (`git-commit`, `git-push`, `git-pull`, `git-fetch`); let the user invoke it.
