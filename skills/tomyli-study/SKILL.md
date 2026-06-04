---
name: tomyli-study
description: "Deep study a GitHub user (or any public creator) — Profile → Repos → Source → Starred Repos → Taste Map → Dual-Write Save (org + Nowledge Mem). MUST trigger when message contains a github.com/USERNAME URL together with words like '学习', 'study', '研究', '画像', '了解一下', '看看这个人', or when user pastes a GitHub user URL with no other instruction. Also trigger on bare username if context (prior assistant turn) implies GitHub profile research. Final phase ALWAYS dual-writes: appends to ~/Nustore/logseq/notes/pages/notes/github_follow.org AND saves nmem insight. Skipping the dual-write is a failure mode — answers in chat alone are lost."
user_invocable: true
version: "1.1.0"
---

# tomyli-study: 学习一个人

给一个 GitHub 用户（或其他公开平台创作者），通过作品逆向还原此人的思维模式、技术品味和方法论。最终产出：结构化档案 + 精炼洞察。

> 历史名：原名 `ljg-study`，2026-06-04 随仓库迁移至 `~/github/ljg-skills/`，重命名为 `tomyli-study`。老记忆的 nmem 条目仍以 `ljg-study` 为名，可通过映射记忆桥接。

## 参数

| 参数 | 说明 | 示例 |
|------|------|------|
| URL/用户名 | 必填，GitHub 用户 URL 或用户名 | `https://github.com/redguardtoo`、`jethrokuan` |
| `-s` | 包含 star 分析（默认不含，因为耗时较长） | |
| `-c` | 与其他已知人物做对比 | `-c jethrokuan` |

## 核心理念

**通过作品逆向一个人的思维结构。** 不是罗列 repo，而是回答：
1. 这个人在反复解决什么问题？
2. 他的技术品味是什么？（选择背后的价值观）
3. 他的方法论有什么可以借鉴的？
4. 和用户（我）有什么交集/启发？

## 执行流程

### Phase 1: 基础画像

并行执行以下调用：

```bash
# Profile
gh api users/{username} --jq '{login, name, bio, location, company, blog, followers, following, public_repos, created_at}'

# Top repos (by stars)
gh api "users/{username}/repos?sort=stars&per_page=30" --jq '.[] | {name, description, stargazers_count, language, updated_at, fork}' | head -100
```

从 top repos 中，选出 **5-8 个代表作**（排除 fork、排除明显的配置/dotfiles 类——除非配置本身是作品，如 emacs.d）。

### Phase 2: 深入代表作

对选出的代表作，并行读取：

1. **README**（`gh api repos/{owner}/{repo}/readme --jq .content | base64 -d` 或 WebFetch）
2. **目录结构**（`gh api repos/{owner}/{repo}/contents`）
3. **Recent commits**（`gh api repos/{owner}/{repo}/commits?per_page=10`）
4. **如果是配置类 repo**：读关键配置文件（init.el、config.lua、.zshrc 等）

### Phase 3: 方法论提取

如果此人有 blog、guide、教程类 repo，读取核心内容。这往往是最有价值的——方法论比工具更持久。

### Phase 4: Star 分析（仅 `-s` 模式）

```bash
# 拉全部 starred repos
gh api "users/{username}/starred?per_page=100&page=1" --jq '.[] | {full_name, description, stargazers_count, language}'
# 翻页直到拉完
```

分析维度：
- **按领域聚类**：这个人关注哪些技术方向？
- **按时间线**：兴趣如何演变？
- **品味信号**：star 了冷门但精妙的项目？说明什么？
- **社区地图**：从 star 中能画出他的社交/技术圈子

### Phase 5: 输出画像

输出到对话中，结构：

```
## {Name} ({username}) — 画像

**一句话定位**：{用一句话概括此人的核心}

### 代表作品
| 项目 | Stars | 本质 |
|------|-------|------|
| ... | ... | ... |

### 思维模式（N 个 pattern）
1. **{pattern 名}** — {解释 + 证据}
2. ...

### 方法论
{此人的核心方法论，可以直接借鉴的}

### 职业/创作弧线
{时间线：从最早到现在，关键转折点}

### 品味地图（仅 -s 模式）
{按层分类的 star 分析}

### 和我的交集
| 维度 | {此人} | 我 |
|------|--------|------|
| ... | ... | ... |

### 可行动项
1. {具体可以 act on 的事}
2. ...
```

### Phase 6: 对比分析（仅 `-c` 模式）

如果用户指定了对比对象，增加一个对比表，维度包括：
- 方法论差异
- 工具选择差异
- 价值观差异
- 互补点

### Phase 7: 保存

**双写策略**（两个地方存不同的东西）：

#### 7a. 结构化档案 → github_follow.org

写入 `/Users/tomyli/Nustore/logseq/notes/pages/notes/github_follow.org`

格式：在文件末尾追加一个新的 org heading：

```org
* [[https://github.com/{username}][{username} ({Name})]]
:PROPERTIES:
:ADDED: [{YYYY-MM-DD}]
:END:

{一句话定位}

** 代表作
| 项目 | Stars | 说明 |
|------|-------|------|
| ... | ... | ... |

** 方法论
{核心方法论要点}

** 可借鉴
{对我有用的具体 actionable items}
```

#### 7b. 精炼洞察 → Nowledge Mem

存 1-2 条 memory（`nmem m add`），角度：
- **不是存档案**（那是 org 文件的事）
- **存和我相关的洞察**——未来我在某个语境下搜索时应该命中的内容
- importance: 0.7（除非此人与用户工作高度相关则 0.8）

如果用了 `-s` 模式，额外存一条 star taste map memory。

## 质量标准

- **画像不是 repo list**。如果输出读起来像 `gh api` 的美化版，就是失败。
- **思维模式是核心交付物**。用户想看到的是：从散落的项目中，你提炼出了什么此人反复在做的事。
- **可行动项必须具体**。不说"值得学习他的配置"，说"他的 init-evil.el 里有 path/equals/pipe text objects 的定义，可以直接抄到你的配置里"。
- **对比要有深度**。不只是表格罗列差异，要指出两人选择差异背后的价值观分歧。

## 不做什么

- 不做八卦/隐私推测
- 不对创作者做价值判断（"他的代码质量一般"）
- 如果 repo 很少或信息不够，诚实说"信息不足以画像"，不编造
