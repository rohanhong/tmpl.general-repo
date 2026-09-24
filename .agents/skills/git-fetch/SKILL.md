---
name: git-fetch
description: Refresh origin's branches and tags, then report how the current branch stands against the repo's integration trunk and its own upstream. Use for "what is new on origin", "am I behind main", or an ahead/behind check before deciding what to run next. Read-only apart from remote-tracking refs; never merges, pulls, checks out, or invokes another skill.
compatibility: Requires git 2.22 or later and a POSIX shell (Git Bash on Windows).
---

# Goal

Refresh `refs/remotes/origin/*` and tags from `origin`, then print one tight report describing how the current branch stands against the new remote state.

# When NOT to use

* The user wants remote commits integrated: `git-pull` for a clean fast-forward, `git-merge` for divergence.
* The user wants local commits published: `git-push`.
* The user wants a branch cut from a refreshed base: `git-pull` with `<base>` owns the refresh, then `git-branch-create`.

# Procedure

Terms such as choice question, independent reads, invoke, and suggest follow AGENTS.md (Skill authoring); in a non-interactive session every gate ends this skill.

Run every command in this skill in a POSIX shell; the redirections used across this skill family are POSIX syntax and break under PowerShell.

1. **Capture current branch state.** Run these independent reads:
   * `git branch --show-current` (current branch; empty output when detached, and an unborn zero-commit branch prints its name normally).
   * `git status --short` (dirty marker for the report banner only; does NOT change behaviour).

   The upstream is read in step 4, after the fetch: the step-2 `--prune` can delete the very remote-tracking ref an earlier read would have resolved.

2. **Fetch.** Run exactly:
   ```
   git fetch origin --prune --tags --no-prune-tags '+refs/heads/*:refs/remotes/origin/*'
   ```
   `--prune` drops local `refs/remotes/origin/*` entries whose remote counterparts are gone; `--tags` pulls release tags; `--no-prune-tags` keeps a `fetch.pruneTags` or `remote.origin.pruneTags` setting from deleting local-only tags. The explicit refspec refreshes every origin branch even in a single-branch or shallow clone, whose configured refspec covers one branch only, so `origin/<trunk>` exists and is current. Capture stderr: it lists new branches and pulled tags inline (`* [new branch]`, `* [new tag]`) and the step-5 report consumes that capture directly. Route a non-zero exit: `'origin' does not appear to be a git repository` means the repo has no origin remote, so suggest `git remote add origin <url>` (user-run; both transports work, recommend whichever the machine is set up for per the dual probe in `git-push` step 2) and STOP; anything else (network, auth, proxy), surface stderr verbatim and STOP. No retry, no credential helper, no fallback.

3. **Resolve the integration trunk.** Read the `Workflow:` line in `.gitmessage`'s "Workflow Variant" section. Under `git-flow` the trunk is `develop` (fall back to `main` when `origin/develop` does not exist); under `github-flow` and `trunk-solo` it is `main`. When no variant is declared, or the line carries an unrecognized value (such as the shipped `<not recorded>` placeholder), assume `git-flow`. Comparing a feature branch against `origin/<trunk>` in a git-flow repo answers the wrong question, because work integrates into `develop` first.

4. **Compute ahead / behind counts.** On a zero-commit repository (unborn branch), `HEAD` resolves to nothing and every comparison below fails: skip them all and render the report with the remote-state sections only (new branches, tags), noting "no local commits yet". Otherwise resolve two refs first:
   * `git rev-parse --abbrev-ref @{u} 2>/dev/null` (post-fetch upstream). Decide by the exit code, never by stdout: exit 0 prints the upstream; on failure there is no usable upstream, and when a configured upstream was pruned (for example a merged PR deleted it on origin) git still prints the literal `@{u}` to stdout. The `2>/dev/null` only hides the message; it does not change the exit code, which alone picks the branch below. On failure, run `git config --get branch.<current>.merge` (skip it when detached). Exit 0 means an upstream is configured and prints its remote ref; confirm it is gone with `git ls-remote --exit-code origin <merge-ref>` before rendering "upstream deleted on origin" in the upstream block: exit 2 confirms it; exit 0 means it still exists on origin, so render "upstream present on origin, no tracking ref" instead; any other exit, surface stderr and render "upstream unverified". A non-zero `git config` exit renders "no upstream tracking".
   * `git rev-parse --verify --quiet refs/remotes/origin/<trunk>` (empty output means origin has no such branch: render "origin/`<trunk>` not found" in the trunk block and skip the two trunk reads below; the full ref name keeps a same-name tag from answering).

   Then run these independent reads of post-fetch refs:
   * `git rev-list --left-right --count HEAD...@{u}` (only when the upstream read above exited 0).
   * `git rev-list --left-right --count HEAD...refs/remotes/origin/<trunk>` (skip when the current branch IS the trunk; the upstream block already covers it).
   * `git log --oneline HEAD..refs/remotes/origin/<trunk>` capped at 10 lines.

5. **Render the report** per the Reference layout below.

# Reference: report layout

Every field is required; empty data renders the right-column phrase so the layout stays uniform.

| Field | Empty-state phrase |
|---|---|
| current branch line | always present |
| dirty marker | omit when working tree clean |
| vs upstream block | "no upstream tracking" when no `@{u}`; "upstream deleted on origin" when one is configured and `git ls-remote` confirms it absent; "upstream present on origin, no tracking ref" or "upstream unverified" per step 4 |
| vs origin/`<trunk>` block | always present (omit only when the current branch IS the trunk); "origin/`<trunk>` not found" when the ref does not resolve |
| new remote branches list | "none" |
| incoming commits on origin/`<trunk>` | "already up to date with origin/`<trunk>`" |
| tags pulled this fetch | "none" |

Example with `<trunk>` resolved to `develop` (a `git-flow` repo):

```
## fetch report
Fetched: origin (prune + tags)

Current branch: feature/x/y    (dirty: 3 files unstaged)
- vs upstream origin/feature/x/y : ahead 2, behind 0
- vs origin/develop              : ahead 5, behind 3

New remote branches:
  + origin/feature/new-thing

Incoming on origin/develop (HEAD..origin/develop, last 10):
  abcd123  feat(scope): subject
  ef45678  fix(scope): subject
  (3 commit(s) not shown; use `git log HEAD..origin/develop` for full list)

Tags pulled: v1.4.0, v1.4.1
```

Cap the incoming-commit list and the tag list at 10 entries each; when truncated, print the count of unshown entries and the full `git log HEAD..origin/<trunk>` command with the trunk name substituted.

# Rationale

* **No choice-question gate**, uniquely in this skill family. `git fetch` writes only to `refs/remotes/origin/*` and the local tag namespace, both transient tracking metadata that the integration skills (`git-pull`, `git-merge`) re-verify before acting. A gate here would add a prompt-and-still-do-nothing cost to every call site; the skill exists to be the one cheap, no-prompt remote-state check.
* **The new-branches list comes from the step-2 stderr capture**, not a pre/post `for-each-ref` diff, because downstream skills re-check ref state when they need it.

# Hard rules

* NEVER run `git merge`, `git rebase`, `git checkout` to switch branches, `git pull`, `git reset`, or `git stash`. The skill is read-only against the working tree, the current branch ref, the index, and the stash; the only writes are to `refs/remotes/origin/*` and the local tag namespace.
* NEVER auto-invoke another skill. The report is informational; the operator decides whether `git-pull`, `git-merge`, or `git-branch-create` runs next.
* NEVER pass `--force` to `git fetch`, and NEVER pass `--all`. The step-2 refspec against `origin` is enough; broadening scope requires an edit to this skill, not a one-off override.
* NEVER drop `--no-prune-tags` from the step-2 fetch. Local tags are the user's; only `refs/remotes/origin/*` is pruned.
* NEVER fetch from any remote other than `origin`.
* NEVER swallow a `git fetch` error. Stderr is surfaced verbatim and the skill stops.
* NEVER ask the user to commit or stash before running; `git fetch` does not touch the working tree.
* NEVER add a choice-question gate inside this skill (see Rationale).
