# Branch rescue details

Reference for `git-commit` steps 1, 3b, 3d, 3e, and 3f: detached versus unborn HEAD, the name to propose when the trunk gate fires or HEAD is detached, and why the base handed to `git-branch-create` is always the current HEAD.

## Proposed name (step 3e)

Shape per the adopted naming variant:

* **Variant A**: `<type>/<issue-id>-<short-desc>`; take the issue id from the conversation, or ask when unknown. Lowercase the id (tracker id `PROJ-123` becomes `proj-123`), since branch names are lowercase only.
* **Variant B**: `<type>/<scope>/<short-desc>` with the narrowest top-level scope that captures the change (typically the dominant package or directory under the repo root); fall back to scope `repo` when the change legitimately spans packages.
* **Variant C**: `<type>/<short-desc>`.

`<type>` follows the change: `bugfix` when the pending diffs are a defect fix (a `fix` commit per the message spec), otherwise `feature`. `hotfix/*` and `release/*` carry release-process meaning, so propose them only when the user asked for one.

The short-desc is kebab-case, 2 to 5 words (for example `feature/foo-bot/retry-on-timeout` under Variant B). `git branch --list` is a good style reference.

## Base equals the current HEAD (step 3f)

With base equal to HEAD, `git checkout -b <new-branch>` carries the uncommitted changes onto the new branch with no intervening checkout, and git refuses the carry only when an incoming branch file would clobber a local edit, which cannot happen for a brand-new branch. Passing any other base sends `git-branch-create` into its dirty-tree path, whose only recommended option is to suggest `git-commit` again, and the two skills bounce off each other without progressing.

## Detached versus unborn (steps 1, 3b, and 3d)

A commit made on a detached HEAD is reachable from no branch, so step 3b always stops there. `git branch --show-current` prints nothing only for a detached HEAD; an unborn branch prints its name. `git rev-parse --abbrev-ref HEAD` prints `HEAD` for both, so it cannot tell them apart.

The step-3d rescue path cannot serve an unborn branch: there is no commit to branch from, and moving the unborn symref makes the trunk vanish. That is why the unborn exception offers only a direct first commit or abort.
