#!/usr/bin/env python3
"""local-llm-station 移植存根（纯标准库，Windows/Linux/macOS 通用）。

模拟 macOS QwenServer.app 的两个角色，让 chat.html / dashboard.html 在任何系统上立刻跑起来：

  :8080  对话后端 —— /health、/props、/v1/chat/completions（回显 stub，可换 Ollama 等）
  :8081  宿主服务 —— 存档 CRUD、/pdf、/projects/list、/system/status（空壳，返回正确数据结构）

存档落在脚本同目录 ./chat_history_stub/。用法：

  python3 mock_server.py            # 8080 + 8081
  PORT_CHAT=11434 PORT_HOST=18081 python3 mock_server.py   # 避开被占端口（chat.html 设置里改服务地址）

契约细节见 PORTING.md。填充真实逻辑时逐个替换 handler 里的 stub 分支即可。
"""
import json
import os
import re
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "chat_history_stub")
os.makedirs(DIR, exist_ok=True)

PORT_CHAT = int(os.environ.get("PORT_CHAT", 8080))
PORT_HOST = int(os.environ.get("PORT_HOST", 8081))

CORS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, PUT, POST, DELETE, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
}


# ---------- 工具：只读文件头抽 title/ts（与 QwenServer scanArchive 同契约） ----------
def scan_archive(path):
    try:
        with open(path, "rb") as f:
            head = f.read(512 * 1024).decode("utf-8", "ignore")
    except OSError:
        return None
    m = re.search(r'"title"\s*:\s*"((?:[^"\\]|\\.)*)"', head)
    t = re.search(r'"ts"\s*:\s*(\d{13})', head)
    if not (m and t):
        return None
    return m.group(1).replace('\\"', '"'), int(t.group(1))


class HostHandler(BaseHTTPRequestHandler):   # :8081 —— QwenServer 等价物
    def log_message(self, *a): pass

    def _send(self, code, body=b"", ctype="application/json"):
        if isinstance(body, str):
            body = body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        for k, v in CORS.items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def _name(self):
        # 前端用 encodeURIComponent 编码文件名，需 percent-decode；挡路径穿越
        from urllib.parse import unquote
        raw = self.path[len("/archive/"):]
        name = unquote(raw)
        if not name or "/" in name or "\\" in name or ".." in name:
            return None
        return name

    def do_OPTIONS(self):
        self._send(204)

    def do_GET(self):
        p = self.path.split("?")[0]
        if p == "/health":
            return self._send(200, "ok", "text/plain")
        if p == "/list":
            return self._send(200, json.dumps(sorted(
                n for n in os.listdir(DIR) if n.endswith(".json"))))
        if p.startswith("/archive/"):
            name = self._name()
            path = os.path.join(DIR, name) if name else None
            if path and os.path.isfile(path):
                with open(path, "rb") as f:
                    return self._send(200, f.read())
            return self._send(404, '{"error":"not found"}')
        if p == "/projects/list":
            convs = []
            for n in os.listdir(DIR):
                if not n.endswith(".json") or n == "memory.json":
                    continue
                got = scan_archive(os.path.join(DIR, n))
                if got:
                    convs.append({"id": n.split("-")[0].removesuffix(".json"),
                                  "name": got[0], "ts": got[1], "docs": 0})
            convs.sort(key=lambda c: -c["ts"])
            return self._send(200, json.dumps({"convs": convs}))
        if p == "/system/status":
            return self._send(200, json.dumps({
                "llm": True, "model": "stub-model", "cpu": 0.0,
                "cores": os.cpu_count() or 1, "memUsed": 0.0, "memTotal": 16.0}))
        self._send(404, '{"error":"unknown"}')

    def do_PUT(self):
        if not self.path.startswith("/archive/"):
            return self._send(404)
        name = self._name()
        if not name:
            return self._send(400, '{"error":"bad name"}')
        n = int(self.headers.get("Content-Length", 0))
        with open(os.path.join(DIR, name), "wb") as f:
            f.write(self.rfile.read(n))
        self._send(200)

    def do_DELETE(self):
        if not self.path.startswith("/archive/"):
            return self._send(404)
        name = self._name()
        path = os.path.join(DIR, name) if name else None
        if path and os.path.isfile(path):
            os.remove(path)
        self._send(200)

    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(n)
        p = self.path.split("?")[0]
        if p == "/pdf":
            # stub：替换为 pypdf / PyMuPDF 的真实提取（text 建议剔除参考文献部分）
            return self._send(200, json.dumps({
                "pages": 1,
                "text": "(stub) PDF 文本提取未实现。移植时用 pypdf/PyMuPDF 填充此字段，"
                        "chat.html 只要 text 非空即可继续。",
                "refsStripped": 0, "imgs": [], "timgs": []}))
        if p.startswith("/file"):
            from urllib.parse import unquote, parse_qs
            qs = parse_qs(self.path.split("?", 1)[1]) if "?" in self.path else {}
            name = qs.get("name", ["data.csv"])[0]
            return self._send(200, json.dumps({
                "name": unquote(name), "rows": 0, "cols": 0,
                "summary": f"《{name}》概览：(stub) 未实现"}))
        self._send(404)


class ChatHandler(BaseHTTPRequestHandler):  # :8080 —— llama-server 等价物（回显）
    def log_message(self, *a): pass

    def _send(self, code, body=b"", ctype="application/json"):
        if isinstance(body, str):
            body = body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        for k, v in CORS.items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self._send(204)

    def do_GET(self):
        p = self.path.split("?")[0]
        if p == "/health":
            return self._send(200, "ok", "text/plain")
        if p == "/props":
            return self._send(200, json.dumps({"default_generation_settings": {"n_ctx": 32768}}))
        self._send(404)

    def do_POST(self):
        if self.path.split("?")[0] != "/v1/chat/completions":
            return self._send(404)
        n = int(self.headers.get("Content-Length", 0))
        req = json.loads(self.rfile.read(n))
        # content 可能是字符串或 [{type,text},{type,image_url}] 多模态数组
        last = ""
        for m in reversed(req.get("messages", [])):
            c = m.get("content", "")
            if isinstance(c, list):
                parts = [p.get("text", "") for p in c if p.get("type") == "text"]
                last = " ".join(parts)
            else:
                last = c
            if m.get("role") == "user" and last.strip():
                break
        reply = f"(stub 回显) 你说：{last[:200]}"
        if not req.get("stream"):
            return self._send(200, json.dumps({
                "choices": [{"message": {"role": "assistant", "content": reply}}]}))
        # SSE 流式：delta.content；思考型后端可先发 delta.reasoning_content
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        for k, v in CORS.items():
            self.send_header(k, v)
        self.end_headers()
        for i in range(0, len(reply), 8):
            chunk = json.dumps({"choices": [{"delta": {"content": reply[i:i + 8]}}]})
            self.wfile.write(f"data: {chunk}\n\n".encode("utf-8"))
        self.wfile.write(b"data: [DONE]\n\n")


if __name__ == "__main__":
    threading.Thread(target=lambda: ThreadingHTTPServer(
        ("127.0.0.1", PORT_HOST), HostHandler).serve_forever(), daemon=True).start()
    print(f"[stub] 宿主服务 :{PORT_HOST}（存档目录 {DIR}）")
    print(f"[stub] 对话回显 :{PORT_CHAT} —— 浏览器打开 chat.html 即可测试")
    ThreadingHTTPServer(("127.0.0.1", PORT_CHAT), ChatHandler).serve_forever()
