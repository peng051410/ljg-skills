---
name: tomyli-hubble
description: "三层搜索引擎：先搜记忆（我知道的），再搜订阅（我可能知道的），最后搜公网（世界知道的）。Use when user says '搜我的', '在我的订阅里找', '哈勃搜索', 'hubble', 'hubble search', '三层搜索', '先搜我的再搜外面'."
user_invocable: true
version: "1.0.0"
---

# tomyli-hubble: 哈勃半径搜索

三层搜索，由近及远。先搜自己的记忆，再搜订阅宇宙，最后才去公网。

## 概念

```
第一层  我知道的      Nowledge Mem (memories + threads)
第二层  我可能知道的  Readwise Reader (26,000+ feed items, 1,200+ archived)
第三层  世界知道的    WebSearch (public internet)
```

核心原则：*信息有亲疏*。自己记下的 > 自己订了的 > 公网随机搜到的。

## Instructions

### 1. 接收查询

用户给出一个搜索意图。可以是问题、关键词、或一段描述。

从用户输入中提炼出：
- `query_zh`: 中文搜索词（如果原文是中文直接用，英文则翻译）
- `query_en`: 英文搜索词（如果原文是英文直接用，中文则翻译）
- `query_core`: 最精炼的关键词组合（用于 Nowledge Mem）

### 2. 第一层：记忆（我知道的）

并发执行：

```bash
nmem --json m search "{query_core}" --importance 0.3
```

```bash
nmem --json t search "{query_core}" --limit 3
```

筛选规则：
- memory score >= 0.4 的保留
- thread score >= 0.5 的保留
- 每层最多保留 5 条结果

### 3. 第二层：订阅（我可能知道的）

并发执行，中英文各搜一次：

```bash
readwise reader-search-documents --query "{query_zh}" --limit 10 --json
```

```bash
readwise reader-search-documents --query "{query_en}" --limit 10 --json
```

结果去重（按 document_id），合并后按相关性排序，保留 top 10。

对每条结果提取：
- `title`: 文章标题
- `author`: 作者
- `category`: 类型 (rss/podcast/tweet/article/pdf/email)
- `url`: Reader 链接
- `matches[0].plaintext`: 最相关片段（截取前 200 字）

### 4. 第三层：公网（世界知道的）

仅在以下情况触发第三层：
- 前两层合计结果 < 3 条
- 用户明确说"也搜公网" / "search web too"
- 查询涉及时效性信息（新闻、最新版本、价格等）

触发时用 WebSearch：
- 使用 `query_zh` 或 `query_en` 中更合适的那个
- 保留 top 5 结果

### 5. 输出

按以下格式输出，用分隔线区分三层：

```
## 🧠 记忆层（我知道的）

[结果或"无相关记忆"]

---

## 📡 订阅层（我可能知道的）

[结果列表，每条包含：标题、作者、类型标签、相关片段、Reader 链接]

---

## 🌐 公网层（世界知道的）

[结果或"前两层已充分覆盖，未触发公网搜索"]
```

每层结果之后，附一句话总结该层发现了什么。

最后给出 *综合判断*（2-3 句）：
- 这个话题在你的信息宇宙中覆盖度如何？
- 最值得深入的线索是哪条？
- 是否需要进一步展开某一层？

### 6. 深入模式

如果用户对某条结果说"展开" / "读这篇" / "详细看看"：

- 记忆层 → `nmem --json m show {id}` 或 `nmem --json t show {thread_id} --limit 8`
- 订阅层 → `readwise reader-get-document-details --id {document_id} --json`，提取 markdown content，用 ljg-read 的伴读方式呈现
- 公网层 → WebFetch 抓取全文

## 边界

- 不做自动定时索引（Reader 自己在做）
- 不修改 Reader 中的文档状态（不标记已读、不移动、不打标签）
- 不把搜索结果自动写入 Nowledge Mem（用户主动要求时才存）
- 搜索是只读操作，副作用为零
