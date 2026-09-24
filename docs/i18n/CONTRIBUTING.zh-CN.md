# 贡献指南

<p><a href="../../CONTRIBUTING.md">English</a> | <b>简体中文</b></p>

感谢你帮助改进通用仓库模板。本指南说明如何提出改动，以及改动合并前必须满足的要求。

参与本项目即表示你同意遵守[行为准则](../../CODE_OF_CONDUCT.md)。安全问题请按 [SECURITY.md](../../SECURITY.md) 所述私下报告，切勿发到公开 issue。

## 参与方式

- **报告缺陷**：提交 issue，写明你运行了什么、预期结果、实际结果，以及 git 版本、shell 和所用的智能体工具。
- **提出建议**：比小修复更大的改动请先开 issue，在动手前商定方案。
- **提交拉取请求**：欢迎对技能、git 规范文件和文档的修复。

## 工作流程

1. Fork 本仓库并克隆你的 fork。
2. 配置提交模板：`git config commit.template .gitmessage`。
3. 从 `main` 创建短期分支，命名遵循 `.gitmessage` 的 Branch Naming 一节：`git checkout -b bugfix/repo-init-probe main`。请手动创建：模板的 `Workflow:` 行有意保持未记录，`git-branch-create` 会因此按 `git-flow` 处理并寻找本仓库没有的 `develop` 分支。
4. 按 `.gitmessage` 的格式 `<type>(<scope>): <subject>` 提交，每个提交只做一件事；`git-commit` 技能可以代为起草。
5. 推送到你的 fork，向 `main` 发起拉取请求。说明改了什么、为什么改，并关联对应的 issue。

## 改动规则

- **工件**：代码、注释、技能和仓库内文档一律使用英文且仅限 ASCII。README 与 CONTRIBUTING 文件及其译文例外（可使用非英文文字，README 还可使用 emoji），见 `AGENTS.md`（Conventions）。
- **技能**：遵循 `AGENTS.md`（Skill authoring）：合法的 frontmatter、统一的 Procedure 首行、用能力术语代替具体工具名、使用 POSIX shell 命令片段。
- **变体保持未记录**：`.gitmessage` 中的 `Workflow:` 与 `Adopted:` 行保持未记录，由每个基于模板创建的仓库自行记录。`git-commit` 提议记录变体时请跳过。
- **单一来源**：只修改规范文件（`AGENTS.md`、`.agents/skills`），不要改适配器。
- **不写死数值**：路径和设置从配置文件、命令行参数或环境变量读取。
- **文档随改动更新**：改动导致文档不准确时，在同一个拉取请求中修正，包括 `README.md` 和 `docs/i18n/` 中的每份译文。

## 发起拉取请求前

- [ ] 每段改动过的 shell 命令都能在 POSIX shell（Windows 上为 Git Bash）中运行。
- [ ] README 与 CONTRIBUTING 文件之外没有非 ASCII 文本：`LC_ALL=C git grep -nI --untracked '[^[:print:][:space:]]' -- . ':!README.md' ':!CONTRIBUTING.md' ':!docs/i18n'` 没有输出。
- [ ] README、CONTRIBUTING 与各自译文内容一致。
- [ ] 提交信息符合 `.gitmessage`。

## 许可证

贡献内容按本仓库的 [MIT 许可证](../../LICENSE)接收。
