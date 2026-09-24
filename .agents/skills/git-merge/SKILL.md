---
name: git-merge
description: Merge a source branch into a target with `git merge --no-ff`, always producing a merge commit whose message is drafted inline per .gitmessage and committed via a heredoc. Use for "merge X into Y", "merge X", or the divergence merge that git-pull or git-push suggests. Local only, with no push, pull, rebase, branch cleanup, or conflict auto-resolution.
compatibility: Requires git 2.22 or later and a POSIX shell (Git Bash on Windows).
---

# Goal

Run a single `git merge --no-ff <source>` against the current HEAD, then commit the merge with a `.gitmessage`-compliant message drafted inline. Every merge generates a merge commit, so the source branch's topology stays visible in `git log --graph`.

The only network calls are the step-3 per-ref `git fetch` refreshes of `origin/<ref>` remote-tracking refs; another remote (such as `template`) is never fetched here. A stale or diverged local ref is shown and confirmed before continuing (step 4).

The merge commit message follows `.gitmessage` through `git-commit`'s message spec (see the Reference section).

# When NOT to use

* The branch only needs to catch up with its own remote and has no local commits: `git-pull` fast-forwards without a merge commit.
* The user wants remote state inspected broadly: `git-fetch`.
* The user wants the merge result published: `git-push`.
* The source branch is already merged and only needs removing: `git-branch-delete`.
* The repo declares `trunk-solo` in `.gitmessage` and the user simply wants their work on the trunk: committing directly on `main` is that variant's sanctioned path, so `git-commit` is the whole answer and no merge is involved.

# Procedure

Terms such as choice question, independent reads, invoke, and suggest follow AGENTS.md (Skill authoring); in a non-interactive session every gate ends this skill.

Run every command in this skill in a POSIX shell; the redirections and heredocs used across this skill family are POSIX syntax and break under PowerShell.

1. **Resolve source and target.**
   * **Explicit form** ("merge X into Y" / "merge X to Y" / "merge X onto Y"): source=X, target=Y.
   * **Single-branch form** ("merge X"): source=X, target=the current branch (matching plain `git merge X` semantics), read with `git branch --show-current`. Empty output means HEAD is detached and there is no target yet: skip the gate below; step 2 asks for one before anything else runs.
   * **No-arg form** ("merge"): STOP and ask with a choice question for both. Do not guess.
   * If `source == target`, refuse with a one-line explanation.
   * **Classify the source.** Run `git remote` once. A source of the form `<remote>/<branch>` whose `<remote>` that output lists (for example `origin/main`, or `template/main` after `git remote rename origin template`) is a *remote-tracking* source; any other source, such as `feature/foo` in a repo with no `feature` remote, is a *local* source. When both `refs/heads/<source>` and `refs/remotes/<source>` resolve (`git rev-parse --verify --quiet` on each), ask with a choice question which one is meant (**local branch** / **remote-tracking ref**); do not guess.
   * **Exact name check**, before any other step, for every local branch name (`<target>`, even when it is the current branch, a local `<source>`, and a step-2 alternate target; skip only a current-branch `<target>` while `git rev-parse --verify --quiet HEAD` prints nothing): require `[ "$(git for-each-ref --format='%(refname)' "refs/heads/<b>")" = "refs/heads/<b>" ]`. On failure, STOP: list the local branches whose names match ignoring case (`git for-each-ref --format='%(refname:lstrip=2)' refs/heads/ | grep -ixF -- '<b>'`), or say there is no local `<b>`; for a current-branch `<target>`, suggest `git switch <exact-name>`. On a case-insensitive filesystem `Main` resolves to `main` (also as HEAD after `git checkout Main`), so the merge would land on `main` past the gate below; the equality is needed because `for-each-ref` also matches branches under `refs/heads/<b>/`.
   * **Full refs.** Local reads and the merge itself name each side by its full ref, so a tag sharing the short name cannot be picked instead: `<target-ref>` is `refs/heads/<target>`, and `<source-ref>` is `refs/remotes/<source>` for a remote-tracking source, else `refs/heads/<source>`.
   * **Protected-target gate.** Read the `Workflow:` line in `.gitmessage`'s "Workflow Variant" section to get the protected set. When no variant is declared, or the line carries an unrecognized value (such as the shipped `<not recorded>` placeholder), assume `git-flow`; do not infer a permissive one here. Nothing infers the variant: `git-commit` and `repo-init` ask the user and offer to record the answer.

     | Variant | Protected set |
     |---|---|
     | `git-flow` | `main`, `develop`, `support/*` |
     | `github-flow` | `main`, `support/*` |
     | `trunk-solo` | none |

     This table is a convenience copy. `.gitmessage`'s "Protected Branches" section is normative; when the two disagree, follow `.gitmessage` and say so.

     Compare names ignoring case: `Main`, `DEVELOP`, and `Support/x` count as protected. A merge commit on a protected target is a direct commit there, so if `<target>` is in that set, require an explicit in-turn opt-in as AGENTS.md defines it: a reply in the current turn that names the direct merge and `<target>`, typed (such as "yes, merge directly into `<target>`") or by choosing an option whose label states both. A generic yes, or an opt-in from an earlier turn, does NOT count. Without one, STOP before any checkout or fetch and explain the alternative: open a PR or MR from `<source>` into `<target>`, or re-ask with the opt-in. The divergence merge that `git-pull` or `git-push` suggests (target=`<branch>`, source=`origin/<branch>`) is gated the same way. If the set is empty (`trunk-solo`), skip this gate.

2. **Align HEAD with target.** Run these independent reads: `git branch --show-current` (empty output means detached; an unborn branch prints its name; unlike `git symbolic-ref --short HEAD`, it never prints `heads/<branch>`) and `git status --short`. This status capture is the single canonical read and is reused by step 7.
   * HEAD detached and no target yet (single-branch form): STOP; a merge commit here would land on no branch. Ask with a choice question:
     * **choose**: take a local branch name as the target in free text, then re-run the step-1 exact name check, the protected-target gate, and step 2 with it.
     * **abort**: STOP; no git state has been modified.
   * HEAD already equals the target: proceed to step 3.
   * Tree dirty (status non-empty): STOP and suggest `git-commit`, so `git checkout` cannot carry uncommitted edits across branches.
   * Tree clean and HEAD differs from target: ask with a choice question with three options:
     * **checkout**: run `git checkout --no-overwrite-ignore <target>`, then proceed to step 3. The flag makes checkout fail instead of silently replacing an ignored file (such as `.env`) that `<target>` tracks; `git status --short` never shows ignored files. On failure, surface the verbatim error and stop; never delete the blocking files.
     * **abort**: STOP; no git state has been modified.
     * **choose**: take an alternate target name as free text, then re-run the step-1 exact name check, the protected-target gate, and step 2 with it. The same three options reappear until the user picks **checkout** or **abort**.

3. **Verify remote state (targeted fetch).** First handle a remote-tracking source on a remote other than `origin` (step-1 classification, for example `template/main`): this skill never fetches that remote. Run `git rev-parse --verify --quiet <source-ref>`; when it prints nothing, STOP and tell the user to run `git fetch <remote>` themselves, then re-run this skill. When it resolves, note in the step-9 plan that `<source>` is as of the last `git fetch <remote>`, and that running `git fetch <remote>` first picks up newer commits.

   Then use the step-1 `git remote` output. When it does not list `origin` (a local-only repo, common under `trunk-solo`), skip the rest of step 3 and all of step 4, and note "no origin remote; merging local refs as-is" in the step-9 plan.

   Each side of the merge is a *local* ref (`main`, `feature/foo`) or a *remote-tracking* ref (step-1 classification). Target is always local (step 2 aligned HEAD with it); source may be either form (`origin/<branch>` in a suggested divergence merge).

   Collect the local-side refs only: `<target>` always, plus `<source>` when it is a local source. If the collected list is empty (both sides already remote-tracking, unusual but possible), skip the fetch entirely; those refs ARE the remote and need no refresh. Otherwise fetch each collected ref with its own command, one call per ref:
   ```
   git fetch --no-tags origin +refs/heads/<ref>:refs/remotes/origin/<ref>
   ```
   The explicit refspec writes `origin/<ref>` even in a `--single-branch` or shallow clone. Its `+` force-updates only that remote-tracking ref; `--no-tags` stops the tag auto-follow an explicit refspec triggers. Per-ref calls are deliberate: a ref with no counterpart on `origin` exits 128 with `couldn't find remote ref`, and a combined call would fail as a whole. Route each ref's outcome:
   * Exit 0: tracking ref refreshed; the ref is eligible for the step-4 check.
   * Exit 128 with `couldn't find remote ref`: record that ref as "no remote tracking" for step 4 and proceed.
   * Any other non-zero exit (network, auth, proxy): surface stderr verbatim and STOP.

   This is read-only against the working tree.

4. **Decide based on remote divergence.** Run the check only for local-side refs whose step-3 fetch succeeded (exit 0). A ref recorded as "no remote tracking" is skipped even when a stale `origin/<X>` lingers locally from before the remote branch was deleted; comparing against that stale ref would misreport divergence. Skip any side that is a remote-tracking ref: it IS the remote (for a remote other than `origin`, as of its last fetch). In the common divergence merge that `git-pull` or `git-push` suggests (source=`origin/<branch>`, target=`<branch>`), only the target is checked.

   For each eligible ref, run these independent reads: `git rev-list --left-right --count refs/heads/<branch>...refs/remotes/origin/<branch>`. Then classify:
   * **0 / 0**: local matches remote; no action.
   * **N / 0** (local ahead): unpublished commits; informational only.
   * **0 / N** (local behind): STALE. Merging here lands the merge commit on a stale tip and forces a follow-up integration before the next push.
   * **M / N** (diverged): merging would miss remote commits on that branch.

   If any eligible ref is stale or diverged, render the per-ref findings inline (ahead / behind counts plus `git log refs/heads/<branch>..refs/remotes/origin/<branch> --oneline` capped at 10 lines per ref, so the user sees what would be missed) and ask with a choice question:
   * **abort (Recommended)**: STOP. Suggest `git-pull` with `<stale-branch>` to refresh it, then re-run this skill.
   * **proceed anyway**: continue with the local refs as-is, and record the choice so step 12 repeats the warning.

   In the suggested divergence merge the target is usually diverged by construction; this prompt is the explicit reconfirmation point and is NOT skipped on the assumption that the user already saw the divergence in the report of `git-pull` or `git-push`.

5. **Gather state.** Run these independent reads:
   * `git rev-parse --verify <source-ref>` (source must resolve).
   * `git log <target-ref>..<source-ref> --oneline` (commits the merge will land).
   * `git diff --stat <target-ref>...<source-ref>` (body fuel; three dots diff from the merge base, so target-only changes do not show reversed).
   * `git log -1 --format='%H %s'` (so a hook failure can be diagnosed against the last commit).

   Do NOT re-run `git status --short`; step 2 already captured it.

   A non-zero exit from any of these reads is an error, never an empty list: surface it verbatim and stop. An unborn target, for example, fails the `git log` range read; it has no commit to merge into.

6. **Refuse on no-op.** If `git log <target-ref>..<source-ref>` is empty, STOP and tell the user there is nothing to merge.

7. **Refuse on dirty tree or files in the way.** If the step-2 status capture is non-empty, STOP and suggest `git-commit` first. Do NOT stash; merging over a dirty tree entangles unrelated edits into the merge commit. Then list the untracked or ignored files on disk at a path the source adds, or at a parent of one (an ignored file `dd` where the source adds `dd/inner`); `git status --short` hides ignored ones, and `git merge` silently overwrites them even with `--no-overwrite-ignore`:
   ```
   top=$(git rev-parse --show-toplevel) &&
   git diff --name-only -z --no-renames --diff-filter=A <target-ref> <source-ref> | tr '\0' '\n' |
     while IFS= read -r p; do
       q=$p
       while :; do
         if [ -L "$top/$q" ] || { [ -e "$top/$q" ] && { [ "$q" = "$p" ] || [ ! -d "$top/$q" ]; }; }; then
           [ -n "$(git --literal-pathspecs ls-tree --full-tree --name-only <target-ref> -- "$q")" ] || echo "file in the way: $q"; break
         fi
         case $q in */*) q=${q%/*} ;; *) break ;; esac
       done
     done | sort -u
   ```
   `ls-tree` skips a path `<target>` tracks; Git Bash may rewrite a `<ref>:<path>` argument (such as `x:.env`).
   Any output: STOP and list the paths; the user moves or backs them up (often `.env`-style local config), then re-runs this skill. Never delete them.

8. **Plan the merge.** Compose the draft per the Reference section below. Pick `<scope>` per `.gitmessage`:
   * `feature/<scope>/<desc>` source: use `<scope>`.
   * Otherwise infer the dominant scope from `git diff --stat <target-ref>...<source-ref>`; fall back to `repo` for cross-area integrations (for example back-merging `main` into a feature branch).

9. **Show the plan and confirm.**
   * Display the commits about to land (`git log <target-ref>..<source-ref> --oneline`) and the exact two-command sequence from step 10.
   * Render the drafted merge commit message as a fenced code block immediately above the question.
   * Ask with a choice question: **merge** / **edit** / **abort**.
     * **merge**: proceed to step 10 with the current draft.
     * **edit**: apply the user's free-text edits, re-render the draft inline, re-ask. Loop until approved or aborted.
     * **abort**: stop. No git state has been modified.
   * A bare "merge" / "yes merge" / "go ahead" typed in the current turn counts as confirmation; ambiguous replies do not.

10. **Run the merge.** Always run, in sequence:
    ```
    git merge --no-ff --no-commit <source-ref>
    git commit -F - <<'COMMIT_MSG_EOF'
    <approved message substituted verbatim, preserving the blank line between header and body>
    COMMIT_MSG_EOF
    ```
    The quoted heredoc terminator prevents shell expansion of the body; if the draft contains a line equal to `COMMIT_MSG_EOF`, pick a fresh terminator (for example `COMMIT_MSG_EOF_2`) absent from that body. If `git merge --no-ff --no-commit` fails, do NOT proceed to `git commit`; handle per step 11.

11. **Handle failures. Do NOT retry blindly.**
    * **Conflicts** (`git diff --name-only --diff-filter=U` non-empty): list the conflicted files and STOP. Tell the user to resolve them; once resolved, ask this skill to finish (the approved draft is still in the conversation and the same step-10 heredoc commits it), or they can run `git merge --abort` themselves to back out.
    * **Hook failure on the commit step**: the merge index is still in place and the approved draft is still in the conversation. Surface stderr verbatim and stop. After the user fixes the issue, re-run the step-10 `git commit -F -` heredoc with the still-approved draft.
    * **Other**: surface verbatim and stop.

12. **Report success.** Show:
    * The new target tip (`git log -1 --format='%h %s'`), which is the merge commit.
    * `git log --oneline --graph -5 <target-ref>` so the user can confirm the topology.
    * When `<source>` is a short-lived branch that is now fully contained in `<target>`, one line that suggests `git-branch-delete` with `<source>` as the optional next step.
    * When `<target>` is `main` and `<source>` matches `release/*` or `hotfix/*`, one line that suggests `git-tag` for the release or patch tag that `.gitmessage`'s flow requires on this merge commit.
    * When step 4 was answered with **proceed anyway**, repeat the stale or diverged finding verbatim and suggest `git-pull` with `<branch>` plus a follow-up integration before the next push, so the warning is not silently lost.

# Reference: merge commit message specification

`.gitmessage` is normative. Its detailed reading for this skill family lives in the `git-commit` skill, at `../git-commit/references/message-spec.md` relative to this skill's directory; this skill depends on `git-commit` being installed alongside it. Read that file and apply its "Merge commit message" section; where it and `.gitmessage` disagree, follow `.gitmessage` and say so.

# Hard rules

* NEVER write the merge commit message to a file on disk (no `tmp/commit_msg.txt`, no `.git/COMMIT_EDITMSG` pre-population, no scratch file under the repo root, system tmp, or `/var/tmp`). The message lives only in the chat conversation and the heredoc that feeds `git commit -F -`.
* NEVER merge onto a detached HEAD. The merge commit would belong to no branch; step 2 asks for a target branch instead.
* `git checkout` is permitted ONLY in the step-2 approve path, always with `--no-overwrite-ignore`, and never against a path that was not named as the resolved target or the user-supplied alternate, after that name passed the step-1 exact name check.
* NEVER delete, move, or overwrite an ignored or untracked file that blocks the checkout or merge (steps 2 and 7). Surface it and let the user decide.
* NEVER treat a failed step-5 read as an empty result.
* NEVER `git push`, `git pull`, or `git rebase`. The only network calls permitted are the step-3 per-ref targeted fetches from `origin`, scoped to the local-side refs in the merge, with no `--force`, `--prune`, or `--tags`; the `+` on the step-3 remote-tracking refspec is the only forced update allowed, and it never names a local branch. A broader origin sweep belongs to `git-fetch`, and any other remote (such as `template`) is fetched by the user with `git fetch <remote>`, never by this skill.
* NEVER delete or modify the source branch after merging. Cleanup belongs to `git-branch-delete`; suggest it in the step-12 report, never invoke it.
* NEVER auto-resolve conflicts, run `git merge --abort`, or run `git reset --hard` to recover from a failed merge. Surface the obstruction and let the user decide.
* NEVER use `--force`, `--strategy=ours`, `--strategy-option=theirs`, or any flag that hides conflicts.
* NEVER pass `--ff` or `--ff-only`, and NEVER omit `--no-ff`. Fast-forward is out of scope for this skill.
* NEVER pass `--no-verify` or `--no-gpg-sign` on the `git commit` that follows `git merge --no-ff --no-commit`.
* NEVER add any AI tool, model, agent, or vendor attribution: no `Co-Authored-By:` trailer naming an assistant or its vendor, and no `Generated with <tool>` line. Do not invent co-authors. The message MUST follow `.gitmessage`, stay in concise bullet form, and stay human-authored.
* NEVER merge into a branch the active workflow variant protects without an explicit in-turn opt-in (step 1) that names the direct merge and the target; target names match the protected set ignoring case. A generic yes or prior-turn approval does not count, and an undeclared or unrecognized variant value means `git-flow`, never the most permissive.
* NEVER skip the step 9 confirmation, and NEVER skip the step 4 prompt when remote divergence is detected. Proceeding silently against a stale ref is the exact failure mode that prompt prevents.
* This skill does NOT commit unrelated edits, push, pull, rebase, or clean up branches. When those are needed, surface the situation and suggest the matching skill (`git-commit`, `git-push`, `git-pull`, `git-fetch`) without running it.
