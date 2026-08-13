---
name: git-pull
description: Fast-forward a local branch from origin, defaulting to the current HEAD; an off-HEAD target updates the branch ref only, never its working tree. Use for "pull", "pull main", "pull feature/foo", or updating a branch with new origin commits. Refuses non-fast-forward and hands divergence to git-merge; never rebases, stashes, or forces.
---

# Goal

Bring a local branch up to date with `origin/<branch>` via fast-forward only. When the requested branch is the current HEAD the pull updates the working tree; otherwise the skill updates the local branch ref without checking it out.

# When NOT to use

* Local and remote have diverged: this skill STOPS and hands off to `git-merge` with `origin/<branch>` as the source.
* The user wants local commits published: `git-push`.
* The user wants remote state inspected without integrating anything: `git-fetch`.

# Procedure

Run every command in this skill through the `Bash` tool; the redirections used across this skill family are POSIX syntax and break under PowerShell.

1. **Resolve target branch.**
   * A branch named by the user in the current turn wins ("pull main", "pull feature/foo").
   * Else default to the current branch: `git symbolic-ref --short -q HEAD`. Empty output means detached; an unborn zero-commit branch prints its name normally.
   * If no name was given AND HEAD is detached, STOP and ask via `AskUserQuestion` which local branch to pull. Do not guess.

2. **Gather state for the target branch.** First batch, run in parallel:
   * `git status --short` (working-tree state).
   * `git fetch origin <branch>` (refresh the remote ref). Route a non-zero exit before proceeding:
     * `couldn't find remote ref` (exit 128): the branch has never been pushed, so there is nothing to pull. Say so, suggest `/git-push` to publish it, and STOP.
     * `'origin' does not appear to be a git repository`: the repo has no origin remote. Suggest `git remote add origin <url>` (user-run) and STOP; both transports work, so recommend whichever the machine is set up for (a credential manager favors HTTPS, a working ssh auth favors SSH; dual probe per `git-push` step 2).
     * Anything else (network, auth, proxy): surface stderr verbatim and STOP.

   Then, after the fetch completes, run in parallel:
   * `git log <branch>..origin/<branch> --oneline 2>/dev/null` (incoming commits).
   * `git log origin/<branch>..<branch> --oneline 2>/dev/null` (local-only commits).

   If `<branch>` does not exist locally, surface the error verbatim and stop.

3. **Classify and refuse on no-op or non-fast-forward.**
   * **Both lists empty**: already up to date with `origin/<branch>`. STOP and say so.
   * **Only local-only non-empty**: local is ahead, remote has nothing new. STOP; suggest `git-push` if they want to publish.
   * **Both lists non-empty (divergence)**: integration would need a non-fast-forward merge. STOP, show both lists, and hand off to `git-merge` with source=`origin/<branch>`, target=`<branch>`; its step 2 owns any checkout behind its own gate. This skill runs no checkout and never produces the merge commit itself.
   * **Only incoming non-empty**: fast-forward is possible; proceed.

4. **Handle dirty tree.**
   * Current HEAD equals the target AND `git status --short` non-empty: warn that local edits to files touched by the incoming commits will block the fast-forward, and offer `git-commit` first or abort. Do NOT stash.
   * Current HEAD differs from the target: the working tree is untouched; mention this in the plan output and proceed.

5. **Show the plan and confirm.** Display the commits about to land (`git log <branch>..origin/<branch> --oneline`) and the exact command, then ask via `AskUserQuestion` (**pull** / **abort**). A "pull" / "yes pull" / "go ahead" typed in the current turn counts as confirmation; ambiguous replies do not.
   * **Current HEAD == target**: `git merge --ff-only origin/<branch>` (step 2 already fetched).
   * **Current HEAD != target**: `git fetch . origin/<branch>:<branch>` (local-only refspec; step 2 already refreshed `origin/<branch>`, so no second network round-trip, and the bare `<branch>:<branch>` form stays fast-forward-only).

6. **Run the pull.** Execute the command exactly as displayed. Capture output verbatim.

7. **Handle failures. Do NOT retry blindly.**
   * **Non-fast-forward rejection** (a race between step 2 and step 6): re-fetch, surface the new divergence per step 3, stop, and hand off to `git-merge`.
   * **"Your local changes would be overwritten"**: surface verbatim, suggest `git-commit` first, stop. Do NOT auto-stash.
   * **Network or auth**: surface verbatim and stop.

8. **Report success.** Show:
   * The pulled range (`<old-sha>..<new-sha>`).
   * The target branch name, and whether the working tree was updated (current-HEAD case) or only the branch ref (off-HEAD case).
   * `git log --oneline -5 <branch>` so the user can confirm the new tip.

# Rationale

* **Fast-forward only**, so the skill can never invent history. Any merge commit the user needs is produced by `git-merge`, which carries the `.gitmessage` drafting flow and its own confirmation gate.
* **Off-HEAD targets use `git fetch . <ref>:<ref>` instead of a checkout**, so a branch the user is not standing on can be advanced without disturbing the working tree they are actually using.

# Hard rules

* NEVER use `--force`, `--rebase`, `+<branch>:<branch>`, or any flag that rewrites history. The skill is fast-forward only.
* NEVER auto-resolve a non-fast-forward by rebasing, merging another branch in, or stashing. Divergence means STOP-and-hand-off to `git-merge`.
* NEVER touch the working tree of a branch that is not the current HEAD. Use `git fetch <ref>:<ref>` for off-HEAD targets; never `git checkout` to switch first.
* NEVER skip the step 5 confirmation. Confirming the incoming commits is the safety net.
* NEVER draft a commit message here, and NEVER write one to a file (no `tmp/commit_msg.txt`, no `.git/COMMIT_EDITMSG` pre-population, no scratch file). When a merge commit is required, `git-merge` takes over and keeps its draft inline in chat only.
* NEVER allow an AI, agent, Claude, or Anthropic co-author trailer into any merge commit produced after this skill hands off. That message MUST follow `.gitmessage`, stay in concise bullet form, and stay human-authored.
* If the pull fails for any reason, report the failure verbatim. Let the user diagnose.
