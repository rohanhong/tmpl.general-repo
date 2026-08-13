---
name: git-tag
description: Create an annotated version tag (v<major>.<minor>.<patch>) on a merge commit or named commit per the repo's release flow, and optionally push it to origin, each behind its own AskUserQuestion gate. Use for "tag this release", "tag v1.2.0", "create the patch tag after the hotfix", or finishing a release/* or hotfix/* integration. Refuses to move, delete, or force-push tags.
---

# Goal

Create one annotated tag with a `.gitmessage`-compliant name on an explicitly identified commit, and optionally publish it to `origin`. This completes the `release/*` and `hotfix/*` flows in `.gitmessage`'s "Branch Types" section, which require a release or patch tag on `main` at the merge commit.

# When NOT to use

* The release branch is not merged yet: `git-merge` first, then return here to tag the merge commit.
* The user wants a tag moved or deleted: out of scope. A published tag is an immutable public promise; ship a new version instead. For a tag that was never pushed, render the `git tag -d <name>` command for the user to run themselves.
* The user wants branches published: `git-push` (it pushes branches only, never tags).

# Prerequisites

Resolve before step 1:

1. **Tag name**: `v<major>.<minor>.<patch>` (for example `v1.4.0`), per `.gitmessage`'s "Tags" section. Pre-release suffixes (`v1.4.0-rc.1`) are allowed when the user names one. If the user proposes a name outside this scheme, suggest the corrected form and confirm via `AskUserQuestion` before using it.
2. **Target commit**: the commit being tagged. Named by the user, or defaulting to the tip of the integration trunk right after a `git-merge` handoff. Never tag a moving reference conceptually: resolve to a SHA in step 2 and tag that.

# Procedure

Run every command in this skill through the `Bash` tool; the redirections and the heredoc are POSIX syntax and break under PowerShell.

1. **Read the spec.** Read `.gitmessage`'s "Tags" section for the naming scheme. Fall back to `v<major>.<minor>.<patch>` when absent.

2. **Gather state.** Run in parallel:
   * `git rev-parse --verify <target>` (resolve the target to a SHA; surface the verbatim error if it does not resolve).
   * `git tag --list 'v*' --sort=-v:refname` capped at 10 (existing versions; catches duplicates and informs the next number).
   * `git log -1 --format='%h %s' <target>` (what is being tagged, for the plan render).
   * `git branch --contains <target> --format='%(refname:short)'` (which branches reach the commit).

   If the tag name already exists, STOP and report it with its current target (`git rev-parse <tag>`). Never retarget.

3. **Sanity-check placement.** Release and patch tags belong on the trunk: if the step-2 containment list does not include `main` (or the repo's equivalent trunk), surface that prominently in the plan. Tagging off-trunk is allowed only after the user explicitly confirms the anomaly in the current turn.

4. **Draft the tag message inline (no file).** One short line naming the release (for example `Release v1.4.0`), optionally followed by a blank line and one bullet per headline change since the previous tag (`git log <prev-tag>..<target> --oneline` is the fuel; skip the bullets for a patch tag with a single fix). Hold the draft in chat as a fenced code block.

5. **Show the plan and confirm via `AskUserQuestion`** (**tag** / **edit** / **abort**). Render the tag name, the target SHA and subject, the containment note from step 3, and the exact command:
   ```
   git tag -a <name> <sha> -F - <<'TAG_MSG_EOF'
   <approved message substituted verbatim>
   TAG_MSG_EOF
   ```
   The quoted heredoc terminator prevents shell expansion; if the draft contains a line equal to `TAG_MSG_EOF`, pick a fresh terminator absent from the body. **edit** loops on free-text changes like the other skills in this family.

6. **Create the tag.** Execute the approved command verbatim. On failure, surface the error verbatim and stop.

7. **Offer the push separately.** Ask via `AskUserQuestion` (**push tag** / **local only**):
   * **push tag**: `git push origin <name>` (the single tag ref only). On rejection, surface the error verbatim and stop; never retry with `--force`.
   * **local only**: done; note that `git push origin <name>` publishes it later.

   Skip this question and stay local when the repo has no `origin` remote (`git remote` does not list it).

8. **Report.** Show `git log -1 --format='%h %s' <name>` (this peels the annotated tag to its commit; `git show` would print the tag object header first), the tag message, whether it was pushed, and the natural next step from `.gitmessage`'s flow (for a `release/*` or `hotfix/*` tag: back-merge into `develop` via `git-merge` under `git-flow`, then `git-branch-delete` the short-lived branch).

# Rationale

* **Annotated only.** An annotated tag carries author, date, and message, which is what a release pin needs; lightweight tags are local bookmarks and invisible to `git describe` by default.
* **The push is a separate gate**, mirroring `git-branch-delete`'s scope question: creating a local tag is cheap to undo before publication, pushing it makes it a public promise every clone sees.
* **Resolving the target to a SHA before tagging** removes the race where the branch tip moves between the plan render and the execution.

# Hard rules

* NEVER pass `-f`/`--force` to `git tag`, and NEVER delete or retarget an existing tag, locally or on origin. A wrong published tag is corrected by publishing a new version, not by rewriting.
* NEVER push with `--tags` (it sweeps every local tag) or `--follow-tags`. Push exactly the one approved tag by name.
* NEVER create a lightweight tag. `git tag -a` (or `-s` when the user asks for signing) only.
* NEVER write the tag message to a file on disk. It lives only in the chat conversation and the heredoc that feeds `git tag -F -`, mirroring the discipline of `git-commit` and `git-merge`.
* NEVER add an AI, agent, Claude, or Anthropic attribution to the tag message.
* NEVER skip the step 5 confirmation, and NEVER fold the push into it; steps 5 and 7 are separate decisions with different blast radii.
* NEVER merge, commit, push branches, or delete branches from this skill. Suggest the matching skill and let the user invoke it.
