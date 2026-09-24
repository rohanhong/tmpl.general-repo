# Security Policy

## Supported Versions

This template has no versioned releases yet. Fixes land on `main` only.

| Version | Supported |
|---|---|
| `main` (latest commit) | Yes |
| Older commits and copies made from them | No; pull the fix from the newer template |

## Reporting a Vulnerability

Please do not report security problems in public issues, discussions, or pull
requests.

Report them privately through GitHub:
[Report a vulnerability](https://github.com/rohanhong/tmpl.general-repo/security/advisories/new)
(the **Security** tab, then **Report a vulnerability**).

Include what you can of:

- the affected file or skill, and the commit you tested;
- steps to reproduce, and the agent tool and shell used;
- the impact, and a suggested fix if you have one.

## What to Expect

- An acknowledgement within 7 days. This is a single-maintainer project, so
  responses are best effort.
- Updates as the report is triaged and fixed, through the private advisory.
- Coordinated disclosure: the advisory is published once a fix is on `main`,
  with credit to you unless you prefer otherwise.

## Scope

In scope: anything in this repository that could make an agent or user run an
unintended destructive command, skip a confirmation gate, rewrite history,
publish to the wrong remote, or commit secrets despite the sensitive-content
scan.

Out of scope: vulnerabilities in third-party software the skills call (git,
agent tools, conda, the Hugging Face Hub, shields.io); report those upstream.
