# 移植指南 —— 给 Windows / Linux 开发者

本项目分两层：**chat.html / dashboard.html（纯前端，零平台依赖）** 和 **QwenServer.app（macOS 宿主，SwiftUI）**。
本文是两层之间的完整协议：你只需按契约实现一个宿主服务（C# / C++ / Rust / Python 均可），
前端原样可用。macOS 之外我们不做官方支持——fork 后请自便。

配套 **mock_server.py**（纯 Python 标准库）实现了全部端点的空壳版本，`python3 mock_server.py`
即可让前端跑起来，再逐个端点替换为真实实现。

## 角色 与 端口

```
chat.html / dashboard.html（任意浏览器）
   │  :8080/v1  对话 API —— 任何 OpenAI 兼容后端（llama-server / Ollama / 你自己的）
   │  :8081     宿主 API —— 存档 / PDF 提取 / 系统状态（= QwenServer 的角色，你要移植的部分）
```

- :8080 不必自己写：llama.cpp 与 Ollama 都有 Windows/Linux 版。只在也要替换它时才需实现 §1。
- :8081 是移植主体，见 §2。**两个端口的响应都必须带 CORS 头**（前端从 file:// 发起跨源请求）：

```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, PUT, POST, DELETE, OPTIONS
Access-Control-Allow-Headers: Content-Type
```

- 每个非 OPTIONS 请求前浏览器可能先发 `OPTIONS` 预检，回 `204 No Content` + 上述头即可。
- **安全基线**：宿主服务只绑 `127.0.0.1`；`/archive/<name>` 必须拒绝含 `/`、`\`、`..` 的名字（路径穿越）。

---

## §1 :8080 对话 API（OpenAI 兼容子集）

| 端点 | 方法 | 说明 |
|------|------|------|
| `/health` | GET | 200 即在线（body 任意） |
| `/props` | GET | 可选。返回 `{"default_generation_settings":{"n_ctx":32768}}`，前端用于显示上下文用量条 |
| `/v1/chat/completions` | POST | 主对话端点，支持流式与非流式 |

### 请求（前端实际会发的字段）

```json
{
  "model": "default",
  "messages": [
    {"role":"system","content":"…"},
    {"role":"user","content":"纯文本"},
    {"role":"user","content":[
      {"type":"text","text":"带图问题"},
      {"type":"image_url","image_url":{"url":"data:image/jpeg;base64,…"}}
    ]}
  ],
  "stream": true,
  "temperature": 0.0,
  "chat_template_kwargs": {"enable_thinking": false}
}
```

- `content` 是字符串或上面的多模态数组，两种都要接
- `chat_template_kwargs` 是 llama.cpp 特有参数，不认识就忽略（不要报错）

### 流式响应（SSE）

思考型后端把推理过程放 `delta.reasoning_content`（DeepSeek/llama.cpp 风格）；
普通内容放 `delta.content`。前端两种都解析，也兼容 content 里内嵌 `<think>…</think>` 标签。

```
data: {"choices":[{"delta":{"reasoning_content":"思考中…"}}]}

data: {"choices":[{"delta":{"content":"答案"}}]}

data: [DONE]
```

### 非流式响应

```json
{"choices":[{"message":{"role":"assistant","content":"答案"}}]}
```

---

## §2 :8081 宿主 API

### P0：存档闭环（最小可用集）

| 端点 | 方法 | 请求 | 响应 | 错误 |
|------|------|------|------|------|
| `/health` | GET | — | `"ok"`（200） | — |
| `/list` | GET | — | `["c123-标题.json", …]` JSON 数组 | — |
| `/archive/<name>` | GET | name 需 percent-decode | 存档 JSON 原文 | 404 不存在 |
| `/archive/<name>` | PUT | body = 存档 JSON 全量 | `{}` | 400 非法名 |
| `/archive/<name>` | DELETE | — | `{}` | 400 非法名 |

- 文件名由前端 `encodeURIComponent` 编码后拼接，服务端取路径后须 **percent-decode** 再落盘
- PUT 是全量覆盖写（每轮对话后自动调用），无需合并逻辑
- DELETE 必须真删文件，否则前端下次导入会话会"复活"

### P1：PDF 提取（文献工作流）

| 端点 | 方法 | 请求 | 响应 |
|------|------|------|------|
| `/pdf` | POST | body = PDF 原始字节（Content-Type: application/octet-stream） | 见下 |

```json
{
  "pages": 19,
  "text": "全文文本（建议截断 ~120K 字符、剔除 References 章节省 token）",
  "refsStripped": 3520,
  "imgs": [{"w": 900, "h": 640, "url": "data:image/jpeg;base64,…"}],
  "timgs": []
}
```

- `text` 为空时前端会报"扫描件"并引导截图上传——stub 至少返回非空占位文本
- `imgs` / `timgs` 是图表位图（dataURL），供多模态解读与 PPT 嵌图；提取不了就返回 `[]`，前端可容忍
- 提取失败回 `400` + `{"error":"bad pdf"}`

### P2：dashboard.html 依赖

| 端点 | 方法 | 响应 |
|------|------|------|
| `/projects/list` | GET | `{"convs":[{"id":"c123","name":"📄 标题","ts":1787000000000,"docs":1}]}`，按 ts 降序 |
| `/system/status` | GET | `{"llm":true,"model":"模型名.gguf","cpu":24.1,"cores":10,"memUsed":30.3,"memTotal":32.0}` |

- `convs[].id` 取文件名首个 `-` 之前的部分；`name`/`ts` 从存档 JSON 头部正则取即可（读 512KB 前缀足够，注意容错解码防多字节字符被截断）
- `docs` = 会话附带的文献数（计 `"pages":` 出现次数即可）；`cpu` 为占总算力百分比；内存单位 GiB

### P3：已弃用（可不做）

`POST /file?name=<原名>` —— 数据文件概览，前端入口已移除，保留仅为兼容。

---

## §3 文件结构与 JSON Schema

### 目录

```
~/Qwen38/                     # macOS 默认安装目录；移植时可自定义（前端不感知，只走 HTTP）
├── chat_history/
│   ├── c1786980440039-📄_银屑病.pdf.json    # 每会话一个存档
│   ├── …
│   └── memory.json                        # 跨对话长期记忆（单独合并逻辑）
├── config.json                # 可选：modelPath / mmprojPath / contextLength
├── chat.html
└── dashboard.html
```

### 会话存档 `<id>-<安全标题>.json`

`<id>` = `c` + 毫秒时间戳；`<安全标题>` = 标题中 `\/:*?"<>|` 空白 替换为 `_` 截断 20 字符。

```json
{
  "id": "c1786980440039",
  "title": "📄 银屑病.pdf",
  "ts": 1786980459203,
  "ctxUsed": 20769,
  "messages": [
    {
      "role": "user",
      "text": "总结这篇文献",
      "imgs": ["data:image/jpeg;base64,…"],
      "docs": [{
        "name": "银屑病.pdf",
        "pages": 19,
        "text": "全文…",
        "imgs": [{"w":900,"h":640,"url":"data:image/jpeg;base64,…"}],
        "timgs": []
      }]
    },
    { "role": "assistant", "text": "回答…", "think": "思考过程…", "metrics": {"ttfb":1.2,"tps":6.4} }
  ]
}
```

- 字段只有 `id` / `messages`（数组）是前端导入时硬性校验的，其余缺失可容忍
- 标题约定：`📄 ` 前缀 = 文献对话（dashboard 图标区分）

### memory.json

```json
[{"text": "用户精通麻醉机维修", "ts": 1786881774427}]
```

### 前端合并规则（服务端无需实现，但需保证不破坏）

- 启动时 `GET /list` → 逐个 `GET /archive`，与 localStorage 版本比较：**消息更多且更新的胜出**
- localStorage 有 5MB 上限，超限时前端会剥离图片字段——**磁盘存档是全量真源**，刷新页面即恢复
- memory.json 取"数组更长者胜"

---

## §4 移植路线建议

1. 跑 `mock_server.py` + chat.html，确认闭环
2. P0 三端点接真实文件系统（半天）
3. `:8080` 直接用 [Ollama](https://ollama.com)（`OLLAMA_ORIGINS=* ollama serve`）或 llama.cpp，先不写
4. P1 `/pdf`：Windows 可用 PDFium / PyMuPDF；图表提取做不了先返回 `[]`
5. P2 接 dashboard；不想做 dashboard 可不实现
6. 通知/托盘/登录项等 app 壳层与本协议无关，按各自平台惯例做

PR 回主线前请保持 §2 §3 契约不变——前端零改动是本项目分层的意义所在。
