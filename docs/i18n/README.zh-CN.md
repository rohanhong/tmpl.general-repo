<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../../.github/assets/banner-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="../../.github/assets/banner-light.svg">
  <img alt="tmpl.general-repo" src="../../.github/assets/banner-light.svg" width="640">
</picture>

<h1>🧰 通用仓库模板</h1>

<p><b>Git 规范、智能体指令与带确认关卡的智能体技能，开箱即用于任何新仓库。</b></p>

<p>
  <a href="../../LICENSE"><img alt="License" src="https://img.shields.io/github/license/rohanhong/tmpl.general-repo"></a>
  <a href="https://github.com/rohanhong/tmpl.general-repo/commits/main"><img alt="Last commit" src="https://img.shields.io/github/last-commit/rohanhong/tmpl.general-repo"></a>
  <a href="https://github.com/rohanhong/tmpl.general-repo/stargazers"><img alt="Stars" src="https://img.shields.io/github/stars/rohanhong/tmpl.general-repo?style=flat"></a>
  <a href="https://github.com/rohanhong/tmpl.general-repo/generate"><img alt="Use this template" src="https://img.shields.io/badge/use%20this-template-2ea44f?logo=github"></a>
  <a href="https://agents.md"><img alt="AGENTS.md" src="https://img.shields.io/badge/AGENTS.md-ready-24292f"></a>
  <a href="https://agentskills.io"><img alt="Agent Skills" src="https://img.shields.io/badge/Agent%20Skills-open%20format-8250df"></a>
  <!-- Reserved badges: uncomment when the service exists.
  <a href="https://github.com/rohanhong/tmpl.general-repo/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/rohanhong/tmpl.general-repo/ci.yml?branch=main"></a>
  <a href="https://github.com/rohanhong/tmpl.general-repo/releases"><img alt="Release" src="https://img.shields.io/github/v/release/rohanhong/tmpl.general-repo"></a>
  -->
</p>

<p>🌐 <a href="../../README.md">English</a> | <b>简体中文</b></p>

</div>

新仓库的起点。它提供可移植的 git 配置，以及一套与具体工具无关的智能体指令（`AGENTS.md`）和技能（`.agents/skills`），任何 AI 编程智能体都能使用。这些技能负责 git 工作流、项目初始化、项目文档、Python 环境和 Hugging Face Hub 托管，在执行任何难以撤销的操作前都会等待你确认。

## ✨ 亮点

- 🔧 **开箱即用的 git 规范**：换行符、diff 驱动、忽略规则，以及支持三种工作流变体的提交约定。
- 🤖 **所有智能体工具共用一份来源**：指令与技能放在开放约定的位置；其他工具只加轻量适配器，从不复制内容。
- 🛡️ **默认安全**：技能为不可逆操作设置确认关卡，从不改写历史，也不添加 AI 合著者。
- 🌱 **随项目成长**：`repo-init` 初始化新副本，`repo-docs` 生成与本仓库同样规范的 README 和社区文件。

## 🚀 快速开始

> [!NOTE]
> 技能需要 git 2.22 或更高版本，以及 POSIX shell（Windows 上为 Git Bash）。

1. 通过 **Use this template** 创建仓库，或复制、克隆本仓库。克隆会保留模板的历史，`repo-init` 会提示是否与之分离。
2. 在智能体会话中运行 `repo-init` 技能（例如 `/repo-init`）。它会配置 git、记录你的工作流选择、提供可选的脚手架，并提议由 `repo-docs` 为你的项目重写模板自带的 README、社区文件和许可证。

<details>
<summary>不借助智能体的手动配置</summary>

```bash
# cloned copies first: rm -rf .git   (drops the template's history and
# remote; or keep them and run `git remote rename origin template`)
git init -b main   # git 2.28+; older git: git init && git symbolic-ref HEAD refs/heads/main
git config commit.template .gitmessage
# then edit .gitmessage: set the `Workflow:` line and the `Adopted:` line
# optional: enable the archive excludes in .gitattributes
sed -E 's/^# ([^ ]+ +export-ignore)$/\1/' .gitattributes > .gitattributes.tmp &&
  mv .gitattributes.tmp .gitattributes
# skills adapters that arrived as plain files: register them as links
# (runs under sh, so zsh's error on a glob that matches nothing does
# not apply)
sh <<'EOF'
for f in .[!.]*/skills; do
  [ -f "$f" ] && [ ! -L "$f" ] && [ "$(grep -c '' "$f")" -eq 1 ] || continue
  case "$(tr -d '\r\n' < "$f")" in *.agents/skills) ;; *) continue;; esac
  tr -d '\r\n' < "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  git update-index --add --cacheinfo \
    "120000,$(tr -d '\r\n' < "$f" | git hash-object -w --stdin),$f"
done
EOF
```

</details>

## 📦 包含内容

| 路径 | 用途 |
|---|---|
| `.gitattributes` | LF 规范化、diff 驱动、二进制标记、归档排除（在 `repo-init` 启用前保持关闭） |
| `.gitignore` | 操作系统、编辑器、语言与基础设施规则；项目规则写在 `# Project-local` 下 |
| `.gitmessage` | 提交格式、工作流变体、分支命名、标签 |
| `AGENTS.md` | 智能体指令、规范目录布局与适配器规则 |
| `.agents/skills/` | 下列技能 |
| `CLAUDE.md`、`.claude/skills` | Claude Code 适配器：一行 `@AGENTS.md` 导入，以及指向 `.agents/skills` 的链接 |
| `.github/assets/` | README 图片 |
| `.github/settings.yml` | GitHub About 栏（简介、网站、topics）的记录；GitHub 不读取它，改动需手动同步 |
| `docs/i18n/` | README 与贡献指南的译文 |
| `LICENSE` `CONTRIBUTING.md` `CODE_OF_CONDUCT.md` `SECURITY.md` | 法律与社区文件；`repo-docs` 会为你的项目重写它们以及设置记录 |

| 分组 | 技能 | 作用 |
|---|---|---|
| 🌿 Git | `git-branch-create` `git-commit` `git-fetch` `git-pull` `git-merge` `git-push` `git-tag` `git-branch-delete` | 按 `.gitmessage` 完成建分支、提交、同步、合并、推送与打标签 |
| 🏗️ 初始化 | `repo-init` `repo-docs` `py-env-setup` | 初始化副本、生成 README 与社区文件、创建 conda 环境 |
| 🤗 HF Hub | `hf-setup` `hf-upload` `hf-download` | 以固定且经校验的版本托管大文件 |

## 🔀 工作流变体

`.gitmessage` 是规范来源；每个仓库在其 `Workflow:` 行记录一种变体。

| 变体 | 主干 | 受保护分支 | 适用场景 |
|---|---|---|---|
| `git-flow` | `main` + `develop` | `main`、`develop`、`support/*` | 有发布周期的团队仓库 |
| `github-flow` | `main` | `main`、`support/*` | 基于 PR 的团队仓库 |
| `trunk-solo` | `main` | 无（仍禁止改写历史） | 单人维护的仓库 |

模板中该行未记录，因此在你用 `repo-init` 记录选择之前，技能按最严格的 `git-flow` 处理。本模板自身按 `trunk-solo` 维护，但该行有意保持未记录；维护模板时，在 `repo-init` 的来源问题中选择 **template itself**，再选 `trunk-solo`，并跳过记录。

## 🔄 更新

- **保留了模板历史**（`repo-init` 中选择 **keep history**，并已将模板远程重命名为 `template`）：运行 `git fetch template`，然后以 `template/main` 为源运行 `git-merge`。
- **全新开始**：用新版模板中的 `.agents/skills/` 整体替换现有目录，提交前检查 `git status` 与 `git diff`，因为本地对技能的修改会丢失。同时对照新版模板检查 `AGENTS.md`、`.gitattributes` 和 `.gitmessage`。
- **README 与社区文件**：再次运行 `repo-docs`，把它们升级到当前布局。

## 🪟 Windows

> [!IMPORTANT]
> 技能适配器是符号链接。克隆前请开启开发者模式（或使用管理员权限），并运行 `git config --global core.symlinks true`，否则 Claude Code 等只读取 `.claude/skills` 的工具会找不到技能。`repo-init` 会报告损坏的链接并给出修复方法；详见 AGENTS.md（Layout）。

默认 shell 为 PowerShell 的智能体会通过 Git Bash 运行每段技能命令，做法见 AGENTS.md（Skill authoring）。

## 📚 文档

| 主题 | 位置 |
|---|---|
| 智能体指令、目录布局、适配器、技能编写规范 | [`AGENTS.md`](../../AGENTS.md) |
| 提交格式、工作流变体、分支命名、标签 | [`.gitmessage`](../../.gitmessage) |
| 各技能的流程与规则 | [`.agents/skills/<name>/SKILL.md`](../../.agents/skills) |
| 技能对提交信息规范的解读 | [`message-spec.md`](../../.agents/skills/git-commit/references/message-spec.md) |

## 🤝 参与贡献

欢迎提交 issue 和拉取请求。流程与改动规则见[贡献指南](CONTRIBUTING.zh-CN.md)。

## 🔗 相关资源

- [AGENTS.md](https://agents.md)：智能体指令的开放格式。
- [Agent Skills](https://agentskills.io)：技能的开放格式。
- [Conventional Commits](https://www.conventionalcommits.org)：提交格式的基础。
- [Choose a License](https://choosealicense.com) 与 [Contributor Covenant](https://www.contributor-covenant.org)：法律与社区文件的来源。

## ⚖️ 法律信息

- **许可证**：[MIT](../../LICENSE)
- **行为准则**：[Contributor Covenant 3.0](../../CODE_OF_CONDUCT.md)
- **安全**：请按 [SECURITY.md](../../SECURITY.md) 私下报告漏洞
<!-- - **Terms of Service**: [TERMS.md](../../TERMS.md) (add when the project runs a hosted service) -->

## ⭐ Star History

<a href="https://www.star-history.com/#rohanhong/tmpl.general-repo&Date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=rohanhong/tmpl.general-repo&type=Date&theme=dark">
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=rohanhong/tmpl.general-repo&type=Date">
    <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=rohanhong/tmpl.general-repo&type=Date" width="600">
  </picture>
</a>
