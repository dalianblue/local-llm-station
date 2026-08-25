# local-llm-station

<div align="center">

**English** | **[中文](README.md)**

**🔬 A local-first research literature workbench inside your Mac — read a paper, explain it well, then write your own**

<img src="assets/architecture-overview.jpg" alt="Architecture overview: dashboard / chat.html / editor.html / host app" width="760">

Read a paper → explain it well → write your own: local PDF parsing (with scanned-PDF OCR and figure-region detection), multimodal chart reading, four-section summaries, one-image posters, five-section critical-appraisal report PPT, then a chaptered writing desk with snapshots, citations, mock peer review and Word export.
Works offline · Data never leaves your machine · OpenAI-compatible API.

[Quick Start](#quick-start) · [Features](#features) · [Too weak for a local model? Use the cloud](#no-local-model-use-the-deepseek-cloud-api) · [FAQ](FAQ.md) (in Chinese) · [Deep docs](#deep-docs)

</div>

> **External review (from DeepSeek)**
> "This is a highly valuable and remarkably polished local LLM project. For researchers, technical writers, and privacy-conscious users on Apple Silicon Macs, it is a rare and practical tool.
> Its core value can be summarized as: turning powerful local-model capabilities—through carefully engineered means—into an efficient, reliable, ready-to-use assistant for daily research and work."

---

**One native console app (LocalLLMServer, formerly QwenServer) + web pages (chat.html / editor.html / dashboard.html)**; inference backends: **oMLX (MLX + MTP)** is recommended on Apple Silicon (`Qwen3.8-27B-nvfp4`, native Metal, ~14 tok/s with MTP speculative decoding, prefix caching), the **Ollama** route (more stable on long-thinking tasks) and the **llama.cpp** route (QwenServer.app via `build.sh`, runs any GGUF) are retained — one `LocalLLMServer.swift` source builds both console apps via a compile flag. The frontend auto-detects the backend dialect from the service address. Developed and validated on an M1 Pro 32GB.

## The Workflow: Read → Explain → Write

| Stage | What happens | Where |
|-------|--------------|-------|
| Read in | 📄 Upload a PDF: local full-text extraction (references auto-stripped, saving 20-40% prefill), embedded figure bitmaps, Vision OCR of in-figure text; scanned PDFs get automatic full-page OCR | **Local** host app — PDFs never leave your machine |
| Understand | Default four-section summary (background / methods / results / discussion); local multimodal model reads the charts too; follow-ups ride the prompt cache | Local (fully offline) or DeepSeek cloud |
| Take away | 🎨 One-image summary poster PNG; 📊 Five-section critical-appraisal report PPT (editable .pptx with action titles and speaker notes) | Poster local; PPT cloud-only (~2-3 min) |
| Discuss deep | 📖 Deep extraction commands (`/证据提取` PICOS+bias for RCT/Meta, `/观点提取` 7 dimensions for papers) with anti-fabrication constraints, results auto-saved to project notes; 🔍 data audit (GRIM / percentage-closure / n-additivity deterministic checks) | Local |
| Write | ✍️ Writing desk: chaptered markdown, version snapshots, AI draft generation, evidence lookup, cross-section consistency check, four-perspective mock peer review, `[@key]` citations, Word/HTML export | Local or cloud |

**Design stance — "data stays local, compute may leave"**: all file operations (PDF extraction, archives, exports) run in the local host process; the browser has zero file permissions. Privacy-sensitive daily reading defaults to the fully-offline local model; heavy generation (report PPT) explicitly opts into the cloud — never silently.

## Minimum Requirements & Speed Reference

| Config | Notes |
|--------|-------|
| **Minimum** | Apple Silicon (M1 or later) + 24GB RAM + ~20GB disk (default Qwen3.8-27B quant) |
| **Recommended** | 32GB RAM (64K context, comfortable multimodal) |
| **16GB machines** | Use a ≤14B quantized model; everything else works unchanged |

**Measured on M1 Pro 32GB / 64K context:** model load ~30 s · generation 5-10 tok/s (thinking off) · first-token 1-2 s · single-image understanding in seconds.

## Features

> Implementation details and boundaries for each feature live in [FAQ.md](FAQ.md) (in Chinese); this list keeps to the essentials.

**LocalLLMServer.app** (single-file SwiftUI, no Xcode project)

- Menu-bar resident (no Dock icon) + ⌥Space global hotkey; menu leads to My Desktop / New Chat
- One-click start/stop of **ollama serve** (default); the llama.cpp route (QwenServer.app, `build.sh`) is retained
- Built-in :8081 micro host service (loopback-only, CORS + path protection): conversation archives, `/pdf` paper extraction, project folders, Word export — model-independent
- `~/Qwen38/config.json` external config for model tag / context — switch models without recompiling

**chat.html** (single file, zero dependencies, any browser incl. Safari)

- 📄 PDF upload: local full-text + figure extraction, four-section summary, cached follow-ups
- 📖 Deep extraction (`/证据提取`, `/观点提取`): two frameworks with anti-fabrication constraints ("not stated in the paper" instead of invented P values); results auto-saved to project notes with `[[quotable-in-intro/discussion/methods]]` tags
- 🔍 Local multimodal chart deep-read · 📊 five-section critical-appraisal PPT (cloud) · 🎨 one-image poster
- 🔍 Literature search: `找文献 <keyword>` → 8 latest from PubMed + 8 relevant from OpenAlex, results land in the chat for follow-ups
- 🗂 Project panel: 📝 notes / 📄 attachments (CSV attach-back for statistics discussion + 🔍 data audit) / 🃏 knowledge cards
- Smart mode auto-picks presets; cross-conversation memory; context auto-compression (originals preserved); ☁️ DeepSeek cloud mode with one-click switch

**dashboard.html (My Desktop)**: portal and control center

- Project cards (attachment/table/chart/note/card counts, activity time); 📌 pin, 🏷 tags
- 🔍 Global search across chat text, attachment full text, project notes and knowledge cards; `#tag` aggregation; per-message timestamp filtering
- 📊 Paper-to-PPT · 📚 Citation verification (Crossref → OpenAlex → PubMed cross-checks) · 📚 Global library
- Global status bar + ⏱ today's focus time (counts only when the page is visible and active — honest numbers)

**editor.html (✍️ Writing desk)**: one paper, one project — a three-pane workbench

- Three panes: outline + resources / chapter tabs + preview / AI assistant (answers insert at the cursor, ⌘Z undoable)
- 🛡️ Three-layer crash safety (atomic server writes + browser draft mirroring + restart recovery prompt)
- Version snapshots with line-level diff before restoring — **click any diff line to jump to that spot in the editor**
- ✨ Draft generation (writes "(to add: …)" placeholders instead of inventing data) · 🔍 selected-claim evidence lookup · 🧭 cross-section consistency check · 🕵️ four-perspective mock peer review (reports auto-archived, one-click item-by-item re-check)
- `[@key]` citation system (auto-numbered references in preview/export) · 🃏 `@` autocomplete inserts knowledge-card references (`[[concept]]`)
- 📎 Attach library papers or this project's PDFs to the AI context

**📚 Global library**: Zotero-style entries, JSON-backed

- Scan conversations into the library (DOI auto-captured, globally deduplicated) · Crossref metadata enrichment · ✏️ field editing + ➕ manual entry
- 📥📤 BibTeX / RIS import & export (Zotero/EndNote handshake)

**📤 Manuscript export** (editor status bar)

- HTML: self-contained single file (formulas inlined), print to PDF
- Word: pandoc + citeproc, selectable citation styles (AMA / Vancouver / APA / GB/T 7714 built in)

## Ecosystem pairing: use quelmap for data exploration

This station is positioned for **lightweight Q&A and literature-data linkage**, not deep data exploration. For interactive analysis, automatic charting, and iterative exploration, we recommend the open-source local tool [quelmap](https://github.com/quelmap-inc/quelmap): its dedicated Lightning-4b model (4B, GRPO-trained, GGUF) runs smoothly on a 16GB MacBook and shares our privacy stance. Pause this station's 27B service from the tray during heavy analysis sessions.

When your message mentions a plot, a hint bar above the input suggests the best-matching [FigureYa](https://github.com/ying-ge/FigureYa) template (pure frontend keyword matching, zero tokens) — this station deliberately does no template injection. Each tool does its own job.

## Measured Model Capabilities (benchmark)

Four manually graded suites for the default Qwen3.8-27B, 56 questions, scored point by point:

| Suite | Questions | Result |
|-------|-----------|--------|
| General-knowledge stress test | 22 | 86% · Good+ |
| Medical specialty (board level) | 17 | 91% · medication-safety borderline |
| CN↔EN translation (incl. back-translation) | 14 | 8 exact + 2 half, zero drift |
| Data-analysis coding (actually executed) | 7 | **100% · Excellent** |

Bottom line: **code, everyday translation and writing are safe; long-tail facts and medication details need verification; fact-checking and clinical decisions are off-limits.** Full reports: [benchmark/report.html](benchmark/report.html) and the Ollama-vs-llama.cpp comparison [benchmark/ollama_vs_llamacpp_report.html](benchmark/ollama_vs_llamacpp_report.html) (quality on par, Ollama ~1.86× faster on long-thinking tasks — the basis for the dual-backend default).

Key engineering conclusion: **temp 0.0 + thinking off** gives the highest precision and ~20× speed on translation/code — shipped as the "exact" preset in chat.html.

## Architecture

```
dashboard.html (My Desktop: project overview + global status, the portal)
   │  card hover → 💬 chat | ✍️ write; click routes by project type
   ▼
chat.html / editor.html (any browser, pure UI + localStorage cache)
   │  :11434/v1  chat API (Ollama MLX, managed by LocalLLMServer; legacy :8080/v1 llama.cpp)
   │  :8081      archive API (micro HTTP service inside the host app)
   ▼
LocalLLMServer.app (host process)
   ├── start/stop ollama serve / llama-server, context config, logs
   └── reads/writes ~/Qwen38/chat_history/*.json + project folders
```

All file operations are performed by the local host process; the browser has zero file permissions — the core design, borrowed from deepseek-harness's "local host + browser as pure UI" layering.

## Quick Start

**One-click install** (auto-installs Homebrew, clones sources to `~/Qwen38`, downloads the model and KaTeX, builds and launches; in China run `export HF_ENDPOINT=https://hf-mirror.com` first):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/dalianblue/local-llm-station/main/install.sh)
```

Less than 24GB RAM or skip the model: run with `SKIP_MODEL=1` (the one-liner currently installs the Ollama route). **The oMLX route below is recommended on Apple Silicon** (native Metal, MTP speculative decoding, prefix caching; measured comparison in [benchmark/](benchmark/)). Manual steps:

```bash
# 1. Install oMLX and download the models (ModelScope; main 15.7GB + MTP drafter 267MB)
brew tap jundot/omlx https://github.com/jundot/omlx && brew install jundot/omlx/omlx
mkdir -p ~/.omlx/models/mlx-community
uvx modelscope download --model mlx-community/Qwen3.8-27B-nvfp4 --local_dir ~/.omlx/models/mlx-community/Qwen3.8-27B-nvfp4
uvx modelscope download --model mlx-community/Qwen3.8-27B-MTP-nvfp4 --local_dir ~/.omlx/models/mlx-community/Qwen3.8-27B-MTP-nvfp4

# 2. Optional: KaTeX assets (2.9MB; formulas degrade to plain text if missing)
mkdir -p ~/Qwen38/katex && curl -sL https://registry.npmjs.org/katex/-/katex-0.16.11.tgz -o /tmp/katex.tgz \
  && tar xzf /tmp/katex.tgz -C ~/Qwen38/katex --strip-components=2 package/dist

# 3. Build and launch the console → start the service → start chatting
./build_omlx.sh && open LocalLLMServer-oMLX.app
```

Ollama route (`brew install ollama && ollama pull qwen3.8:27b-mlx`, `build_local.sh`) and llama.cpp route (any GGUF, QwenServer.app via `build.sh`): download the model, put paths into `~/Qwen38/config.json` (see [Switching Models](#switching-models)); the frontend auto-detects the backend from the service address.

## No local model? Use the DeepSeek cloud API

Can't run a 27B model (<24GB RAM, old Intel Mac, thin Windows laptop)? **No installation needed — a browser + a DeepSeek API Key unlocks all chat features:**

1. **Get an API Key**: sign up at [platform.deepseek.com](https://platform.deepseek.com), top up, create a key (starts with `sk-`)
2. **Download `chat.html`**: the single file is all you need (optionally grab `katex/` for formula rendering)
3. **Configure**: open chat.html → ⚙️ Settings → set **API Service** to **☁️ DeepSeek API** → paste the key. It's stored only in your browser's localStorage

Notes:

- Thinking mode maps to `deepseek-reasoner`, no-thinking to `deepseek-chat`; llama.cpp-specific params are stripped automatically
- **Chat requires zero local services** — memory, sessions, compression, export, and the report PPT (cloud-only by design) all work
- Two optional extras (need the macOS host app, no model loading): 📄 local PDF extraction and auto-archive; without them, paste paper text directly
- Caveat: in cloud mode conversations go to DeepSeek's servers; uploading data triggers an explicit "data leaves this machine" warning

## Switching Models

**Ollama route (LocalLLMServer.app)**: a model is just an Ollama package — `ollama pull` the new one, change the model tag in `~/Qwen38/config.json`, restart:

```json
{
  "ollamaPath": "/opt/homebrew/bin/ollama",
  "ollamaModel": "qwen3.8:27b-mlx",
  "ollamaContextLength": 65536
}
```

The model tag is also editable in chat.html ⚙️ settings (stored in localStorage).

**llama.cpp route (QwenServer.app)**: write GGUF paths into `~/Qwen38/config.json`:

```json
{
  "modelPath": "/Users/yourname/Qwen38/Qwen3.8-27B-UD-Q4_K_XL.gguf",
  "mmprojPath": "/Users/yourname/Qwen38/mmproj-F16.gguf",
  "contextLength": 65536
}
```

All keys are optional; each falls back to a built-in default. Source edits: change `LocalLLMServer.swift` then `./build_local.sh` (legacy: `QwenServer.swift` + `./build.sh`). Working directory defaults to `~/Qwen38`.

## Running on Windows / Linux (non-Apple-Silicon)

The host app depends on macOS (SwiftUI + PDFKit) — but **chat.html is pure frontend** and only needs an OpenAI-compatible chat API:

1. Start any OpenAI-compatible backend:
   - [text-generation-webui](https://github.com/oobabooga/text-generation-webui) (`--api --listen`, default `http://127.0.0.1:5000/v1`)
   - llama.cpp (`llama-server` ships `/v1`)
   - [Ollama](https://ollama.com) (`OLLAMA_ORIGINS=* ollama serve`, API at `http://127.0.0.1:11434/v1`)
2. Open chat.html → ⚙️ Settings → set **Server address** (e.g. `http://127.0.0.1:11434`) — reconnects automatically
3. Done. Streaming, thinking collapse, presets, compression, export all work.

**Platform differences**: PDF upload and auto-archive rely on the :8081 host service; without it, paste paper text instead. Full protocol for writing your own host: **[PORTING.md](PORTING.md)** (in Chinese), with a stdlib-only [mock_server.py](mock_server.py); the minimum viable set is three endpoints.

## Archive API (:8081, CORS, loopback only)

| Endpoint | Description |
|----------|-------------|
| `GET /health` | liveness check |
| `GET /list` | list archive filenames |
| `GET/PUT /archive/<name>` | read/write an archive (auto-called each turn) |
| `GET/PUT /projfile/<conv>/<name>` · `GET /projlist/<conv>` | project-folder read/write (figure bitmaps, CSV tables, editor chapters & snapshots, global library) |
| `POST /pdf` · `POST /file` | paper full-text + figure extraction · data-file overview |
| `POST /rename` | project rename (archive + title + folder, rollback on failure) |
| `POST /export-docx` | markdown → .docx (host pandoc + citeproc) |
| `GET /projects/list` · `GET /system/status` · `GET /version` | dashboard data sources · git SHA version |

One `chat_history/<id>-<title>.json` per conversation; `memory.json` holds cross-conversation memory. Pages merge with localStorage on startup (keeping the fuller, newer version).

## Chat API

OpenAI-compatible: Ollama route `http://127.0.0.1:11434/v1` (`model` field required), llama.cpp route `http://127.0.0.1:8080/v1`, any API key:

```bash
curl http://127.0.0.1:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen3.8:27b-mlx","messages":[{"role":"user","content":"Hello"}],
       "chat_template_kwargs":{"enable_thinking": false}}'
```

## Files

| File | Description |
|------|-------------|
| `chat.html` | web chat UI (literature reading) |
| `editor.html` | ✍️ writing desk: chapters + snapshots + AI three-pane workbench |
| `dashboard.html` | My Desktop: the portal (project overview + global status + library) |
| `LocalLLMServer.swift` | console + archive/PDF/export service source (shared by oMLX/Ollama backends via a compile flag) |
| `QwenServer.swift` | legacy llama.cpp route source (`build.sh`), baseline retained |
| `pptxgen.bundle.js` | PptxGenJS single-file local bundle (report PPT, offline) |
| `build_omlx.sh` · `build_local.sh` · `build.sh` | one-command builds (oMLX / Ollama / llama.cpp apps) |

## Rebuilding

```bash
./build_omlx.sh    # oMLX route (-D OMLX compile flag, LocalLLMServer-oMLX.app; recommended on Apple Silicon)
./build_local.sh   # Ollama route (LocalLLMServer.app)
./build.sh         # legacy llama.cpp route; HTML changes just need a refresh
```

## Deep docs

| Want to know | Where |
|--------------|-------|
| Product positioning & common questions | [FAQ.md](FAQ.md) (in Chinese) |
| Why the author built this (micro-autobiography) | [docs/story.md](docs/story.md) (in Chinese) |
| Benchmark reports, test papers, reproducible scripts | [benchmark/](benchmark/) |
| Roadmap: short/mid-term plans & PR-friendly areas | [docs/roadmap.md](docs/roadmap.md) (in Chinese) |
| API protocol spec for porting to Windows/Linux | [PORTING.md](PORTING.md) (in Chinese) |
| How to contribute (accepted PR types & conventions) | [CONTRIBUTING.md](CONTRIBUTING.md) (in Chinese) |

## Acknowledgements

- [Crossref](https://www.crossref.org) / [OpenAlex](https://openalex.org) — free open scholarly-metadata APIs behind citation verification (ranking, not generation — zero-hallucination lookup)
- [PaSaMaster: Towards Self-Evolving Agentic Literature Retrieval (arXiv:2605.14306)](https://arxiv.org/abs/2605.14306) — the citation-verification architecture is inspired by it
- [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness) — the "local host does file operations, browser is pure UI" layering is borrowed from it
- [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp) · [Ollama](https://ollama.com) — inference engines
- [unsloth](https://unsloth.ai) — high-quality dynamic-quant GGUFs
- [KaTeX](https://katex.org) / [html2canvas](https://github.com/niklasvh/html2canvas) / [PptxGenJS](https://gitbrent.github.io/PptxGenJS/) — formula rendering, PNG export, editable PPTX generation

## License

AGPL-3.0 (the copyleft applies to network-service deployments too: derivatives serving users over the network must offer them the source)
