# Badge catalog

Loaded from `repo-docs/SKILL.md` at the badge step. All badges are shields.io (`https://img.shields.io/...`) in the default `flat` style unless noted. Fill `<owner>`, `<repo>`, `<branch>` (the default branch), `<workflow>` (a file name under `.github/workflows/`), and `<package>` from the probe; never guess them.

## Rules

* Show a badge only when its "show when" evidence exists; otherwise, when it fits the project's likely future, put it in the reserved HTML comment. Leave out badges that fit neither.
* Order in the row: License first (always shown when a LICENSE exists), then version and release, build, quality, docs, activity, community, and meta. About eight visible at most. This is the single source for the order.
* `github/*` badges need a public GitHub repository; for a private one or another forge, use the static form or the forge's own badge.
* Markup, one per line inside the header `<p>`: `<a href="<link>"><img alt="<label>" src="<url>"></a>`. The alt text is the badge label.

## Catalog

| Badge | Image URL | Link | Show when |
|---|---|---|---|
| Release | `github/v/release/<owner>/<repo>` | `https://github.com/<owner>/<repo>/releases` | a GitHub release exists |
| Tag | `github/v/tag/<owner>/<repo>` | `.../tags` | `v*` tags but no releases |
| PyPI | `pypi/v/<package>` | `https://pypi.org/project/<package>/` | the user confirms the package is published |
| Python versions | `pypi/pyversions/<package>` | PyPI page | PyPI badge shown |
| Python (static) | `badge/python-<version>-3776AB?logo=python&logoColor=white` | `https://www.python.org` | `environment.yml`, `pyproject.toml`, or `.python-version` pins a version, package not published |
| npm | `npm/v/<package>` | `https://www.npmjs.com/package/<package>` | published npm package |
| crates.io | `crates/v/<package>` | `https://crates.io/crates/<package>` | published crate |
| Go reference | `https://pkg.go.dev/badge/<module>.svg` | `https://pkg.go.dev/<module>` | `go.mod` with a public module path |
| Docker | `docker/v/<image>?sort=semver` | Docker Hub page | a published image |
| Downloads | `pypi/dm/<package>`, `npm/dm/<package>`, `crates/d/<package>`, `docker/pulls/<image>` | package page | package badge shown and the user wants it |
| CI | `github/actions/workflow/status/<owner>/<repo>/<workflow>?branch=<branch>` | `https://github.com/<owner>/<repo>/actions/workflows/<workflow>` | a workflow that runs tests or builds |
| GitLab pipeline | `gitlab/pipeline-status/<path with every / as %2F>?branch=<branch>` | pipelines page | `.gitlab-ci.yml` on GitLab (subgroups included) |
| Coverage | `codecov/c/github/<owner>/<repo>` | `https://codecov.io/gh/<owner>/<repo>` | `codecov.yml` or a Codecov upload step |
| pre-commit | `badge/pre--commit-enabled-brightgreen?logo=pre-commit` | `https://pre-commit.com` | `.pre-commit-config.yaml` |
| Ruff | `endpoint?url=https://raw.githubusercontent.com/astral-sh/ruff/main/assets/badge/v2.json` | `https://github.com/astral-sh/ruff` | Ruff configured |
| OpenSSF Scorecard | `https://api.scorecard.dev/projects/github.com/<owner>/<repo>/badge` | `https://scorecard.dev/viewer/?uri=github.com/<owner>/<repo>` | a Scorecard workflow |
| Docs | `badge/docs-<label>-blue` | docs URL | a published docs site |
| Read the Docs | `readthedocs/<project>` | `https://<project>.readthedocs.io` | `.readthedocs.yaml` |
| Hugging Face | `badge/Hugging%20Face-<label>-FFD21E?logo=huggingface&logoColor=black` | the HF repo URL | the project hosts artifacts on the HF Hub |
| Last commit | `github/last-commit/<owner>/<repo>` | `.../commits/<branch>` | public GitHub repository |
| Commit activity | `github/commit-activity/m/<owner>/<repo>` | `.../pulse` | active project, user wants it |
| Issues | `github/issues/<owner>/<repo>` | `.../issues` | issues enabled and used |
| Pull requests | `github/issues-pr/<owner>/<repo>` | `.../pulls` | contributions accepted |
| Contributors | `github/contributors/<owner>/<repo>` | `.../graphs/contributors` | more than one contributor |
| Stars | `github/stars/<owner>/<repo>?style=flat` | `.../stargazers` | public GitHub repository |
| Forks | `github/forks/<owner>/<repo>?style=flat` | `.../forks` | public, fork-oriented project |
| Discussions | `github/discussions/<owner>/<repo>` | `.../discussions` | Discussions enabled |
| Discord | `discord/<server-id>?logo=discord&logoColor=white` | invite URL | the user gives a server |
| PRs welcome | `badge/PRs-welcome-brightgreen` | `CONTRIBUTING.md` or `.../pulls` | contributions accepted |
| License | `github/license/<owner>/<repo>` | `LICENSE` | public GitHub repository with a LICENSE, except a GNU license with an `-only` or `-or-later` choice (use the static form) |
| License (static) | `badge/license-<SPDX id, escaped>-blue`, for example `badge/license-Apache--2.0-blue` | `LICENSE` | LICENSE present, dynamic form unavailable |
| License (proprietary) | `badge/license-Proprietary-red` | `LICENSE` | all-rights-reserved LICENSE |
| Use this template | `badge/use%20this-template-2ea44f?logo=github` | `https://github.com/<owner>/<repo>/generate` | the repository is a GitHub template repository |
| AGENTS.md | `badge/AGENTS.md-ready-24292f` | `https://agents.md` | `AGENTS.md` present |
| Agent Skills | `badge/Agent%20Skills-open%20format-8250df` | `https://agentskills.io` | `.agents/skills` present |

In static `badge/<label>-<message>-<color>` URLs, write a literal `-` as `--`, `_` as `__`, and a space as `%20`.

## Recommended defaults

* Every repository with a LICENSE: a License badge, always shown.
* Any public GitHub repository: Last commit and Stars as well.
* Repositories created from this template: add AGENTS.md and Agent Skills; reserve CI and Release until they exist.
* Add CI as soon as a workflow runs tests, and Release or the package badge after the first release.
