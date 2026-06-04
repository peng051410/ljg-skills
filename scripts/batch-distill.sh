#!/usr/bin/env bash
# batch-distill.sh — 批量蒸馏 Nowledge Mem threads
# 用法: bash batch-distill.sh [--dry-run] [--min-msgs 8] [--level swift]
#
# 前置条件: OMLx 必须在运行 (nmem 的 LLM provider)
# 检查: curl -s http://localhost:10240/v1/models

set -euo pipefail

# ── 参数 ──
DRY_RUN=false
MIN_MSGS=8
LEVEL="swift"
LOG_DIR="$HOME/.cache/nmem-distill"
LOG_FILE="$LOG_DIR/distill-$(date +%Y%m%d).log"
DONE_FILE="$LOG_DIR/done.txt"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)    DRY_RUN=true; shift ;;
    --min-msgs)   MIN_MSGS="$2"; shift 2 ;;
    --level)      LEVEL="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--dry-run] [--min-msgs N] [--level swift|guided|expert]"
      echo ""
      echo "Options:"
      echo "  --dry-run     只列出候选 thread，不执行蒸馏"
      echo "  --min-msgs N  最少消息数 (默认 8)"
      echo "  --level       蒸馏深度: swift(快/本地), guided(多步/本地), expert(远程LLM)"
      echo ""
      echo "进度保存在 $LOG_DIR/done.txt，中断后重跑会跳过已完成的。"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

mkdir -p "$LOG_DIR"
touch "$DONE_FILE"

# ── 前置检查 ──
if ! $DRY_RUN; then
  echo "🔍 检查 OMLx..."
  if ! curl -s --max-time 5 http://localhost:18989/v1/models >/dev/null 2>&1; then
    echo "❌ OMLx 未运行 (端口 18989)。请先启动 OMLx，然后重试。"
    echo "   nmem distill 依赖本地 LLM 做蒸馏。"
    exit 1
  fi
  echo "✅ OMLx 在线 (localhost:18989)"
fi

# ── 获取所有 thread ──
echo "📋 获取 thread 列表..."
ALL_IDS=$(nmem --json t list -n 300 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
for t in d.get('threads', []):
    print(t['id'])
")
TOTAL=$(echo "$ALL_IDS" | wc -l | tr -d ' ')
echo "   共 $TOTAL 个 thread"

# ── 筛选有内容的 thread ──
echo "🔬 筛选消息数 >= $MIN_MSGS 的 thread..."
CANDIDATES=()
SKIPPED_SHORT=0
SKIPPED_DONE=0

while read -r tid; do
  [ -z "$tid" ] && continue

  # 跳过已完成
  if grep -qF "$tid" "$DONE_FILE" 2>/dev/null; then
    SKIPPED_DONE=$((SKIPPED_DONE + 1))
    continue
  fi

  # 检查消息数
  msg_count=$(nmem --json t show "$tid" --limit 1 --content-limit 1 2>/dev/null | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('total_messages', d.get('total', 0)))" 2>/dev/null || echo "0")

  if [ -n "$msg_count" ] && [ "$msg_count" -ge "$MIN_MSGS" ] 2>/dev/null; then
    # 获取首条消息做标注
    topic=$(nmem --json t show "$tid" --limit 1 --content-limit 60 2>/dev/null | \
      python3 -c "
import sys,json
d=json.load(sys.stdin)
msgs=d.get('messages',[])
if msgs: print(msgs[0].get('content','?')[:60].replace('\n',' '))
else: print('?')
" 2>/dev/null || echo "?")
    CANDIDATES+=("$msg_count|$tid|$topic")
  else
    SKIPPED_SHORT=$((SKIPPED_SHORT + 1))
  fi
done <<< "$ALL_IDS"

# 按消息数降序排
IFS=$'\n' SORTED=($(printf '%s\n' "${CANDIDATES[@]}" | sort -t'|' -k1 -rn)); unset IFS

echo ""
echo "📊 筛选结果:"
echo "   候选: ${#SORTED[@]} 个 thread"
echo "   跳过 (消息太少): $SKIPPED_SHORT"
echo "   跳过 (已蒸馏): $SKIPPED_DONE"
echo ""

if [ ${#SORTED[@]} -eq 0 ]; then
  echo "✅ 没有需要蒸馏的 thread。"
  exit 0
fi

# ── 列出候选 ──
echo "┌─────┬──────┬──────────────────────────────────────────────────────────┐"
printf "│ %-3s │ %-4s │ %-56s │\n" "#" "msgs" "topic"
echo "├─────┼──────┼──────────────────────────────────────────────────────────┤"
i=1
for entry in "${SORTED[@]}"; do
  IFS='|' read -r msgs tid topic <<< "$entry"
  printf "│ %-3d │ %-4s │ %-56s │\n" "$i" "$msgs" "${topic:0:56}"
  i=$((i + 1))
done
echo "└─────┴──────┴──────────────────────────────────────────────────────────┘"

if $DRY_RUN; then
  echo ""
  echo "🏁 --dry-run 模式，不执行蒸馏。"
  echo "   去掉 --dry-run 开始蒸馏。"
  exit 0
fi

# ── 执行蒸馏 ──
echo ""
echo "🚀 开始蒸馏 (level=$LEVEL, 共 ${#SORTED[@]} 个)..."
echo "   中断后重跑会自动跳过已完成的 thread。"
echo "   日志: $LOG_FILE"
echo ""

SUCCESS=0
FAILED=0
SKIPPED_TRIAGE=0

for entry in "${SORTED[@]}"; do
  IFS='|' read -r msgs tid topic <<< "$entry"

  echo -n "  [$((SUCCESS + FAILED + SKIPPED_TRIAGE + 1))/${#SORTED[@]}] ($msgs msgs) ${topic:0:40}... "

  # 先 triage
  triage_output=$(nmem t distill "$tid" --triage 2>&1) || true

  if echo "$triage_output" | grep -qi "skip"; then
    echo "⏭️  triage: 跳过"
    echo "$(date +%H:%M:%S) TRIAGE_SKIP $tid ($msgs msgs) $topic" >> "$LOG_FILE"
    SKIPPED_TRIAGE=$((SKIPPED_TRIAGE + 1))
    echo "$tid" >> "$DONE_FILE"
    continue
  fi

  # 执行蒸馏
  distill_output=$(nmem t distill "$tid" -l "$LEVEL" 2>&1) || true

  if echo "$distill_output" | grep -qi "error\|timeout\|failed"; then
    echo "❌ 失败"
    echo "$(date +%H:%M:%S) FAIL $tid ($msgs msgs) $topic | $distill_output" >> "$LOG_FILE"
    FAILED=$((FAILED + 1))
    # 不标记为 done，下次重试
  else
    echo "✅"
    echo "$(date +%H:%M:%S) OK $tid ($msgs msgs) $topic" >> "$LOG_FILE"
    echo "$tid" >> "$DONE_FILE"
    SUCCESS=$((SUCCESS + 1))
  fi

  # 每 5 个暂停 2 秒，避免压垮本地 LLM
  if (( (SUCCESS + FAILED + SKIPPED_TRIAGE) % 5 == 0 )); then
    sleep 2
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 蒸馏完成"
echo "   ✅ 成功: $SUCCESS"
echo "   ⏭️  跳过 (triage): $SKIPPED_TRIAGE"
echo "   ❌ 失败: $FAILED"
echo "   日志: $LOG_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
