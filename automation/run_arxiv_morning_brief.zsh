#!/bin/zsh
set -euo pipefail

export TZ="Asia/Shanghai"

SCRIPT_DIR="${0:A:h}"
ROOT="${PAPERPULSE_ROOT:-${SCRIPT_DIR:h}}"
CODEX="${CODEX_BIN:-/Applications/Codex.app/Contents/Resources/codex}"
PROMPT_FILE="$ROOT/automation/arxiv_morning_brief_prompt.md"
DATE="$(/bin/date +%F)"
OUT_DIR="$ROOT/arxiv_morning_brief/$DATE"
LOG_DIR="$ROOT/logs"
RUN_PROMPT="$OUT_DIR/run_prompt.md"
FINAL_MESSAGE="$OUT_DIR/final_message.txt"
RUN_LOG="$LOG_DIR/arxiv_morning_brief.$DATE.log"

/bin/mkdir -p "$OUT_DIR" "$LOG_DIR"

{
  /bin/date
  /bin/echo
  /bin/echo "Current date: $DATE"
  /bin/echo "Current timezone: Asia/Shanghai"
  /bin/echo "Output directory: $OUT_DIR"
  /bin/echo
  /bin/cat "$PROMPT_FILE"
} > "$RUN_PROMPT"

{
  /bin/echo "===== arXiv morning brief run started: $(/bin/date) ====="
  "$CODEX" --search exec \
    -C "$ROOT" \
    -s workspace-write \
    -a never \
    --output-last-message "$FINAL_MESSAGE" \
    - < "$RUN_PROMPT"
  /bin/echo "===== arXiv morning brief run finished: $(/bin/date) ====="
} >> "$RUN_LOG" 2>&1
