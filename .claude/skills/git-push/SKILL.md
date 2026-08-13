---
name: git-push
description: Push a local branch to origin, defaulting to the current HEAD; the user may name any local branch in the current turn. Use for "push", "push main", "push feature/foo", publishing a branch, or sharing commits. Refuses force-push, non-fast-forward, and any push to a branch protected by the repo's declared workflow variant without an explicit in-turn opt-in.
---

# Goal

Publish a local branch to `origin` safely. The skill performs the push only.

# When NOT to use

* There is nothing committed yet: `git-commit`.
* The remote has commits the local branch lacks: `git-pull` (clean fast-forward) or `git-merge` (divergence), then re-run this skill.
* The user needs a new branch first: `git-branch-create`.

# Procedure

Run every command in this skill through the `Bash` tool; the redirections used across this skill family are POSIX syntax and break under PowerShell.

1. **Resolve target branch.**
   * A branch named by the user in the current turn wins ("push main", "push feature/foo").
   * Else default to the current branch: `git symbolic-ref --short -q HEAD`. Empty output means detached; an unborn zero-commit branch prints its name normally.
   * If no name was given AND HEAD is detached, STOP and ask via `AskUserQuestion` which local branch to push. Do not guess.

2. **Gather state.** First batch, run in parallel:
   * `git status --short` (working-tree state).
   * `git fetch origin <branch>` (refresh the remote ref). An exit 128 with `couldn't find remote ref` is NOT an error here: it is the first-push signal. Record it as such and skip the two `git log` range reads below (with no `origin/<branch>` ref they exit 128 and print nothing). An exit with `'origin' does not appear to be a git repository` means the repo has no origin remote: suggest `git remote add origin <url>` (user-run) and STOP. Both transports are fully supported; recommend whichever the machine is already set up for instead of holding a fixed preference. Probe both in parallel: `git config --get credential.helper` (a `manager` hit means the HTTPS form authenticates through the existing credential manager) and `ssh -o BatchMode=yes -o ConnectTimeout=5 -T git@github.com 2>&1` (a `successfully authenticated` greeting means the SSH form is ready; `Host key verification failed` or `Permission denied` means it is not, and the probe fails fast without prompting). Exactly one ready: recommend that form. Both ready: either works, let the user pick (SSH needs no browser or token prompts and suits headless use; HTTPS rides port 443 and needs no key management). Neither: HTTPS is the lower-setup path on Windows (Git for Windows ships the credential manager), and a locally-created repo can also be published from GitHub Desktop (Add local repository, then Publish), which wires an HTTPS origin automatically. Any other non-zero exit (network, auth, proxy): surface stderr verbatim and STOP.

   Then, when `origin/<branch>` exists after the fetch, run in parallel:
   * `git log origin/<branch>..<branch> --oneline 2>/dev/null` (commits about to land).
   * `git log <branch>..origin/<branch> --oneline 2>/dev/null` (remote-only commits; non-empty means non-fast-forward).

   In the first-push case, produce the about-to-land list with `git log <branch> --oneline` instead, capped at 20 lines with an overflow count; there is nothing remote-only to check.

   If `<branch>` does not exist locally the `git log` calls error out; surface that verbatim and stop.

3. **Protected-branch gate.** Read the `Workflow:` line in `.gitmessage`'s "Workflow Variant" section to get the protected set. When no variant is declared, or the line carries an unrecognized value (such as the shipped `<not recorded>` placeholder), assume `git-flow`; do not infer a permissive one here (`git-commit` owns inference and recording).

   | Variant | Protected set |
   |---|---|
   | `git-flow` | `main`, `develop`, `support/*` |
   | `github-flow` | `main`, `support/*` |
   | `trunk-solo` | none |

   This table is a convenience copy. `.gitmessage`'s "Protected Branches" section is normative; when the two disagree, follow `.gitmessage` and say so.

   If `<branch>` is in that set, require an explicit in-turn opt-in ("yes, push `<branch>` directly", "I'm intentionally pushing main"). Opt-ins from earlier turns do NOT carry over. Without one, refuse and explain the alternatives:
   * `main`: checkout main and invoke `git-merge` to integrate, then re-invoke this skill; or open a PR.
   * `develop` / `support/*`: the user must opt in explicitly.

   If the set is empty (`trunk-solo`), skip this gate entirely and proceed to step 4. Pushing the trunk is that variant's normal path; the step-7 confirmation still shows exactly what lands.

4. **Refuse on non-fast-forward.** If `git log <branch>..origin/<branch>` is non-empty, the remote has commits the local branch lacks. STOP, show both lists, and route by local state:
   * `git log origin/<branch>..<branch>` empty (no unpublished local commits): `/git-pull <branch>` fast-forwards cleanly; re-run this skill afterwards.
   * Both lists non-empty (diverged): hand off to `/git-merge` with source=`origin/<branch>`, target=`<branch>`; its step 2 owns any checkout behind its own gate. Re-run this skill afterwards.

5. **Refuse when nothing to push.** If the target has an upstream and `git log origin/<branch>..<branch>` is empty, tell the user the remote is already up to date and stop.

6. **Handle dirty tree.**
   * Current HEAD equals the target AND `git status --short` non-empty: warn that uncommitted changes will NOT be included, and offer `git-commit` first.
   * Current HEAD differs from the target: note in the plan output that uncommitted changes on the current HEAD are not part of this push, and proceed.

7. **Show the plan and confirm.** Display the commits about to land (the step-2 about-to-land list; on first push that is the capped `git log <branch> --oneline`, which MUST render non-empty) and the exact command, then ask via `AskUserQuestion` (**push** / **abort**). A "push" / "yes push" / "go ahead" typed in the current turn counts as confirmation; ambiguous replies do not.
   * **No upstream, current HEAD == target**: `git push -u origin <branch>` (sets tracking on first push).
   * **No upstream, current HEAD != target**: `git push origin <branch>:<branch>`; afterward advise `git branch --set-upstream-to=origin/<branch> <branch>` if they want tracking on the local ref.
   * **Has upstream, fast-forward**: `git push origin <branch>`.

8. **Run the push.** Execute the command exactly as displayed. Capture output verbatim.

9. **Handle failures. Do NOT retry blindly.**
   * **Server-side branch protection rejection**: surface the rule output. Do NOT attempt to bypass (no `--force`, no deploy-key swap). The user must disable the rule, push via a PR, or contact a maintainer.
   * **Non-fast-forward rejection** (a race between step 2 and step 8): re-fetch, surface the new divergence per step 4, stop.
   * **Auth, network, or hook**: surface the error verbatim and stop.

10. **Report success.** Show:
    * The pushed range (`<old-sha>..<new-sha>`), or `[new branch]` on first push.
    * Branch name and upstream, with the active workflow variant in parentheses (for example `main (trunk-solo)`). Naming it is what makes an unprotected trunk visible; without it a user has no way to notice that nothing is guarding `main`.
    * `git log --oneline -5 <branch>` so the user can confirm what is now on the remote.

# Hard rules

* NEVER use `--force` or `--force-with-lease` unless the user explicitly types the flag themselves in the current turn.
* NEVER push to a branch the active workflow variant protects without an explicit in-turn opt-in. Prior-turn approval does not carry over. The protected set comes from `.gitmessage`, and an undeclared or unrecognized variant value means `git-flow` (the strictest), never the most permissive.
* NEVER relax the protected set on inference alone. Only a `Workflow:` line in `.gitmessage`, or an in-turn statement from the user, changes it.
* NEVER auto-resolve a rejection (non-fast-forward, branch protection, hook failure) by force-pushing, rebasing destructively, deleting commits, or any other workaround. A rejection means STOP-and-explain.
* NEVER recommend `git pull --rebase` as the fix for a non-fast-forward. Rebase rewrites history and is forbidden across this skill family; route to `/git-pull` or `/git-merge` per step 4.
* NEVER skip the step 7 confirmation. Confirming the exact commits is the safety net.
* This skill does NOT commit, merge, rebase, or rescue commits onto another branch. Surface the situation and suggest the matching skill (`git-commit`, `git-merge`, `git-pull`, `git-branch-create`); let the user invoke it.
* If the push fails for any reason, report the failure verbatim. Let the user diagnose.
