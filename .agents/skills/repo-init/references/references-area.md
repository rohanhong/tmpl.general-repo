# References area files

Loaded from `repo-init/SKILL.md`. Read this file at step 6c, before rendering the two files for the **create** / **abort** gate. The Hard rules in `SKILL.md` remain in force throughout.

## New file `references/README.md`

```markdown
# Reference Repositories

Read-only copies of external repositories kept for consultation.
Nothing here is called, imported, built, or depended on by this
project, and everything except this README is ignored by git.

To add one: clone or copy it into this directory, then record it
below with the commit hash so future readers know exactly which
snapshot was consulted.

| Name | Source URL | Commit | Date added | Why it is here |
|---|---|---|---|---|
```

## New file `references/.gitignore`

```
# Read-only reference material; only this file and README.md are tracked.
*
!.gitignore
!README.md
```

## Why this shape

The `*` plus re-include pair is deliberate: ignoring everything by default makes cloned repos (including their `.git` directories) invisible to the parent repo, so they cannot become accidental gitlinks, while the two `!` lines keep the README and this ignore file themselves tracked. A nested `.gitignore` scopes to its own directory by definition, so nothing else in the tree is affected; the root `.gitignore` is NOT touched, the area is self-contained and portable, and no `.gitkeep` is needed because the directory always holds two tracked files.

`references/` over `third_party/`, `external/`, or `vendor/`: those names carry build-layout semantics (code the project embeds, builds, or ships). This directory is pure reading material with zero calls and zero dependencies, so the name says "reference", and the tracked README carries the provenance (source, commit hash, date, purpose) that a build manifest would otherwise hold.
