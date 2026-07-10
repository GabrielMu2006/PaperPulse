#!/usr/bin/env python3
"""Generate a fallback arXiv morning brief without an LLM.

This is intentionally conservative: it uses arXiv metadata, downloads PDFs,
and emits a readable Chinese Markdown brief when the Codex generation path is
unavailable or times out.
"""

from __future__ import annotations

import datetime as dt
import re
import sys
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path


NS = {
    "a": "http://www.w3.org/2005/Atom",
    "opensearch": "http://a9.com/-/spec/opensearch/1.1/",
}

CATEGORY_QUERY = "(cat:cs.AI OR cat:cs.CL OR cat:cs.LG OR cat:cs.RO OR cat:stat.ML)"

TERMS = [
    ("world model", 18),
    ("world models", 18),
    ("agent-authored", 16),
    ("agentic", 14),
    ("multi-agent", 13),
    ("multi agent", 13),
    ("tool-use", 13),
    ("tool use", 13),
    ("tool-using", 13),
    ("vision-language-action", 13),
    ("vla", 11),
    ("embodied", 11),
    ("robot", 10),
    ("robotic", 10),
    ("gui", 10),
    ("web agent", 10),
    ("computer-use", 10),
    ("planning", 9),
    ("planner", 9),
    ("agents", 8),
    ("agent", 8),
    ("reasoning", 6),
    ("environment", 5),
    ("interaction", 4),
    ("reinforcement learning", 4),
    ("benchmark", 4),
    ("memory", 3),
    ("tool", 3),
]

NEGATIVE_TERMS = [
    ("medical", -5),
    ("protein", -5),
    ("segmentation", -4),
    ("classification", -3),
]


def clean(text: str) -> str:
    return re.sub(r"\s+", " ", text or "").strip()


def fetch_arxiv(query: str, max_results: int) -> list[dict]:
    items: list[dict] = []
    for start in range(0, max_results, 100):
        params = urllib.parse.urlencode(
            {
                "search_query": query,
                "start": start,
                "max_results": 100,
                "sortBy": "submittedDate",
                "sortOrder": "descending",
            }
        )
        url = "https://export.arxiv.org/api/query?" + params
        with urllib.request.urlopen(url, timeout=45) as response:
            root = ET.fromstring(response.read())

        entries = root.findall("a:entry", NS)
        if not entries:
            break

        for entry in entries:
            arxiv_id = entry.findtext("a:id", namespaces=NS).rsplit("/", 1)[-1]
            links = {}
            for link in entry.findall("a:link", NS):
                key = link.attrib.get("title") or link.attrib.get("type") or link.attrib.get("rel")
                links[key or "link"] = link.attrib.get("href", "")

            items.append(
                {
                    "id": arxiv_id,
                    "title": clean(entry.findtext("a:title", namespaces=NS)),
                    "summary": clean(entry.findtext("a:summary", namespaces=NS)),
                    "published": clean(entry.findtext("a:published", namespaces=NS))[:10],
                    "updated": clean(entry.findtext("a:updated", namespaces=NS))[:10],
                    "authors": [
                        clean(author.findtext("a:name", namespaces=NS))
                        for author in entry.findall("a:author", NS)
                    ],
                    "cats": [cat.attrib.get("term", "") for cat in entry.findall("a:category", NS)],
                    "links": links,
                }
            )
        time.sleep(0.35)
    return items


def score_item(item: dict) -> int:
    text = f"{item['title']} {item['summary']}".lower()
    score = 0
    for term, weight in TERMS + NEGATIVE_TERMS:
        if term in text:
            score += weight * min(text.count(term), 3)

    title = item["title"].lower()
    for term in ("world model", "agent", "agents", "tool", "planning", "robot", "vla", "embodied"):
        if term in title:
            score += 12

    if any(cat in {"cs.AI", "cs.CL", "cs.RO", "cs.LG"} for cat in item["cats"]):
        score += 4
    return score


def safe_slug(title: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9]+", "-", title.lower()).strip("-")
    return "-".join(slug.split("-")[:8]) or "paper"


def pdf_filename(item: dict) -> str:
    base_id = item["id"].split("v", 1)[0]
    return f"{base_id}_{safe_slug(item['title'])}.pdf"


def download_pdf(item: dict, out_dir: Path) -> Path:
    dest = out_dir / pdf_filename(item)
    if dest.exists() and dest.stat().st_size > 10_000:
        return dest

    url = item["links"].get("pdf") or f"https://arxiv.org/pdf/{item['id']}"
    request = urllib.request.Request(url, headers={"User-Agent": "CodexAutomations/1.0"})
    with urllib.request.urlopen(request, timeout=90) as response:
        dest.write_bytes(response.read())
    time.sleep(0.75)
    return dest


def first_page_text(pdf_path: Path) -> str:
    try:
        from pypdf import PdfReader  # type: ignore

        reader = PdfReader(str(pdf_path))
        if not reader.pages:
            return ""
        return reader.pages[0].extract_text() or ""
    except Exception:
        return ""


def infer_institutions(first_page: str) -> str:
    lines = [clean(line) for line in first_page.splitlines()]
    keywords = (
        "University",
        "Institute",
        "School",
        "Laboratory",
        "College",
        "Department",
        "Academy",
        "Center",
        "Centre",
        "Team",
        "Google",
        "Microsoft",
        "Meta",
        "OpenAI",
        "Alibaba",
        "Tencent",
        "ByteDance",
        "Meituan",
        "Fudan",
        "Shanghai",
    )
    hits: list[str] = []
    for line in lines[:45]:
        if 4 <= len(line) <= 180 and any(keyword in line for keyword in keywords):
            if not line.lower().startswith(("abstract", "introduction")):
                hits.append(line)
    deduped = []
    for hit in hits:
        if hit not in deduped:
            deduped.append(hit)
    return "; ".join(deduped[:3]) or "arXiv 元数据未包含机构；保底生成器未能可靠提取，请以 PDF 首页为准。"


def key_sentence(summary: str, patterns: tuple[str, ...]) -> str:
    sentences = re.split(r"(?<=[.!?])\s+", summary)
    for sentence in sentences:
        lower = sentence.lower()
        if any(pattern in lower for pattern in patterns):
            return clean(sentence)
    return clean(sentences[0] if sentences else summary)


def topic_note(item: dict) -> str:
    text = f"{item['title']} {item['summary']}".lower()
    if "world model" in text:
        return "世界模型/环境动态建模，关注 agent 在行动前如何理解状态转移、系统配置或交互后果。"
    if "tool" in text:
        return "工具使用 agent，关注工具环境、函数调用、故障诊断与恢复。"
    if any(term in text for term in ("robot", "vla", "embodied")):
        return "具身 agent/机器人规划，关注真实物理环境中的执行、适配与安全恢复。"
    if "multi-agent" in text or "multi agent" in text:
        return "多 agent 协作，关注专家分工、协调、规则或集体决策。"
    if "gui" in text or "web" in text:
        return "GUI/Web agent，关注多步页面操作、规划与经验泛化。"
    return "LLM agent 相关工作，关注多步交互、规划、记忆或评测。"


def method_note(item: dict) -> str:
    summary = item["summary"]
    text = f"{item['title']} {summary}".lower()
    if "benchmark" in text:
        return "方法上以构建 benchmark/任务集为主，并通过可执行任务、标准答案或结构化干预来评估 agent 行为。"
    if "world model" in text:
        return "方法上围绕交互轨迹、状态转移或系统识别构造训练/推理信号，使模型学习对决策有用的环境动态。"
    if "reinforcement learning" in text:
        return "方法上结合交互轨迹与环境反馈，通过强化学习或策略优化提升多步决策表现。"
    if "memory" in text or "experience" in text:
        return "方法上将历史经验显式存储、检索、压缩或重写，再反馈到后续决策或训练中。"
    return "方法细节请重点阅读 PDF；保底版主要依据 arXiv 摘要和首页信息生成。"


def limitations_note(item: dict) -> str:
    text = f"{item['title']} {item['summary']}".lower()
    notes = []
    if "benchmark" in text:
        notes.append("benchmark 的覆盖面和构造假设可能影响结论外推")
    if "robot" in text or "embodied" in text or "vla" in text:
        notes.append("真实机器人部署仍受感知遮挡、控制延迟、安全约束和平台差异影响")
    if "world model" in text:
        notes.append("world model 的模拟误差、数据分布偏差和长程滚动误差仍需验证")
    if "tool" in text:
        notes.append("真实工具生态中的权限、非确定性、延迟和安全策略可能比实验设定更复杂")
    if not notes:
        notes.append("保底生成器未完整解析全文 limitation 段，需结合 PDF 进一步核对")
    return "；".join(notes) + "。"


def future_note(item: dict) -> str:
    text = f"{item['title']} {item['summary']}".lower()
    if "world model" in text:
        return "后续值得关注其能否稳定服务于 agent RL、规划搜索和真实环境替代模拟。"
    if "tool" in text:
        return "后续值得关注 failure-aware tool planner、恢复策略训练和证据一致性评测。"
    if "robot" in text or "vla" in text or "embodied" in text:
        return "后续值得关注在线适配、闭环安全监控、跨平台泛化和低延迟部署。"
    if "experience" in text or "memory" in text:
        return "后续值得关注长期记忆、经验规则池和策略更新之间的一致性维护。"
    return "后续可继续跟踪其在更开放、更长时程 agent 环境中的复现与扩展。"


def write_brief(date_str: str, selected: list[dict], brief_path: Path) -> None:
    lines: list[str] = []
    lines.append(f"# 科研晨间简报 - {date_str}")
    lines.append("")
    lines.append("## 日期与检索范围")
    lines.append("")
    lines.append(f"- 日期：{date_str}")
    lines.append("- 生成方式：保底生成器。Codex 深度生成失败或超时后，本脚本基于 arXiv 元数据、摘要和已下载 PDF 首页信息自动生成。")
    lines.append("- 检索范围：近 7 天 arXiv cs.AI、cs.CL、cs.LG、cs.RO、stat.ML 的新提交与重要更新。")
    lines.append("- 注意：保底版优先保证不缺席，分析深度弱于正常 Codex 版；机构信息若无法可靠抽取会明确说明。")
    lines.append("")
    lines.append("## 总体趋势观察")
    lines.append("")
    lines.append("1. LLM agent 研究继续向世界模型、工具恢复、GUI/Web 操作和具身机器人执行四条线并行推进。")
    lines.append("2. 新工作普遍把 agent 能力拆成规划、记忆、验证、恢复、环境建模等模块，而不是只依赖单一模型一次性输出。")
    lines.append("3. 评测关注点从静态问答转向多步交互、执行可靠性、OOD 泛化和真实环境约束。")
    lines.append("4. 经验数据、轨迹、规则池和 world model 正成为训练 agent 的关键中间资产。")
    lines.append("5. 成本、延迟、环境覆盖、模拟误差和安全恢复仍是后续落地的主要限制。")
    lines.append("")

    for idx, item in enumerate(selected, 1):
        authors = ", ".join(item["authors"]) if item["authors"] else "arXiv 元数据未提供作者。"
        if len(authors) > 260:
            authors = authors[:257].rstrip() + "..."
        arxiv_abs = f"https://arxiv.org/abs/{item['id']}"
        pdf_path = item.get("pdf_path", "")
        institutions = item.get("institutions", "arXiv 元数据未包含机构；保底生成器未能可靠提取。")
        result = key_sentence(
            item["summary"],
            ("outperform", "achieve", "improve", "demonstrate", "experiments", "results", "show"),
        )
        contribution = key_sentence(
            item["summary"],
            ("introduce", "propose", "present", "develop", "construct", "we study", "we investigate"),
        )

        lines.append(f"## {idx}. {item['title']}")
        lines.append("")
        lines.append(f"- **日期**：{item['published']}")
        lines.append(f"- **作者**：{authors}")
        lines.append(f"- **机构**：{institutions}")
        lines.append(f"- **arXiv**：{arxiv_abs}")
        lines.append(f"- **本地 PDF**：`{pdf_path}`")
        lines.append("")
        lines.append(f"**主题分析**：{topic_note(item)}")
        lines.append("")
        lines.append(f"**主要内容与贡献**：根据摘要，{contribution}")
        lines.append("")
        lines.append(f"**方法介绍**：{method_note(item)}")
        lines.append("")
        lines.append(f"**实验或结果亮点**：{result}")
        lines.append("")
        lines.append(f"**局限性**：{limitations_note(item)}")
        lines.append("")
        lines.append(f"**未来展望**：{future_note(item)}")
        lines.append("")

    lines.append("## Worth Tracking Next")
    lines.append("")
    lines.append("- 语言世界模型与 agent RL/simulation 的结合是否能稳定替代部分真实环境交互。")
    lines.append("- tool-use agents 在不可靠 API、冲突证据、权限限制和执行失败下的恢复能力。")
    lines.append("- GUI/Web agents 的长期经验是否能迁移到登录、支付、隐私敏感等高风险流程。")
    lines.append("- 具身 agents 的在线系统识别、闭环安全监控和跨平台泛化。")
    lines.append("- 经验规则池、长期记忆和参数更新之间如何避免不同步与规则污染。")

    brief_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    if len(sys.argv) != 4:
        print("Usage: generate_arxiv_fallback_brief.py <YYYY-MM-DD> <out_dir> <brief_path>", file=sys.stderr)
        return 2

    date_str = sys.argv[1]
    out_dir = Path(sys.argv[2])
    brief_path = Path(sys.argv[3])
    out_dir.mkdir(parents=True, exist_ok=True)

    target = dt.date.fromisoformat(date_str)
    start = target - dt.timedelta(days=7)
    start_s = start.strftime("%Y%m%d")
    end_s = target.strftime("%Y%m%d")

    queries = [
        f"{CATEGORY_QUERY} AND submittedDate:[{start_s}0000 TO {end_s}2359]",
        f"{CATEGORY_QUERY} AND lastUpdatedDate:[{start_s}0000 TO {end_s}2359]",
    ]

    by_id: dict[str, dict] = {}
    for query, max_results in zip(queries, (1000, 500)):
        for item in fetch_arxiv(query, max_results):
            by_id.setdefault(item["id"], item)

    items = list(by_id.values())
    for item in items:
        item["score"] = score_item(item)

    items.sort(key=lambda x: (x["score"], x["published"], x["updated"]), reverse=True)
    selected = [item for item in items if item["score"] >= 40][:8]
    if len(selected) < 5:
        selected = items[:8]

    if not selected:
        raise RuntimeError("No arXiv candidates found for fallback brief.")

    for item in selected:
        pdf_path = download_pdf(item, out_dir)
        item["pdf_path"] = str(pdf_path)
        item["institutions"] = infer_institutions(first_page_text(pdf_path))

    write_brief(date_str, selected, brief_path)
    print(f"Fallback brief written: {brief_path}")
    print(f"Selected papers: {len(selected)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
