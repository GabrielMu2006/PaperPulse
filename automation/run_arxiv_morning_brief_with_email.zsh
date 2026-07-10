#!/bin/zsh
set -euo pipefail

export TZ="Asia/Shanghai"

ROOT="${PAPERPULSE_ROOT:-$HOME/Documents/papers}"
CODEX="${CODEX_BIN:-/Applications/Codex.app/Contents/Resources/codex}"
APP_DIR="${PAPERPULSE_AUTOMATION_DIR:-$HOME/Library/Application Support/CodexAutomations}"
LOG_DIR="${PAPERPULSE_LOG_DIR:-$HOME/Library/Logs/CodexAutomations}"
PROMPT_FILE="$APP_DIR/arxiv_morning_brief_prompt.md"
MAIL_SCRIPT="$APP_DIR/send_morning_brief_email.applescript"
FALLBACK_SCRIPT="$APP_DIR/generate_arxiv_fallback_brief.py"
DATE="$(/bin/date +%F)"
OUT_DIR="$ROOT/arxiv_morning_brief/$DATE"
BRIEF="$OUT_DIR/morning_brief.md"
EMAIL_BODY="$OUT_DIR/email_body.txt"
STAMP="$OUT_DIR/.morning_brief_email_sent"
FINAL_MESSAGE="$LOG_DIR/arxiv_morning_brief.last_message.txt"
RUN_LOG="$LOG_DIR/arxiv_morning_brief.wrapper.$DATE.log"
CODEX_MAX_ATTEMPTS=2
CODEX_RETRY_DELAY_SECONDS=120
CODEX_TIMEOUT_SECONDS=1800
if [[ -z "${PAPERPULSE_MAIL_SENDER:-}" || -z "${PAPERPULSE_RECIPIENTS:-}" ]]; then
  /bin/echo "Set PAPERPULSE_MAIL_SENDER and comma-separated PAPERPULSE_RECIPIENTS." >&2
  exit 2
fi
RECIPIENTS=("${(@s:,:)PAPERPULSE_RECIPIENTS}")

/bin/mkdir -p "$APP_DIR" "$LOG_DIR" "$OUT_DIR"

{
  /bin/echo "===== run started: $(/bin/date) ====="
  /bin/echo "Output directory: $OUT_DIR"
  /bin/echo "Brief attachment: $BRIEF"
  /bin/echo "Codex max attempts: $CODEX_MAX_ATTEMPTS"
  /bin/echo "Codex timeout seconds: $CODEX_TIMEOUT_SECONDS"
} >> "$RUN_LOG"

if [[ -e "$STAMP" ]]; then
  /bin/echo "Email already sent for $DATE; skipping duplicate run." >> "$RUN_LOG"
  exit 0
fi

run_codex_once() {
  "$CODEX" -a never exec \
    -C "$ROOT" \
    -s danger-full-access \
    --output-last-message "$FINAL_MESSAGE" \
    - < "$PROMPT_FILE" >> "$RUN_LOG" 2>&1 &

  local codex_pid=$!
  local elapsed=0
  local interval=10

  while /bin/kill -0 "$codex_pid" 2>/dev/null; do
    if [[ "$elapsed" -ge "$CODEX_TIMEOUT_SECONDS" ]]; then
      /bin/echo "Codex attempt timed out after $CODEX_TIMEOUT_SECONDS seconds; terminating pid $codex_pid." >> "$RUN_LOG"
      /bin/kill -TERM "$codex_pid" 2>/dev/null || true
      /bin/sleep 15
      if /bin/kill -0 "$codex_pid" 2>/dev/null; then
        /bin/echo "Codex pid $codex_pid did not exit after TERM; killing." >> "$RUN_LOG"
        /bin/kill -KILL "$codex_pid" 2>/dev/null || true
      fi
      wait "$codex_pid" 2>/dev/null || true
      return 124
    fi
    /bin/sleep "$interval"
    elapsed=$((elapsed + interval))
  done

  wait "$codex_pid"
  return $?
}

CODEX_STATUS=1
ATTEMPT=1
if [[ -s "$BRIEF" ]]; then
  /bin/echo "Existing brief found; skipping generation and proceeding to email: $BRIEF" >> "$RUN_LOG"
  CODEX_STATUS=0
else
  while [[ "$ATTEMPT" -le "$CODEX_MAX_ATTEMPTS" ]]; do
    /bin/echo "Codex attempt $ATTEMPT/$CODEX_MAX_ATTEMPTS started: $(/bin/date)" >> "$RUN_LOG"

    set +e
    run_codex_once
    CODEX_STATUS=$?
    set -e

    if [[ "$CODEX_STATUS" -eq 0 && -s "$BRIEF" ]]; then
      /bin/echo "Codex attempt $ATTEMPT succeeded." >> "$RUN_LOG"
      break
    fi

    /bin/echo "Codex attempt $ATTEMPT failed or did not create brief. Status: $CODEX_STATUS" >> "$RUN_LOG"
    if [[ "$ATTEMPT" -lt "$CODEX_MAX_ATTEMPTS" ]]; then
      /bin/echo "Retrying in $CODEX_RETRY_DELAY_SECONDS seconds..." >> "$RUN_LOG"
      /bin/sleep "$CODEX_RETRY_DELAY_SECONDS"
    fi
    ATTEMPT=$((ATTEMPT + 1))
  done
fi

{
  /bin/echo "Codex exit status: $CODEX_STATUS"
} >> "$RUN_LOG"

if [[ "$CODEX_STATUS" -ne 0 || ! -s "$BRIEF" ]]; then
  /bin/echo "Codex path failed or produced no brief; attempting fallback generator." >> "$RUN_LOG"
  set +e
  /usr/bin/python3 "$FALLBACK_SCRIPT" "$DATE" "$OUT_DIR" "$BRIEF" >> "$RUN_LOG" 2>&1
  FALLBACK_STATUS=$?
  set -e
  /bin/echo "Fallback generator exit status: $FALLBACK_STATUS" >> "$RUN_LOG"
fi

if [[ ! -s "$BRIEF" ]]; then
  /bin/echo "Fallback also failed; writing failure notification brief." >> "$RUN_LOG"
  /usr/bin/python3 - "$BRIEF" "$DATE" "$RUN_LOG" <<'PY' >> "$RUN_LOG" 2>&1
import sys
from pathlib import Path

brief_path = Path(sys.argv[1])
brief_date = sys.argv[2]
run_log = Path(sys.argv[3])

log_excerpt = ""
try:
    lines = run_log.read_text(encoding="utf-8", errors="replace").splitlines()
    log_excerpt = "\n".join(lines[-80:])
except Exception as exc:
    log_excerpt = f"无法读取日志：{exc}"

brief_path.write_text(
    "\n".join(
        [
            f"# 科研晨间简报生成失败 - {brief_date}",
            "",
            "今天的正常 Codex 生成和本地保底生成都没有成功完成，因此发送这封失败通知，避免静默缺席。",
            "",
            f"- 日志路径：`{run_log}`",
            "- 建议：检查网络、Codex 后端连接、arXiv API 访问和 Mail 发信状态后手动补跑。",
            "",
            "## 最近日志片段",
            "",
            "```text",
            log_excerpt,
            "```",
            "",
        ]
    ),
    encoding="utf-8",
)
print(f"Wrote failure notification brief: {brief_path}")
PY
fi

/usr/bin/python3 - "$BRIEF" "$DATE" "$EMAIL_BODY" <<'PY' >> "$RUN_LOG" 2>&1
import re
import sys
from pathlib import Path

brief_path = Path(sys.argv[1])
brief_date = sys.argv[2]
body_path = Path(sys.argv[3])
text = brief_path.read_text(encoding="utf-8")
is_failure = text.lstrip().startswith("# 科研晨间简报生成失败")
is_fallback = "生成方式：保底生成器" in text

def clean(line):
    return re.sub(r"\s+", " ", line).strip()

trends = []
in_trends = False
for raw in text.splitlines():
    line = raw.strip()
    if line.startswith("## 总体趋势观察"):
        in_trends = True
        continue
    if in_trends and line.startswith("## "):
        break
    if in_trends and re.match(r"^\d+\.\s+", line):
        trends.append(clean(re.sub(r"^\d+\.\s+", "", line)))

papers = []
current = None
for raw in text.splitlines():
    line = raw.strip()
    m = re.match(r"^##\s+\d+\.\s+(.+)$", line)
    if m:
        if current:
            papers.append(current)
        current = {"title": clean(m.group(1)), "date": "", "authors": "", "arxiv": ""}
        continue
    if not current:
        continue
    if line.startswith("- **日期**"):
        current["date"] = clean(line.split("：", 1)[-1])
    elif line.startswith("- **作者**"):
        current["authors"] = clean(line.split("：", 1)[-1])
    elif line.startswith("- **arXiv**"):
        current["arxiv"] = clean(line.split("：", 1)[-1])
if current:
    papers.append(current)

if is_failure:
    lines = [
        f"科研晨间简报生成失败 - {brief_date}",
        "",
        "今天的正常 Codex 生成和本地保底生成都没有成功完成。",
        "已发送 Markdown 失败通知作为附件，里面包含日志路径和最近日志片段。",
        f"本地路径：{brief_path}",
        "",
    ]
else:
    lines = [
        f"科研晨间简报 - {brief_date}",
        "",
        "完整 Markdown 简报已作为附件随邮件发送。",
        f"本地路径：{brief_path}",
        "",
    ]
    if is_fallback:
        lines.extend([
            "注意：这是一份保底版简报。正常 Codex 深度生成失败或超时后，系统基于 arXiv 元数据、摘要和 PDF 首页信息自动生成。",
            "",
        ])

if trends:
    lines.append("总体趋势：")
    for idx, trend in enumerate(trends[:5], 1):
        lines.append(f"{idx}. {trend}")
    lines.append("")

if papers:
    lines.append("今日入选文章概览：")
    for idx, paper in enumerate(papers, 1):
        lines.append(f"{idx}. {paper['title']}")
        if paper["date"]:
            lines.append(f"   日期：{paper['date']}")
        if paper["authors"]:
            authors = paper["authors"]
            if len(authors) > 180:
                authors = authors[:177].rstrip() + "..."
            lines.append(f"   作者：{authors}")
        if paper["arxiv"]:
            lines.append(f"   arXiv：{paper['arxiv']}")
    lines.append("")

lines.append("附件：morning_brief.md")
body_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"Wrote email body: {body_path}")
PY

/usr/bin/osascript "$MAIL_SCRIPT" "$BRIEF" "$DATE" "$EMAIL_BODY" "$PAPERPULSE_MAIL_SENDER" "${RECIPIENTS[@]}" >> "$RUN_LOG" 2>&1
/usr/bin/touch "$STAMP"

{
  /bin/echo "Email sent to: ${RECIPIENTS[*]}"
  /bin/echo "===== run finished: $(/bin/date) ====="
} >> "$RUN_LOG"
