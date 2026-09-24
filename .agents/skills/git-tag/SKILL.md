---
name: git-tag
description: Create an annotated version tag (v<major>.<minor>.<patch>) on a merge commit or named commit per the repo's release flow, and optionally push it to origin, each behind its own choice-question gate. Use for "tag this release", "tag v1.2.0", "create the patch tag after the hotfix", or finishing a release/* or hotfix/* integration. Refuses to move, delete, or force-push tags, and to push a tag whose commit no origin branch contains.
compatibility: Requires git 2.22 or later and a POSIX shell (Git Bash on Windows).
---

# Goal

Create one annotated tag with a `.gitmessage`-compliant name on an explicitly identified commit, and optionally publish it to `origin` once an origin branch contains the tagged commit. This completes the `release/*` and `hotfix/*` flows in `.gitmessage`'s "Branch Types" section, which require a release or patch tag on `main` at the merge commit.

# When NOT to use

* The release branch is not merged yet: `git-merge` first, then return here to tag the merge commit.
* The user wants a tag moved or deleted: out of scope. A published tag is an immutable public promise; ship a new version instead. For a tag that was never pushed, render the `git tag -d <name>` command for the user to run themselves.
* The user wants branches published: `git-push` (it pushes branches only, never tags). A tag push waits for it: step 7 refuses to publish a tag whose commit is not yet on an origin branch.

# Prerequisites

Resolve before step 1:

1. **Tag name**: `v<major>.<minor>.<patch>` (for example `v1.4.0`), per `.gitmessage`'s "Tags" section. Pre-release suffixes (`v1.4.0-rc.1`) are allowed when the user names one. If the user proposes a name outside this scheme, suggest the corrected form and confirm with a choice question before using it.
2. **Target commit**: the commit being tagged. Named by the user, or defaulting to the tip of the integration trunk right after the `git-merge` run that suggested this skill. Never tag a moving reference conceptually: resolve to a SHA in step 2 and tag that.

# Procedure

Terms such as choice question, independent reads, invoke, and suggest follow AGENTS.md (Skill authoring); in a non-interactive session every gate ends this skill.

Run every command in this skill in a POSIX shell; the redirections and the heredoc are POSIX syntax and break under PowerShell.

1. **Read the spec.** Read `.gitmessage`'s "Tags" section for the naming scheme. Fall back to `v<major>.<minor>.<patch>` when absent.

2. **Gather state.** Run these independent reads:
   * `git rev-parse --verify '<target>^{commit}'` (resolve the target to a commit SHA; surface the verbatim error if it does not resolve). The `^{commit}` peel matters when `<target>` is itself a tag (promoting `v1.4.0-rc.2` to `v1.4.0`): without it the SHA is the tag object and step 6 would create a nested tag, whose only fix is the forbidden `git tag -f`.
   * `git rev-parse --verify --quiet refs/tags/<name>` (exact-name duplicate probe; any output means the tag already exists locally).
   * `git ls-remote origin refs/tags/<name> 'refs/tags/<name>^{}'` when `git remote` lists `origin` (the same probe against origin, for a tag published from another clone and never fetched here; a network failure is not fatal, note it and continue, since step 7 would surface the collision anyway).
   * `git -c versionsort.suffix=- tag --list 'v*' --sort=-v:refname` capped at 10 (recent versions; the `versionsort.suffix` setting ranks `v1.4.0-rc.1` below `v1.4.0`, which plain version sort puts above it, to inform the next number and the step-4 changelog range; NOT the duplicate check, since ten newest entries would miss an older name).
   * `git log -1 --format='%h %s' <target>` (what is being tagged, for the plan render).
   * `git branch -a --contains <target> --format='%(refname)'` (local AND remote-tracking branches that reach the commit, as full refs such as `refs/heads/main` and `refs/remotes/origin/main`, which stay unambiguous even when a tag shares a branch name; a local `main` lags behind a merge that landed on the server, so `origin/main` counts in step 3).

   If the tag name already exists, locally or on origin, STOP and report it with the commit it points at (`git rev-parse 'refs/tags/<name>^{commit}'` locally; for origin, the SHA on the `^{}` line, which an annotated tag has, else the SHA on the plain line). Never retarget. For an origin-only hit, suggest `git-fetch`, which brings the tag down so the two clones agree. One exception: when the tag exists locally, the origin probe succeeded and found nothing, and the user asked to push that tag (for example after a step-7 refusal), take `<sha>` from `git rev-parse 'refs/tags/<name>^{commit}'`, recompute the containment list for it with `git branch -a --contains <sha> --format='%(refname)'` (the list above describes `<target>`, which defaults to the trunk tip and may not be the tagged commit), run step 3 on that list (an off-trunk existing tag needs the same opt-in), then skip to step 7 with it.

3. **Sanity-check placement.** Release and patch tags belong on the trunk: if the step-2 containment list (recomputed, for the step-2 exception) includes neither `refs/heads/main` nor `refs/remotes/origin/main` (or the repo's equivalent trunk), surface that prominently in the plan. Tagging off-trunk is allowed only with an explicit in-turn opt-in (AGENTS.md) that names the off-trunk tag and its target, typed or by choosing an option whose label states both; a generic yes or earlier-turn approval does not count. When only `origin/main` contains the target, the placement is fine and the local `main` is merely behind; suggest `git-pull` with `main` as a follow-up, not a blocker, since the tag pins a SHA rather than a branch.

4. **Draft the tag message inline (no file).** One short line naming the release (for example `Release v1.4.0`), optionally followed by a blank line and one bullet per headline change since the previous tag (`git log <prev-tag>..<target> --oneline` is the fuel; skip the bullets for a patch tag with a single fix). Hold the draft in chat as a fenced code block.

5. **Show the plan and confirm with a choice question** (**tag** / **edit** / **abort**). Render the tag name, the target SHA and subject, the containment note from step 3, and the exact command:
   ```
   git tag -a <name> <sha> -F - <<'TAG_MSG_EOF'
   <approved message substituted verbatim>
   TAG_MSG_EOF
   ```
   The quoted heredoc terminator prevents shell expansion; if the draft contains a line equal to `TAG_MSG_EOF`, pick a fresh terminator absent from the body. **edit** loops on free-text changes like the other skills in this family.

6. **Create the tag.** Execute the approved command verbatim. On failure, surface the error verbatim and stop.

7. **Offer the push separately.** Skip this step and stay local when the repo has no `origin` remote (`git remote` does not list it).

   First check that the tagged commit is published. Pushing a tag also uploads every commit it reaches, so a tag on an unpushed commit would publish that commit (for example a local merge into `main`) past `git-push`'s protected-branch gate. Refresh the candidate branches with one targeted fetch per branch: `main` (or the repo's equivalent trunk) plus every `refs/remotes/origin/<b>` in the step-2 containment list (for the step-2 exception, the list recomputed for the existing tag's commit):
   ```
   git fetch --no-tags origin +refs/heads/<b>:refs/remotes/origin/<b>
   ```
   An exit 128 with `couldn't find remote ref` means `<b>` is gone from origin: drop it, since its lingering `origin/<b>` is stale. Any other non-zero exit (network, auth, proxy): surface stderr verbatim, skip the question, and stay local. For each refreshed branch, run `git merge-base --is-ancestor <sha> refs/remotes/origin/<b>` (exit 0 contains, exit 1 does not, anything else is an error to surface).
   * **No refreshed branch contains `<sha>`**: refuse the tag push; do not ask the question below. Say the tag stays local because its commit is on no origin branch, and suggest `git-push` for the branch that holds it (usually `main`), so that skill's protected-branch gate decides whether the commit may land. Once it has, the user can ask this skill to push `<name>` (the step-2 exception brings them back here, and the check runs again).
   * **At least one contains it**: ask with a choice question (**push tag** / **local only**):
     * **push tag**: `git push --no-follow-tags origin refs/tags/<name>` (the single tag ref only; the full ref avoids a `matches more than one` failure when a branch shares the name, and `--no-follow-tags` stops a `push.followTags=true` config from publishing every other annotated tag reachable from this one). On rejection, surface the error verbatim and stop; never retry with `--force`.
     * **local only**: done; note that asking this skill to push `<name>` later publishes it after the same check.

8. **Report.** Show `git log -1 --format='%h %s' refs/tags/<name>` (this peels the annotated tag to its commit; `git show` would print the tag object header first), the tag message, whether it was pushed, and the natural next step from `.gitmessage`'s flow. Under `git-flow`, suggest `git-merge` to back-merge the tagged branch into `develop`; for a `hotfix/*` tag, also into every active `release/*` branch. Then suggest `git-branch-delete` for the short-lived branch.

# Rationale

* **Annotated only.** An annotated tag carries author, date, and message, which is what a release pin needs; lightweight tags are local bookmarks and invisible to `git describe` by default.
* **The push is a separate gate**, mirroring `git-branch-delete`'s scope question: creating a local tag is cheap to undo before publication, pushing it makes it a public promise every clone sees.
* **Resolving the target to a SHA before tagging** removes the race where the branch tip moves between the plan render and the execution.
* **A tag push waits for its commit to be on an origin branch.** `git push` of a tag uploads the commits it points at, so without the step-7 check a tag on a local-only merge would publish that merge while bypassing the protected-branch gate that `git-push` applies to the branch itself.

# Hard rules

* NEVER pass `-f`/`--force` to `git tag`, and NEVER delete or retarget an existing tag, locally or on origin. A wrong published tag is corrected by publishing a new version, not by rewriting.
* NEVER push with `--tags` (it sweeps every local tag) or `--follow-tags`, and always pass `--no-follow-tags` so `push.followTags` config cannot do the same. Push exactly the one approved tag as `refs/tags/<name>`.
* NEVER create a lightweight tag. `git tag -a` (or `-s` when the user asks for signing) only.
* NEVER write the tag message to a file on disk. It lives only in the chat conversation and the heredoc that feeds `git tag -F -`, mirroring the discipline of `git-commit` and `git-merge`.
* NEVER add an AI tool, model, agent, or vendor attribution to the tag message.
* NEVER skip the step 5 confirmation, and NEVER fold the push into it; steps 5 and 7 are separate decisions with different blast radii.
* NEVER create or push an off-trunk tag, new or existing, without the step-3 explicit in-turn opt-in.
* NEVER push a tag whose commit no refreshed origin branch contains (step 7). Suggest `git-push` for the branch first; never push the branch from here.
* NEVER merge, commit, push branches, or delete branches from this skill. Suggest the matching skill without running it.
