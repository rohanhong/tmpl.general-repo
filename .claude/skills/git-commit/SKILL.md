---
name: git-commit
description: Stage the user-named paths (or the whole workspace after confirmation), draft a .gitmessage-compliant message inline in chat, get approval, then commit via a `git commit -F -` heredoc. A mixed change set is offered as one commit or an ordered batch plan whose messages are ALL drafted up front and then confirmed batch by batch. Use for "commit this", "commit <paths>", "make a commit", or landing pending changes. Never writes the message to a file and never adds an AI co-author.
---

# Goal

Take the user's pending workspace from "edited" to "committed" in one guided flow. The draft MUST follow `.gitmessage` at the repo root, stay in concise bullet form, and contain no AI, agent, Claude, or Anthropic co-author.

# When NOT to use

* Nothing is pending: the skill stops at step 2.
* The user wants the commit published: `git-push`.
* The user wants two branches integrated: `git-merge` (it owns its own merge-commit drafting).

# Procedure

Run every command in this skill through the `Bash` tool; the redirections and the step-9 heredoc are POSIX syntax and break under PowerShell.

1. **Gather state.** Run in parallel:
   * `git rev-parse --show-toplevel` (repo root, confirming the skill runs inside a working tree).
   * `git status --short`.
   * `git diff --cached --stat` (staged shape summary for the user).
   * `git diff --stat` (unstaged shape summary for the user).
   * `git diff --cached` (full staged diff, fuel for the draft; see the size cap below).
   * `git diff` (full unstaged diff, fuel if any of it will be staged; same cap).
   * `git symbolic-ref --short -q HEAD` (the current branch; EMPTY output means detached HEAD. An unborn branch with zero commits prints its name normally and is NOT detached. Do not use `git rev-parse --abbrev-ref HEAD` here: it prints the literal `HEAD` for unborn branches too, conflating the two states and blocking a repo's first commit).
   * `git log --oneline -10` (style reference, also covers the HEAD subject for hook-failure diagnosis; on a zero-commit repo this exits fatal, which is fine: there is no style reference yet, proceed without one).

   **Size cap on the full-diff reads.** When the two `--stat` summaries report more than roughly 400 changed lines combined, do NOT pull the full diffs into context. Draft from the `--stat` shape plus targeted per-file reads (`git diff --cached -- <path>`) of the most central files, and note in the step-8 presentation which files were summarized from stat alone.

   Do NOT add history-shape probes here for the step-3 workflow variant. The variant comes from `.gitmessage` or from the user, never from a heuristic.

2. **Refuse when nothing to commit.** If `git status` shows no staged, unstaged, or untracked entries, STOP and tell the user the tree is clean.

3. **Resolve the workflow variant, then apply its trunk policy. Handle this BEFORE asking about scope, stage choice, or anything else**, because the step-4 questions assume the commit is allowed to land where HEAD points.

   a. **Resolve the variant.** Read the `Workflow:` line in `.gitmessage`'s "Workflow Variant" section.
      * **Declared** (`git-flow`, `github-flow`, or `trunk-solo`): use it as-is. Do not probe, do not ask.
      * **Absent, or an unrecognized value** (anything other than the three, including the shipped `<not recorded>` placeholder): ask via `AskUserQuestion` which of the three applies, with no option marked recommended and each option's tradeoff taken from `.gitmessage`'s own descriptions. Do NOT guess from history: a squash-merged PR flow and a direct-commit trunk produce the same linear shape, so the user is the only reliable source. Then ask a second `record` / `skip` gate to write the answer onto the `Workflow:` line via `Edit`, so the question never returns. When `.gitmessage` itself is absent from the repo root, skip the record gate: the chosen variant applies to this session only, and suggest copying the template's `.gitmessage` in so the answer can be recorded. Until the user answers, treat the variant as `git-flow`.

   b. **Detached HEAD is a hard stop under every variant.** Commits made there are reachable from no branch. STOP and go to step 3d.

   c. **Apply the trunk policy for the current branch.**

      | Current branch | `git-flow` | `github-flow` | `trunk-solo` |
      |---|---|---|---|
      | `support/*` | gate | gate | gate |
      | `develop` | gate | does not exist | does not exist |
      | `main` | gate | gate | **no gate** |
      | short-lived branch | no gate | no gate | no gate |

      This table is a convenience copy. `.gitmessage`'s "Protected Branches" section is normative; when the two disagree, follow `.gitmessage` and say so.

      **gate** = refuse to commit here unless the user has explicitly typed something like "yes, commit directly on `<branch>`" in the current turn. Prior-turn approval does NOT carry over. Without it, go to step 3d.

      **no gate** = proceed straight to step 4. Under `trunk-solo`, committing on `main` is the sanctioned path, not a lapse: do not ask, do not propose a branch, do not editorialize. The one exception is advisory: when the staged set spans three or more top-level directories, add a single line to the step-8 presentation noting the commit may be worth splitting (step 5 offers the batched path) or moving to a branch. Say it once, then proceed either way.

   d. **When the gate fires or HEAD is detached**, do not commit where HEAD points. Land the work on a fresh short-lived branch via steps 3e to 3g. The pending changes carry over untouched because the new branch is cut from the current HEAD, so nothing needs stashing.

      **Unborn exception.** When the current branch has zero commits (step 1's `git log` reported no commits yet), the rescue path cannot work: there is no commit to branch from, and moving the unborn symref would make the trunk itself vanish. State that this is the repository's first commit and offer exactly two ways forward: the explicit in-turn opt-in to commit directly here (the normal bootstrap move, even under `git-flow`), or abort. Do NOT invoke `git-branch-create`.

   e. **Infer a sensible branch name** from the step-1 diffs, following the repo's adopted naming variant (read the `Adopted:` line in `.gitmessage`'s "Branch Naming" section first; when it is `<not recorded>` or absent, infer the dominant variant from existing short-lived branches the way `git-branch-create` step 4 does, and fall back to Variant C when none exist):
      * **Variant A**: `feature/<issue-id>-<short-desc>`; take the issue id from the conversation, or ask when unknown.
      * **Variant B**: `feature/<scope>/<short-desc>` with the narrowest top-level scope that captures the change (typically the dominant package or directory under the repo root); fall back to scope `repo` when the change legitimately spans packages.
      * **Variant C**: `feature/<short-desc>`.

      The short-desc is kebab-case, 2 to 5 words (for example `feature/foo-bot/retry-on-timeout` under Variant B). `git branch --list` is a good style reference.

   f. **Invoke the `git-branch-create` skill** with the proposed name AND an explicit `base=<current HEAD>`, for example `Skill(git-branch-create, "feature/foo-bot/retry-on-timeout base=develop")` when HEAD is `develop`. That skill owns naming validation and its own `AskUserQuestion` confirmation; do not duplicate either here.

   The base MUST be the current HEAD, never a hardcoded `main` or `develop`. With base equal to HEAD, `git checkout -b <new-branch>` carries the uncommitted changes onto the new branch with no intervening checkout, and git refuses the carry only when an incoming branch file would clobber a local edit, which cannot happen for a brand-new branch. Passing any other base sends `git-branch-create` into its dirty-tree path, whose only recommended option is to hand back to `/git-commit`, and the two skills bounce off each other without progressing.

   g. **After `git-branch-create` returns**, verify with `git symbolic-ref --short -q HEAD` that a short-lived branch is checked out, then re-enter this skill at step 1 to re-gather state on the new branch.

4. **Resolve the commit scope.**
   * **User-named scope in the current turn** ("commit src/foo.py and src/bar.py", "commit the launch dir", "commit only what is already staged"): stage exactly that set and nothing else. Use `git add <path>...` for explicit paths and `git reset HEAD -- <path>` to unstage anything the user excluded.
   * **No scope specified (default: the entire workspace)**: list every pending change (staged, unstaged, and untracked separately) and ask via `AskUserQuestion` whether to (a) commit everything pending, (b) commit only the currently staged set, (c) commit a user-supplied subset of paths, or (d) abort. Option (a) is the recommended default; it stages all tracked modifications via `git add -u` and stages each untracked file ONLY after the user confirms it by name.
   * **Both staged and unstaged non-empty with no scope said**: same prompt, and surface that a partial stage already exists so the user decides intentionally.

5. **Choose single or batched commits.** With the scope resolved, judge whether the pending set is ONE logical change or several: look for distinct `<type>(<scope>)` pairs per the message spec (for example a `feat` in one package plus an unrelated `fix` elsewhere), or the step-3c advisory case of three or more top-level directories.
   * **Clearly one logical change**: proceed as a single commit; do NOT ask. The question is reserved for genuinely mixed sets, so it never becomes routine friction.
   * **Two or more distinguishable changes**: render a proposed partition inline first (one line per batch: `<n>. <type>(<scope>): <intent> -- <paths>`; every pending path appears in exactly one batch, no leftover "misc" bucket), then ask via `AskUserQuestion`:
     * **split as proposed (Recommended)**: continue on the batched path.
     * **single commit**: everything in one commit; continue on the single-commit path.
     * **adjust batches**: the user replies with free-text moves ("put the README with batch 2", "merge 1 and 3"); re-render the partition and re-ask.
     * **abort**: STOP. Staging state stays as the user left it.
   * **Whole-file semantics guard.** Step 9 stages each batch path from the working tree, whole file. Before asking, re-run `git status --short` (step 4 may have restaged, so the step-1 capture is stale for this check) and look for dual-state paths (staged AND unstaged edits on the same file, for example `MM`); also check whether step 4 resolved to option (b) (only the currently staged set). If either holds, batching would commit the CURRENT working-tree content of those files instead of the staged hunks: render a WARNING line naming the affected paths immediately above the question. Choosing **split as proposed** with that warning shown counts as the acknowledgment; when staged-hunk precision matters, **single commit** is the option that preserves it exactly.
   * In batched mode, hold each batch as an explicit path list and defer all staging to step 9; nothing is staged or committed while the plan is being drafted and reviewed.

6. **Sanity-check sensitive content.** Before drafting, scan the final commit set (the staged diff; in batched mode, the union of every batch's paths diffed against HEAD, plus the full content of untracked paths read directly, since `git diff HEAD` does not show them) on two levels:
   * **Filenames**: `.env`, `.env.*`, `credentials.*`, `*.pem`, `*.key`, `*_rsa`, `id_rsa*`, `*.keystore`, `*.p12`, `*.pfx`.
   * **Diff content, value-shaped patterns only**: `-----BEGIN [A-Z ]*PRIVATE KEY-----`, `hf_[A-Za-z0-9]{30,}`, `ghp_[A-Za-z0-9]{36}`, `github_pat_[A-Za-z0-9_]{20,}`, `AKIA[0-9A-Z]{16}`, `xox[baprs]-[A-Za-z0-9-]+`, `eyJ[A-Za-z0-9_-]{20,}` (JWT), `(api[_-]?key|token|password|secret)\s*[:=]\s*['"][^'"]{8,}` (an assignment carrying a literal value), plus absolute home paths (`/home/<user>/`, `~/`, `C:\Users\<user>\`, `%USERPROFILE%`).

   Bare words like `token` or `secret` outside an assignment-with-literal are NOT matches; docs and code that merely handle credentials would otherwise false-positive on every commit. On any match, STOP and ask for confirmation per file; suggest `.gitignore` additions rather than committing.

7. **Draft the message(s) inline (no file).** Read `.gitmessage` from the repo root for the authoritative type, scope, and footer rules; fall back to `references/message-spec.md` (see the Reference section below) when absent.
   * **Single commit**: one draft from the final staged diff (refresh `git diff --cached` if step 4 restaged anything) and the recent log from step 1.
   * **Batched**: draft EVERY batch's message NOW, one per batch, each from its batch's diff (`git diff HEAD -- <batch-paths>`), before any confirmation or commit. For untracked paths in a batch, read the file directly or use `git diff --no-index /dev/null <path>`; `git diff HEAD` does not show them. The step-1 size cap applies per batch: a batch whose diff exceeds roughly 400 changed lines is drafted from its `--stat` shape plus targeted per-file reads. Writing all drafts in one pass is mandatory: it is what keeps the sequence coherent (consistent scopes, no bullet duplicated across two messages, no vague final batch) and lets the user review a complete plan instead of discovering the next message only after the previous commit has landed.

   Hold the draft(s) in chat as fenced code blocks, labeled by batch number in batched mode.

8. **Show and confirm.**
   * **Single commit**: display the draft inline as a fenced code block, then ask via `AskUserQuestion` (use the `preview` field to show the draft alongside the options): **approve** / **edit** / **abort**.
     * **approve**: proceed to step 9 with the current draft.
     * **edit**: the user replies with free-text edits ("drop bullet 3", "add `Refs #42`", "shorten the subject", or a complete replacement). Apply them, re-render the draft inline, and re-ask. Loop until approved or aborted.
     * **abort**: stop. The staged set stays as is; the draft is discarded with the conversation.
   * **Batched**: render the complete plan once (every batch with its path list and full draft), then walk the batches IN ORDER, one `AskUserQuestion` per batch with the `preview` field showing that batch's draft: **commit** / **edit** / **skip** / **abort rest**.
     * **commit**: execute step 9 for this batch immediately, then move to the next batch.
     * **edit**: apply free-text edits to THIS batch's message, or move a path between this batch and a LATER one (a move re-renders both affected drafts); re-ask. Never reopen an already-committed batch.
     * **skip**: leave this batch's changes pending and uncommitted; continue with the next batch.
     * **abort rest**: stop the sequence. Batches already committed stay committed; say so plainly and list what remains pending.

9. **Commit via heredoc, no file.** In batched mode, run this step once per approved batch: first unstage anything staged that is outside the batch (`git reset HEAD -- <path>...`), stage exactly the batch (`git add -- <path>...`; untracked files only after their step-4 per-file confirmation), and verify `git diff --cached --stat` matches the batch's path list before committing. Pipe the approved message to `git commit -F -` through a quoted heredoc (the quoted terminator prevents shell expansion of the body):
   ```
   git commit -F - <<'COMMIT_MSG_EOF'
   <type>(<scope>): <subject>

   - bullet 1
   - bullet 2
   COMMIT_MSG_EOF
   ```
   Substitute the approved draft verbatim, preserving the blank line between header and body. If the draft contains a line equal to `COMMIT_MSG_EOF`, pick a fresh terminator (for example `COMMIT_MSG_EOF_2`) absent from the body for that invocation. Run this through the `Bash` tool, not PowerShell, so the heredoc is valid. Capture the exit code and full output.

10. **Handle hook failure.** If a pre-commit, commit-msg, or pre-push hook blocked the commit:
    * The commit did NOT happen; the previous commit at HEAD is unchanged.
    * Surface the hook's exact output.
    * STOP. In batched mode the whole sequence stops with it: report which batches already landed (with SHAs) and which remain pending. Help the user fix the underlying issue, then re-run this skill from step 1; the drafted message(s) stay in the conversation and may be approved again unchanged.

11. **Report success.** Show the new commit SHA and subject (`git log -1 --format='%h %s'`); in batched mode, one `<sha> <subject>` line per landed batch in order, plus any batch that was skipped. Then the branch it landed on with the active workflow variant in parentheses (for example `main (trunk-solo)`), `git status --short` for anything still pending, and the natural next step (usually `git-push`, or another `git-commit` for the remainder). Naming the variant is what makes an unprotected trunk visible; without it a user on `trunk-solo` has no way to notice that nothing is guarding `main`.

# Reference: commit message specification

The full specification lives in `references/message-spec.md` next to this file (repo path `.claude/skills/git-commit/references/message-spec.md`). Read it and apply its "Standard commit message" section. That file is the single normative copy for this skill and `git-merge`, so neither SKILL.md restates the rules and there is no second copy to drift.

# Hard rules

* NEVER write the commit message to a file on disk (no `tmp/commit_msg.txt`, no `.git/COMMIT_EDITMSG` pre-population, no scratch file under the repo root, system tmp, or `/var/tmp`). The message lives only in the chat conversation and the heredoc that feeds `git commit -F -`.
* NEVER stage files with `git add .` or `git add -A`, and never use a path glob that could pick up untracked files. `git add -u` is permitted ONLY for the tracked-modification bulk-stage in step 4 option (a); stage untracked files by explicit name after per-file confirmation.
* NEVER pass `--no-verify`, `--no-gpg-sign`, `-c commit.gpgsign=false`, `--amend`, or `--allow-empty` unless the user typed the flag themselves in the current turn. Hooks fail for a reason; fix the underlying issue.
* NEVER `--amend` after a hook failure. The failed commit never landed, so `--amend` would silently rewrite the PREVIOUS commit. Always create a new commit instead.
* NEVER commit files matching the step-6 sensitive-content patterns without per-file user confirmation.
* NEVER draft batch messages lazily. In batched mode every message is written in step 7 before the first batch is confirmed; interleaving draft-confirm-commit per batch is the incoherence the batched path exists to prevent.
* NEVER amend, reorder, or otherwise reopen an already-committed batch during the step-8 walk. A later edit request applies to later batches only.
* NEVER commit onto a detached HEAD under any workflow variant.
* NEVER commit on a branch the active variant protects without an explicit in-turn opt-in. The protected set comes from `.gitmessage`'s "Workflow Variant" section, never from a hardcoded list in this file.
* NEVER assume a permissive variant. When `.gitmessage` declares no `Workflow:` line, or the line carries an unrecognized value (such as the shipped `<not recorded>` placeholder), treat the repo as `git-flow` (the strictest) until the user says otherwise, and record their answer in `.gitmessage` rather than remembering it across turns.
* NEVER infer the workflow variant from history shape. Squash merges and rebase merges both produce single-parent commits, so a PR-reviewed team repo and a direct-commit trunk are indistinguishable by topology. Ask the user.
* NEVER re-propose a branch on `main` under `trunk-solo` beyond the single advisory line in step 3c. Committing on the trunk is that variant's sanctioned path, and repeating the suggestion is the friction the variant exists to remove.
* NEVER add `Generated with Claude Code`, `Co-Authored-By: Claude`, `Co-Authored-By: Anthropic`, or any AI, agent, or assistant attribution. Do not invent co-authors. The message MUST follow `.gitmessage`, stay in concise bullet form, and stay human-authored.
* NEVER include credentials, API keys, or absolute home paths (`/home/<user>/`, `C:\Users\<user>\`) in the body. Use repo-relative paths only.
* If `git commit -F -` fails for any reason other than a hook (a corrupt index, a missing GPG key), surface the error verbatim and stop. Do not invent a workaround.
