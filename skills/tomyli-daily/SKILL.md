---
name: tomyli-daily
description: "每日一词一语：每天学一个英语词 + 一个汉语成语，并找出两者底层的同一组对立（元洞察）。从队列文件取下一对未学的，按强制结构生成深度分析，自动双写到 logseq tracker 和 Nowledge Mem。Use when user says '一词一语', '今日学习', '每日一词', 'daily pair', 'daily word idiom', or starts a daily learning session for English word + Chinese idiom."
user_invocable: true
version: "1.3.0"
---

# tomyli-daily: 每日一词一语

把英语词、汉语成语、底层对立洞察、双写持久化绑成一次操作的日课流程。**编排器，不是内容生成器**——内容由 Claude 生成，但骨架、队列管理、双写不可漂移。

> 历史名：原名 `ljg-daily`，2026-06-04 随仓库迁移至 `~/github/ljg-skills/`，重命名为 `tomyli-daily`。老记忆的 nmem 条目仍以 `ljg-daily` 为名，可通过映射记忆桥接。

## 依赖 skills

- **logseq-syntax** — tracker 文件 `每日一词一语.md` 的 logseq 块级语法 / 命名空间 / 缩进规则
- **markdown-bilingual** — voc/idiom 输出页的 YAML frontmatter 规范（双 app 兼容）

## 模式

**强制 NATIVE 模式。** 直接按执行步骤生成内容并双写，不走 Algorithm 七步流程。

## 触发

```
/tomyli-daily                       # 自动取队列下一对
/tomyli-daily foreign 画蛇添足      # 显式指定一对
/tomyli-daily -c                    # 同时调用 ljg-word-flow 生成词的 PNG 信息图
```

## 关键文件路径

- **队列 + 记录文件**: `/Users/tomyli/Nustore/logseq/notes/pages/每日一词一语.md`（**logseq-only** tracker，纯块级语法）
- **词卡输出**: `/Users/tomyli/Nustore/logseq/notes/pages/voc___{word}.md`（**bilingual**：YAML frontmatter + 标准 markdown）
- **成语输出**: `/Users/tomyli/Nustore/logseq/notes/pages/idiom___{成语}.md`（**bilingual**）

## 执行

### Step 0: 核实日期（强制）

每次执行第一步必须调用：

```bash
date +%Y-%m-%d
```

把这个 shell 输出当作"今天"。**禁止**用 SessionStart briefing、CLAUDE.md、对话上下文里出现过的任何日期作为今天。这一步防止 [LESSON-3d14ca0c](nowledgemem://memory/3d14ca0c-5a7c-44ba-9a45-6b95cf02cffa) 描述的日期错位。

### 1. 读队列文件

Read `每日一词一语.md`：
- 找"英语词队列"区第一个未勾选 `[ ] [[voc/X]]`
- 找"成语队列"区第一个未勾选 `[ ] [[idiom/Y]]`
- 同时**抓取最近 7 天已学成语**（"记录"区里的 idiom 链接），作为本周母题串联的素材
- 读"记录"最新日期，判断是否需要标注"跳过 N 天"

如果用户显式传词/成语参数，跳过队列查找，但仍抓取最近 7 天已学成语用于串联。

### 2. 生成英语词部分（强制结构）

**所有六块都必须有，缺一块视为流程失败。**

**输出文件**：`pages/voc___{word}.md`

#### Step 2a: 发音回填（强制前置子步骤）

写深度解剖之前先确认 voc 文件 *已有 IPA 音标 + 可播放 audio*。三种入口状态：

| 状态 | 处理 |
|---|---|
| A. 文件不存在 | 直接进入 Step 2 主流程，按下方 "新建文件 phonetic 块" 模板插 IPA + audio |
| B. quick-capture 已写入完整 phonetic（含 `/xxx/` IPA + `<audio>` 标签且非空） | 跳过回填，直接追加深度解剖段 |
| C. **quick-capture 已写入但 phonetic 字段为空**（IPA 缺、`<audio>` 缺、或两者都缺） | **必须先回填**，再追加深度解剖段 |

**状态 C 的回填脚本**（先 dictionaryapi.dev，失败回退 Wiktionary + Google TTS）：

```bash
WORD={word}
# 1. dictionaryapi.dev：同时给 IPA 和 mp3
curl -s "https://api.dictionaryapi.dev/api/v2/entries/en/$WORD" \
  | jq -r '.[0].phonetics[]? | select(.text != "" or .audio != "") | "\(.text)\t\(.audio)"' \
  | head -5
# 2. 直接探活 us / uk mp3（dictionaryapi.dev 的 media URL 即使 JSON 为空也可能有文件）
for region in us uk; do
  url="https://api.dictionaryapi.dev/media/pronunciations/en/$WORD-$region.mp3"
  size=$(curl -sI "$url" | awk '/^content-length:/ {print $2}' | tr -d '\r')
  echo "$region: $url (size=${size:-0})"
done
# 3. Google TTS fallback（任何词都能拿到 mp3，但是机器音）
echo "fallback: https://translate.google.com/translate_tts?ie=UTF-8&q=$WORD&tl=en&client=tw-ob"
```

**判定 + 写入规则**：
1. 若 dictionaryapi.dev JSON 有 `text`（IPA）→ 用它；无则查 Wiktionary 英文词条人工定 IPA（最坏情况：从 Step 2 词根分析里推导一个近似 IPA 加 *(approximate)* 标注）
2. 若 dictionaryapi.dev media URL 返回 `content-length > 1024`（真实 mp3）→ 用它；返回 0 或 404 → 用 Google TTS fallback URL
3. 不允许把空 phonetic 字段保留——*要么有真人录音，要么有 TTS fallback*，不能没声音

**新建文件 phonetic 块（状态 A）模板**：

```markdown
- {word}
	- phonetic
		- /{IPA}/
		  <audio controls><source src="{verified_mp3_url}"></audio>
	- noun
		- {基础定义}
	- verb
		- {基础定义}
```

**回填空 phonetic（状态 C）模板**——**只改 phonetic 块，不动 quick-capture 已有的 noun/verb 定义**：

```markdown
	- phonetic
		- /{IPA}/
		  <audio controls><source src="{verified_mp3_url}"></audio>
```

回填完成后才进入下方深度解剖段。

#### Step 2b: 深度解剖段

**文件首部使用 YAML frontmatter（双 app 兼容，让 Obsidian 也正确显示 properties）**：

```markdown
---
tags: [english, voc]
aliases: [{word}]
type: voc-deep-dive
created: {YYYY-MM-DD}
---

# {Word} — 深度解剖

## English Word: **{Word}** /{音标}/ — {中文翻译}

**灵魂：{词根公式}** —— {一句话核心：不是 X，是 Y 的判断}

词根 {Latin/Old English/...} *{源词}* = "{原始物理含义}"。同族词（如有，3-5 个，揭示共享动作）：
- **{cognate1}**（{怎么从源词派生}）
- **{cognate2}**（...）

整族词共享一个动作：**{什么动作/判断}**。{Word} 的核心从来不是 {表面义}，是 **{深层判断}**。

### N 兄弟辨析（最关键）
- **{Word}** = {核心轴上的位置}
- **{近义词1}** = {同轴另一位置}
- **{近义词2}** = ...
{至少 3 个，最多 5 个；每条必须沿同一条概念轴排开，不能各说各话}

{用一句话点破这组词的"冷热轴"或"主动被动轴"}

### 被忽略的用法（这才是真正的心脏）
- **{phrase1}** — {为什么这个用法揭穿了词的真实结构}
- **{phrase2}** — ...

{这两/三个用法揭穿：{Word} 衡量的从来不是 X，是 **Y**}

### 反面不是 {直觉反义词}，是 **{真正反面}**
{解释：你以为反义是 X，其实反义是 Y。一两句对照例子}

### 英文金句

> *{English one-liner that compresses the soul, often "X is not about Y, it's about Z" or "X is a verdict on Z" 形式}*
```

### 3. 生成成语部分（强制结构）

**输出文件**：`pages/idiom___{成语}.md`

**文件首部使用 YAML frontmatter（双 app 兼容）**：

```markdown
---
tags: [idiom, chinese, learning]
aliases: [{成语}]
type: idiom-deep-dive
created: {YYYY-MM-DD}
source: 汉语成语小词典
---

# {成语} — 深度解剖

## Idiom: **{成语}**（{出处，如《战国策·齐策二》}）

**灵魂：{一句话核心，必须反直觉或揭穿一层}**

{原文/典故核心情节，2-3 句}

### 三层（或多层）结构

1. **{表层名}（{一词}）**— {表层现象}
2. **{中层名}（{一词}）**— {中层心理}
3. **{深层名}（{一词}）**— {深层存在论判断}——**这才是真正的罪/灵魂**

{用一句话点破：原意/真正提示不是 X，是 Y}

### 与本周其他成语的母题串联

{读取最近 7 天已学成语列表，找出与今天成语共享的母题。如果三条以上能串成一个三角/谱系，明确标出"X 三部曲"或类似结构。如果今天的成语跳出现有母题，明确说明"今天跳出了之前的 X 母题轴，转向 Y"}

- [[idiom/X]] — {它在母题里负责什么}
- [[idiom/Y]] — {同}
- [[idiom/今天的]] — {同}

{一句话总结这组串联的意义}

### 现代镜像

- **{现代场景1}**：{怎么对应}
- **{现代场景2}**：...
- **{现代场景3}**：...

**{真正的 X 不是 Y，是 Z}**——{升级到当下时代特征的一句话警示}
```

### 4. 元洞察（核心创造性步骤）

**这是 tomyli-daily 的灵魂，必须出现，必须是对立结构。**

```markdown
## 两者共通的底层模式（今天的元洞察）

{Word} 和 {成语} 在最底层指向同一组对立：**{X 的清醒/失守}** 或 **{显化 vs 自欺}** 或 **{释放 vs 困住}** 等格式。

|  | {Word} | {成语} |
|---|---|---|
| {维度1} | ... | ... |
| {维度2} | ... | ... |
| {失守代价} | ... | ... |

**两者本质同一：{压缩到一句的共通病}**

**今天的检验之刀**：
> {把元洞察转成一个可以问自己的判断句}
```

**约束**：元洞察必须是"X vs Y"对立结构，不能是泛泛的"两者都讲了重要性/局限性/某种品质"。如果找不到对立结构，必须回头重选词或成语。

### 5. Trigger Hints

```markdown
## Trigger Hints
- **{未来场景1}** —— {该浮现的提醒}
- **{未来场景2}** —— ...
- **{未来场景3}** —— ...
{3-5 条，必须是"未来在 X 场景下应该浮现"，不是"X 是什么意思"}
```

### 6. 双写持久化（不可省略）

#### 6a. 更新 logseq tracker 文件

Edit `每日一词一语.md`：

1. **勾选队列项**：`[ ] [[voc/X]]` → `[x] [[voc/X]]`，成语同理
2. **顶部插入新日期块**（在"## 记录"标题下，紧邻最新日期之上）：

```markdown
- ## 记录
	- ### {YYYY-MM-DD}{如跳过则补 (上次 X-XX，跳过 N 天)}
		- 英语：[[voc/{word}]] ✓
		- 成语：[[idiom/{成语}]] ✓
		- 元洞察：{X vs Y 一句话压缩}
	- ### {上一次日期}
```

注意原文用 tab 缩进，不能用空格。

#### 6b. 写入 Nowledge Mem

```bash
nmem m add "{完整的当日 markdown 内容，包括词部分+成语部分+元洞察+Trigger Hints}" \
  -t "Daily Word & Idiom {YYYY-MM-DD}: {word} + {成语} ({元洞察压缩})" \
  -i 0.8
```

importance 固定 0.8——日课条目都是结构性记忆。

#### 6c.（可选 -c flag）调用 ljg-word-flow 生成 PNG

如果用户加了 `-c`：
```
Skill: ljg-word-flow {Word}
```

生成 `~/Downloads/{Word}.png`。

### 7. 汇总报告

```
════ 一词一语 {YYYY-MM-DD} ═══════════════════════
📖 {Word} ({中文}) ✓
🀄 {成语} ✓
💡 元洞察：{X vs Y}
✓ 队列已勾选
✓ 记录已加 ### {日期} 块
✓ Nowledge Mem 已存（id: {id}）
{如 -c：🖼️ ~/Downloads/{Word}.png}
```

## 关键约束（红线）

1. **Step 0 必须先调 `date +%Y-%m-%d`** —— 所有日期来自 shell 输出，不从 context 推断（防 [LESSON-3d14ca0c](nowledgemem://memory/3d14ca0c-5a7c-44ba-9a45-6b95cf02cffa)）
2. **元洞察必须对立结构**——X vs Y 格式。"两者都讲 X"不是元洞察，是总结。
3. **本周母题串联必须读最近 7 天已学成语**——不能凭空举例或胡编已学列表。
4. **Trigger Hints 必须面向未来**——是"什么时候该想起来"，不是"它是什么"。
5. **每日条目按时间倒序插入**——最新日期永远在"## 记录"下第一项。
6. **跳过日子要标注**——读上一次日期，差 ≥2 天就在标题加"(上次 X-XX，跳过 N 天)"。
7. **importance 固定 0.8**——不要随场景调整。
8. **logseq tracker 文件用 tab 缩进**——`每日一词一语.md` 是 logseq-only，按 logseq-syntax 处理。
9. **voc/idiom 输出页用 YAML frontmatter**——双 app 兼容，Obsidian 也能识别 properties。**禁止**在 voc/idiom 页首用 logseq 块级 `tags::` 双冒号（会让 Obsidian 显示成丑字）。
10. **voc 文件 phonetic 字段不能为空**——Step 2a 必须把 IPA + audio 写齐。空 phonetic 必须用 dictionaryapi.dev → Wiktionary → Google TTS 三级 fallback 回填，不能让深度解剖段写在没声音的文件上面。
11. **强制 NATIVE 模式**——不走七步流程。
12. **队列空了要提醒补充**——如果某个队列没有未勾选项，明确告诉用户去补充队列再继续。

## 参考样本

最新双 app 兼容样本（v1.2.0 之后）：见 nmem id `2c6df265-34ca-4ee2-ae94-3b820f1e62d5`（late + 叶公好龙，2026-06-08）。

旧样本（v1.0 logseq-only 格式）：nmem id `03858b1a-07e5-4841-a11c-810f51c2f362`（foreign + 画蛇添足，2026-06-01）。两者结构相同，区别仅在文件首部 frontmatter 风格。

要看完整产物：`nmem m get <id>`。
