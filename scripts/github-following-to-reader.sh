#!/usr/bin/env bash
# github-following-to-reader.sh — 将 GitHub 精选关注者的 .atom feed 导出为 OPML
#
# 用法:
#   bash github-following-to-reader.sh [--all] [--min-followers N]
#
# 默认: 导出精选列表 (Tier 1)
# --all: 导出所有关注者 (313 人，不推荐)
# --min-followers N: 按 followers 数筛选

set -euo pipefail

OUTPUT="${1:-github-feeds.opml}"

# Tier 1 精选列表：GitHub 动态本身有信息价值的人
TIER1_USERS=(
  # Emacs 核心
  manateelazycat    # Andy Stewart, EAF/lsp-bridge 作者
  purcell           # Emacs 包维护大户
  jwiegley          # use-package 作者
  sachac            # Sacha Chua, Emacs 周报
  minad             # Vertico/Consult/Corfu 作者
  tarsius           # Magit 作者
  hlissner          # Doom Emacs 作者
  zilongshanren     # 子龙山人
  redguardtoo       # Emacs 实践者

  # AI / 前沿技术
  steipete          # AI + iOS, OpenClaw
  yetone            # Bob 翻译, AI 工具

  # 开源 / 工具 / 独立开发
  antirez           # Redis 作者
  sindresorhus      # 开源工具之王
  jvns              # Julia Evans, 技术写作
  skeeto            # C 语言深度
  easychen          # 独立开发者
  cloudwu           # 云风
  ruanyf            # 阮一峰
  djyde             # Randy, 独立开发
  matklad           # rust-analyzer 作者
  madawei2699       # Building 方向
)

echo "📋 生成 GitHub .atom feed OPML"
echo "   精选 ${#TIER1_USERS[@]} 人"
echo ""

# 生成 OPML
cat > "$OUTPUT" << 'HEADER'
<?xml version="1.0" encoding="UTF-8"?>
<opml version="2.0">
  <head>
    <title>GitHub Following (Tier 1)</title>
  </head>
  <body>
    <outline text="GitHub" title="GitHub">
HEADER

for user in "${TIER1_USERS[@]}"; do
  atom_url="https://github.com/${user}.atom"
  html_url="https://github.com/${user}"
  echo "      <outline type=\"rss\" text=\"${user}\" title=\"${user}\" xmlUrl=\"${atom_url}\" htmlUrl=\"${html_url}\"/>" >> "$OUTPUT"
  echo "  ✅ $user"
done

cat >> "$OUTPUT" << 'FOOTER'
    </outline>
  </body>
</opml>
FOOTER

echo ""
echo "✅ 已生成: $OUTPUT"
echo "   包含 ${#TIER1_USERS[@]} 个 GitHub 用户的 .atom feed"
echo ""
echo "下一步:"
echo "  1. 打开 https://read.readwise.io/feed"
echo "  2. 点击 Import OPML"
echo "  3. 选择 $OUTPUT"
echo ""
echo "注意: .atom feed 包含 star/fork/create/push 等所有公开活动"
echo "      如果嘈杂可在 Reader 中 mute 特定 feed"
echo ""
echo "Tier 2/3 的 ~290 人不需要订 feed:"
echo "  - 他们的博客大部分已在 Reader RSS 中"
echo "  - GitHub Stars 已通过 38 个 Star Lists 覆盖"
echo "  - 按需搜索: gh api /users/USERNAME/events"
