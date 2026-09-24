---
name: git-pull
description: Fast-forward a local branch from origin, defaulting to the current HEAD; an off-HEAD target updates the branch ref only, never its working tree. Use for "pull", "pull main", "pull feature/foo", or updating a branch with new origin commits. Refuses non-fast-forward and suggests git-merge on divergence; never rebases, stashes, or forces.
compatibility: Requires git 2.22 or later and a POSIX shell (Git Bash on Windows).
---

# Goal

Bring a local branch up to date with `origin/<branch>` via fast-forward only. When the requested branch is the current HEAD the pull updates the working tree; otherwise the skill updates the local branch ref without checking it out.

# When NOT to use

* Local and remote have diverged: this skill STOPS and suggests `git-merge` with `origin/<branch>` as the source.
* The user wants local commits published: `git-push`.
* The user wants remote state inspected without integrating anything: `git-fetch`.

# Procedure

Terms such as choice question, independent reads, invoke, and suggest follow AGENTS.md (Skill authoring); in a non-interactive session every gate ends this skill.

Run every command in this skill in a POSIX shell; the redirections used across this skill family are POSIX syntax and break under PowerShell.

1. **Resolve target branch.**
   * A branch named by the user in the current turn wins ("pull main", "pull feature/foo").
   * Else default to the current branch: `git branch --show-current`. Empty output means detached; an unborn zero-commit branch prints its name normally. Unlike `git symbolic-ref --short HEAD`, it never prints a disambiguated `heads/<branch>` when a tag shares the branch name.
   * If no name was given AND HEAD is detached, STOP and ask with a choice question which local branch to pull. Do not guess.
   * **Name format check**, first, for a user-supplied `<branch>`: require `[ "$(git check-ref-format --branch "<branch>" 2>/dev/null)" = "<branch>" ]` (equality also rejects `@{-1}`, which the command expands) and that the name contains none of `*`, `?`, `[`. On failure, STOP: `<branch>` is not a valid branch name. Step 2 puts the name into a fetch refspec, where `feature/*` becomes a glob that force-updates every matching `origin/*` tracking ref.
   * **Exact name check**, before any other step, for `<branch>`, including the current branch (skip only when `<branch>` is the current branch and `git rev-parse --verify --quiet HEAD` prints nothing, as on an unborn branch): require `[ "$(git for-each-ref --format='%(refname)' "refs/heads/<branch>")" = "refs/heads/<branch>" ]`. On failure, list the names that match ignoring case: local branches (`git for-each-ref --format='%(refname:lstrip=2)' refs/heads/ | grep -ixF -- '<branch>'`) and the current branch, which may be unborn. Any match: STOP, name the matches, and ask for the exact name (for the current branch, suggest `git switch <exact-name>`); a case variant resolves to another branch's ref on a case-insensitive filesystem (Windows, default macOS). No match: `<branch>` does not exist locally in any case; continue to step 2, whose missing-branch route applies.

2. **Gather state for the target branch.** Local reads name the branch as `refs/heads/<branch>`: a tag sharing the short name would otherwise win, and `git log` then silently lists the tag's history. First batch. Run these independent reads:
   * `git status --short` (working-tree state).
   * `git rev-parse --verify --quiet refs/heads/<branch>` (local branch exists). No output means either an unborn branch (`<branch>` is the step-1 current branch and has zero commits) or a branch that does not exist locally.
   * `git fetch --no-tags origin +refs/heads/<branch>:refs/remotes/origin/<branch>` (refresh the remote ref). The explicit refspec writes `origin/<branch>` even in a `--single-branch` or shallow clone whose configured fetch refspec does not cover `<branch>`; its `+` force-updates only that remote-tracking ref, as the default refspec does, and `--no-tags` stops the tag auto-follow an explicit refspec would otherwise trigger. Route a non-zero exit before proceeding:
     * `couldn't find remote ref` (exit 128): `<branch>` is absent on origin, so there is nothing to pull. When the local probe found it, it was never pushed: say so, suggest `git-push` to publish it, and STOP. When the probe also missed, the name exists on neither side: say so and STOP.
     * `'origin' does not appear to be a git repository`: the repo has no origin remote. Suggest `git remote add origin <url>` (user-run) and STOP; both transports work, so recommend whichever the machine is set up for (a configured credential helper favors HTTPS, a working ssh auth favors SSH; dual probe per `git-push` step 2).
     * Anything else (network, auth, proxy): surface stderr verbatim and STOP.

   Route the local-branch probe before any range read, since a range read against a missing ref exits 128 with empty output that would look like "up to date":
   * **Missing locally, not the current branch** (only reached when the step-1 exact name check found no case variant): say `<branch>` has no local branch, render `git branch --track <branch> origin/<branch>` for the user to run themselves, and STOP. `git-branch-create` does not fit: it only creates new `<type>/...` names and refuses `main`, `develop`, and `support/*`. The created branch already sits at `origin/<branch>` with tracking set, so a re-run of this skill reports it up to date.
   * **Unborn current branch**: every commit on `origin/<branch>` is incoming and nothing is local-only. Read the incoming list with `git log origin/<branch> --oneline`, capped at 20 lines with an overflow count, and go to step 4 (step 3 does not apply).

   Otherwise, after the fetch completes, run these independent reads:
   * `git log refs/heads/<branch>..origin/<branch> --oneline` (incoming commits).
   * `git log origin/<branch>..refs/heads/<branch> --oneline` (local-only commits).

   A non-zero exit from either read is an error, never an empty list: surface it verbatim and stop.

3. **Classify and refuse on no-op or non-fast-forward.**
   * **Both lists empty**: already up to date with `origin/<branch>`. STOP and say so.
   * **Only local-only non-empty**: local is ahead, remote has nothing new. STOP; suggest `git-push` if they want to publish.
   * **Both lists non-empty (divergence)**: integration would need a non-fast-forward merge. STOP, show both lists, and suggest `git-merge` with source=`origin/<branch>`, target=`<branch>`; its step 2 owns any checkout behind its own gate. This skill runs no checkout and never produces the merge commit itself.
   * **Only incoming non-empty**: fast-forward is possible; proceed.

4. **Handle dirty tree.**
   * Current HEAD equals the target AND `git status --short` non-empty: warn that local edits to files touched by the incoming commits will block the fast-forward, and suggest `git-commit` first or abort. Do NOT stash.
   * Current HEAD differs from the target: the working tree is untouched; mention this in the plan output and proceed.
   * Unborn current branch: `--no-overwrite-ignore` does not protect a merge into an unborn branch, so list the incoming paths that already exist on disk, plus any parent directory of one that exists as a file or symlink (see Rationale). Any output: STOP, list them, and ask the user to move or back them up; never delete them.
     ```
     top=$(git rev-parse --show-toplevel) &&
     git ls-tree -r -z --full-tree --name-only refs/remotes/origin/<branch> | tr '\0' '\n' |
       while IFS= read -r p; do
         q=$p
         while :; do
           if [ -L "$top/$q" ] || { [ -e "$top/$q" ] && { [ "$q" = "$p" ] || [ ! -d "$top/$q" ]; }; }; then
             echo "file in the way: $q"; break
           fi
           case $q in */*) q=${q%/*} ;; *) break ;; esac
         done
       done | sort -u
     ```

5. **Show the plan and confirm.** Display the commits about to land (the step-2 incoming list) and the exact command, then ask with a choice question (**pull** / **abort**). A "pull" / "yes pull" / "go ahead" typed in the current turn counts as confirmation; ambiguous replies do not.
   * **Current HEAD == target**: `git merge --ff-only --no-overwrite-ignore refs/remotes/origin/<branch>` (step 2 already fetched). This also covers the unborn current branch, where it creates the branch at `origin/<branch>`. `--no-overwrite-ignore` makes the merge fail instead of silently replacing an ignored local file (such as `.env`) that the incoming commits track; `git status --short` never shows ignored files.
   * **Current HEAD != target**: `git fetch . origin/<branch>:refs/heads/<branch>` (local-only refspec; step 2 already refreshed `origin/<branch>`, so no second network round-trip, the full destination ref cannot be mistaken for a same-name tag, and without a leading `+` the refspec stays fast-forward-only).

6. **Run the pull.** Execute the command exactly as displayed. Capture output verbatim.

7. **Handle failures. Do NOT retry blindly.**
   * **Non-fast-forward rejection** (a race between step 2 and step 6): re-fetch, surface the new divergence per step 3, stop, and suggest `git-merge`.
   * **"Your local changes would be overwritten"**: surface verbatim, suggest `git-commit` first, stop. Do NOT auto-stash.
   * **"untracked working tree files would be overwritten"**: surface verbatim and stop. The listed files, often ignored ones such as `.env`, would be replaced by tracked versions; the user moves or backs them up first. Never delete them or drop `--no-overwrite-ignore`.
   * **Network or auth**: surface verbatim and stop.

8. **Report success.** Show:
   * The pulled range (`<old-sha>..<new-sha>`), or the new tip alone for an unborn branch.
   * The target branch name, and whether the working tree was updated (current-HEAD case) or only the branch ref (off-HEAD case).
   * `git log --oneline -5 refs/heads/<branch>` so the user can confirm the new tip.

# Rationale

* **Fast-forward only**, so the skill can never invent history. Any merge commit the user needs is produced by `git-merge`, which carries the `.gitmessage` drafting flow and its own confirmation gate.
* **Exact branch names.** On a case-insensitive filesystem, `refs/heads/Main` resolves to the loose ref file of `main`, so `pull Main` would read and write another branch under a name the user did not mean. `for-each-ref` reports only real ref names; the equality test is needed because it also matches every branch under a `refs/heads/<branch>/` hierarchy. The current branch is checked too: after `git checkout Main` with only `main` present, HEAD is `refs/heads/Main` and `git branch --show-current` prints `Main`, so the fast-forward would move `main` under the wrong name.
* **Parent paths in the unborn check.** An ignored local file `dd`, where origin adds `dd/inner`, sits at no incoming path itself, yet the fast-forward silently replaces it with a directory. The step-4 loop therefore walks up each incoming path and reports the first ancestor that exists as a non-directory or symlink.
* **Off-HEAD targets use `git fetch . origin/<branch>:refs/heads/<branch>` instead of a checkout**, so a branch the user is not standing on can be advanced without disturbing the working tree they are actually using.

# Hard rules

* NEVER use `--force`, `--rebase`, a `+` refspec that writes a local branch (`+<branch>:<branch>`), or any flag that rewrites history. The skill is fast-forward only; the step-2 `+refs/heads/<branch>:refs/remotes/origin/<branch>` updates only the remote-tracking ref.
* NEVER auto-resolve a non-fast-forward by rebasing, merging another branch in, or stashing. Divergence means STOP and suggest `git-merge`.
* NEVER act on a branch name, user-supplied or current, whose case variant the step-1 exact name check found, and NEVER put a name that fails the step-1 format check into a refspec.
* NEVER drop `--no-overwrite-ignore` from the step-5 fast-forward or skip the step-4 unborn-branch check, and never delete or move a file that blocks either; ignored files are user data.
* NEVER touch the working tree of a branch that is not the current HEAD. Use `git fetch . origin/<branch>:refs/heads/<branch>` for off-HEAD targets; never `git checkout` to switch first.
* NEVER skip the step 5 confirmation. Confirming the incoming commits is the safety net.
* NEVER draft a commit message here, and NEVER write one to a file (no `tmp/commit_msg.txt`, no `.git/COMMIT_EDITMSG` pre-population, no scratch file). When a merge commit is required, suggest `git-merge`, which keeps its draft inline in chat only.
* NEVER allow an AI tool, model, agent, or vendor co-author trailer into any merge commit produced by the `git-merge` run this skill suggests. That message MUST follow `.gitmessage`, stay in concise bullet form, and stay human-authored.
* If the pull fails for any reason, report the failure verbatim. Let the user diagnose.
