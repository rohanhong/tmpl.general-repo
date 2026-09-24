# Agent Instructions

Shared instructions for every AI agent tool working in this repository. This
file is the single source of instructions; edit it, never an adapter file.

## Project

<Project name and one-line description.>

## Commands

<Build / test / run commands, once established.>

## Conventions

- Commits and branching follow `.gitmessage` (see its `Workflow:` and
  `Adopted:` lines).
- Use the git-* skills for git operations. `.gitmessage` is normative for
  the repository's commit and merge messages;
  `.agents/skills/git-commit/references/message-spec.md` is the skills'
  detailed reading of it and defers to `.gitmessage` on any conflict.

## Layout

Canonical content lives only in the two open-convention locations:

- `AGENTS.md` (this file): instructions.
- `.agents/skills/<name>/SKILL.md`: skills, one directory each.

A tool that does not read these locations gets a thin adapter, never a copy.
Add adapters only for such tools: a tool that reads both a canonical location
and an adapter may list the same content twice.

- Instruction adapter: a file in the tool's own format and location whose
  only content imports or points to `AGENTS.md` (for example, a single
  `@AGENTS.md` import line where the tool supports imports).
- Skills adapter: a relative symbolic link from the tool's skills directory to
  `.agents/skills` (for example, `.<tool>/skills -> ../.agents/skills`).

The template ships two adapters, both for Claude Code:

- `CLAUDE.md` holds only the `@AGENTS.md` import. When a `CLAUDE.md` exists,
  Claude Code loads it instead of reading `AGENTS.md` directly, so this import
  is how `AGENTS.md` reaches Claude Code; it never loads the file twice.
- `.claude/skills` is an accepted exception to the adapter rule above: Claude
  Code discovers skills only in `.claude/skills`, but several other tools read
  both `.agents/skills` and `.claude/skills`, so they may list each skill
  twice. Some of those tools offer a setting to ignore the Claude location.

Some tools need an adapter the template does not ship. For example, Gemini
CLI reads `GEMINI.md` by default (an instruction adapter, or its setting for
the context file name), and Kiro reads skills only from `.kiro/skills` (a
skills adapter). Add a skills adapter with a relative link where symbolic
links work:

```sh
MSYS=winsymlinks:nativestrict ln -s ../.agents/skills .<tool>/skills &&
  [ -L .<tool>/skills ]
```

The `MSYS` setting is ignored outside Git Bash. Without it, Git Bash lacking
symlink permission silently copies the directory instead of linking it; with
it, `ln` fails with `Operation not permitted`, a nonzero exit status, and no
copy left behind.

Where links do not work (Windows without symlink permission), write the
target as a plain file and register it in the index as a link, so every
symlink-aware checkout gets a real link:

```sh
printf %s ../.agents/skills > .<tool>/skills
git update-index --add --cacheinfo "120000,$(printf %s ../.agents/skills | git hash-object -w --stdin),.<tool>/skills"
```

Adding support for a tool means adding its adapters, plus its directory and
root instruction file to the AI tool `export-ignore` list in `.gitattributes`
when not already listed (commented out while the other lines there are);
nothing canonical moves or is duplicated. Adapter links are recognized by
target, not by path: a symbolic link whose target ends in `.agents/skills`.
Where a link has to be written as a plain file, its content is the target
alone, with no trailing newline.

On Windows, links need Developer Mode or administrator rights, plus
`core.symlinks`. Before a fresh clone, run `git config --global core.symlinks
true` (or clone with `git clone -c core.symlinks=true <url>`); to repair an
existing checkout, run `git config core.symlinks true` in it, then `rm <link>
&& git checkout -- <link>` for each broken link. Otherwise git writes each
link as a plain text file and the tool reading it sees nothing.

## Skill authoring

Skills must run under any agent tool, so they follow these rules:

- Frontmatter requires `name` and `description`. The only optional field
  allowed is `compatibility` (Agent Skills specification, at most 500
  characters), for environment needs such as network access or an installed
  program. Frontmatter must be valid YAML: quote a value, or use a block
  scalar such as `>-`, when it contains `: `.
- Skills need git 2.22 or later (they use `git branch --show-current`) and a
  POSIX shell.
- A skill may use another skill's file only through a path relative to its
  own directory (`../<skill>/...`) and must name that dependency in its body;
  the template ships the skills as one set.
- Every SKILL.md begins its Procedure with this line: "Terms such as choice
  question, independent reads, invoke, and suggest follow AGENTS.md (Skill
  authoring); in a non-interactive session every gate ends this skill."
- Name capabilities, never a specific tool's feature or tool names. Each tool
  maps these terms to its own features:
  - **gate**: a step whose action waits on the user: a choice question used
    as a gate, a confirmation, or an explicit in-turn opt-in.
  - **choice question**: 2 to 4 options, mutually exclusive unless the
    question is multi-select, each with its tradeoff; the user may always
    answer in their own words. Use the tool's structured question interface
    when it has one, otherwise numbered options in plain text, then wait. A
    choice question used as a gate blocks the gated action until the user
    answers.
  - **explicit in-turn opt-in**: a reply in the current turn that names the
    protected action and its target, either typed or by choosing an option
    whose label states that action and target (for example `yes, merge
    directly into main`). A generic yes, or approval from an earlier turn, is
    not an opt-in.
  - **non-interactive session**: when the session cannot put a question to
    the user and receive the answer (batch, CI, or cloud runs), every gate
    ends the skill: stop, report the pending question and the current state,
    and take no gated action. Never pick an option on the user's behalf; an
    explicit in-turn opt-in can only come from the user.
  - **POSIX shell**: run commands in a POSIX shell (Git Bash on Windows);
    snippets use POSIX redirections and heredocs. When the agent's default
    shell is not POSIX (for example PowerShell on Windows), run each snippet
    through bash. From Windows PowerShell 5.1, pass the snippet verbatim in a
    single-quoted here-string on stdin:

    ```powershell
    try { $bash = (Resolve-Path -ErrorAction Stop (Join-Path (git --exec-path) '../../../bin/bash.exe')).Path } catch { throw "Git Bash not found: $_" }
    $OutputEncoding = [Console]::InputEncoding = [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
    @'
    <snippet, unchanged>
    '@ | & $bash -c "tr -d '\r' | bash /dev/fd/3 3<&0 </dev/null"
    ```

    The first line finds Git Bash next to git (a bare `bash` may be WSL's)
    and throws, ending the command, when git or Git Bash is missing, so a
    stale `$LASTEXITCODE` is never read as the snippet's status; report that
    and stop. The single-quoted here-string keeps quotes, `$`, and quoted
    heredocs literal; stdin avoids the 5.1 bug that drops double quotes from
    native arguments such as `bash -c '<snippet>'`. The encoding line stops
    5.1 from prepending a byte order mark and makes non-ASCII output decode
    as UTF-8; these settings persist for the rest of that PowerShell session.
    `tr` drops the carriage returns PowerShell adds. The inner bash reads the
    script from descriptor 3 and gives its commands an empty stdin, so a
    command that reads stdin cannot swallow the rest of the snippet (with
    `bash -s`, later lines would silently never run and the status would
    still be 0). The closing `'@` must start its line, so a snippet cannot
    contain a line that starts with `'@`. `$LASTEXITCODE` holds the snippet's
    exit status.
  - **independent reads**: commands that do not depend on each other; run
    them concurrently when the agent can, otherwise one after another in any
    order.
  - **in-place edit** / **write the file**: change part of a file while
    preserving the rest, versus create or replace a whole file.
  - **the agent**: whichever tool is executing the skill.
  - **invoke `<skill>`**: the agent runs that skill now, under that skill's
    own gates, however the tool triggers skills.
  - **suggest `<skill>`**: name that skill to the user as a next step without
    running it.
