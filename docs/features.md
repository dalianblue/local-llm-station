# 功能详情（自 README 迁入）

README 只保留主干速览；本章是完整功能清单、实现边界与配置细节。

## 它能做什么：文献工作流一条龙

围绕**读一篇文献 → 讲清楚一篇文献**的完整链路：

| 环节 | 功能 | 在哪里发生 |
|------|------|-----------|
| 读进来 | 📄 上传 PDF：本地提取全文（自动剔除参考文献省 20-40% 预填充）+ 内嵌图表位图 + **Vision OCR 图内文字回填**（轴标签/流程图框内文字）；**扫描版 PDF 自动整页 OCR**（正文并入全文、图文混排页按文字块定位裁出图表区域） | **本地** LocalLLMServer，PDF 不出本机 |
| 读得懂 | 默认按 **背景/方法/结果/讨论** 四段解读；本地 Qwen 多模态连图表一起"看"；追问走 prompt 缓存免重读 | 本地（完全离线）或 DeepSeek 云端 |
| 带得走 | 🎨 **一图总结海报** PNG（结果段嵌图表）；📊 **五段批判性框架汇报 PPT**（可编辑 .pptx：结论式标题、图左文右、自动分页、独立结论页，每页带讲稿）——dashboard「📊 文献转PPT」一键工作流：上传 → 默认解读 → 卡片命名 → 自动出片 | 海报本地截图零模型；PPT 云端专属（deepseek-reasoner，约 2-3 分钟） |
| 讨得深 | **项目文件夹**：图表位图与数据表 CSV 自动落盘 `chat_history/<会话>/`（重新生成覆盖不堆积）；资料页点击 CSV **附到对话**做统计讨论（列类型/缺失/min-max-均值概览自动注入）；🔍 **数据体检**：对 CSV 表跑确定性一致性检验（GRIM 均值粒度 / 百分比闭合 / 例数可加性），疑点交由模型判读（舍入表象 / 转录错误 / 统计上不可能） | 本地 |
| 日常 | 对话/翻译/代码、📊 数据文件概览、FigureYa 图型推荐、长图/Markdown 导出、跨对话记忆 | 本地或云端 |

**设计定位——"数据留在本地，算力可以出走"**：

- **文件与数据全本地处理**：PDF 提取、图表提取、数据文件概览、会话存档都由宿主 app（LocalLLMServer）在本机执行，浏览器零文件权限；默认路径下没有任何文献内容离开你的 Mac
- **生成引擎双轨，切换权在用户**：隐私敏感的日常解读默认本地模型完全离线；重生成任务（汇报 PPT）明确走云端换取 10 倍速度与更好文笔——本地模式点 PPT 会提示切换而非静默上云
- **产出物原生可编辑**：PPT 由结构化 JSON 直接渲染为原生文本框与形状（pptxgenjs），不是"生成图片再 OCR 拆回文字"的假可编辑

---

## 特性

> 每个功能的实现细节与边界说明见 [FAQ「功能细节」](../FAQ.md#功能细节自-readme-迁入)，这里只列主干。

**LocalLLMServer.app**（单文件 SwiftUI，无需 Xcode 工程）

- 托盘常驻（无 Dock 图标）+ ⌥Space 全局热键；菜单栏直达我的桌面 / 开始新对话
- 一键启停 **ollama serve**（默认）；旧 llama.cpp 路线保留（QwenServer.app，`build.sh` 构建）
- 内嵌 :8081 微型宿主服务（仅本机）：会话存档、`/pdf` 文献提取、项目文件夹、成稿导出——文件操作全在宿主进程，浏览器零文件权限
- `~/Qwen38/config.json` 外部配置模型标签/上下文，换模型免重编译

**chat.html**（单文件，零依赖，任意浏览器可用，含 Safari）

- 📄 PDF 上传：本地提取全文+图表，四段解读（背景/方法/结果/讨论），追问走缓存
- 📖 深度提取（`/证据提取`、`/观点提取`）：RCT/Meta 与论著两套框架，防编造约束，结果自动存项目笔记
- 🔍 图表本地多模态深读 · 📊 五段批判性框架汇报 PPT（云端）· 🎨 一图总结海报
- 🔍 `找文献 关键词`：PubMed + OpenAlex 双源检索，结果落进对话可追问
- 🗂 项目面板：📝 笔记 / 📄 资料（CSV 附回对话 + 🔍 数据体检：GRIM 等确定性检验）/ 🃏 知识卡片
- 智能模式自动分档 + 三档手动预设；跨对话记忆；上下文自动压缩（原文保留）
- ☁️ DeepSeek 云端模式：无模型/无 Mac 可用，与本地一键互切
- 细节功能（时间戳、导出、URL 参数、输入法处理等）见 [FAQ](../FAQ.md#chathtml-还有哪些细节功能)

**dashboard.html（我的桌面）**：门户与控制中心

- 项目总览卡片（资料/数据表/图表/笔记/卡片计数与活跃时间）；📌 置顶、🏷 标签
- 🔍 全局搜索：对话全文 + 附件全文 + 项目笔记 + 知识卡片；`#标签` 聚合；时间过滤
- 📊 文献转PPT · 📚 引文校验（Crossref → OpenAlex → PubMed 交叉查证）· 📚 文献库
- 全局状态条 + ⏱ 今日专注时长（页面可见且 3 分钟内有操作才计时，挂机不计）

**editor.html（✍️ 写作台）**：一篇论文一个项目，三栏工作台

- 三栏布局：大纲+资源 / 章节 tab + 预览 / AI 论文助手（回答一键插入光标处，⌘Z 可撤销）
- 🛡️ 三层防丢字（服务端原子写 + 浏览器崩溃草稿 + 重启恢复询问）
- 版本快照：自动+手动+命名，恢复前可看行级 diff，**点击差异行跳到编辑区对应位置**
- ✨ 初稿生成（无依据处写「待补」不编造）· 🔍 选中查证据 · 🧭 跨章节一致性检查 · 🕵️ 四视角模拟审稿（报告自动存档，一键对照修改）
- [@键] 引文系统（预览/导出自动编号列参考文献）· 🃏 `@` 补全引用知识卡片（`[[概念]]`）
- 📎 附文献全文给 AI（文献库/本项目 PDF）· 📋 一键带入本项目「聊聊文献」的讨论纪要（截断注入，不挤爆上下文）

**📮 审稿修稿闭环**（一篇稿的完整生命周期）

- 投稿标记：状态栏「📮 投稿」→「收到审稿」**fork 出修稿版项目**（章节/快照/笔记/卡片全量拷贝），原投稿版自动锁定、dashboard 点旧卡直达修稿版；多轮修稿再 fork 即可
- 📨 意见结构化：粘贴整封 decision letter，AI 拆成逐条清单（Reviewer 编号 + Major/Minor + 原文逐字保留，解析失败整段保底不丢意见），逐条状态追踪（待处理/已修改/已反驳）
- 逐条工作流：💬 AI 给定位+修改方案+反驳论点+Response 草稿 → 用户执锤改稿（快照/⌘Z 现链路）→ 📝 Response 编辑存档（可一键截取 AI 草稿节）
- 🏥 落地体检：逐条核对 Response 声称的修改在当前稿中是否真实存在（✅已落地/⚠️未落地/➖纯反驳），防"信里说改了、稿里没改"
- 📤 point-by-point 回复信 Word（按 Reviewer 分组，未写条目留占位）· 🖍 高亮修改稿 Word（与投稿基线行级 diff，改动行黄底，参考文献不标）

**📚 全局文献库**：Zotero 式条目，JSON 实现

- 扫描对话入库（DOI 自动抓取去重，**按来源项目自动归入分类**）· Crossref 补元数据 · ✏️ 字段编辑 + ➕ 手动添加
- 📁 分类（collections）：一条文献可属多个分类；库面板分类筛选、编辑器附文献按分类过滤、RIS 导出映射为关键词
- 📥📤 BibTeX / RIS 双格式导入导出（Zotero/EndNote 握手）

**📤 成稿导出**（editor 状态栏）

- HTML：自包含单文件（公式内联），浏览器打印即 PDF
- Word：pandoc + citeproc，引文样式可选（内置 AMA / Vancouver / APA / GB/T 7714）
- 🖍 高亮修改稿 Word：仅修稿版显示，与投稿基线 diff 的改动行黄底

产品定位与常见疑问见 [FAQ.md](../FAQ.md)。

## 生态搭配：数据探索推荐 quelmap

本站定位是**轻量问答与文献数据联动**（📊 附件只注入列概况，供"结合我的数据回答"式提问），不做深度数据探索。需要交互式分析、自动出图、迭代探索时，推荐开源本地工具 [quelmap](https://github.com/quelmap-inc/quelmap)：其专用模型 Lightning-4b（4B，GRPO 特训，GGUF）把"代码 + 占位符报告"的习惯训练进了权重，官方实测 16GB MacBook 即可流畅运行，隐私定位与本站一致。跑重分析时建议在托盘停掉本站的 27B 服务，避免统一内存争抢。

画图时输入框上方会自动提示最合适的 [FigureYa](https://github.com/ying-ge/FigureYa) 模板（纯前端关键词匹配，零 token），点击直达该模块的 GitHub 页面自取论文级 R 脚本——本站不做模板注入与代码生成，各司其职。

---

## 换模型

**Ollama 路线（LocalLLMServer.app）**：模型即 Ollama 包，`ollama pull` 新模型后改 `~/Qwen38/config.json` 的模型标签，重启生效：

```json
{
  "ollamaPath": "/opt/homebrew/bin/ollama",
  "ollamaModel": "qwen3.8:27b-mlx",
  "ollamaContextLength": 65536
}
```

模型标签也在 chat.html ⚙️ 设置里可改（存 localStorage，升级换模型不动代码）。

**llama.cpp 路线（QwenServer.app）**：`~/Qwen38/config.json` 写 GGUF 路径：

```json
{
  "modelPath": "/Users/你的用户名/Qwen38/Qwen3.8-27B-UD-Q4_K_XL.gguf",
  "mmprojPath": "/Users/你的用户名/Qwen38/mmproj-F16.gguf",
  "contextLength": 65536
}
```

- 三项全部可选，缺哪项回落内置默认（上下文档位按内存动态计算）；路径填错自动回落默认并仍提示
- 改源码路线依然可用：编辑 `LocalLLMServer.swift` 后 `./build_local.sh`（旧路线 `QwenServer.swift` + `./build.sh`）。工作目录默认 `~/Qwen38`，搬家时代码里全局替换

## 在 Windows / Linux 上使用（非 Apple Silicon 方案）

QwenServer.app 依赖 macOS（SwiftUI + PDFKit），无法跨平台；但 **chat.html 是纯前端**，只要求一个 OpenAI 兼容的对话 API，后端可自由替换：

1. 起一个 OpenAI 兼容后端，任选其一：
   - [text-generation-webui](https://github.com/oobabooga/text-generation-webui)（`--api --listen`，默认 `http://127.0.0.1:5000/v1`）
   - llama.cpp（Windows/Linux 同样可编译，`llama-server` 自带 `/v1`，与 Mac 方案零差别）
   - [Ollama](https://ollama.com)（`OLLAMA_ORIGINS=* ollama serve` 开 CORS，API 为 `http://127.0.0.1:11434/v1`）
2. 浏览器打开 chat.html → ⚙️ 设置 → 「服务地址」填你的后端（如 `http://127.0.0.1:5000`、Ollama 填 `http://127.0.0.1:11434`），改完自动重连——无需改代码
3. 即可使用。流式输出、思考折叠、模式选择、对话压缩、导出等全部功能不依赖平台。

**平台差异**：PDF 文献上传与自动存档走 QwenServer 的 :8081 服务（PDFKit 提取），无 QwenServer 时这两项不可用（文献解读可粘贴正文文本替代）；KaTeX 资产目录路径按需调整。`chat_template_kwargs.enable_thinking` 为 llama.cpp 特有参数，其他后端会忽略，不影响运行——思考过程是否展示取决于该后端是否返回 `reasoning_content` 或 `<think>` 标签，chat.html 两种格式都接。

### 移植指南（想自己写宿主服务的开发者）

本项目只官方支持 macOS，但前后端之间是纯 HTTP 契约，欢迎 fork 移植：完整协议见 **[PORTING.md](../PORTING.md)**，配套 [mock_server.py](../mock_server.py)（纯标准库空壳，跑起来即可联调前端）；最小可用集只有三个端点（`/health`、`/list`、`/archive`），半天可完成。

## 上下文长度与内存（动态计算）

模型原生上下文上限 **256K**（GGUF 元数据 `qwen35.context_length = 262144`）。控制台采用**两档制**（推荐/极限），按本机配置实时计算，换机器/换模型免配置：

```
KV 预算 = 物理内存 × 70% − 模型文件体积 − 1.5GB 系统余量
推荐档  = 预算可容纳的最大上下文（KV 按 64KB/token 上界估 + 15% 余量）
```

| 内存（配 27B Q4） | 默认推荐档 | 极限档 |
|------------------|-----------|--------|
| 24GB | 8K | 16K |
| 32GB | 64K | 128K |
| 48GB | 128K | 256K |
| 64GB+ | 256K（顶档） | — |

系数按 M1 Pro 实测校准（新版 macOS 可锁约 70% 统一内存；Qwen3.8 混合注意力实际 KV 低于 64KB/token 上界）。极限档超出 GPU 默认锁定上限，需先执行 `sudo sysctl iogpu.wired_limit_mb=26624`，否则回退 CPU、速度暴跌。该命令允许单个进程锁定更多统一内存（数值过高可能卡死系统），仅本次开机生效、重启自动恢复；`=0` 可撤销。

## 存档 API（:8081，带 CORS，仅供本机）

| 接口 | 说明 |
|------|------|
| `GET /health` | 在线检查 |
| `GET /list` | 列出所有存档文件名 |
| `GET /archive/<文件名>` | 读取存档 |
| `PUT /archive/<文件名>` | 写入存档（每轮对话自动调用） |
| `PUT/GET /projfile/<会话>/<文件名>` | 项目文件夹读写（图表位图 / 数据表 CSV 落盘；editor 章节与快照、全局文献库同走此端点） |
| `GET /projlist/<会话>` | 列出项目文件（资料页"项目文件"数据源） |
| `POST /pdf` · `POST /file` | 文献全文+图表提取（Vision OCR/扫描版兜底/全大写标题式图注版式）· 数据文件概览 |
| `POST /rename` | 项目改名（存档文件名 + 内部 title + 项目文件夹三处同步，失败自动回滚不丢数据） |
| `POST /export-docx` | 成稿导出 markdown → .docx（宿主机 pandoc + AMA 引文） |
| `GET /static/katex/*` | KaTeX 静态资源（导出 HTML 内联样式用，file:// 同源策略兜底） |
| `GET /projects/list` | 项目列表（每条会话：id/标题/活跃时间/资料数/笔记/卡片/自动标签/数据表数/图表数），dashboard 数据源 |
| `GET /system/status` | llama-server 探活 + CPU/内存/模型名，dashboard 数据源 |
| `GET /version` | git SHA 版本标识（零手工维护），issue 汇报与上游更新比对用 |

每会话一个 `chat_history/<id>-<标题>.json`，含完整消息/指标/图片；另有 `memory.json` 存跨对话长期记忆。页面启动时自动与 localStorage 合并（取消息更多、更新的版本）。图表位图与数据表 CSV 另存于 `chat_history/<id>-<标题>/` 项目文件夹，重新生成同名覆盖。

## 对话 API

OpenAI 兼容：Ollama 路线 `http://127.0.0.1:11434/v1`（须带 `model` 字段），llama.cpp 路线 `http://127.0.0.1:8080/v1`，API Key 随便填：

```bash
curl http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"你好"}],
       "chat_template_kwargs":{"enable_thinking": false}}'
```
