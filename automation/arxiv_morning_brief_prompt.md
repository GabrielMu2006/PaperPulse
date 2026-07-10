You are preparing a Chinese research morning brief for Gabriel.

Task:
Read recent arXiv papers related to LLM agents, AI agents, tool-using agents, multi-agent systems, world models, model-based reasoning, planning with language models, and embodied agents.

Scope and selection:
- Prioritize new submissions and important updates from the current day and the previous few days.
- Search especially in cs.AI, cs.CL, cs.LG, cs.RO, and stat.ML.
- Select 5 to 8 highly relevant papers.
- If there are too few strong papers from the current day, include highly relevant papers from the last 7 days and clearly label their arXiv dates.
- Prefer papers with concrete methods, experiments, benchmarks, systems, datasets, or conceptual relevance to LLM agents or world models.

Local output requirements:
- Create a dated output directory under the configured PaperPulse workspace at `arxiv_morning_brief/YYYY-MM-DD/`.
- Download each selected paper's PDF into that dated directory.
- Use readable filenames such as arxiv_id_short-title.pdf.
- Generate a Markdown brief named morning_brief.md in the same dated directory.
- Include local PDF paths in the brief.

For each paper, include:
- Title
- Authors
- Institutions or affiliations, inferred from the paper metadata/PDF when available
- arXiv URL
- Local PDF path
- Topic analysis
- Main content and contribution
- Method introduction
- Experiment or result highlights
- Limitations
- Future outlook

Brief structure:
1. Date and search scope.
2. 3 to 5 overall trend observations.
3. A ranked list of selected papers with the full analysis above.
4. A short "worth tracking next" section listing open questions, promising directions, and related keywords to monitor.

Style:
- Write in Chinese.
- Be concise but technically useful.
- Do not overclaim beyond the paper evidence.
- If institution information is unavailable, say so explicitly rather than guessing.
