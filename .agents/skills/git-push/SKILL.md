---
name: git-push
description: Push a local branch to origin, defaulting to the current HEAD; the user may name any local branch in the current turn. Use for "push", "push main", "push feature/foo", publishing a branch, or sharing commits. Refuses non-fast-forward, force-push on main, develop, or support/*, force-push elsewhere without an explicit in-turn opt-in, and any push to a branch protected by the repo's declared workflow variant without an explicit in-turn opt-in.
compatibility: Requires git 2.22 or later and a POSIX shell (Git Bash on Windows).
---

# Goal

Publish a local branch to `origin` safely. The skill performs the push only.

# When NOT to use

* There is nothing committed yet: `git-commit`.
* The remote has commits the local branch lacks: `git-pull` (clean fast-forward) or `git-merge` (divergence), then re-run this skill.
* The user needs a new branch first: `git-branch-create`.

# Procedure

Terms such as choice question, independent reads, invoke, and suggest follow AGENTS.md (Skill authoring); in a non-interactive session every gate ends this skill.

Run every command in this skill in a POSIX shell; the redirections used across this skill family are POSIX syntax and break under PowerShell.

1. **Resolve target branch.**
   * A branch named by the user in the current turn wins ("push main", "push feature/foo").
   * Else default to the current branch: `git branch --show-current`. Empty output means detached; an unborn zero-commit branch prints its name normally. Unlike `git symbolic-ref --short HEAD`, it never prints a disambiguated `heads/<branch>` when a tag shares the branch name.
   * If no name was given AND HEAD is detached, STOP and ask with a choice question which local branch to push. Do not guess.
   * **Exact name check**, before any other step, for `<branch>`, including the current branch (skip only when `<branch>` is the current branch and `git rev-parse --verify --quiet HEAD` prints nothing, as on an unborn branch): require `[ "$(git for-each-ref --format='%(refname)' "refs/heads/<branch>")" = "refs/heads/<branch>" ]`. On failure, STOP: list the local branches whose names match ignoring case (`git for-each-ref --format='%(refname:lstrip=2)' refs/heads/ | grep -ixF -- '<branch>'`), or say there is no local `<branch>`. When `<branch>` is the current branch, suggest `git switch <exact-name>`. See Rationale.

2. **Gather state.** Local reads name the branch as `refs/heads/<branch>`: a tag sharing the short name would otherwise win, and `git log` then silently lists the tag's history. First batch. Run these independent reads:
   * `git status --short` (working-tree state).
   * `git remote get-url origin` and `git remote get-url --push --all origin` (the fetch URL, and every URL the push goes to after `pushurl` and `pushInsteadOf`). Exit 2 means no origin; the fetch below handles that. Compare them after normalizing each URL with this function, so spellings of one repository (`C:/x/o.git` and `/c/x/o.git` in Git Bash, a trailing `/` or `.git`) match:
     ```
     norm() { u=${1%/}; case $u in file://*) u=${u#file://} ;; esac
       for d in "$u" "$u.git"; do r=$(CDPATH= cd "$d" 2>/dev/null && pwd -P) && { printf '%s\n' "$r"; return; }; done
       printf '%s\n' "${u%.git}"; }
     ```
     A local path becomes its resolved directory; any other URL keeps its spelling minus one trailing `/` and `.git`. When any normalized push URL differs from the normalized fetch URL, every read here describes the fetch side only: record the split for step 7.
   * `git rev-parse --verify --quiet refs/heads/<branch>` (local branch exists). No output means there is nothing to push: an unborn current branch has no commits yet (suggest `git-commit`), and any other name has no local branch (say so). STOP in both cases, before any range read; a range read against a missing ref exits 128 with empty output that step 5 would misread as "up to date".
   * `git fetch --no-tags origin +refs/heads/<branch>:refs/remotes/origin/<branch>` (refresh the remote ref). The explicit refspec writes `origin/<branch>` even in a `--single-branch` or shallow clone whose configured fetch refspec does not cover `<branch>`; its `+` force-updates only that remote-tracking ref, as the default refspec does, and `--no-tags` stops the tag auto-follow an explicit refspec would otherwise trigger. An exit 128 with `couldn't find remote ref` is NOT an error here: the branch is absent on origin, either never pushed (first push) or deleted there after an earlier push (a merged PR with auto-delete, or a teammate's cleanup). Tell the two apart with `git rev-parse --verify --quiet origin/<branch>`: a hit after that failed fetch is a STALE remote-tracking ref (a failed fetch never prunes), and it no longer describes anything on the server. Record both shapes as the first-push case and skip the two `git log` range reads below; without the ref they exit 128 and print nothing, and against a stale ref the about-to-land list comes back empty and step 5 would wrongly report the remote as up to date. An exit with `'origin' does not appear to be a git repository` means the repo has no origin remote: suggest `git remote add origin <url>` (user-run) and STOP. Both transports are fully supported; recommend whichever the machine is already set up for instead of holding a fixed preference. Take `<host>` from the URL the user supplies (for example `github.com` from `git@github.com:owner/repo.git` or `https://github.com/owner/repo.git`); when no URL is known yet, ask for it. Run these independent reads: `git config --get credential.helper` (any non-empty value, such as `manager`, `osxkeychain`, `libsecret`, `store`, or `cache`, means the HTTPS form has a helper to authenticate through) and `ssh -o BatchMode=yes -o ConnectTimeout=5 -T git@<host> 2>&1` (exit 255 is ssh's own failure, such as `Permission denied`, `Host key verification failed`, or a timeout, and means the SSH form is not ready; any other exit, typically 0 or 1 with a greeting from the host, means the key authenticated; `BatchMode` makes it fail fast without prompting). Exactly one ready: recommend that form. Both ready: either works, let the user pick (SSH needs no browser or token prompts and suits headless use; HTTPS rides port 443 and needs no key management). Neither: HTTPS is usually the lower-setup path once a credential helper is configured (Git Credential Manager ships with Git for Windows and is available for macOS and Linux; `osxkeychain` ships with git on macOS); otherwise generate an SSH key and register it with the host. Any other non-zero exit (network, auth, proxy): surface stderr verbatim and STOP.

   Then, when the fetch succeeded (so `origin/<branch>` is current), run these independent reads:
   * `git log origin/<branch>..refs/heads/<branch> --oneline` (commits about to land).
   * `git log refs/heads/<branch>..origin/<branch> --oneline` (remote-only commits; non-empty means non-fast-forward).

   In the first-push case, produce the about-to-land list with `git log refs/heads/<branch> --oneline --not --exclude=origin/<branch> --remotes=origin` instead, capped at 20 lines with an overflow count; there is nothing remote-only to check. It lists only the commits no `origin/*` ref in this clone already reaches, so a branch cut from `main` does not re-list the whole trunk history. The `--exclude` (which must come before `--remotes`) drops a stale `origin/<branch>`, whose commits the server no longer holds on that branch; it is a no-op when that ref does not exist. An empty list is valid: the push only creates `<branch>` on origin at a commit origin already has. With a stale ref, add one line to the step-7 plan: `origin/<branch>` is stale, the remote branch is gone, and this push re-creates it (the push refreshes the ref; `git-fetch` prunes stale refs in bulk). When the branch vanished because its PR merged, re-creating it is usually not what the user wants: say so, and suggest `git-branch-delete` for the local leftover.

   A non-zero exit from any of these reads is an error, never an empty list: surface it verbatim and stop.

3. **Protected-branch gate.** Read the `Workflow:` line in `.gitmessage`'s "Workflow Variant" section to get the protected set. When no variant is declared, or the line carries an unrecognized value (such as the shipped `<not recorded>` placeholder), assume `git-flow`; do not infer a permissive one here. Nothing infers the variant: `git-commit` and `repo-init` ask the user and offer to record the answer.

   | Variant | Protected set |
   |---|---|
   | `git-flow` | `main`, `develop`, `support/*` |
   | `github-flow` | `main`, `support/*` |
   | `trunk-solo` | none |

   This table is a convenience copy. `.gitmessage`'s "Protected Branches" section is normative; when the two disagree, follow `.gitmessage` and say so.

   Compare names ignoring case: `Main`, `DEVELOP`, and `Support/x` count as protected (see Rationale). If `<branch>` is in that set, require an explicit in-turn opt-in as AGENTS.md defines it: a reply in the current turn that names the direct push and `<branch>`, typed (such as "yes, push `<branch>` directly") or by choosing an option whose label states both. A generic yes, or an opt-in from an earlier turn, does NOT count. Without one, refuse and explain the alternatives:
   * Land the commits through a PR or MR instead: move them onto a short-lived branch (`git-branch-create`), push that branch with this skill, and open the PR or MR against `<branch>`.
   * Or re-ask with the explicit in-turn opt-in above. Merging locally first does not help: `<branch>` stays protected, and `git-merge` gates a protected target the same way.

   If the set is empty (`trunk-solo`), skip this gate entirely and proceed to step 4. Pushing the trunk is that variant's normal path; the step-7 confirmation still shows exactly what lands.

4. **Refuse on non-fast-forward.** If `git log refs/heads/<branch>..origin/<branch>` is non-empty, the remote has commits the local branch lacks. STOP, show both lists, and choose the suggestion by local state:
   * `git log origin/<branch>..refs/heads/<branch>` empty (no unpublished local commits): suggest `git-pull` with `<branch>`, which fast-forwards cleanly; re-run this skill afterwards.
   * Both lists non-empty (diverged): suggest `git-merge` with source=`origin/<branch>`, target=`<branch>`; its step 2 owns any checkout behind its own gate. Re-run this skill afterwards.

5. **Refuse when nothing to push.** If the step-2 fetch succeeded and `git log origin/<branch>..refs/heads/<branch>` is empty, tell the user the remote is already up to date and stop. This never applies to the first-push case, stale ref included: an upstream configured on the local branch says nothing about whether the remote branch still exists.

6. **Handle dirty tree.**
   * Current HEAD equals the target AND `git status --short` non-empty: warn that uncommitted changes will NOT be included, and suggest `git-commit` first.
   * Current HEAD differs from the target: note in the plan output that uncommitted changes on the current HEAD are not part of this push, and proceed.

7. **Show the plan and confirm.** Display the commits about to land (the step-2 about-to-land list; on first push that is the capped `git log refs/heads/<branch> --oneline --not --exclude=origin/<branch> --remotes=origin`; when it is empty, say instead that the push creates `<branch>` on origin at `<sha>` with no new commits) and the exact command, then ask with a choice question (**push** / **abort**). A "push" / "yes push" / "go ahead" typed in the current turn counts as confirmation; ambiguous replies do not.
   * **Split push URL** (step 2): show the fetch URL and each push URL above the command, say the commit lists were read from the fetch side, and label the confirm option `push to <push-url>`; a typed reply must name that URL, and a bare "push" does not count.
   * **First push (never pushed, or re-publish after a remote delete), current HEAD == target**: `git push --no-follow-tags -u origin refs/heads/<branch>:refs/heads/<branch>` (sets or refreshes tracking to `origin/<branch>`).
   * **First push, current HEAD != target**: `git push --no-follow-tags origin refs/heads/<branch>:refs/heads/<branch>`; afterward advise `git branch --set-upstream-to=origin/<branch> <branch>` if they want tracking on the local ref.
   * **Remote branch present, fast-forward**: `git push --no-follow-tags origin refs/heads/<branch>:refs/heads/<branch>`.

   The full-ref refspec is always present: a bare `<branch>` fails with `src refspec <branch> matches more than one` when a tag shares the name. `--no-follow-tags` is always present: a user-level `push.followTags=true` would otherwise publish every annotated tag reachable from the pushed commits, bypassing `git-tag`'s separate push gate.

8. **Run the push.** Execute the command exactly as displayed. Capture output verbatim.

9. **Handle failures. Do NOT retry blindly.**
   * **Server-side branch protection rejection**: surface the rule output. Do NOT attempt to bypass (no `--force`, no deploy-key swap). The user must disable the rule, push via a PR, or contact a maintainer.
   * **Non-fast-forward rejection** (a race between step 2 and step 8): re-fetch, surface the new divergence per step 4, stop.
   * **Auth, network, or hook**: surface the error verbatim and stop.

10. **Report success.** Show:
    * The pushed range (`<old-sha>..<new-sha>`), or `[new branch]` on first push.
    * Branch name and upstream, with the active workflow variant in parentheses (for example `main (trunk-solo)`). Naming it is what makes an unprotected trunk visible; without it a user has no way to notice that nothing is guarding `main`.
    * `git log --oneline -5 refs/heads/<branch>` so the user can confirm what is now on the remote.

# Rationale

* **Exact branch names.** On a case-insensitive filesystem (Windows, default macOS), `refs/heads/Main` resolves to the loose ref file of `main`, so `push Main` would publish `main`'s commits (as a new `Main` on a case-sensitive forge, or moving `main` on a case-insensitive one) while a literal protected-name check sees `Main` and passes it. `for-each-ref` reports only real ref names; the equality test is needed because it also matches every branch under a `refs/heads/<branch>/` hierarchy. The current branch is checked too: after `git checkout Main` with only `main` present, HEAD is `refs/heads/Main`, `git branch --show-current` prints `Main`, and a push of `refs/heads/Main` would move `main` on a case-insensitive origin. Comparing protected names ignoring case covers a real branch whose name differs from a protected one only in case.
* **Push destination.** Every push command names `origin` explicitly, so `branch.<b>.pushRemote` and `remote.pushDefault` never redirect it; only origin's own push URLs (`remote.origin.pushurl`, a `pushInsteadOf` rewrite, or several `url` entries) do, which is why step 2 compares them with the fetch URL. It compares normalized forms, since flagging a mere respelling would teach users to wave the split gate through. With a split, the step-2 fetch and range reads describe the fetch side while the push lands elsewhere, so the gate names the push URL.

# Hard rules

* NEVER use `--force` or `--force-with-lease` on `main`, `develop`, or `support/*`, under any workflow variant and with or without an opt-in: `.gitmessage` forbids force push and history rewrite there, including under `trunk-solo`. On other branches, where `.gitmessage` permits it (`feature/*`, `bugfix/*`, `hotfix/*`, and `release/*` before its first release tag), use either flag only with an explicit in-turn opt-in (AGENTS.md) that names the flag and `<branch>`; a generic yes or earlier-turn approval does not count. The `+` on the step-2 fetch refspec is not a push force: it updates only the `origin/<branch>` remote-tracking ref.
* NEVER push tags from this skill. Every push command carries `--no-follow-tags`, so `push.followTags` config cannot sweep tags along; tags go through `git-tag`.
* NEVER push to a branch the active workflow variant protects without an explicit in-turn opt-in naming the direct push and the branch. A generic yes or prior-turn approval does not count. The protected set comes from `.gitmessage`, names match it ignoring case, and an undeclared or unrecognized variant value means `git-flow` (the strictest), never the most permissive.
* NEVER act on a branch name, user-supplied or current, that fails the step-1 exact name check.
* NEVER relax the protected set on inference alone. Only a `Workflow:` line in `.gitmessage`, or an in-turn statement from the user, changes it.
* NEVER auto-resolve a rejection (non-fast-forward, branch protection, hook failure) by force-pushing, rebasing destructively, deleting commits, or any other workaround. A rejection means STOP-and-explain.
* NEVER recommend `git pull --rebase` as the fix for a non-fast-forward. Rebase rewrites history and is forbidden across this skill family; suggest `git-pull` or `git-merge` per step 4.
* NEVER skip the step 7 confirmation. Confirming the exact commits is the safety net.
* This skill does NOT commit, merge, rebase, or rescue commits onto another branch. Surface the situation and suggest the matching skill (`git-commit`, `git-merge`, `git-pull`, `git-branch-create`) without running it.
* If the push fails for any reason, report the failure verbatim. Let the user diagnose.
