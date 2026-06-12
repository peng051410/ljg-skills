---
name: tomyli-push
description: 把 canonical ljg-skills repo (~/github/ljg-skills) 里改过的 skills 一键提交并推到 origin/master。canonical 即 source of truth——~/.claude/skills/ 全部是它的 symlink，没有 rsync 步骤。覆盖 ljg-*、tomyli-* 以及非前缀 skill (如 understand-change)。Use when user says '/tomyli-push', 'push tomyli skills', '推送 tomyli skills', '同步 skills 到 fork', '推 skills', or whenever any skill in ~/github/ljg-skills/skills/ has been edited and needs shipping. NOT FOR pushing to upstream lijigang/ljg-skills, NOT FOR md branch (this fork is master-only), NOT FOR arbitrary git repos.
user_invocable: true
version: "0.1.0"
---

# tomyli-push: 推送 canonical ljg-skills fork

把 `~/github/ljg-skills/skills/` 下的改动（ljg-* / tomyli-* / 非前缀 skill）一键 commit + 推到 `origin/master`。

## 与 ljg-push 的关键差异

| 维度 | ljg-push（旧） | tomyli-push（新） |
|------|---------------|-------------------|
| Repo 路径 | `~/code/ljg-skills` | `~/github/ljg-skills`（canonical） |
| Remote | `lijigang/ljg-skills` | `peng051410/ljg-skills`（fork） |
| 拓扑 | `.claude/skills` 是源，rsync 进 repo | `~/.claude/skills/*` 是 **symlink → canonical**；canonical 即源 |
| 同步动作 | rsync + diff detect | **无 rsync**；直接 `git add skills/` |
| 分支 | master + md（双推 + mdize） | **只 master**（fork 不维护 md 分支） |
| 覆盖范围 | 仅 `ljg-*` | `ljg-*` + `tomyli-*` + 非前缀（`understand-change` 等） |

> **为什么没有 rsync**：2026-06 重构后，`~/.claude/skills/ljg-*` 和 `~/.claude/skills/tomyli-*` 全部是指向 canonical 的 symlink。在 canonical 里编辑 = 在 `~/.claude/skills/` 里编辑，再 rsync 反而引入幻象差异。

## 仓库路径（硬编码）

```
SKILLS_REPO="$HOME/github/ljg-skills"
REPO_URL="git@github.com:peng051410/ljg-skills.git"
```

如果 `$SKILLS_REPO` 不存在或 origin 不指向 peng051410 的 fork，脚本报错退出。**不会**自动 clone（canonical 应该早已存在；缺失意味着环境异常，需人工排查）。

## README 一致性（硬 gate）

每次 push 前，脚本扫描所有 skills 目录名，跟 `README.md` 对照：

- 列出 `$SKILLS_REPO/skills/` 下所有目录名（含 ljg-*、tomyli-*、其他）
- grep `README.md` 里出现的 skill 名
- 找出 repo 里有但 README 没提的——*几乎肯定意味着 README 漂移*
- 命中 → push 中止，列出缺失清单

每次 push 都问自己：

1. *新增 skill 了吗*？README 的清单 / 安装命令 / CLAUDE.md inventory 需要加一行
2. *删了 skill 吗*？对应行要删
3. *某个 skill 的描述大改了吗*？README 简介可能要同步

确认 README 已审、确实不需要更新时，绕过：

```bash
/tomyli-push --skip-readme-check
```

## 工作流

按 `Workflows/Push.md` 步骤执行 → 调用 `Tools/Push.sh`。

## Voice Notification

```bash
curl -s -X POST http://localhost:31337/notify \
  -H "Content-Type: application/json" \
  -d '{"message": "Running Push in tomyli-push"}' \
  > /dev/null 2>&1 &
```

输出文本：`Running **Push** in **tomyli-push**...`

## 自动版本 bump

脚本会自动 bump patch version 在：
- `.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json`

想 bump minor / major：先手动改完再跑脚本，脚本只会追加 patch。

## Examples

*Example 1: 一键推送*

```
User: /tomyli-push
→ 检查 origin 是否指向 peng051410/ljg-skills
→ README consistency check（跨 ljg-* / tomyli-* / 其他）
→ git status：列出有改动的 skill 目录
→ bump patch version
→ git add skills/ .claude-plugin/
→ git commit + git push origin master
→ 报告：哪些 skills 推了，新版本号
```

*Example 2: 只看不推*

```
User: /tomyli-push --dry-run
→ 列出 git status 里有改动的 skill 目录
→ 列出 README 缺失项（如有）
→ 不执行 commit / push
```

## Gotchas

- *README 漂移是最容易被忽略的*——加完新 skill 直接推，README 还停在老清单。脚本有硬 gate；拦下来时不要无脑加 `--skip-readme-check`，先看 README
- *git credentials 必须配好*（ssh key 或 PAT）—— 认证失败时直接报错
- *origin 必须是 peng051410/ljg-skills*——指向其他 remote（如上游 lijigang）会被脚本拒绝，避免误推到上游
- *脚本不动 md 分支*——这个 fork 不维护 md 分支。如果 md 分支需要同步，先手动切过去处理
- *symlink 模型下没有 rsync*——直接编辑 canonical 文件，不要再去 `~/.claude/skills/` 改（虽然两者等价，但保持心智模型一致：canonical 是源）
- *新 skill 的目录命名不限前缀*——`ljg-`、`tomyli-`、纯名字（如 `understand-change`）都会被捕获并参与 README check
