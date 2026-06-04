---
name: ljg-word
description: Deep-dive English word mastery tool. Deconstructs a single English word into core semantics and epiphany. Use when user asks to explain/master a specific English word.
version: "1.2.0"
user_invocable: true
---

## Usage

<example>
User: Deeply explain the word "Serendipity".
Assistant: [Calls ljg-explain-words with "Serendipity"]
</example>

## Instructions

目标不是翻译，而是让用户掌握这个词的深层含义和用法。

针对输入的 `word`（转换为小写，首字母大写），进行以下分析，直接在对话中用 Markdown 输出：

### 输出结构

#### 1. 标题行

```
## {Word}  /{音标}/  ![{Word}.mp3](../assets/voc/{Word}.mp3)  {English definition}  {中文翻译}
```

- `{Word}`：首字母大写。
- `{音标}`：IPA 音标（美式优先），形如 `/səˌrendəˈpɪdi/`。
- `![{Word}.mp3](../assets/voc/{Word}.mp3)`：发音音频内嵌链接（详见下方"发音音频下载"）。链接路径相对 logseq 笔记目录，跨平台稳定。
- `{English definition}`：一句简短的英文释义（来自权威词典，如 Merriam-Webster / Collins）。
- `{中文翻译}`：核心中文释义（一到两个最常用义项）。

#### 2. 词源说明（Etymology）

提供三个维度的词源信息，帮助用户从根上理解词义：

- **词根分解**：列出词根 / 词缀 / 来源语言 / 原始含义。例如 `serendipity` ← `Serendip`（古波斯语 *Sarandib*，斯里兰卡旧称）+ `-ity`（名词后缀）。
- **演变时间线**：跨语言演变路径与重要时间节点。例如：古波斯语 → 阿拉伯语 → 拉丁化 → 1754 年 Horace Walpole 在书信中造词。
- **语义漂移**：是否经历了词义收窄 / 扩展 / 褒贬转移。例如 `awful` 从"令人敬畏"漂移到"糟糕"。

#### 3. 核心语义

- **原始画面**: 用一句话描述该词源头最物理的画面（例如 Incubate: 母鸡趴在蛋上）。
- **核心意象**: 提炼公式（例如：温暖 + 时间 + 保护 = 孕育）。
- **解释**: 用充满洞见的语言阐述其深层含义与现代用法。分段清晰，**加粗**关键词。要有穿透力，展现词源、多领域含义之间的内在联系。

#### 4. 一语道破

一句中英双语的金句，必须具有哲学高度，总结该词的灵魂。用引用格式：

```
> "English sentence. 中文金句。"
```

## 发音音频下载

每次处理新词时，必须下载发音 MP3 并落地到 logseq 资源目录，以便词卡和下游 (ljg-word-flow → ljg-card) 直接引用稳定路径。

### 下载流程

1. **来源**：优先使用 [Forvo.com](https://forvo.com/word/{word}/) 的美式发音条目，否则退化到 Cambridge Dictionary 的 mp3 端点。
2. **下载到 Downloads**：用 `curl` 把 MP3 抓到 `~/Downloads/{Word}.mp3`。
3. **移动到 logseq 资源目录**：`mv ~/Downloads/{Word}.mp3 ~/Nustore/logseq/notes/assets/voc/{Word}.mp3`。
4. **校验**：确认文件存在且大小 > 0；失败则在输出中明确标注"发音文件未生成"，不要伪造链接。

### 文件命名约定

- 文件名首字母大写、保留原拼写：`Serendipity.mp3` / `Acquire.mp3` / `Foreign.mp3`。
- 资源目录：`~/Nustore/logseq/notes/assets/voc/`（已建立）。
- 笔记内引用路径（相对）：`../assets/voc/{Word}.mp3`。

### Acceptance check

完成一个词的输出前，确认：

- [ ] 标题行四要素齐：音标 + 音频链接 + 英文释义 + 中文翻译
- [ ] §2 词源三维度齐：词根 / 演变 / 漂移
- [ ] §3 核心语义有原始画面 + 核心意象公式 + 解释
- [ ] §4 一语道破是中英双语引用
- [ ] `~/Nustore/logseq/notes/assets/voc/{Word}.mp3` 文件实存且非空
