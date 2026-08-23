# local-llm-station

<div align="center">

**[English](README.en.md)** | **中文**

**🔬 读文献的人，值得一个懂文献的本地工作台——装进 Mac 的科研文献研读与汇报工具**

<img src="assets/architecture-overview.jpg" alt="架构总览：dashboard / chat.html / QwenServer / llama.cpp 分层" width="760">

读一篇文献 → 讲清楚一篇文献 → 讨论它：PDF 上传本地解析（含扫描版 OCR 与图表区域探测）、图表多模态判读、
四段解读、一图总结海报、五段批判性框架汇报 PPT、数据表 CSV 落盘并可附回对话做统计讨论。
离线可用 · 数据不出本机 · API 兼容 OpenAI。

> 项目始于"测一下本地模型能干什么"，如今收窄为一条完整的文献工作流——通用对话仍在，但一切设计围绕文献场景展开。

[新手指南](#新手指南5-分钟跑通第一条文献工作流) · [快速开始](#快速开始) · [功能一览](#它能做什么文献工作流一条龙) · [跑不动本地模型？走云端](#零本地模型方案deepseek-云端-api旧电脑--无-mac-均可用) · [FAQ](FAQ.md) · [深度文档](#深度文档)

</div>

> **外部评价（来自 DeepSeek）**
> "这是一个非常有价值且完成度极高的本地 LLM 项目，尤其对于使用 Apple Silicon Mac 的科研人员、技术写作者和注重数据隐私的用户来说，它是一个难得的实用工具。
> 它的核心价值可以总结为：将强大的本地模型能力，通过精心设计的工程化手段，真正落地为高效、可靠、开箱即用的日常科研与工作助手。"

---

**一个原生控制台 app（LocalLLMServer，旧名 QwenServer）+ 一个网页对话界面（chat.html）**；推理后端双轨：**Ollama（MLX）** 为默认（`qwen3.8:27b-mlx`，视觉+思考原生、长思考任务快约 2 倍），**llama.cpp** 路线保留（`build.sh` 构建 QwenServer.app，跑任意 GGUF）；在 M1 Pro 32GB 上开发验证。前端按服务地址自动识别后端方言（思考开关 / 流式字段 / 探活路径），切换只改设置。

## 它能做什么：文献工作流一条龙

围绕**读一篇文献 → 讲清楚一篇文献**的完整链路：

| 环节 | 功能 | 在哪里发生 |
|------|------|-----------|
| 读进来 | 📄 上传 PDF：本地提取全文（自动剔除参考文献省 20-40% 预填充）+ 内嵌图表位图 + **Vision OCR 图内文字回填**（轴标签/流程图框内文字）；**扫描版 PDF 自动整页 OCR**（正文并入全文、图文混排页按文字块定位裁出图表区域） | **本地** QwenServer，PDF 不出本机 |
| 读得懂 | 默认按 **背景/方法/结果/讨论** 四段解读；本地 Qwen 多模态连图表一起"看"；追问走 prompt 缓存免重读 | 本地（完全离线）或 DeepSeek 云端 |
| 带得走 | 🎨 **一图总结海报** PNG（结果段嵌图表）；📊 **五段批判性框架汇报 PPT**（可编辑 .pptx：结论式标题、图左文右、自动分页、独立结论页，每页带讲稿）——dashboard「📊 文献转PPT」一键工作流：上传 → 默认解读 → 卡片命名 → 自动出片 | 海报本地截图零模型；PPT 云端专属（deepseek-reasoner，约 2-3 分钟） |
| 讨得深 | **项目文件夹**：图表位图与数据表 CSV 自动落盘 `chat_history/<会话>/`（重新生成覆盖不堆积）；资料页点击 CSV **附到对话**做统计讨论（列类型/缺失/min-max-均值概览自动注入）；🔍 **数据体检**：对 CSV 表跑确定性一致性检验（GRIM 均值粒度 / 百分比闭合 / 例数可加性），疑点交由模型判读（舍入表象 / 转录错误 / 统计上不可能） | 本地 |
| 日常 | 对话/翻译/代码、📊 数据文件概览、FigureYa 图型推荐、长图/Markdown 导出、跨对话记忆 | 本地或云端 |

**设计定位——"数据留在本地，算力可以出走"**：

- **文件与数据全本地处理**：PDF 提取、图表提取、数据文件概览、会话存档都由 QwenServer 在本机执行，浏览器零文件权限；默认路径下没有任何文献内容离开你的 Mac
- **生成引擎双轨，切换权在用户**：隐私敏感的日常解读默认本地模型完全离线；重生成任务（汇报 PPT）明确走云端换取 10 倍速度与更好文笔——本地模式点 PPT 会提示切换而非静默上云
- **产出物原生可编辑**：PPT 由结构化 JSON 直接渲染为原生文本框与形状（pptxgenjs），不是"生成图片再 OCR 拆回文字"的假可编辑

## 新手指南：5 分钟跑通第一条文献工作流

装好后（见[快速开始](#快速开始)），照下面顺序走一遍，就是本站的全部核心玩法——每一步只有一个入口，不需要预先理解任何概念：

```
🏠 我的桌面（dashboard.html）—— 一切的入口，做完的事都变成一张卡片
```

**① 读一篇文献**
托盘 →「🌐 开始新对话」→ 输入框旁 📎 上传 PDF → 等提取完成，自动出**四段解读**（背景 / 方法 / 结果 / 讨论）。PDF 只在本机解析，不出网。

**② 追问与图表深读**
对解读里任何一处继续提问（追问走缓存，秒回）；想细看图，直接输入「深读 图1,3 表2」——本地模型逐张看图讲组间差异，图表不出本机。解读结尾的「建议追问」点了就直接发。

**③ 讲给别人听**
- 🎨 **一图总结海报** PNG：本地秒出，适合快速汇报
- 📊 **汇报 PPT**：dashboard 点「文献转PPT」，五段批判性框架 + 逐图页 + 讲稿备注，云端生成约 2-3 分钟

**④ 写自己的稿子**
我的桌面「➕ 新建」→ ✍️ 新写作 → 按 背景/方法/结果/讨论 分章节写；右栏就是 AI——选段润色、让它查证，回答**一键插入光标处**（⌘Z 可撤销，插入前自动快照）。

**⑤ 引用与导出**
dashboard「📚 文献库」把读过的 PDF 扫描入库（自动抓 DOI）→ 编辑器里写 `[@键]` 引用（可点「引用」按钮插入）→ 状态栏 📤 **导出 HTML / Word**——Word 导出前可选引文样式（内置 AMA / Vancouver / APA / GB/T 7714，往 `~/Qwen38/csl/` 放 `.csl` 文件即扩充），pandoc citeproc 自动渲染编号引文与参考文献。

到这一步，读 → 懂 → 讲 → 写 → 引的闭环就走完了。数据体检、引文校验、文献检索等进阶功能按需探索（见[功能一览](#它能做什么文献工作流一条龙)与 [FAQ](FAQ.md)）；电脑跑不动 27B？看下面的云端方案。

> 💡 **想先看成品再上手？** 仓库自带一个示例写作项目（`examples/`，含 5 章节正文、版本快照与写作对话，演示 AI 插入 / 选中润色 / 跨章节检查）。拷入即可在「我的桌面」和编辑器里打开：
> ```bash
> cp -r examples/* chat_history/
> ```
> 示例只是一个普通项目，随时可删。

## 最低配置与速度参考

| 配置 | 说明 |
|------|------|
| **最低可用** | Apple Silicon（M1 及以后）+ 24GB 内存 + 约 20GB 磁盘（默认 Qwen3.8-27B Q4 量化） |
| **推荐** | 32GB 内存（可开 64K 上下文，多模态更从容） |
| **16GB 机器** | 换 14B 及以下量化模型，本站其余功能全部可用 |

**本机实测速度**（M1 Pro 32GB / Qwen3.8-27B UD-Q4_K_XL / 64K 上下文）：

| 指标 | 数值 |
|------|------|
| 模型加载 | ~30 秒 |
| 生成速度 | 5-8 tok/s（关闭深度思考） |
| 首字延迟 | 1-2 秒（短提问） |
| 纯文本对话流畅度 | 可用，长回答需等待 |
| OCR / 图片理解 | 单图 1-2K token，秒级出结果 |

## 特性

**LocalLLMServer.app**（单文件 SwiftUI，无需 Xcode 工程）

- 托盘常驻（无 Dock 图标，自定义羊驼单色图标随系统深浅色）+ ⌥Space 全局热键；菜单栏直达我的桌面 / 开始新对话（经跳转页携带 `?new=1`——macOS 打开 file:// 会丢弃 query）
- 一键启停 **ollama serve**（`build_local.sh` 构建）；接管已运行的外部 serve 时读取实际上下文并在日志明示；停止即 `ollama stop` 卸载模型内存。旧 llama.cpp 路线（QwenServer.app，`build.sh` 构建）保留：启停 llama-server + 上下文两档制动态计算
- 内嵌 :8081 微型宿主服务（仅本机，CORS + 路径防护），随 app 自启、与模型无关：会话存档 CRUD、`/pdf` 文献全文与图表提取（Vision OCR 回填 + 扫描版兜底 + JACC 系全大写图注版式）、`/file` 数据概览、项目文件夹 `/projfile`·`/projlist`、`/projects/list` + `/system/status`（dashboard 数据源）、`/rename` 项目三处同步改名、`/export-docx` 成稿导出
- `~/Qwen38/config.json` 外部配置 ollama 路径/模型标签/上下文，换模型免重编译

**chat.html**（单文件，零依赖，任意浏览器可用，含 Safari）

- 流式输出、可中断、思考折叠（`reasoning_content` 与 `<think>` 双格式）；长输出生成中大纲预览
- 智能模式按内容自动选档 + 三档手动预设（深度推理 / 精确 / 日常），依据见 benchmark 结论
- 📄 PDF 文献上传：本地提取全文+图表（解析等待条），默认四段解读（背景/方法/结果/讨论），追问走 prompt 缓存
- 📖 深度提取（`/证据提取`、`/观点提取`）：RCT/Meta 按 PICOS+偏倚+绝对效应提取证据、论著按七维度提取观点与数据；防编造约束（原文没有就写"未明确说明"，禁止脑补 P 值）、「数据显示 vs 作者认为」分离、`[[可引用于引言/讨论/方法]]` 标签；结果自动存入项目笔记供编辑器引用
- 🔍 图表本地多模态深读（支持范围选择，OCR 图内文字随附）；📊 一键五段批判性框架汇报 PPT（云端专属，约 2-3 分钟，数据表同步落盘 CSV）；🎨 一图总结海报 PNG
- 🗂 项目面板：📝 笔记 / 📄 资料（含项目文件——点击 CSV 附到对话做统计讨论；🔍 数据体检：GRIM/百分比闭合/n 可加性确定性检验 + 模型判读）/ 🃏 知识卡片
- 跨对话长期记忆（🧠 面板管理）；上下文用量条 + 自动压缩（原文保留）
- ☁️ DeepSeek 云端模式：无模型/无 Mac 可用，与本地一键互切
- 多会话侧栏、搜索、排队输入、编辑重发（截断前确认）；Markdown/表格/KaTeX 公式渲染；多模态图片上传
- 🔍 文献检索：「/」指令菜单唤起，`找文献 关键词` → PubMed 最新 8 篇 + OpenAlex 相关 8 篇（附开放获取全文 PDF 链接）落进对话，可继续追问
- 其余细节功能（时间戳落盘、导出格式、URL 直达参数、输入法处理等）见 [FAQ 完整清单](FAQ.md#chathtml-还有哪些细节功能)

**dashboard.html（我的桌面）**：打开对话之前的门户、整个工作区的控制中心

- 项目总览：每条存档对话一张卡片（📄 文献 / 💬 对话），显示资料数/数据表数/图表数/笔记/卡片与活跃时间，点击直达；📌 置顶、🏷 手动标签（存 dashboard.json，与知识卡片 concept 自动标签合并展示）
- 🔍 全局搜索：跨所有会话全文检索（懒加载建内存索引，点击命中卡片直达对话）；「全部内容」档同时索引 📝 项目笔记与 🃏 知识卡片，范围可切 💬 对话正文 / 📎 附件全文（文献 PDF text，文件名可搜）；`#标签` 按标签聚合；时间过滤精确到**消息级时间戳**（新消息落盘 ts，旧消息回退会话活跃时间）
- 📊 文献转PPT / 📚 引文校验（粘贴参考文献列表，逐条查证 Crossref → OpenAlex，存疑再经 PubMed 交叉验证，报告落入对话）/ ✏️ 开始新对话：一键直达对应工作流
- 全局状态：模型服务/模型名/CPU/内存（5 秒轮询）+ ⏱ 今日专注时长（chat/editor 页面可见且 3 分钟内有操作才计时，挂机不计——数字诚实才有激励价值）；纯静态单文件，数据来自 :8081

**editor.html（✍️ 写作台）**：一篇论文一个项目——分章节写作、版本快照、AI 辅助三栏工作台

- 三栏布局（可拖拽调宽/折叠）：左 大纲+项目资源（知识卡片/文献/笔记）· 中 markdown 章节 tab（可增删改名/拖拽排序）+ 格式工具栏 + 预览 · 右 AI 写作助手（润色/改写/查证，回答一键插入光标处，⌘Z 可撤销）
- 版本快照：手动保存 / AI 插入前 / 恢复前自动快照，可命名、一键恢复整文档；恢复前可看「差异」——行级 diff（双向行号、变更行±2 上下文折叠），**点击任意差异行直接跳到编辑区对应位置**；章节与对话存项目子目录（`/projfile`，零服务端侵入）
- 🛡️ 三层防丢字（Typora 式）：服务端原子写 + `name~` 上一版滚动备份（写一半崩溃最坏退一版、永不截断）· 浏览器崩溃草稿（输入即镜像 localStorage，保存成功才清除）· 重启自动检测未落盘编辑并询问恢复——存档服务挂掉、关标签页、断电都不丢字
- ✨ 初稿生成：按当前章节的小节大纲逐节撰写——无依据处写「（待补：…）」占位不编造数据、只用文献库引文键、术语全文一致；已有内容时只补缺失小节不重写
- 🔍 选中论断「查证据」：在已附文献全文中逐条找支持/反驳证据（来源、判定、关键数据，禁止编造）
- 🧭 跨章节一致性检查 + 🕵️ 模拟审稿：检查结果—讨论呼应/术语与数据一致；四视角审稿（综合/方法学/统计/临床）输出 Major/Minor 意见与总体评价；报告自动存项目文件，左栏 💬 一键对照逐条核查（已满足/部分满足/未满足 + 最小修改方案）
- 📎 附文献全文：右栏勾选文献库条目注入上下文（每篇截 25K 字，首问预填充后追问走缓存）；指代消歧（附文献时"这篇文章"默认指文献）
- [@key] 引文系统：正文写 `[@r1abc]`，预览/导出渲染 `[1]` 编号 + 文末参考文献；AI 上下文注入引文键清单，可直接产出带引文的段落
- 🃏 知识卡片引用：编辑区敲 `@` 唤起混合补全（卡片+文献），`[[概念名]]` 渲染为卡片徽标（悬停见定义），内容随卡片更新自动同步

**📚 全局文献库（dashboard → 文献库面板）**：Zotero 式条目数据，JSON 实现

- 「扫描对话入库」聚合全部会话传过的 PDF（全文提取时保存 DOI/PMID，按 DOI 全局去重——同一论文不同文件名也合并）
- 「补元数据」：DOI 精确查 Crossref（免误配），无 DOI 走全文开头模糊查询（中英文相似度校验宁缺勿错）；✎ 手动补录支持粘贴 DOI 链接 / 裸 DOI / PMID（Europe PMC，中文文献）/ 完整标题；✏️ 字段直接编辑 + ➕ 手动添加（中文文献/书籍等外部查不到的条目）
- 📥📤 BibTeX / RIS 双格式导入导出（Zotero/EndNote 握手；导入按内容自动识别格式、DOI/标题去重）
- 条目可删可查（作者·期刊·年份·DOI·字数），编辑器引用与附全文共用此库

**📤 成稿导出**（editor 状态栏）

- HTML：自包含单文件（KaTeX 样式与字体 base64 内联，拷走不丢公式），浅色纸面排版，浏览器打印即 PDF
- Word（.docx）：宿主机 pandoc + citeproc，引文按 AMA 方括号样式（`[1]` 非上标）自动生成参考文献；中文模板 宋体-简/黑体-简/1.5 倍行距 + Times New Roman 混排（改 `export-template-zh.docx` 即自定义版式），英文模板全文 Times New Roman

产品定位与常见疑问见 [FAQ.md](FAQ.md)。

## 生态搭配：数据探索推荐 quelmap

本站定位是**轻量问答与文献数据联动**（📊 附件只注入列概况，供"结合我的数据回答"式提问），不做深度数据探索。需要交互式分析、自动出图、迭代探索时，推荐开源本地工具 [quelmap](https://github.com/quelmap-inc/quelmap)：其专用模型 Lightning-4b（4B，GRPO 特训，GGUF）把"代码 + 占位符报告"的习惯训练进了权重，官方实测 16GB MacBook 即可流畅运行，隐私定位与本站一致。跑重分析时建议在托盘停掉本站的 27B 服务，避免统一内存争抢。

画图时输入框上方会自动提示最合适的 [FigureYa](https://github.com/ying-ge/FigureYa) 模板（纯前端关键词匹配，零 token），点击直达该模块的 GitHub 页面自取论文级 R 脚本——本站不做模板注入与代码生成，各司其职。

## 模型能力实测（benchmark）

针对默认模型 Qwen3.8-27B 做了四套人工评分卷、共 56 题，逐题对照踩分点判定：

| 测试卷 | 题数 | 结果 |
|--------|------|------|
| 通用知识压力测试 | 22 | 86% · 良好+ |
| 医学专项（执业医师级） | 17 | 91% · 用药安全项踩线 |
| 中英双向翻译（含回译） | 14 | 8 全对 + 2 半对，回译零漂移 |
| 数据分析编程（实际运行验证） | 7 | **100% · 卓越** |

结论速览：**代码生成、日常翻译、写作放心用；长尾事实与用药细节需人工核对；查证事实、临床决策禁用**。

- 完整报告（能力边界、场景推荐、配置建议）：[benchmark/report.html](benchmark/report.html)
- 公众号版：[benchmark/report_wechat.html](benchmark/report_wechat.html)
- 试卷、原始答案与可复现脚本：[benchmark/](benchmark/) 目录

关键工程结论：**temp 0.0 + 关闭思考**，翻译/代码任务精度最高且快约 20 倍——chat.html 底部的模式选择器已内置该预设。

### 双后端对照：Ollama（MLX）vs llama.cpp（2026-08-21）

默认模型切换 `qwen3.8:27b-mlx`（Ollama，NVFP4/262K）前后，同一台 M1 Pro 上跑同题四套件（57 题）对照：

| 套件 | llama.cpp | Ollama MLX | 套件 | llama.cpp | Ollama MLX |
|------|-----------|------------|------|-----------|------------|
| 常识卷 22 题 | 777s | 1046s (0.74x) | 编程卷 7 题 | 296s | 376s (0.79x)，双方 7/7 运行通过 |
| 医学卷 17 题 | 5211s | **2805s (1.86x)** | 翻译卷 11 题 | 59s | 433s (0.14x，译文啰嗦) |

- **质量同水平，性格互补**：事实题 Ollama 更稳（水浒天罡地煞、肖申克圣经卷——llama.cpp 自信编造《马太福音》，Ollama 不装确定）；无解数学陷阱题 llama.cpp 胜（Ollama 关思考档偶发空响应，前端已自动重试兜底）；医学抽查全部准确
- **速度各擅一场**：短问答/翻译 llama.cpp 快 1.5-5 倍；**长思考任务 Ollama 快约 1.86 倍**（思考链更收敛，单题最高 1531.9s → 276.6s）；解码均 ~10 tok/s
- **多模态真实可用**：图内埋入的无法猜到的数值（N=87、p=0.0037）全部逐字读出，无静默幻觉；文本 prompt 缓存 55.7x；**图片前缀缓存不生效**（同图追问每次多付约 12s）
- 完整对照报告：[benchmark/ollama_vs_llamacpp_report.html](benchmark/ollama_vs_llamacpp_report.html)

这正是"文本走 Ollama、图表深读等连续多模态追问场景可切回 llama.cpp"双轨设计的依据。

## 架构

```
dashboard.html（我的桌面：项目总览 + 全局状态，门户页）
   │  卡片悬停出底部双入口（💬 对话 | ✍️ 写作）；点卡片按类型分流兜底
   ▼
chat.html / editor.html（任意浏览器，纯 UI + localStorage 缓存）
   │  :11434/v1  对话 API（Ollama MLX，LocalLLMServer 启停；旧路线 :8080/v1 llama.cpp）
   │  :8081      存档 API（LocalLLMServer 内嵌微型 HTTP 服务）
   ▼
LocalLLMServer.app（宿主进程）
   ├── 启停 ollama serve / llama-server、上下文选择、运行时间/日志
   └── 读写 ~/local-llm-station/chat_history/*.json
```

文件操作全部由本地宿主进程执行，浏览器零文件权限——这是本项目的核心设计：借鉴 deepseek-harness 的"本地宿主 + 浏览器纯 UI"分层，浏览器只是壳。

## 快速开始

**一键安装**（自动装 Homebrew/llama.cpp、克隆源码到 `~/Qwen38`、下载 27B 模型与 KaTeX、编译启动；国内可先 `export HF_ENDPOINT=https://hf-mirror.com`）：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/dalianblue/local-llm-station/main/install.sh)
```

内存不足 24GB 或暂不下载模型：`SKIP_MODEL=1` 运行上述命令。以下为手动分步：

```bash
# 1. 安装 llama.cpp
brew install llama.cpp

# 2. 下载任意 GGUF 模型（示例为 unsloth 量化，国内用 hf-mirror）
export HF_ENDPOINT=https://hf-mirror.com   # 可选
hf download unsloth/Qwen3.8-27B-GGUF Qwen3.8-27B-UD-Q4_K_XL.gguf --local-dir .

# 3. 可选：KaTeX 公式渲染资产（2.9MB，不入库；缺失时公式自动降级为原样文本，其余功能不受影响）
mkdir -p ~/Qwen38/katex && curl -sL https://registry.npmjs.org/katex/-/katex-0.16.11.tgz -o /tmp/katex.tgz \
  && tar xzf /tmp/katex.tgz -C ~/Qwen38/katex --strip-components=2 package/dist

# 4. 编译并启动控制台
./build.sh && open QwenServer.app

# 5. app 里选上下文 → 启动服务 → 开始对话
```

Ollama（MLX）路线：`brew install ollama` → `ollama pull qwen3.8:27b-mlx` → `./build_local.sh && open LocalLLMServer.app`（详见上文「换模型」）。

## 零本地模型方案：DeepSeek 云端 API（旧电脑 / 无 Mac 均可用）

电脑跑不动 27B（内存 <24GB、老 Intel Mac、Windows 轻薄本）？**不需要安装任何东西，一个浏览器 + DeepSeek API Key 即可用全部对话功能**：

1. **获取 API Key**：注册 [platform.deepseek.com](https://platform.deepseek.com)，充值后创建 Key（`sk-` 开头，几块钱可用很久）
2. **下载 chat.html**：只需仓库里的 `chat.html` 单文件（可选：连同 `katex/` 目录下载，公式渲染更好看；缺失时公式降级为原样文本）
3. **配置**：浏览器打开 chat.html → 右上角 ⚙️ 设置 → 「API 服务」选 **☁️ DeepSeek API** → 粘贴 Key。Key 仅存本机浏览器 localStorage，不经过任何第三方

配置完成即用，行为说明：

- 思考档自动映射 `deepseek-reasoner`（思考过程流式展示），关思考映射 `deepseek-chat`；llama.cpp 专有参数自动剔除，无需手动适配
- **对话完全不依赖本地服务**——无需 QwenServer.app、无需模型文件；跨对话记忆、会话管理、压缩、导出、📊 一键汇报 PPT（本就是云端专属）全部可用
- 两个可选增强（需 macOS 上跑 QwenServer.app，不加载模型也可）：📄 PDF 本地提取、自动存档；没有它们时文献解读可直接粘贴正文文本
- 注意：云端模式下对话内容会发送到 DeepSeek 服务器；上传数据文件前页面会弹"数据出本机"警示

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

本项目只官方支持 macOS，但前后端之间是纯 HTTP 契约，欢迎 fork 移植：完整协议见 **[PORTING.md](PORTING.md)**，配套 [mock_server.py](mock_server.py)（纯标准库空壳，跑起来即可联调前端）；最小可用集只有三个端点（`/health`、`/list`、`/archive`），半天可完成。

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

## 文件说明

| 文件 | 说明 |
|------|------|
| `chat.html` | 网页对话界面 |
| `editor.html` | ✍️ 写作台：分章节写作 + 版本快照 + AI 辅助三栏工作台 |
| `dashboard.html` | 我的桌面：项目仪表盘门户页（项目总览 + 全局状态 + 文献库） |
| `LocalLLMServer.swift` | 控制台 + 存档/PDF/图表提取/导出服务源码（Ollama 后端，`build_local.sh` 构建） |
| `QwenServer.swift` | 旧 llama.cpp 路线源码（`build.sh` 构建），功能基线保留 |
| `pptxgen.bundle.js` | PptxGenJS 单文件本地包（汇报 PPT 渲染，离线零 CDN） |
| `build_local.sh` · `build.sh` | 一键编译（自动生成 Info.plist；前者出 LocalLLMServer.app，后者出 QwenServer.app） |

## 修改与重新编译

```bash
./build_local.sh   # 改 LocalLLMServer.swift 后执行（Ollama 路线，默认）
./build.sh         # 旧 llama.cpp 路线（QwenServer.swift）；改 chat.html 等 HTML 刷新浏览器即可
```

## 深度文档

| 想了解 | 去哪里 |
|--------|--------|
| 产品定位、微自传与常见疑问 | [FAQ.md](FAQ.md) |
| 模型能力实测报告、试卷与可复现脚本 | [benchmark/](benchmark/) 与 [benchmark/report.html](benchmark/report.html) |
| 移植到 Windows/Linux 的 API 协议规范 | [PORTING.md](PORTING.md) |

## 致谢

- [Crossref](https://www.crossref.org) / [OpenAlex](https://openalex.org)——引文校验使用的两个免费公开学术元数据 API（排序而非生成，零幻觉查证）
- [PaSaMaster: Towards Self-Evolving Agentic Literature Retrieval (arXiv:2605.14306)](https://arxiv.org/abs/2605.14306)——引文校验"查证走数据库排序比对、绝不让模型凭记忆生成"的架构借鉴自它
- [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness)——本项目的"本地宿主进程执行文件操作、浏览器只做纯 UI"分层架构借鉴自它
- [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp)——推理引擎
- [unsloth](https://unsloth.ai)——高质量动态量化 GGUF
- [KaTeX](https://katex.org) / [html2canvas](https://github.com/niklasvh/html2canvas) / [PptxGenJS](https://gitbrent.github.io/PptxGenJS/)——公式渲染、PNG 导出与可编辑 PPTX 生成

## License

AGPL-3.0（网络服务部署同样适用传染条款：衍生品无论以何种形式提供服务，须向用户提供源码）
