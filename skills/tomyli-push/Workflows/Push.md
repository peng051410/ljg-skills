# Push Workflow

一键 commit + 推 `~/github/ljg-skills` 到 `origin/master`。

## Voice Notification

```bash
curl -s -X POST http://localhost:31337/notify \
  -H "Content-Type: application/json" \
  -d '{"message": "Running Push in tomyli-push"}' \
  > /dev/null 2>&1 &
```

## Step 0: Pre-push README check（硬 gate）

每次 push 都要先问自己一句：

> README / CLAUDE.md inventory 还跟实际 skills 目录对得上吗？

具体三件事：

1. *新增 skill 了吗*？ → README 的 skill 清单 / 安装命令需要加一行
2. *删了 skill 了吗*？ → README 对应行要删
3. *某个 skill 的描述大改了吗*？ → README 的简介可能要同步

脚本会扫描 `$SKILLS_REPO/skills/` 下所有目录名（含 `ljg-*`、`tomyli-*`、其他），grep README 里 skill 名引用。如果 repo 里有但 README 没提，*push 直接中止*。

绕过办法（仅当确认 README 已审过）：

```bash
bash Push.sh --skip-readme-check
```

## Step 1: 解析参数

| 用户说 | 标志 | 效果 |
|--------|------|------|
| 默认 | （无标志） | README check + git status detect + commit + push master |
| "dry-run", "看一下" | `--dry-run` | 只列出会做什么，不真推（README check 仍跑但不阻塞） |
| "force", "强推" | `--force` | 跳过 detect，强制 add 所有 skills/ 改动 |
| "README 已审" | `--skip-readme-check` | 跳过 README 一致性 gate（其他 check 仍跑） |

## Step 2: 执行脚本

```bash
bash ~/.claude/skills/tomyli-push/Tools/Push.sh [--dry-run|--force|--skip-readme-check]
```

脚本逻辑：

1. *Setup*：确认 `$HOME/github/ljg-skills` 存在且 origin = `peng051410/ljg-skills`
2. *README check*：列 `skills/*` 目录名，grep README，缺失 → exit 1
3. *Detect*：`git status --porcelain` 看 `skills/` 下哪些 skill 目录有改动
4. *Master 推送*：
   - `git checkout master` + `git pull --rebase`
   - bump patch version (`plugin.json` + `marketplace.json`)
   - `git add skills/ .claude-plugin/`
   - `git commit -m "feat: sync skills [<list>] (v<new>)"`
   - `git push origin master`
5. *Report*：列出推送结果 + 版本号

## Step 3: 报告

输出格式：

```
═══ tomyli-push 报告 ═══════════════
更新的 skills:
  - tomyli-mem
  - understand-change

master @ v1.18.1 → pushed

══════════════════════════════════
```

## Step 4: 异常处理

| 异常 | 处理 |
|------|------|
| `$SKILLS_REPO` 不存在 | 报错退出（不自动 clone，canonical 缺失意味着环境异常） |
| origin 不指向 peng051410/ljg-skills | 报错退出，避免误推上游 |
| `git push` 被远端拒（远端有新 commit） | 尝试 `pull --rebase`；冲突时报错让用户处理 |
| `skills/` 下没有任何变更 | 输出 "Nothing to push." 退出 0 |
| `git checkout master` 因脏文件失败 | 报错并提示先 commit/stash |

## 验收

- master 分支有新 commit（除非检测到无变更）
- 远端 origin/master 已更新
- 报告里列出版本号和推送的 skills
- README check 通过或被显式跳过
