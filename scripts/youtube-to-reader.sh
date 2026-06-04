#!/usr/bin/env bash
# youtube-to-reader.sh — 将 YouTube 订阅导出为 Reader 可导入的 OPML
#
# 用法:
#   1. 先从 Google Takeout 导出 YouTube 订阅 CSV
#      https://takeout.google.com → 选 YouTube → 导出
#      文件位置: Takeout/YouTube and YouTube Music/subscriptions/subscriptions.csv
#
#   2. 运行此脚本:
#      bash youtube-to-reader.sh ~/Downloads/Takeout/.../subscriptions.csv
#
#   3. 将生成的 OPML 文件导入 Reader:
#      打开 https://read.readwise.io/feed → Import OPML
#
# CSV 格式 (Google Takeout):
#   Channel Id,Channel Url,Channel Title
#   UCxxxxxx,http://www.youtube.com/channel/UCxxxxxx,Channel Name

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "用法: $0 <subscriptions.csv> [output.opml]"
  echo ""
  echo "从 Google Takeout 导出的 YouTube subscriptions.csv 转换为 OPML"
  echo "然后在 Readwise Reader 中 Import OPML 即可批量订阅"
  echo ""
  echo "获取 CSV:"
  echo "  1. 打开 https://takeout.google.com"
  echo "  2. 取消全选 → 只勾选 YouTube and YouTube Music"
  echo "  3. 导出 → 解压 → 找到 subscriptions/subscriptions.csv"
  exit 1
fi

INPUT="$1"
OUTPUT="${2:-youtube-feeds.opml}"

if [ ! -f "$INPUT" ]; then
  echo "❌ 文件不存在: $INPUT"
  exit 1
fi

# 统计频道数
TOTAL=$(tail -n +2 "$INPUT" | wc -l | tr -d ' ')
echo "📺 发现 $TOTAL 个 YouTube 订阅频道"

# 生成 OPML
cat > "$OUTPUT" << 'HEADER'
<?xml version="1.0" encoding="UTF-8"?>
<opml version="2.0">
  <head>
    <title>YouTube Subscriptions</title>
  </head>
  <body>
    <outline text="YouTube" title="YouTube">
HEADER

COUNT=0
tail -n +2 "$INPUT" | while IFS=',' read -r channel_id channel_url channel_title; do
  # 清理可能的 BOM 和空白
  channel_id=$(echo "$channel_id" | tr -d '\r' | xargs)
  channel_title=$(echo "$channel_title" | tr -d '\r' | xargs)

  # 跳过空行
  [ -z "$channel_id" ] && continue

  # 构造 RSS URL
  rss_url="https://www.youtube.com/feeds/videos.xml?channel_id=${channel_id}"
  html_url="https://www.youtube.com/channel/${channel_id}"

  # XML 转义标题中的特殊字符
  safe_title=$(echo "$channel_title" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')

  echo "      <outline type=\"rss\" text=\"${safe_title}\" title=\"${safe_title}\" xmlUrl=\"${rss_url}\" htmlUrl=\"${html_url}\"/>" >> "$OUTPUT"
  COUNT=$((COUNT + 1))
done

cat >> "$OUTPUT" << 'FOOTER'
    </outline>
  </body>
</opml>
FOOTER

echo "✅ 已生成 OPML: $OUTPUT"
echo "   包含 $TOTAL 个 YouTube 频道的 RSS feed"
echo ""
echo "下一步:"
echo "  1. 打开 https://read.readwise.io/feed"
echo "  2. 点击 Import OPML"
echo "  3. 选择 $OUTPUT"
echo "  4. 完成！YouTube 更新会自动出现在 Reader feed 中"
echo ""
echo "提示: Reader 会自动获取视频的 transcript（如果有字幕的话）"
echo "      搜索: readwise reader-search-documents --query '关键词' --location-in feed"
