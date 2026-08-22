# local-llm-station

<div align="center">

**English** | **[中文](README.md)**

<!-- TODO: replace with an architecture GIF or UI screenshot (wide crop, under docs/), so visitors get it in 10 seconds -->

**🔬 A 27B-class research assistant inside your Mac — a local-first research literature workbench**

Read a paper → explain it well: local PDF parsing, multimodal chart reading, four-section summaries, one-image posters, one-click report PPT.
Works offline · Data never leaves your machine · OpenAI-compatible API.

[Quick Start](#quick-start) · [Features](#features) · [Too weak for a local model? Use the cloud](#no-local-model-use-the-deepseek-cloud-api) · [FAQ](FAQ.md) · [Deep docs](#deep-docs)

</div>

> **External review (from DeepSeek)**
> "This is a highly valuable and remarkably polished local LLM project. For researchers, technical writers, and privacy-conscious users on Apple Silicon Macs, it is a rare and practical tool.
> Its core value can be summarized as: turning powerful local-model capabilities—through carefully engineered means—into an efficient, reliable, ready-to-use assistant for daily research and work."

---

**One native console app (QwenServer) + one web chat UI (chat.html)**, running any GGUF model via llama.cpp. Developed and validated on an M1 Pro 32GB with Qwen3.8-27B (a vision-language model) as the default.

## Minimum Requirements & Speed Reference

| Config | Notes |
|--------|-------|
| **Minimum** | Apple Silicon (M1 or later) + 24GB RAM + ~20GB disk (default Qwen3.8-27B Q4 quant) |
| **Recommended** | 32GB RAM (64K context, comfortable multimodal) |
| **16GB machines** | Use a ≤14B quantized model; everything else works unchanged |

**Measured on M1 Pro 32GB / Qwen3.8-27B UD-Q4_K_XL / 64K context:**

| Metric | Value |
|--------|-------|
| Model load | ~30 s |
| Generation | 5-8 tok/s (deep thinking off) |
| First-token latency | 1-2 s (short prompts) |
| Text chat fluency | usable; long answers need patience |
| OCR / image understanding | 1-2K tokens per image, results in seconds |

## Features

**QwenServer.app** (single-file SwiftUI, no Xcode project)

- Menu-bar resident (no Dock icon) + ⌥Space global hotkey; the ✨ icon leads to My Desktop / New Chat
- One-click start/stop of llama-server; two-tier context picker computed from RAM + model size; optional login item and auto-start on launch
- Built-in :8081 micro host service (loopback-only, CORS + path-traversal protection), starts with the app, model-independent: conversation archive CRUD, `/pdf` paper text & chart extraction, `/file` data overview, `/projects/list` + `/system/status` (dashboard data sources)
- `~/Qwen38/config.json` external config for model paths/context — switch models without recompiling

**chat.html** (single file, zero dependencies, any browser incl. Safari)

- Streaming output, interruptible, collapsible reasoning (both `reasoning_content` and `<think>` formats); live outline preview for long outputs
- Smart mode picks the preset per message + three manual presets (deep reasoning / exact / casual), grounded in benchmark results
- 📄 PDF paper upload: local full-text + chart extraction, default four-section summary (background/methods/results/discussion), follow-ups ride the prompt cache
- 🔍 local multimodal chart deep-read (range-selectable); 📊 one-click five-section critical-appraisal report PPT (cloud-only, ~2-3 min); 🎨 one-image summary poster PNG
- Cross-conversation long-term memory (🧠 panel); capability-boundary rules auto-injected
- Context usage bar + auto compression (originals preserved, old details recalled via keyword retrieval)
- ☁️ DeepSeek cloud mode: works with no model and no Mac; one-click switch from local
- Multi-conversation sidebar, search, queued input, edit-and-resend; Markdown/tables/KaTeX rendering
- Multimodal image upload; export to Markdown / long-image PNG / poster; auto-archived to disk (survives browser switches); `?conv=` deep link
- 🔍 Literature search: type `找文献 <keyword>` (find papers) in any chat → 8 latest from PubMed + 8 relevant from OpenAlex (with open-access full-text PDF links) land in the conversation for follow-up questions
- Per-message timestamps persisted (`messages[].ts`, feeds dashboard time filtering; legacy archives fall back to conversation activity time)

**dashboard.html (My Desktop)**: the portal you see before opening a chat — the control center of the whole workspace

- Project overview: one card per archived conversation (📄 papers / 💬 chats) with attachment/table/chart/note/card counts and activity time; click to jump straight in; 📌 pin, 🏷 manual tags (stored in dashboard.json, merged with auto tags extracted from knowledge cards)
- 🔍 Global search: full-text search across all conversations (lazy in-memory index, click a hit to jump); scope switch between 💬 chat text / 📎 attachment full text (paper PDF text, filenames searchable); `#tag` aggregation; time filter precise to per-message timestamps
- 📚 Citation verification: paste a reference list; each entry checked against Crossref → OpenAlex, with PubMed cross-validation for uncertain ones; three-level verdict report lands in the chat
- Global status: model service / model name / CPU / memory (5s polling); pure static single file, fed by :8081

Product positioning and common questions live in [FAQ.md](FAQ.md) (in Chinese).

## Ecosystem pairing: use quelmap for data exploration

This station is positioned for **lightweight Q&A and literature-data linkage** (the 📊 attachment injects only a column overview for "answer with my data in mind" questions), not deep data exploration. For interactive analysis, automatic charting, and iterative exploration, we recommend the open-source local tool [quelmap](https://github.com/quelmap-inc/quelmap): its dedicated Lightning-4b model (4B, GRPO-trained, GGUF) bakes the "code + placeholder report" habit into the weights, runs smoothly on a 16GB MacBook per official tests, and shares our privacy stance. Pause this station's 27B service from the tray during heavy analysis sessions to avoid unified-memory contention.

When your message mentions a plot, a hint bar above the input suggests the best-matching [FigureYa](https://github.com/ying-ge/FigureYa) template (pure frontend keyword matching, zero tokens); click through to the module's GitHub page and grab the paper-grade R script yourself — this station deliberately does no template injection or code generation. Each tool does its own job.

## Measured Model Capabilities (benchmark)

Four manually graded test suites for the default Qwen3.8-27B, 56 questions total, scored point by point:

| Suite | Questions | Result |
|-------|-----------|--------|
| General-knowledge stress test | 22 | 86% · Good+ |
| Medical specialty (board level) | 17 | 91% · medication-safety items borderline |
| CN↔EN translation (incl. back-translation) | 14 | 8 exact + 2 half, zero back-translation drift |
| Data-analysis coding (actually executed) | 7 | **100% · Excellent** |

Bottom line: **code generation, everyday translation, and writing are safe to use; long-tail facts and medication details need human verification; fact-checking and clinical decisions are off-limits.**

- Full report (capability boundaries, use-case recommendations, config advice): [benchmark/report.html](benchmark/report.html)
- Reproducible scripts and raw answers: the [benchmark/](benchmark/) directory

Key engineering conclusion: **temp 0.0 + thinking off** gives the highest precision and ~20× speed on translation/code tasks — the mode selector at the bottom of chat.html ships with these presets.

## Architecture

```
dashboard.html (My Desktop: project overview + global status, the portal)
   │  click a card → chat.html?conv=<id> jumps into that conversation
   ▼
chat.html (any browser, pure UI + localStorage cache)
   │  :8080/v1  chat API (llama.cpp, launched by QwenServer)
   │  :8081     archive API (micro HTTP service inside QwenServer)
   ▼
QwenServer.app (host process)
   ├── start/stop llama-server, context picker, uptime/logs
   └── reads/writes ~/local-llm-station/chat_history/*.json
```

All file operations are performed by the local host process; the browser has zero file permissions — the core design of this project, borrowed from deepseek-harness's "local host + browser as pure UI" layering.

## Quick Start

**One-click install** (auto-installs Homebrew/llama.cpp, clones sources to `~/Qwen38`, downloads the 27B model and KaTeX, builds and launches; in China run `export HF_ENDPOINT=https://hf-mirror.com` first):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/dalianblue/local-llm-station/main/install.sh)
```

Less than 24GB RAM or skip the model download: run with `SKIP_MODEL=1`. Manual step-by-step below:

```bash
# 1. Install llama.cpp
brew install llama.cpp

# 2. Download any GGUF model (unsloth quant in this example)
hf download unsloth/Qwen3.8-27B-GGUF Qwen3.8-27B-UD-Q4_K_XL.gguf --local-dir .

# 3. Optional: KaTeX assets (2.9MB, not in the repo; formulas degrade
#    to plain text if missing, nothing else breaks)
mkdir -p ~/Qwen38/katex && curl -sL https://registry.npmjs.org/katex/-/katex-0.16.11.tgz -o /tmp/katex.tgz \
  && tar xzf /tmp/katex.tgz -C ~/Qwen38/katex --strip-components=2 package/dist

# 4. Build and launch the console
./build.sh && open QwenServer.app

# 5. Pick a context tier → start the service → start chatting
```

## No local model? Use the DeepSeek cloud API

Can't run a 27B model (<24GB RAM, old Intel Mac, thin Windows laptop)? **No installation needed — a browser + a DeepSeek API Key unlocks all chat features:**

1. **Get an API Key**: sign up at [platform.deepseek.com](https://platform.deepseek.com), top up, create a key (starts with `sk-`)
2. **Download `chat.html`**: the single file is all you need (optionally grab the `katex/` directory for formula rendering; missing it degrades formulas to plain text)
3. **Configure**: open chat.html in a browser → ⚙️ Settings → set **API Service** to **☁️ DeepSeek API** → paste the key. It's stored only in your browser's localStorage

Notes:

- Thinking mode maps to `deepseek-reasoner` (streamed thinking display), no-thinking maps to `deepseek-chat`; llama.cpp-specific params are stripped automatically
- **Chat requires zero local services** — no QwenServer.app, no model files; cross-conversation memory, sessions, compression, export, and the 📊 one-click report PPT (cloud-only by design) all work
- Two optional extras (need QwenServer.app on macOS, no model loading required): 📄 local PDF extraction and auto-archive; without them, paste paper text directly
- Caveat: in cloud mode conversations go to DeepSeek's servers; uploading data files triggers an explicit "data leaves this machine" warning

## Switching Models

**Edit the config file (recommended, no recompile)**: create `~/Qwen38/config.json` and restart QwenServer.app:

```json
{
  "modelPath": "/Users/yourname/Qwen38/Qwen3.8-27B-UD-Q4_K_XL.gguf",
  "mmprojPath": "/Users/yourname/Qwen38/mmproj-F16.gguf",
  "contextLength": 65536
}
```

- All three keys are optional; each falls back to a built-in default (default model path as above; context tier computed from your RAM)
- `contextLength` only sets the default selection in the launch panel — still freely changeable
- A nonexistent path falls back to the default automatically (with a hint)

The source-edit route (the old way) still works: edit `QwenServer.swift` and run `./build.sh`. The working directory defaults to `~/Qwen38`; a global find-and-replace relocates everything.

## Running on Windows / Linux (non-Apple-Silicon)

QwenServer.app depends on macOS (SwiftUI + PDFKit) and cannot be ported — but **chat.html is pure frontend** and only needs an OpenAI-compatible chat API, so the backend is swappable:

1. Start any OpenAI-compatible backend, e.g.:
   - [text-generation-webui](https://github.com/oobabooga/text-generation-webui) (`--api --listen`, default `http://127.0.0.1:5000/v1`)
   - llama.cpp (builds on Windows/Linux too; `llama-server` ships `/v1` — identical to the Mac setup)
   - [Ollama](https://ollama.com) (`OLLAMA_ORIGINS=* ollama serve` enables CORS, API at `http://127.0.0.1:11434/v1`)
2. Open chat.html in a browser → ⚙️ Settings → set **Server address** to your backend (e.g. `http://127.0.0.1:5000`; for Ollama use `http://127.0.0.1:11434`) — it reconnects automatically, no code edit needed
3. Done. Streaming, thinking collapse, mode presets, compression, export — none of these depend on the platform.

**Platform differences**: PDF paper upload and auto-archive rely on QwenServer's :8081 service (PDFKit extraction); without QwenServer those two features are unavailable (paste the paper text instead for literature reading); adjust the KaTeX asset path as needed. `chat_template_kwargs.enable_thinking` is llama.cpp-specific and simply ignored by other backends — whether thinking is shown depends on the backend returning `reasoning_content` or `<think>` tags, both of which chat.html handles.

### Porting guide (for developers writing their own host service)

This project officially supports macOS only, but the frontend/backend boundary is a pure HTTP contract — forks and ports are welcome. The full protocol lives in **[PORTING.md](PORTING.md)** (in Chinese), with a stdlib-only stub [mock_server.py](mock_server.py) for instant frontend integration; the minimum viable set is just three endpoints (`/health`, `/list`, `/archive`), half a day of work.

## Context Length & Memory (dynamically computed)

The model's native context ceiling is **256K** (GGUF metadata `qwen35.context_length = 262144`). The console uses a **two-tier picker** (recommended / extreme), computed live from your hardware — zero configuration across machines and models:

```
KV budget      = physical RAM × 70% − model file size − 1.5GB system reserve
recommended    = the largest context the budget fits (KV bounded at 64KB/token + 15% headroom)
```

| RAM (with 27B Q4) | Default tier | Extreme tier |
|-------------------|--------------|--------------|
| 24GB | 8K | 16K |
| 32GB | 64K | 128K |
| 48GB | 128K | 256K |
| 64GB+ | 256K (top) | — |

Coefficients are calibrated against M1 Pro measurements (recent macOS locks ~70% of unified memory; Qwen3.8's hybrid attention actually uses less than the 64KB/token upper bound). The extreme tier exceeds the default GPU wired limit — run `sudo sysctl iogpu.wired_limit_mb=26624` first, otherwise it falls back to CPU and throughput collapses. That command lets a single process wire more unified memory (too high a value can freeze the system), lasts until reboot, and `=0` reverts it.

## Archive API (:8081, CORS, loopback only)

| Endpoint | Description |
|----------|-------------|
| `GET /health` | liveness check |
| `GET /list` | list archive filenames |
| `GET /archive/<name>` | read an archive |
| `PUT /archive/<name>` | write an archive (called automatically each turn) |
| `GET /projects/list` | project listing (per conversation: id/title/activity/attachments/notes/cards/auto-tags/table & chart counts), dashboard data source |
| `GET /system/status` | llama-server liveness + CPU/memory/model name, dashboard data source |

One `chat_history/<id>-<title>.json` per conversation, with full messages/metrics/images; `memory.json` holds the cross-conversation memory. On startup the page merges with localStorage (keeping the fuller, newer version).

## Chat API

`http://127.0.0.1:8080/v1` (OpenAI-compatible), any API key:

```bash
curl http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"Hello"}],
       "chat_template_kwargs":{"enable_thinking": false}}'
```

## Files

| File | Description |
|------|-------------|
| `chat.html` | web chat UI |
| `dashboard.html` | My Desktop: the project-dashboard portal (project overview + global status) |
| `QwenServer.swift` | console + archive service source |
| `build.sh` | one-command build (generates Info.plist, syncs /Applications) |

## Rebuilding

```bash
./build.sh   # after changing QwenServer.swift; chat.html just needs a browser refresh
```

## Deep docs

| Want to know | Where |
|--------------|-------|
| Product positioning, micro-autobiography & common questions | [FAQ.md](FAQ.md) (in Chinese) |
| Benchmark report, test papers, reproducible scripts | [benchmark/](benchmark/) and [benchmark/report.html](benchmark/report.html) |
| API protocol spec for porting to Windows/Linux | [PORTING.md](PORTING.md) (in Chinese) |

## Acknowledgements

- [Crossref](https://www.crossref.org) / [OpenAlex](https://openalex.org) — the two free open scholarly-metadata APIs behind citation verification (ranking, not generation — zero-hallucination lookup)
- [PaSaMaster: Towards Self-Evolving Agentic Literature Retrieval (arXiv:2605.14306)](https://arxiv.org/abs/2605.14306) — the citation-verification architecture (database lookup + deterministic matching, never LLM recall) is inspired by it
- [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness) — the "local host does file operations, browser is pure UI" layering is borrowed from it
- [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp) — inference engine
- [unsloth](https://unsloth.ai) — high-quality dynamic-quant GGUFs
- [KaTeX](https://katex.org) / [html2canvas](https://github.com/niklasvh/html2canvas) — formula rendering and PNG export

## License

GPL-3.0
