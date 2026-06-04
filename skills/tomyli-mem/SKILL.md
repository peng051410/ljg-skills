---
name: tomyli-mem
description: "Skill 产出蒸馏器。读一篇 ljg-* / tomyli-* skill 生成的 org 文件，提取核心洞见，存入 Nowledge Mem。无参数时自动找最近写入的 org 文件。Use when user says '存记忆', '记住这篇', 'mem', 'save to mem', or after any ljg/tomyli skill finishes and user wants to persist the insight."
user_invocable: true
version: "1.1.0"
---

# tomyli-mem: 蒸馏入忆

把 skill 产出的 org 文件蒸馏成一条记忆，存进 Nowledge Mem。

> 历史名：原名 `ljg-mem`，2026-06-04 随仓库迁移至 `~/github/ljg-skills/`，重命名为 `tomyli-mem`。老记忆 nmem id 仍以 `ljg-{identifier}` 为前缀，新跑产生 `tomyli-{identifier}` 前缀；同一 org 重跑互不覆盖。如需迁移历史 id，单独处理。

## 用法

```
/tomyli-mem                        # 自动找 ~/Documents/notes/ 最近修改的 org 文件
/tomyli-mem ~/Documents/notes/xxx.org   # 指定文件
```

## 执行

### 1. 定位文件

- 有参数 -> 用参数指定的路径
- 无参数 -> 找 `~/Documents/notes/` 里最近修改的 `.org` 文件：

```bash
ls -t ~/Documents/notes/*.org | head -1
```

读取该文件全文。

### 2. 识别类型

从 `#+filetags:` 提取标签，确定产出类型和蒸馏取材位置：

| filetags 含 | 来源 skill | 蒸馏取材 |
|-------------|-----------|---------|
| paper | ljg-paper | 「洞见」section |
| write | ljg-writes | 最底层切面的核心发现 |
| think | ljg-think | 最后一层（终点） |
| concept | ljg-learn | 「压缩」section（公式 + 一句话） |
| rank | ljg-rank | root rank 几根线的一句话概括 |
| reading | ljg-read | 「终局问题」+「读后一句话」 |
| roundtable | ljg-roundtable | 主持人全局总结中的核心判断 |
| relationship | ljg-relationship | 「核心洞察」section |
| invest | ljg-invest | 最后一句（创造新秩序 vs 搬运旧秩序） |
| travel | ljg-travel | 「城市概览」的文明定位 |
| paper-river | ljg-paper-river | 「提炼洞见」section |
| plain | ljg-plain | `#+title:` 本身即结晶 |

如果 filetags 不在上表中，按通用规则：读全文，提取最核心的 1-3 句。

### 3. 蒸馏

从取材位置提取内容，压缩成 1-3 句。

蒸馏标准：
- 不是摘要，是结晶——这篇产出最值钱的那个点
- 脱离原文上下文，这 1-3 句仍然有力量
- 半年后搜到这条记忆，能立刻想起是怎么回事

### 4. 存入 Nowledge Mem

从 org 文件提取元数据：
- `title`: `#+title:` 的值
- `identifier`: `#+identifier:` 的值（用作 nmem `--id`，保证幂等）
- `labels`: `#+filetags:` 的标签（去掉冒号，每个标签一个 `-l`）
- `source`: `file://` + org 文件绝对路径

```bash
nmem m add "{蒸馏的 1-3 句}" \
  -t "{title}" \
  --id "tomyli-{identifier}" \
  -i {importance} \
  -l {label1} -l {label2} \
  -s "file://{org 文件绝对路径}" \
  --unit-type learning
```

importance 按类型：

| 类型 | importance |
|------|-----------|
| paper, write, think, rank, paper-river | 0.7 |
| concept, reading, roundtable, relationship | 0.6 |
| invest | 0.8 |
| travel, plain | 0.5 |

### 5. 报告

```
已存入记忆 ✓
  标题: {title}
  蒸馏: {1-3 句}
  ID:   tomyli-{identifier}
```

## 幂等

用 `--id "tomyli-{identifier}"` 做 upsert。同一篇 org 文件重复跑，更新而非重复创建。

> **历史 id 兼容**：在此 skill 重命名前（2026-06-04 之前）跑过的同一篇 org，其 id 是 `ljg-{identifier}`。新跑会创建一条 `tomyli-{identifier}` 而不会覆盖老记忆。如需合并，可手动 `nmem m delete ljg-{identifier}`。

## 边界

- 只读 org 文件，不修改
- 不处理 ljg-card 的 PNG 产出（图片无文本可蒸馏）
- 不处理 ljg-word 的对话内输出（无 org 文件；如需存忆，用户直接 `nmem m add`）
