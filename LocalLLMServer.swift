import SwiftUI
import Network
import PDFKit
import Carbon.HIToolbox
import CryptoKit
import CoreGraphics
import Vision
import Compression
import ServiceManagement
import UserNotifications

// 微型存档服务：读写 ~/Qwen38/chat_history，供 chat.html 调用（含 CORS）
final class ArchiveServer {
    static let shared = ArchiveServer()
    private var listener: NWListener?
    let dir = URL(fileURLWithPath: NSHomeDirectory() + "/Qwen38/chat_history")

    func start() {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // 只绑 loopback
        let params = NWParameters.tcp
        params.requiredLocalEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host.ipv4(.loopback),
                                                           port: NWEndpoint.Port(rawValue: 8081)!)
        guard let l = try? NWListener(using: params) else { return }
        l.newConnectionHandler = { conn in
            conn.start(queue: .global())
            self.read(conn, Data())
        }
        l.stateUpdateHandler = { state in
            print("[archive] listener: \(state)")
        }
        l.start(queue: .global())
        listener = l
    }

    private func read(_ conn: NWConnection, _ buf: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024 * 1024) { content, _, isComplete, _ in
            let data = buf + (content ?? Data())
            if let req = Self.parse(data) { self.respond(conn, req) }
            else if isComplete || data.count > 128 * 1024 * 1024 { conn.cancel() }   // 累积上限 128MB
            else { self.read(conn, data) }
        }
    }

    struct Req { let method: String; let path: String; let body: Data }

    static func parse(_ data: Data) -> Req? {
        guard let headEnd = data.range(of: Data("\r\n\r\n".utf8)),
              let head = String(data: data[..<headEnd.lowerBound], encoding: .utf8) else { return nil }
        let lines = head.components(separatedBy: "\r\n")
        let reqLine = lines[0].components(separatedBy: " ")
        guard reqLine.count >= 2 else { return nil }
        var length = 0
        for l in lines {
            let p = l.lowercased().components(separatedBy: ":")
            if p.count == 2, p[0].trimmingCharacters(in: .whitespaces) == "content-length",
               let n = Int(p[1].trimmingCharacters(in: .whitespaces)), n >= 0, n <= 64 * 1024 * 1024 { length = n }
        }
        let body = data[headEnd.upperBound...]
        guard body.count >= length else { return nil }
        return Req(method: reqLine[0], path: reqLine[1].removingPercentEncoding ?? reqLine[1],
                   body: body.prefix(length))
    }

    private func respond(_ conn: NWConnection, _ req: Req) {
        var status = "200 OK"
        var body = Data("{}".utf8)
        var respType = "application/json"
        let path = req.path

        switch (req.method, path) {
        case ("OPTIONS", _):
            status = "204 No Content"; body = Data()
        case ("GET", "/health"):
            body = Data("\"ok\"".utf8)
        case ("GET", "/list"):
            let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))?
                .filter { $0.pathExtension == "json" }.map { $0.lastPathComponent } ?? []
            body = (try? JSONEncoder().encode(files)) ?? Data("[]".utf8)
        case ("GET", let p) where p.hasPrefix("/archive/"):
            let name = String(p.dropFirst(9))
            if !name.contains(".."), !name.contains("/"), let d = try? Data(contentsOf: dir.appendingPathComponent(name)) {
                body = d
            } else { status = "404 Not Found" }
        case ("PUT", let p) where p.hasPrefix("/archive/"):
            let name = String(p.dropFirst(9))
            if name.contains("..") || name.contains("/") || name.isEmpty { status = "400 Bad Request" }
            else { Self.safeWrite(req.body, to: dir.appendingPathComponent(name)) }
        case ("DELETE", let p) where p.hasPrefix("/archive/"):
            let name = String(p.dropFirst(9))
            if name.contains("..") || name.contains("/") || name.isEmpty { status = "400 Bad Request" }
            else { try? FileManager.default.removeItem(at: dir.appendingPathComponent(name)) }
        case ("GET", "/projects/list"):
            // 项目 = 每个存档会话；只读文件头 512KB 抠 id/title/ts/资料数
            var list: [[String: Any]] = []
            let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            for f in files where f.pathExtension == "json" && f.lastPathComponent != "memory.json" {
                guard let (title, ts, docs) = Self.scanArchive(f) else { continue }
                let id = String(f.deletingPathExtension().lastPathComponent.prefix { $0 != "-" })
                // 项目笔记/知识卡片：<id>.notes.md、<id>-cards.json（chat.html 项目面板写入）
                let fm2 = FileManager.default
                let hasNotes = fm2.fileExists(atPath: dir.appendingPathComponent(id + ".notes.md").path)
                var cards = 0, tags: [String] = []
                if let cd = try? Data(contentsOf: dir.appendingPathComponent(id + "-cards.json")),
                   let cs = String(data: cd, encoding: .utf8) {
                    cards = cs.components(separatedBy: "\"concept\"").count - 1
                    // 概念标签（取前 3 个去重）
                    if let re = try? NSRegularExpression(pattern: #""concept"\s*:\s*"([^"]{1,30})""#) {
                        let ns = cs as NSString
                        for m in re.matches(in: cs, range: NSRange(location: 0, length: ns.length)) where tags.count < 3 {
                            let t = ns.substring(with: m.range(at: 1))
                            if !tags.contains(t) { tags.append(t) }
                        }
                    }
                }
                // 项目文件夹（图表位图 + 数据表 CSV）落盘统计，卡片可见
                var tables = 0, figs = 0
                if let pf = try? FileManager.default.contentsOfDirectory(
                    at: dir.appendingPathComponent(f.deletingPathExtension().lastPathComponent),
                    includingPropertiesForKeys: nil) {
                    tables = pf.filter { $0.pathExtension == "csv" }.count
                    figs = pf.filter { ["jpg", "jpeg", "png"].contains($0.pathExtension.lowercased()) }.count
                }
                list.append(["id": id, "name": title, "ts": ts, "docs": docs, "notes": hasNotes,
                             "cards": cards, "tags": tags, "file": f.lastPathComponent,
                             "tables": tables, "figs": figs])
            }
            list.sort { ($0["ts"] as! Double) > ($1["ts"] as! Double) }
            body = (try? JSONSerialization.data(withJSONObject: ["convs": list])) ?? Data("{\"convs\":[]}".utf8)
        case ("GET", "/system/status"):
            body = (try? JSONSerialization.data(withJSONObject: SystemStatus.snapshot())) ?? Data("{}".utf8)
        // 项目文件夹（chat_history/<会话>/）：图表位图 + 数据表 CSV 落盘
        case ("PUT", let p) where p.hasPrefix("/projfile/"):
            let parts = String(p.dropFirst(10)).split(separator: "/", maxSplits: 1).map(String.init)
            let conv = parts.first ?? "", name = parts.count > 1 ? parts[1] : ""
            if conv.contains("..") || name.contains("..") || name.contains("/") || conv.isEmpty || name.isEmpty {
                status = "400 Bad Request"
            } else {
                let d = dir.appendingPathComponent(conv, isDirectory: true)
                try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
                Self.safeWrite(req.body, to: d.appendingPathComponent(name))
            }
        case ("GET", let p) where p.hasPrefix("/projfile/"):
            let parts = String(p.dropFirst(10)).split(separator: "/", maxSplits: 1).map(String.init)
            if parts.count == 2, !parts[0].contains(".."), !parts[1].contains(".."), !parts[1].contains("/"),
               let d = try? Data(contentsOf: dir.appendingPathComponent(parts[0]).appendingPathComponent(parts[1])) {
                body = d
            } else { status = "404 Not Found" }
        // 项目重命名：存档文件名 + 内部 title + 项目文件夹三处同步改
        case ("POST", "/rename"):
            if let j = (try? JSONSerialization.jsonObject(with: req.body, options: [])) as? [String: String],
               let from = j["from"], let to = j["to"],
               !from.isEmpty, !to.isEmpty,
               !from.contains(".."), !from.contains("/"), !to.contains(".."), !to.contains("/") {
                let fm = FileManager.default
                let fromURL = dir.appendingPathComponent(from), toURL = dir.appendingPathComponent(to)
                var any = false, failed = false
                if fm.fileExists(atPath: fromURL.path) {
                    if let data = try? Data(contentsOf: fromURL),
                       var obj = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] {
                        if let t = j["title"] { obj["title"] = t }
                        if let nd = try? JSONSerialization.data(withJSONObject: obj) {
                            if (try? nd.write(to: toURL)) != nil {
                                try? fm.removeItem(at: fromURL)
                                any = true
                            } else { failed = true }
                        }
                    }
                }
                // 项目文件夹（章节 sec-*.md / versions.json / editor.json 所在）
                if from.hasSuffix(".json"), to.hasSuffix(".json") {
                    let fdir = dir.appendingPathComponent(String(from.dropLast(5)), isDirectory: true)
                    let tdir = dir.appendingPathComponent(String(to.dropLast(5)), isDirectory: true)
                    if fm.fileExists(atPath: fdir.path) {
                        // 目标目录重名时先挪作备份再 move，move 失败回滚
                        let bak = dir.appendingPathComponent(String(to.dropLast(5)) + ".rename-bak", isDirectory: true)
                        try? fm.removeItem(at: bak)
                        var hadTarget = false
                        if fm.fileExists(atPath: tdir.path), (try? fm.moveItem(at: tdir, to: bak)) != nil { hadTarget = true }
                        if (try? fm.moveItem(at: fdir, to: tdir)) != nil {
                            any = true
                            if hadTarget { try? fm.removeItem(at: bak) }
                        } else {
                            failed = true
                            if hadTarget { try? fm.moveItem(at: bak, to: tdir) }
                        }
                    }
                }
                if failed { status = "500 Internal Server Error" }
                else if !any { status = "404 Not Found" }
            } else { status = "400 Bad Request" }
        // 文档导出：markdown → docx（宿主机 pandoc；输入输出都不过网络）
        // 请求 JSON {md, refs(CSL-JSON), csl(样式文件名，可选)}：
        // refs 非空时 --citeproc 按所选 CSL 样式（默认 AMA brackets）渲染 [@key] 引文
        // 版式模板按正文语言自动选：中文→zh（宋体/黑体/1.5倍行距），否则 en
        case ("POST", "/export-docx"):
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("export-\(UUID().uuidString)")
            defer { for ext in ["md", "json", "docx"] { try? FileManager.default.removeItem(at: tmp.appendingPathExtension(ext)) } }
            do {
                var md = req.body
                var refs: Data? = nil
                var cslName = "american-medical-association-brackets"
                if let j = (try? JSONSerialization.jsonObject(with: req.body, options: [])) as? [String: Any],
                   let m = j["md"] as? String {
                    md = Data(m.utf8)
                    if let r = j["refs"] { refs = try? JSONSerialization.data(withJSONObject: r) }
                    if let c = j["csl"] as? String,
                       !c.isEmpty, !c.contains("/"), !c.contains("..") {   // 限定 csl/ 目录内
                        cslName = c.hasSuffix(".csl") ? String(c.dropLast(4)) : c
                    }
                }
                try md.write(to: tmp.appendingPathExtension("md"))
                let out = tmp.appendingPathExtension("docx")
                let s = String(data: md.prefix(50000), encoding: .utf8) ?? ""
                let cjk = s.unicodeScalars.filter { $0.value >= 0x4E00 && $0.value <= 0x9FFF }.count
                let fm = FileManager.default
                let zh = cjk * 10 > s.count
                let tplName = zh ? "export-template-zh.docx" : "export-template-en.docx"
                let tpl = dir.deletingLastPathComponent().appendingPathComponent(tplName)
                var args = [tmp.appendingPathExtension("md").path, "-o", out.path,
                            "--resource-path", NSHomeDirectory() + "/Qwen38"]
                if fm.fileExists(atPath: tpl.path) { args += ["--reference-doc", tpl.path] }
                // citeproc 引文：样式文件限定 csl/ 目录，缺省回退 AMA
                let cslDir = dir.deletingLastPathComponent().appendingPathComponent("csl", isDirectory: true)
                var csl = cslDir.appendingPathComponent(cslName + ".csl")
                if !fm.fileExists(atPath: csl.path) {
                    csl = cslDir.appendingPathComponent("american-medical-association-brackets.csl")
                }
                if let refs = refs, refs.count > 4, fm.fileExists(atPath: csl.path) {
                    let refPath = tmp.appendingPathExtension("json")
                    try refs.write(to: refPath)
                    // 参考文献节标题随正文语言（与章节一级标题同级，citeproc 自动排在文末）
                    args += ["--citeproc", "--bibliography", refPath.path, "--csl", csl.path,
                             "-M", "reference-section-title=" + (zh ? "参考文献" : "References")]
                }
                // pandoc 路径按常见安装位置探测，兼容 Intel Mac（/usr/local）与自定义 brew 前缀
                guard let pandoc = ["/opt/homebrew/bin/pandoc", "/usr/local/bin/pandoc", "/usr/bin/pandoc"]
                    .first(where: { fm.fileExists(atPath: $0) }) else {
                    throw NSError(domain: "pandoc", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "未找到 pandoc（已探测 /opt/homebrew、/usr/local、/usr/bin）"])
                }
                let p = Process()
                p.executableURL = URL(fileURLWithPath: pandoc)
                p.arguments = args
                p.standardError = Pipe()
                try p.run(); p.waitUntilExit()
                guard p.terminationStatus == 0 else { throw NSError(domain: "pandoc", code: Int(p.terminationStatus)) }
                body = try Data(contentsOf: out)
                respType = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
            } catch {
                status = "500 Internal Server Error"
                // 错误消息走 JSONSerialization
                body = (try? JSONSerialization.data(withJSONObject: ["error": error.localizedDescription])) ?? Data("{}".utf8)
            }
        // 静态资源（限 ~/Qwen38/katex/ 前缀）
        case ("GET", let p) where p.hasPrefix("/static/katex/"):
            let name = String(p.dropFirst(14))
            if !name.isEmpty, !name.contains(".."), !name.hasPrefix("/"),
               let d = try? Data(contentsOf: dir.deletingLastPathComponent()
                   .appendingPathComponent("katex").appendingPathComponent(name)) {
                body = d
                respType = name.hasSuffix(".css") ? "text/css"
                    : name.hasSuffix(".woff2") ? "font/woff2" : "application/octet-stream"
            } else { status = "404 Not Found" }
        case ("GET", "/version"):
            // git SHA 版本标识
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            p.arguments = ["-C", NSHomeDirectory() + "/Qwen38", "log", "-1", "--format=%h|%cs"]
            let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
            if (try? p.run()) != nil { p.waitUntilExit() }
            let s = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let parts = s.split(separator: "|").map(String.init)
            let obj: [String: Any] = parts.count == 2 ? ["sha": parts[0], "date": parts[1]] : ["sha": NSNull()]
            body = (try? JSONSerialization.data(withJSONObject: obj)) ?? Data("{\"sha\":null}".utf8)
        case ("GET", let p) where p.hasPrefix("/projlist/"):
            let conv = String(p.dropFirst(10))
            let files = (try? FileManager.default.contentsOfDirectory(
                at: dir.appendingPathComponent(conv), includingPropertiesForKeys: nil))?
                // 跳过滚动备份（name~）与原子写残片（name.tmp）
                .filter { !$0.hasDirectoryPath && !$0.lastPathComponent.hasSuffix("~") && !$0.lastPathComponent.hasSuffix(".tmp") }
                .map { $0.lastPathComponent } ?? []
            body = (try? JSONEncoder().encode(files)) ?? Data("[]".utf8)
        // 可用引文样式清单（csl/ 目录，导出 Word 的样式选择弹窗数据源）
        case ("GET", "/csllist"):
            let cslDir = dir.deletingLastPathComponent().appendingPathComponent("csl", isDirectory: true)
            let styles = (try? FileManager.default.contentsOfDirectory(at: cslDir, includingPropertiesForKeys: nil))?
                .filter { $0.pathExtension == "csl" }.map { $0.deletingPathExtension().lastPathComponent }.sorted() ?? []
            body = (try? JSONEncoder().encode(styles)) ?? Data("[]".utf8)
        case ("POST", "/pdf"):
            // PDF → 全文文本（PDFKit）；截断 120K 字符、剔除参考文献；提取内嵌图表位图
            if let doc = PDFDocument(data: req.body), doc.pageCount > 0 {
                var text = ""
                var scanPages = 0   // 文字层缺失的页（扫描版 PDF）
                for i in 0..<doc.pageCount {
                    let pt = doc.page(at: i)?.string ?? ""
                    if pt.count < 100 { scanPages += 1 }
                    text += pt + "\n\n"
                    if text.count > 120_000 { text = String(text.prefix(120_000)) + "\n…（过长已截断）"; break }
                }
                var refsStripped = 0
                if let re = try? NSRegularExpression(pattern: #"(?im)^[ \t]{0,6}(references|bibliography|literature cited|参考文献)[ \t]*:?[ \t]*$"#) {
                    let ns = text as NSString
                    let matches = re.matches(in: text, range: NSRange(location: 0, length: ns.length))
                    // 只认后 60% 出现的标题行
                    if let m = matches.first(where: { $0.range.location >= ns.length * 6 / 10 }) {
                        refsStripped = ns.length - m.range.location
                        text = ns.substring(to: m.range.location) + "\n\n[参考文献部分已省略]\n"
                    }
                }
                let jpegImgs = PDFImages.extract(req.body, limit: 20)
                let flateImgs = PDFImages.extractFlate(req.body, limit: 20 - jpegImgs.count)
                var imgs = jpegImgs + flateImgs
                var timgs: [[String: Any]] = []
                if scanPages >= 3 {
                    // 扫描版 PDF：整页 Vision OCR；长文页并入全文、低密度页按图表收
                    let (ocrTxt, scanFigs) = PDFImages.scannedFallback(doc)
                    text += "\n\n" + ocrTxt
                    if text.count > 120_000 { text = String(text.prefix(120_000)) + "\n…（过长已截断）" }
                    imgs += scanFigs
                } else {
                    if imgs.count < 4 { imgs += PDFImages.vectorFigures(doc, limit: 20 - imgs.count) }
                    timgs = PDFImages.vectorFigures(doc, limit: 8, tables: true)
                }
                // 图表 OCR：图内文字回填（每组最多 12 张，并行）
                func withOcr(_ arr: [[String: Any]]) -> [[String: Any]] {
                    var out = arr
                    let lock = NSLock()
                    DispatchQueue.concurrentPerform(iterations: min(arr.count, 12)) { idx in
                        // 已带 ocr 的（scannedFallback/figureRegions 已回填）不重跑不覆盖
                        guard arr[idx]["ocr"] == nil,
                              let t = (arr[idx]["url"] as? String).flatMap({ PDFImages.ocrText($0) }) else { return }
                        var i = arr[idx]; i["ocr"] = t
                        lock.lock(); out[idx] = i; lock.unlock()
                    }
                    return out
                }
                imgs = withOcr(imgs)
                let timgs2 = withOcr(timgs)
                let obj: [String: Any] = ["pages": doc.pageCount, "text": text, "refsStripped": refsStripped,
                                           "imgs": imgs, "timgs": timgs2]
                body = (try? JSONSerialization.data(withJSONObject: obj)) ?? Data("{}".utf8)
            } else { status = "400 Bad Request"; body = Data("{\"error\":\"bad pdf\"}".utf8) }
        case ("POST", let p) where p.hasPrefix("/file"):
            // ?name= 传原始文件名（展示用）；摘要器只回概况+预览，不回全文
            let q = p.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
            let name = q.count > 1
                ? (String(q[1]).removingPercentEncoding ?? String(q[1]))
                : "data.csv"
            let obj = FileSummarizer.summarize(req.body, name: name)
            if obj["error"] != nil { status = "400 Bad Request" }
            body = (try? JSONSerialization.data(withJSONObject: obj)) ?? Data("{}".utf8)
        default:
            status = "404 Not Found"
        }

        let head = "HTTP/1.1 \(status)\r\nContent-Type: \(respType)\r\nContent-Length: \(body.count)\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: GET, PUT, POST, DELETE, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type\r\nConnection: close\r\n\r\n"
        conn.send(content: Data(head.utf8) + body, completion: .contentProcessed { _ in conn.cancel() })
    }
}

// 只读文件头 512KB 正则抠 title/ts/资料数；资料数按 "pages": 计数
extension ArchiveServer {
    // 原子写 + 滚动备份（name~ / .tmp → rename）
    static func safeWrite(_ data: Data, to url: URL) {
        let fm = FileManager.default
        let bak = url.deletingLastPathComponent().appendingPathComponent(url.lastPathComponent + "~")
        if fm.fileExists(atPath: url.path) {
            try? fm.removeItem(at: bak)
            try? fm.copyItem(at: url, to: bak)
        }
        let tmp = url.appendingPathExtension("tmp")
        guard (try? data.write(to: tmp)) != nil else { return }
        if (try? fm.replaceItemAt(url, withItemAt: tmp)) == nil {
            // replaceItemAt 失败兜底走 move
            try? fm.removeItem(at: url)
            try? fm.moveItem(at: tmp, to: url)
        }
    }

    static func scanArchive(_ url: URL) -> (String, Double, Int)? {
        guard let h = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? h.close() }
        // 容错解码（512KB 截断点可能切开多字节字符）
        let s = String(decoding: (try? h.read(upToCount: 512 * 1024)) ?? Data(), as: UTF8.self)
        var title: String?
        if let re = try? NSRegularExpression(pattern: #""title"\s*:\s*"((?:[^"\\]|\\.)*)""#),
           let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
           let r = Range(m.range(at: 1), in: s) {
            title = String(s[r]).replacingOccurrences(of: "\\\"", with: "\"")
        }
        var ts = 0.0
        if let re = try? NSRegularExpression(pattern: #""ts"\s*:\s*(\d{13})"#),
           let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
           let r = Range(m.range(at: 1), in: s) { ts = Double(s[r]) ?? 0 }
        var docs = 0
        if let re = try? NSRegularExpression(pattern: #""pages":"#) {
            docs = re.numberOfMatches(in: s, range: NSRange(s.startIndex..., in: s))
        }
        guard let t = title, ts > 0 else { return nil }
        return (t, ts, docs)
    }
}

// ---------- 系统状态：ollama 探活 + CPU/内存（dashboard.html 全局状态区） ----------
enum SystemStatus {
    static func snapshot() -> [String: Any] {
        let model = Config.ollamaModel
        // used = 物理总量 − (free+inactive+speculative)
        var usedGB = 0.0
        var vm = vm_statistics64_data_t()
        var cnt = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var kr: kern_return_t = KERN_FAILURE
        withUnsafeMutablePointer(to: &vm) { vp in
            vp.withMemoryRebound(to: integer_t.self, capacity: Int(cnt)) { ip in
                kr = host_statistics64(mach_host_self(), HOST_VM_INFO64, ip, &cnt)
            }
        }
        let gib = 1_073_741_824.0   // GiB 口径，与 macOS 系统信息一致
        if kr == KERN_SUCCESS {
            let free = (Double(vm.free_count) + Double(vm.inactive_count) + Double(vm.speculative_count)) * Double(vm_page_size)
            usedGB = max(Double(ProcessInfo.processInfo.physicalMemory) - free, 0) / gib
        }
        return ["llm": llmUp(), "model": model, "cpu": cpuPct(),
                "cores": ProcessInfo.processInfo.activeProcessorCount,
                "memUsed": (usedGB * 10).rounded() / 10,
                "memTotal": (Double(ProcessInfo.processInfo.physicalMemory) / gib * 10).rounded() / 10]
    }

    private static func llmUp() -> Bool {
        let sem = DispatchSemaphore(value: 0)
        var up = false
        var req = URLRequest(url: URL(string: "http://127.0.0.1:11434/api/version")!)
        req.timeoutInterval = 1.5
        URLSession.shared.dataTask(with: req) { _, resp, _ in
            up = (resp as? HTTPURLResponse)?.statusCode == 200
            sem.signal()
        }.resume()
        sem.wait()
        return up
    }

    private static func cpuPct() -> Double {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/ps")
        p.arguments = ["-A", "-o", "%cpu="]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
        guard (try? p.run()) != nil else { return 0 }
        p.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (out.split(separator: "\n").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) ?? 0 }
            .reduce(0, +) * 10).rounded() / 10
    }
}

// ---------- PDF 图表提取：定位 /DCTDecode 图像对象（供多模态解读 + PPT 结果页插图） ----------
enum PDFImages {
    static func extract(_ data: Data, limit: Int = 6) -> [[String: Any]] {
        let b = [UInt8](data)
        var out: [[String: Any]] = [], seen = Set<String>(), pos = 0
        let dct = Array("/DCTDecode".utf8), streamKw = Array("stream".utf8), endKw = Array("endstream".utf8)
        while out.count < limit, let i = find(b, dct, pos) {
            pos = i + dct.count
            guard let dictStart = findRev(b, [0x3C, 0x3C], i),               // "<<"
                  let sIdx = find(b, streamKw, i),
                  let eIdx = find(b, endKw, sIdx) else { continue }
            // stream 关键字后紧跟 \r\n / \n
            var js = sIdx + streamKw.count
            if js < b.count, b[js] == 0x0D { js += 1 }
            if js < b.count, b[js] == 0x0A { js += 1 }
            var jpg = Array(b[js..<eIdx])
            while let last = jpg.last, last == 0x0A || last == 0x0D { jpg.removeLast() }
            // "endstream" ASCII 偶现于压缩数据内：以最后一个 FFD9（JPEG EOI）截断
            if let e = findRev(jpg, [0xFF, 0xD9], jpg.count) { jpg = Array(jpg.prefix(e + 2)) }
            guard jpg.count > 5_000, jpg[0] == 0xFF, jpg[1] == 0xD8 else { continue }   // JPEG 魔数 + 滤掉 logo
            let dict = Array(b[dictStart..<i])
            let w = intAfter(dict, "/Width") ?? 0, h = intAfter(dict, "/Height") ?? 0
            guard find(dict, Array("/Image".utf8), 0) != nil,
                  w >= 120, h >= 120, max(w, h) / max(min(w, h), 1) <= 8 else { continue }   // 滤小图标/装饰条
            let key = SHA256.hash(data: Data(jpg)).compactMap { String(format: "%02x", $0) }.joined()
            guard !seen.contains(key), let small = shrink(Data(jpg)) else { continue }
            seen.insert(key)
            out.append(["w": w, "h": h, "url": "data:image/jpeg;base64," + small.base64EncodedString()])
        }
        return out
    }

    // FlateDecode / JPXDecode 内嵌位图（JACC 系整刊用 Flate 存位图，JPEG 字节扫描天然抓不到）
    static func extractFlate(_ data: Data, limit: Int) -> [[String: Any]] {
        guard limit > 0 else { return [] }
        let b = [UInt8](data)
        var out: [[String: Any]] = [], seen = Set<String>(), pos = 0
        let imgKw = Array("/Image".utf8), dct = Array("/DCTDecode".utf8), flateKw = Array("/FlateDecode".utf8), jpxKw = Array("/JPXDecode".utf8)
        while out.count < limit, let i = find(b, imgKw, pos) {
            pos = i + imgKw.count
            guard let dictStart = findRev(b, [0x3C, 0x3C], i),
                  let dictEnd = find(b, [0x3E, 0x3E], i),
                  let sIdx = find(b, Array("stream".utf8), i),
                  let eIdx = find(b, Array("endstream".utf8), sIdx) else { continue }
            let dict = Array(b[dictStart..<dictEnd])
            let isFlate = find(dict, flateKw, 0) != nil, isJpx = find(dict, jpxKw, 0) != nil
            guard find(dict, Array("/Subtype".utf8), 0) != nil, find(dict, dct, 0) == nil,
                  isFlate || isJpx,
                  let w = intAfter(dict, "/Width"), let h = intAfter(dict, "/Height"),
                  w >= 120, h >= 120, max(w, h) / max(min(w, h), 1) <= 8 else { continue }   // 滤小图标/装饰条（与 DCT 同门槛）
            var js = sIdx + 6
            if js < b.count, b[js] == 0x0D { js += 1 }
            if js < b.count, b[js] == 0x0A { js += 1 }
            var raw = Array(b[js..<eIdx])
            while let last = raw.last, last == 0x0A || last == 0x0D { raw.removeLast() }
            guard raw.count > 2_000,
                  let cg = imageFromStream(Data(raw), w: w, h: h, bpc: intAfter(dict, "/BitsPerComponent") ?? 8, flate: isFlate, dict: dict, file: b) else { continue }
            let key = SHA256.hash(data: Data(raw)).compactMap { String(format: "%02x", $0) }.joined()
            guard !seen.contains(key), let jpg = jpegData(cg), let small = shrink(jpg) else { continue }
            seen.insert(key)
            out.append(["w": w, "h": h, "url": "data:image/jpeg;base64," + small.base64EncodedString()])
        }
        return out
    }
    // 压缩流 → CGImage：JPX 交给 ImageIO（macOS 原生 jp2）；Flate 解压（含 PNG predictor 反滤波）后按数据长度反推通道数构位图
    private static func imageFromStream(_ raw: Data, w: Int, h: Int, bpc: Int, flate: Bool, dict: [UInt8], file b: [UInt8]) -> CGImage? {
        if !flate {
            guard let src = CGImageSourceCreateWithData(raw as CFData, nil),
                  let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
            return img
        }
        guard let inf = inflateZlib(raw, expect: max(1, w * h * max(bpc, 1) / 8) * 5) else { return nil }
        let unit = max(1, w * h * max(bpc, 1) / 8)
        var px: [UInt8]
        // /DecodeParms 预测器：PNG（≥10，行首 filter 字节）或 TIFF（=2，水平差分无行首字节）
        if let dp = decodeParms(b, dict), dp.bpc == 8, dp.cols > 0, dp.colors > 0, dp.pred >= 10 {
            let rowLen = dp.cols * dp.colors
            guard inf.count % (rowLen + 1) == 0, inf.count / (rowLen + 1) == h,
                  let unf = pngUnfilter([UInt8](inf), colors: dp.colors, cols: dp.cols, rows: h) else { return nil }
            px = unf
        } else if let dp = decodeParms(b, dict), dp.bpc == 8, dp.cols > 0, dp.colors > 0, dp.pred == 2 {
            px = [UInt8](inf)
            for r in 0..<h {   // TIFF 水平差分：行内 sample[i] += sample[i-colors]
                let row = r * dp.cols * dp.colors
                for i in dp.colors..<(dp.cols * dp.colors) { px[row + i] = px[row + i] &+ px[row + i - dp.colors] }
            }
        } else {
            px = [UInt8](inf)
        }
        let k = px.count / unit
        guard px.count == unit * k, k == 1 || k == 3 || k == 4 else { return nil }   // 1=灰度 3=RGB 4=CMYK
        if k == 1, find(dict, Array("/Decode".utf8), 0) != nil, find(dict, Array("1 0".utf8), 0) != nil {
            for i in 0..<px.count { px[i] = 255 - px[i] }   // 灰度反相（扫描位图常见 Decode [1 0]）
        }
        if k == 4 {   // CMYK：先构 CMYK 位图再画到白底 RGB
            let img = px.withUnsafeMutableBytes { p in
                CGContext(data: p.baseAddress, width: w, height: h, bitsPerComponent: bpc, bytesPerRow: w * 4,
                          space: CGColorSpace(name: CGColorSpace.genericCMYK) ?? CGColorSpaceCreateDeviceCMYK(),
                          bitmapInfo: CGImageAlphaInfo.none.rawValue)?.makeImage()
            }
            guard let img, let rgb = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            rgb.setFillColor(CGColor(gray: 1, alpha: 1)); rgb.fill(CGRect(x: 0, y: 0, width: w, height: h))
            rgb.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
            return rgb.makeImage()
        }
        if k == 3 {   // Quartz 不支持 24bpp：RGB 展开为 RGBX（noneSkipLast）
            var q = [UInt8](repeating: 255, count: w * h * 4)
            for i in 0..<w * h { q[i * 4] = px[i * 3]; q[i * 4 + 1] = px[i * 3 + 1]; q[i * 4 + 2] = px[i * 3 + 2] }
            px = q
            return px.withUnsafeMutableBytes { p in
                CGContext(data: p.baseAddress, width: w, height: h, bitsPerComponent: bpc, bytesPerRow: w * 4,
                          space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)?.makeImage()
            }
        }
        return px.withUnsafeMutableBytes { p in
            CGContext(data: p.baseAddress, width: w, height: h, bitsPerComponent: bpc, bytesPerRow: w * k,
                      space: k == 1 ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceCMYK(),
                      bitmapInfo: CGImageAlphaInfo.none.rawValue)?.makeImage()
        }
    }
    // 解析 /DecodeParms（间接引用 "N 0 R" 或内联字典）里的 PNG predictor 参数
    private static func decodeParms(_ b: [UInt8], _ dict: [UInt8]) -> (pred: Int, colors: Int, cols: Int, bpc: Int)? {
        guard find(dict, Array("/DecodeParms".utf8), 0) != nil else { return nil }
        var pd = dict
        if let n = intAfter(dict, "/DecodeParms"), n > 0 {
            guard let oi = find(b, Array("\(n) 0 obj".utf8), 0),
                  let oe = find(b, [0x3E, 0x3E], oi) else { return nil }
            pd = Array(b[oi..<oe])
        }
        return (intAfter(pd, "/Predictor") ?? 0, intAfter(pd, "/Colors") ?? 1,
                intAfter(pd, "/Columns") ?? 0, intAfter(pd, "/BitsPerComponent") ?? 8)
    }
    // PNG 反滤波（行首 filter 字节 0-4：None/Sub/Up/Average/Paeth），bpc=8
    private static func pngUnfilter(_ d: [UInt8], colors: Int, cols: Int, rows: Int) -> [UInt8]? {
        let bpp = colors, len = cols * colors
        guard len > 0 else { return nil }
        var out = [UInt8](repeating: 0, count: len * rows)
        var p = 0
        for r in 0..<rows {
            guard p + 1 + len <= d.count else { return nil }
            let tag = d[p]; p += 1
            let orow = r * len, prev = r > 0 ? orow - len : -1
            for i in 0..<len {
                let x = Int(d[p + i])
                let a = i >= bpp ? Int(out[orow + i - bpp]) : 0
                let bb = prev >= 0 ? Int(out[prev + i]) : 0
                let c = (i >= bpp && prev >= 0) ? Int(out[prev + i - bpp]) : 0
                let v: Int
                switch tag {
                case 0: v = x
                case 1: v = x + a
                case 2: v = x + bb
                case 3: v = x + (a + bb) / 2
                case 4:
                    let pa = abs(bb - c), pb = abs(a - c), pc = abs(a + bb - 2 * c)
                    v = x + ((pa <= pb && pa <= pc) ? a : (pb <= pc ? bb : c))
                default: return nil
                }
                out[orow + i] = UInt8(v & 0xFF)
            }
            p += len
        }
        return out
    }
    // zlib 解压（PDF FlateDecode 带 2 字节头；COMPRESSION_ZLIB 是裸 deflate，先去头）
    private static func inflateZlib(_ d: Data, expect: Int) -> Data? {
        guard d.count > 6, d[d.startIndex] == 0x78 else { return nil }
        let src = [UInt8](d.dropFirst(2))
        var cap = max(expect, 1 << 16)
        while cap <= 1 << 28 {
            var dst = [UInt8](repeating: 0, count: cap)
            let n = src.withUnsafeBufferPointer { sp in
                dst.withUnsafeMutableBufferPointer { dp in
                    compression_decode_buffer(dp.baseAddress!, dp.count, sp.baseAddress!, sp.count, nil, COMPRESSION_ZLIB)
                }
            }
            if n > 0, n < cap { return Data(dst.prefix(n)) }
            if n == cap { cap *= 2; continue }   // 输出装满 = 可能截断，翻倍重试
            return nil
        }
        return nil
    }
    // Vision OCR：图内嵌文字（轴标签/CONSORT 框图文字等）回填给模型
    static func ocrText(_ dataURL: String, maxLen: Int = 1500) -> String? {
        guard let b64 = Data(base64Encoded: String(dataURL.dropFirst("data:image/jpeg;base64,".count))),
              let src = CGImageSourceCreateWithData(b64 as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .fast   // 印刷体轴标签/图例够用，比 accurate 快数倍
        req.recognitionLanguages = ["en-US", "zh-Hans"]
        try? VNImageRequestHandler(cgImage: cg).perform([req])
        let s = (req.results ?? []).compactMap { $0.topCandidates(1).first }
            .filter { $0.confidence > 0.5 }.map { $0.string }
            .joined(separator: " | ")
        return s.count >= 8 ? String(s.prefix(maxLen)) : nil   // 几乎无文字的图（纯曲线）不挂字段
    }

    // 扫描版 PDF 兜底（≥3 页文字层缺失时启用）：整页渲染 + Vision OCR
    // 按 OCR 字数分类：>800 字 = 正文页（并入全文，并探测图文混排的图表区域）；20-800 字 = 真图表页
    static func scannedFallback(_ doc: PDFDocument) -> (String, [[String: Any]]) {
        var txt: [String] = [], figs: [[String: Any]] = []
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i), (page.string ?? "").count < 100 else { continue }
            guard let cg = renderCG(page) else { continue }
            let obs = ocrBoxes(cg)
            let full = obs.map { $0.text }.joined(separator: " | ")
            guard full.count >= 8 else { continue }   // 空白/装饰页跳过
            if full.count > 800 {
                txt.append("[第 \(i + 1) 页 · 扫描 OCR]\n" + String(full.prefix(6000)))
                figs += figureRegions(cg, obs, pageSize: page.bounds(for: .mediaBox).size)
            } else if full.count >= 20 {
                guard let jpg = jpegData(cg) else { continue }
                figs.append(["w": cg.width, "h": cg.height,
                             "url": "data:image/jpeg;base64," + jpg.base64EncodedString(),
                             "ocr": String(full.prefix(1500))])
            }
        }
        return (txt.joined(separator: "\n\n"), Array(figs.prefix(20)))
    }

    // 整页渲染为位图（内缩 4%/3% 去页边，长边 ≤1200px）——扫描页区域分析用
    private static func renderCG(_ page: PDFPage) -> CGImage? {
        guard let ref = page.pageRef else { return nil }
        let box = page.bounds(for: .mediaBox).insetBy(dx: page.bounds(for: .mediaBox).width * 0.04,
                                                      dy: page.bounds(for: .mediaBox).height * 0.03)
        let scale = min(1200 / max(box.width, box.height), 3.0)
        let W = Int(box.width * scale), H = Int(box.height * scale)
        guard W > 50, H > 50, W * H < 4_000_000,
              let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(gray: 1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -box.minX, y: -box.minY)
        ctx.drawPDFPage(ref)
        return ctx.makeImage()
    }

    // OCR 并返回 (文本, 归一化包围盒)；Vision 坐标原点在左下
    private static func ocrBoxes(_ cg: CGImage) -> [(text: String, box: CGRect)] {
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.recognitionLanguages = ["en-US", "zh-Hans"]
        try? VNImageRequestHandler(cgImage: cg).perform([req])
        return (req.results ?? []).compactMap { obs in
            guard let c = obs.topCandidates(1).first, c.confidence > 0.5 else { return nil }
            return (c.string, obs.boundingBox)
        }
    }

    // 图文混排扫描页的图表区域探测：宽正文行（>50% 页宽）合并为文本块，
    // 块间 >12% 页高的空带 + 暗像素确证（contentFrac）= 图表；带内碎片文字（轴标签/图例）与紧邻下方宽行（图注）回填 ocr
    private static func figureRegions(_ cg: CGImage, _ obs: [(text: String, box: CGRect)], pageSize: CGSize) -> [[String: Any]] {
        let W = cg.width, H = cg.height
        let wide = obs.filter { $0.box.width > 0.5 }.map { $0.box }.sorted { $0.minY > $1.minY }   // 自上而下
        guard wide.count >= 2 else { return [] }
        // 合并相邻宽行为文本块（垂直间隙 < 3.5% 页高视为同块）
        var blocks: [CGRect] = []
        for b in wide {
            if let last = blocks.last, last.minY - b.maxY < 0.035 {
                blocks[blocks.count - 1] = last.union(b)
            } else { blocks.append(b) }
        }
        // 块间空带 = 候选图表区域（顶部 8% 是页眉刊头区，不探测）
        var bands: [CGRect] = []
        var prevBottom = 0.92
        for blk in blocks {
            if prevBottom - blk.maxY > 0.12 { bands.append(CGRect(x: 0.02, y: blk.maxY, width: 0.96, height: prevBottom - blk.maxY)) }
            prevBottom = blk.minY
        }
        if prevBottom > 0.12 { bands.append(CGRect(x: 0.02, y: 0, width: 0.96, height: prevBottom)) }
        var out: [[String: Any]] = []
        for band in bands.prefix(3) {
            let px = CGRect(x: band.minX * CGFloat(W), y: (1 - band.maxY) * CGFloat(H),
                            width: band.width * CGFloat(W), height: band.height * CGFloat(H)).integral
            guard px.width > 60, px.height > 60,
                  let crop = cg.cropping(to: px.intersection(CGRect(x: 0, y: 0, width: W, height: H))),
                  let jpg = jpegData(crop),
                  let frac = contentFrac(jpg), frac.w > 0.35, frac.h > 0.35 else { continue }   // 空白带跳过
            let inside = obs.filter { $0.box.intersects(band) }
            guard inside.reduce(0) { $0 + $1.text.count } < 800 else { continue }   // 带内文字多 = 窄栏正文非图
            // 图注 = 紧邻带下方的宽行，以 Fig/Table/图/表 开头
            let capLine = obs.filter { $0.box.width > 0.5 && $0.box.maxY <= band.minY + 0.005 && band.minY - $0.box.maxY < 0.03 }
                .sorted { $0.box.maxY > $1.box.maxY }.first?.text ?? ""
            guard capLine.range(of: #"^\s*(fig|table|图|表)"#, options: [.regularExpression, .caseInsensitive]) != nil else { continue }
            let ocrTxt = (["【图注】" + capLine] + inside.map { $0.text }).joined(separator: " | ")
            out.append(["w": Int(band.width * pageSize.width), "h": Int(band.height * pageSize.height),
                        "url": "data:image/jpeg;base64," + jpg.base64EncodedString(),
                        "ocr": String(ocrTxt.prefix(1500))])
        }
        return out
    }

    private static func jpegData(_ cg: CGImage) -> Data? {
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, "public.jpeg" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, cg, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        return CGImageDestinationFinalize(dest) ? out as Data : nil
    }

    // 统一缩到 ≤900px / JPEG 0.8
    static func shrink(_ jpeg: Data, maxPixel: CGFloat = 900) -> Data? {
        guard let src = CGImageSourceCreateWithData(jpeg as CFData, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel,
              ] as CFDictionary) else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, "public.jpeg" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, cg, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        return CGImageDestinationFinalize(dest) ? out as Data : nil
    }

    // ---------- 矢量图兜底：图注锚定 + 无正文文本带探测，整页渲染后裁剪 ----------
    // 版面规律：图注在图正下方；矢量图区域没有成段正文（轴刻度/标签是短文本行）。
    // 从图注上沿向上找最近一条"长正文行"作为图域上界，按图注横向范围裁剪。
    static func vectorFigures(_ doc: PDFDocument, limit: Int, tables: Bool = false) -> [[String: Any]] {
        guard limit > 0 else { return [] }
        var out: [[String: Any]] = []
        // 图注形态：带号 "Fig. 3 Effect…" / 竖线分隔 "Fig. 1 | Markers…"（Nature 系）、无号单图 "Figure. Flow chart."、中文 "图 3"；
        // 补充材料 "Fig. S1" / 前缀 "Supplementary|Extended Data" / 面板号 "Fig. 1A"（行中面板引用 "4C)" 数字后紧跟字母无分隔符，天然被拒）
        // tables=true 时锚 Table N / 表 N 标题行（表格图裁剪，供本地多模态逐表深读）
        let captionRe = try? NSRegularExpression(pattern: tables
            ? #"^\s{0,4}(?:Supplementary\s+)?(?i:Table)\s*S?\d+(?:\s*[\.:|]\s*|\s+)[A-Z(]|表\s*S?\d+"#
            : #"^\s{0,4}(?:(?:Supplementary|Extended\s+Data)\s+)?(?i:Fig(?:ure)?s?)\.?\s*S?\d+[A-Z]?(?:\s*[\.:|]\s*|\s+)[A-Z(]|(?i:Fig(?:ure)?s?)\.\s+[A-Z]|图\s*S?\d+"#)
        var pages: [(page: PDFPage, lines: [(rect: CGRect, text: String)])] = []
        var manuscript = false
        for pi in 0..<doc.pageCount {
            guard let page = doc.page(at: pi), let txt = page.string else { continue }
            let ns = txt as NSString
            // 收集本页逐行文本与 PDF 坐标（PDFKit 坐标系原点在左下）
            var lines: [(rect: CGRect, text: String)] = []
            var loc = 0
            while loc < ns.length {
                let lineRange = ns.lineRange(for: NSRange(location: loc, length: 0))
                guard lineRange.length > 0 else { break }
                let line = ns.substring(with: lineRange).trimmingCharacters(in: .whitespaces)
                if !line.isEmpty, let sel = page.selection(for: lineRange) {
                    let r = sel.bounds(for: page)
                    if !r.isNull { lines.append((r, line)) }
                }
                loc = NSMaxRange(lineRange)
            }
            if lines.filter({ $0.text.count >= 2 }).count <= 2 { manuscript = true }
            pages.append((page, lines))
        }
        for (page, lines) in pages {
            guard out.count < limit else { break }
            let bodyLines = lines.filter { $0.text.count > 60 }   // 长行视为正文，短行（轴标签/图注）不挡
            let box = page.bounds(for: .mediaBox)
            // ≤2 行文本的无文字页没有图注可锚，锚定循环天然跳过；手稿整页收图挪到末尾兜底
            for ci in lines.indices {
                let line = lines[ci]
                guard out.count < limit, let re = captionRe,
                      re.firstMatch(in: line.text, range: NSRange(location: 0, length: line.text.utf16.count)) != nil
                else { continue }
                // 图注块：向下连续同栏行（多行图注/侧排图注）；图域下界取块底
                var block = Set([ci]), blockBottom = line.rect.minY
                var growing = true
                while growing {
                    growing = false
                    for j in lines.indices where !block.contains(j) {
                        let o = lines[j]
                        if blockBottom - o.rect.maxY < 6, o.rect.maxY <= blockBottom + 6,
                           o.rect.maxX > line.rect.minX, o.rect.minX < line.rect.maxX {
                            block.insert(j); blockBottom = min(blockBottom, o.rect.minY); growing = true
                        }
                    }
                }
                // 图注 x 范围外扩一点作为图域宽度；上界 = 图注上方最近正文行（或页顶）
                let x0 = max(line.rect.minX - 15, box.minX), x1 = min(line.rect.maxX + 15, box.maxX)
                guard x1 - x0 > 80 else { continue }
                // 表模式：表标题在表上方；从标题块底向下按行距连续性扩到表尾
                if tables {
                    var yLow = blockBottom - 2   // 表体向下扩展的最低沿
                    // 列约束：只吸收与表标题横向重叠（±20pt）的行
                    let ox0 = x0 - 20, ox1 = x1 + 20
                    for l in lines.filter({ $0.rect.maxY < blockBottom - 1 && $0.rect.maxX > ox0 && $0.rect.minX < ox1
                        && $0.rect.minX >= box.minX + box.width * 0.05
                        && $0.rect.minY <= box.maxY - 45 }).sorted(by: { $0.rect.minY > $1.rect.minY }) {
                        if yLow - l.rect.maxY > 16 { break }   // 与已收行底间隙过大 = 表尾
                        yLow = min(yLow, l.rect.minY)
                        if blockBottom - yLow > 400 { break }
                    }
                    let th = blockBottom - yLow + 6
                    guard th >= 60, th <= box.height - 30 else { continue }
                    var tx0 = x0, tx1 = x1
                    for l in lines where l.rect.minY >= yLow && l.rect.maxY <= blockBottom && l.text.count <= 60
                        && l.rect.maxX > ox0 && l.rect.minX < ox1 {
                        tx0 = min(tx0, l.rect.minX - 8); tx1 = max(tx1, l.rect.maxX + 8)
                    }
                    tx0 = max(tx0, box.minX); tx1 = min(tx1, box.maxX)
                    guard tx1 - tx0 > 80 else { continue }
                    if let url = renderCrop(page, CGRect(x: tx0, y: yLow - 2, width: tx1 - tx0, height: th)) {
                        out.append(["w": Int(tx1 - tx0), "h": Int(th), "url": url])
                    }
                    continue
                }
                var top = box.maxY
                for b in bodyLines where b.rect.minY > line.rect.maxY + 2
                    && b.rect.maxX > x0 && b.rect.minX < x1 {
                    top = min(top, b.rect.minY - 4)
                }
                top = min(top, box.maxY - 40)   // 避开刊眉/页眉行
                // —— 图域定界（列宽起算）——
                // 下界延伸：图注块下方若为无文本带且确有视觉内容，扩到最近下方文本行（gap 与探针按全宽判）
                var yBot = blockBottom - 2
                let belowAll = lines.indices.filter { !block.contains($0) && lines[$0].rect.maxY < blockBottom - 2 }
                // 下界锚点先取与图注横向重叠的行；没有则取下方任意最近行（标题式图注窄居一栏、图通栏在下方时，下方常无同行文本）
                let belowOvl = belowAll.filter { lines[$0].rect.maxX > x0 && lines[$0].rect.minX < x1 }
                var extended = false
                if let bb = (belowOvl.isEmpty ? belowAll : belowOvl).map({ lines[$0].rect.maxY }).max(),
                   blockBottom - bb > 30, blockBottom - bb < 500 {
                    let gapText = (0..<lines.count).contains { j in !block.contains(j)
                        && lines[j].rect.minY < blockBottom - 2 && lines[j].rect.maxY > bb + 2
                        && lines[j].rect.minY <= box.maxY - 45 && lines[j].rect.minX >= box.minX + box.width * 0.05
                        && lines[j].text.count >= 2 }
                    if !gapText,
                       let probe = renderCrop(page, CGRect(x: box.minX + box.width * 0.06, y: bb + 2,
                            width: box.width * 0.88, height: blockBottom - bb - 4)),
                       let pf = contentFrac(Data(base64Encoded: String(probe.dropFirst("data:image/jpeg;base64,".count)))!),
                       pf.w > 0.2, pf.h > 0.2 {
                        yBot = bb + 2; extended = true
                    }
                    // 标题式图注（图在图注下方）：上方近处无图域时收紧到图注顶，避免吃进正文尾行
                    let blockTop = block.map { lines[$0].rect.maxY }.max() ?? line.rect.maxY
                    if extended && top - blockTop < 60 { top = blockTop + 4 }
                }
                let h = top - yBot
                guard h >= 100, h <= box.height - 30 else { continue }   // 下限滤装饰；上限放开到近整页（整页大图合法）
                // 带内"正文区"内容行（排除图注块自身、页眉区 y 顶部 45pt 与侧边栏 x<5% 宽度）
                let band = (0..<lines.count).filter { !block.contains($0)
                    && lines[$0].rect.minY >= yBot && lines[$0].rect.maxY <= top
                    && lines[$0].rect.minY <= box.maxY - 45 && lines[$0].rect.minX >= box.minX + box.width * 0.05
                    && lines[$0].text.count >= 2 }.map { lines[$0] }
                var ux0 = x0, ux1 = x1
                // 横向自适应：图注窄但图内方框文字更宽时，并入短文本行范围
                for s in band where s.text.count <= 60 {
                    ux0 = min(ux0, s.rect.minX - 8); ux1 = max(ux1, s.rect.maxX + 8)
                }
                // 全宽升级：最终 y 范围内列外无文本行时升级全宽，否则保持列宽
                let outOfCol = band.contains { $0.rect.maxX <= ux0 + 20 || $0.rect.minX >= ux1 - 20 }
                if !outOfCol {
                    ux0 = box.minX + box.width * 0.06; ux1 = box.maxX - box.width * 0.06
                }
                ux0 = max(ux0, box.minX); ux1 = min(ux1, box.maxX)
                guard ux1 - ux0 > 80 else { continue }
                // 图域有效性校验：终裁区域本身须有实际视觉内容
                if let url = renderCrop(page, CGRect(x: ux0, y: yBot, width: ux1 - ux0, height: h)),
                   let pf = contentFrac(Data(base64Encoded: String(url.dropFirst("data:image/jpeg;base64,".count)))!),
                   pf.w >= 0.25, pf.h >= 0.25 {
                    out.append(["w": Int(ux1 - ux0), "h": Int(h), "url": url])
                }
            }
        }
        // 手稿兜底：图注锚定 0 命中且存在无文字页（图单独整页的预印稿）才整页收图
        if !tables && out.isEmpty && manuscript {
            for (page, lines) in pages {
                guard out.count < limit else { break }
                guard lines.filter({ $0.text.count >= 2 }).count <= 2 else { continue }
                let box = page.bounds(for: .mediaBox)
                if let url = renderCrop(page, box.insetBy(dx: box.width * 0.04, dy: box.height * 0.03)),
                   let frac = contentFrac(Data(base64Encoded: String(url.dropFirst("data:image/jpeg;base64,".count)))!),
                   frac.w > 0.4, frac.h > 0.4 {   // 暗像素铺满大半页：防分节标题页（窄条+浅水印）混入
                    out.append(["w": Int(box.width), "h": Int(box.height), "url": url])
                }
            }
        }
        return out
    }

    // 整页渲染到 2x 位图并裁出 crop 区域（PDF 坐标），长边 ≤1200px，JPEG 0.85
    private static func renderCrop(_ page: PDFPage, _ crop: CGRect) -> String? {
        guard let ref = page.pageRef else { return nil }
        let scale = min(1200 / max(crop.width, crop.height), 3.0)   // 封顶 3x，小图不虚放大
        let pw = Int(crop.width * scale), ph = Int(crop.height * scale)
        guard pw > 50, ph > 50, pw * ph < 4_000_000 else { return nil }
        let cs = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(gray: 1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: pw, height: ph))
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -crop.minX, y: -crop.minY)
        ctx.drawPDFPage(ref)
        guard let cg = ctx.makeImage() else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, "public.jpeg" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, cg, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(dest), out.length > 8_000 else { return nil }
        return "data:image/jpeg;base64," + (out as Data).base64EncodedString()
    }

    // 整页图校验：缩略后扫暗像素（亮度和 <570/765，滤浅色水印），返回内容包围盒占比
    private static func contentFrac(_ jpeg: Data) -> (w: Double, h: Double)? {
        guard let src = CGImageSourceCreateWithData(jpeg as CFData, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 120,
              ] as CFDictionary) else { return nil }
        let w = cg.width, h = cg.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let d = ctx.data else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        let px = d.bindMemory(to: UInt8.self, capacity: w * h * 4)
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h { for x in 0..<w {
            let i = (y * w + x) * 4
            if Int(px[i]) + Int(px[i + 1]) + Int(px[i + 2]) < 570 {
                if x < minX { minX = x }; if x > maxX { maxX = x }
                if y < minY { minY = y }; if y > maxY { maxY = y }
            }
        }}
        guard maxX >= 0 else { return (0, 0) }
        return (Double(maxX - minX + 1) / Double(w), Double(maxY - minY + 1) / Double(h))
    }

    private static func find(_ h: [UInt8], _ n: [UInt8], _ from: Int) -> Int? {
        guard from >= 0, n.count > 0, h.count - from >= n.count else { return nil }
        var i = from
        while i <= h.count - n.count {
            if h[i] == n[0] {
                var j = 1
                while j < n.count, h[i + j] == n[j] { j += 1 }
                if j == n.count { return i }
            }
            i += 1
        }
        return nil
    }
    private static func findRev(_ h: [UInt8], _ n: [UInt8], _ before: Int) -> Int? {
        var i = min(before - n.count, h.count - n.count)
        while i >= 0 {
            if h[i] == n[0] {
                var j = 1
                while j < n.count, h[i + j] == n[j] { j += 1 }
                if j == n.count { return i }
            }
            i -= 1
        }
        return nil
    }
    private static func intAfter(_ h: [UInt8], _ key: String) -> Int? {
        guard let k = find(h, Array(key.utf8), 0) else { return nil }
        var i = k + key.utf8.count
        while i < h.count, h[i] == 0x20 { i += 1 }
        var v = 0, any = false
        while i < h.count, h[i] >= 0x30, h[i] <= 0x39 { v = v * 10 + Int(h[i] - 0x30); i += 1; any = true }
        return any ? v : nil
    }
}

// ---------- 数据文件摘要：CSV/TSV/JSON 纯 Swift 解析；xlsx 借系统 python3 标准库（zipfile+re） ----------
enum FileSummarizer {
    static func summarize(_ body: Data, name: String) -> [String: Any] {
        var text = ""
        if body.starts(with: [0x50, 0x4B]) {          // xlsx = zip（PK 魔数）
            switch xlsxToTSV(body) {
            case .ok(let t): text = t
            case .err(let e): return ["error": e]
            }
        } else if let t = String(data: body, encoding: .utf8) { text = t }
        else { return ["error": "二进制文件不支持（旧版 .xls 请在 Excel 里另存为 CSV/XLSX 后上传）"] }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var header: [String] = [], rows: [[String]] = [], sep = ""
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
            if let obj = try? JSONSerialization.jsonObject(with: Data(trimmed.utf8)) {
                if let arr = obj as? [[String: Any]], let first = arr.first {
                    header = first.keys.map { String(describing: $0) }.sorted()
                    rows = arr.prefix(10_000).map { item in header.map { col in stringify(item[col] ?? "") } }
                    sep = "JSON 数组"
                } else if let arr = obj as? [Any] {
                    header = ["value"]; rows = arr.prefix(10_000).map { [stringify($0)] }; sep = "JSON 数组"
                } else if let dict = obj as? [String: Any] {
                    header = ["key", "value"]
                    rows = dict.sorted { $0.key < $1.key }.prefix(10_000).map { [$0.key, stringify($0.value)] }
                    sep = "JSON 对象"
                }
            }
        }
        if header.isEmpty {                            // CSV / TSV
            let lines = trimmed.split(whereSeparator: \.isNewline).filter { !$0.isEmpty }
            guard let first = lines.first, !lines.isEmpty else { return ["error": "文件内容为空"] }
            let tab = first.filter { $0 == "\t" }.count, comma = first.filter { $0 == "," }.count
            let d: Character = tab > comma ? "\t" : ","
            sep = d == "\t" ? "Tab" : "逗号"
            header = splitLine(first, d)
            rows = lines.dropFirst().prefix(10_000).map { splitLine($0, d) }
        }

        let cols = max(header.count, rows.map { $0.count }.max() ?? 0)
        guard cols > 0 else { return ["error": "未解析出表格结构"] }
        // 列概况：数值列给 min/max/均值，文本列给唯一数（首行视为表头）
        var colInfo: [String] = []
        for c in 0..<cols {
            let cname = c < header.count && !header[c].isEmpty ? header[c] : "列\(c + 1)"
            let vals = rows.compactMap { c < $0.count && !$0[c].isEmpty ? $0[c] : nil }
            let miss = rows.count - vals.count
            let nums = vals.compactMap { Double($0) }
            if Double(nums.count) >= Double(vals.count) * 0.8, let mn = nums.min(), let mx = nums.max() {
                let mean = nums.reduce(0, +) / Double(nums.count)
                colInfo.append("- \(cname)：数值 · 缺失 \(miss) · min \(trimNum(mn)) / max \(trimNum(mx)) / 均值 \(trimNum(mean))")
            } else {
                colInfo.append("- \(cname)：文本 · 缺失 \(miss) · 唯一 \(Set(vals).count) 种")
            }
        }
        let preview = ([header] + rows.prefix(8))
            .map { row in (0..<cols).map { c in String((row.count > c ? row[c] : "").prefix(30)) }.joined(separator: " | ") }
            .joined(separator: "\n")
        let summary = "《\(name)》概览：\(rows.count) 行 × \(cols) 列（\(sep) 分隔，首行视为表头）\n"
            + "列概况：\n" + colInfo.joined(separator: "\n")
            + "\n预览（前 \(min(rows.count, 8)) 行）：\n" + preview
        return ["name": name, "rows": rows.count, "cols": cols, "summary": summary]
    }

    private static func stringify(_ v: Any) -> String {
        if let s = v as? String { return s }
        if let n = v as? NSNumber { return n.stringValue }
        return String(describing: v)
    }
    private static func trimNum(_ d: Double) -> String {
        d == d.rounded() && abs(d) < 1e15 ? String(Int64(d)) : String(format: "%.3g", d)
    }
    private static func splitLine(_ line: Substring, _ d: Character) -> [String] {
        var out: [String] = [], cur = "", inQ = false
        for ch in line {
            if ch == "\"" { inQ.toggle(); continue }
            if ch == d, !inQ { out.append(cur.trimmingCharacters(in: .whitespaces)); cur = ""; continue }
            cur.append(ch)
        }
        out.append(cur.trimmingCharacters(in: .whitespaces))
        return out
    }

    // xlsx → TSV：python3 仅标准库（zipfile/re），系统自带 CLT 即有
    private enum XlsxOut { case ok(String), err(String) }
    private static func xlsxToTSV(_ data: Data) -> XlsxOut {
        let tmp = NSTemporaryDirectory() + "qs-" + UUID().uuidString + ".xlsx"
        let script = NSTemporaryDirectory() + "qs-xlsx.py"
        let py = """
        import sys, re, zipfile
        z = zipfile.ZipFile(sys.argv[1])
        shared = []
        if 'xl/sharedStrings.xml' in z.namelist():
            ss = z.read('xl/sharedStrings.xml').decode('utf-8', 'ignore')
            shared = [''.join(re.findall(r'<t[^>]*>([^<]*)</t>', si)) for si in re.findall(r'<si>(.*?)</si>', ss, re.S)]
        sheets = sorted((n for n in z.namelist() if re.match(r'xl/worksheets/sheet\\d+\\.xml$', n)),
                        key=lambda s: int(re.search(r'(\\d+)', s).group(1)))
        sheet = z.read(sheets[0]).decode('utf-8', 'ignore')
        for row in re.findall(r'<row[^>]*>(.*?)</row>', sheet, re.S):
            vals = []
            for c in re.finditer(r'<c([^>]*)>(.*?)</c>', row, re.S):
                attrs, inner = c.group(1), c.group(2)
                m = re.search(r'<v>([^<]*)</v>', inner)
                if 't="s"' in attrs and m:
                    i = int(float(m.group(1)))
                    vals.append(shared[i] if i < len(shared) else '')
                elif m: vals.append(m.group(1))
                else:
                    im = re.search(r'<t[^>]*>([^<]*)</t>', inner)
                    vals.append(im.group(1) if im else '')
            print('\\t'.join(v.replace('\\t', ' ') for v in vals))
        """
        try? data.write(to: URL(fileURLWithPath: tmp))
        try? py.data(using: .utf8)?.write(to: URL(fileURLWithPath: script))
        defer { try? FileManager.default.removeItem(atPath: tmp); try? FileManager.default.removeItem(atPath: script) }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        p.arguments = [script, tmp]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
        do { try p.run() } catch { return .err("无法调用 python3 解析 xlsx，请另存为 CSV 上传") }
        p.waitUntilExit()
        guard p.terminationStatus == 0,
              let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8),
              !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return .err("xlsx 解析失败，请另存为 CSV 上传") }
        return .ok(out)
    }
}

// 单文件 SwiftUI app（swiftc 直接编译）；托盘常驻，⌥Space 全局热键呼出主窗口
@main
struct LocalLLMServerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        MenuBarExtra { TrayMenu() } label: { TrayLabel() }
        Window("LocalLLM 服务（Ollama）", id: "main") {
            ContentView().frame(width: 480, height: 520)
        }
    }
}

// openWindow action 捕获点（label 视图常驻渲染），存静态位供热键/托盘呼出主窗口
enum MainWin { static var openWindowAction: OpenWindowAction? }
func showMainWindow() {
    NSApp.activate(ignoringOtherApps: true)
    MainWin.openWindowAction?.callAsFunction(id: "main")
}

struct TrayLabel: View {
    @Environment(\.openWindow) var openWindow
    var body: some View {
        Group {
            if let img = TrayIcon.image { Image(nsImage: img) }
            else { Image(systemName: "sparkles") }
        }
        .onAppear { MainWin.openWindowAction = openWindow }
    }
}

// 菜单栏自定义图标：Resources/tray.png（纯黑透明 template，已裁边）；缺图回落 sparkles
enum TrayIcon {
    static let image: NSImage? = {
        guard let url = Bundle.main.url(forResource: "tray", withExtension: "png"),
              let img = NSImage(contentsOf: url) else { return nil }
        let h: CGFloat = 20   // 菜单栏高 22pt，20 接近撑满
        img.size = NSSize(width: h * img.size.width / max(img.size.height, 1), height: h)
        img.isTemplate = true   // 菜单栏单色图标：浅色栏黑色、深色栏白色，随系统切换
        return img
    }()
}

struct TrayMenu: View {
    @ObservedObject var server = ServerManager.shared
    var body: some View {
        Button(server.running ? "■ 停止服务" : "▶ 启动服务") {
            server.running ? server.stop() : server.start(context: ServerManager.recommendedContext())
        }
        Divider()
        Button("🖥 控制面板（⌥Space）") { showMainWindow() }
        Button("🏠 我的桌面（dashboard.html）") {
            NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory() + "/Qwen38/dashboard.html"))
        }
        Button("🌐 开始新对话（chat.html）") {
            // 经 newchat.html 跳转（携带 ?new=1）
            NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory() + "/Qwen38/newchat.html"))
        }
        Divider()
        Button("退出") { NSApp.terminate(nil) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
    }
    // 托盘常驻：关窗不退出，退出走托盘菜单
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ n: Notification) { ServerManager.shared.stop() }
    func applicationDidFinishLaunching(_ n: Notification) {
        ArchiveServer.shared.start()
        // 自动启动模型服务
        if UserDefaults.standard.bool(forKey: "autoStartModel"), ServerManager.modelExists {
            ServerManager.shared.start(context: Config.context ?? ServerManager.recommendedContext())
        }
        // 内存压力提醒（仅通知不自动停服；需系统通知授权）
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
        ServerManager.shared.watchMemoryPressure()
        HotKey.shared.onTrigger = { showMainWindow() }
        HotKey.shared.register()
        // 启动后显式呼出主窗体
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showMainWindow() }
    }
}

// ---------- 全局热键（Carbon RegisterEventHotKey，仍是 macOS 官方可用的全局快捷键途径） ----------
final class HotKey {
    static let shared = HotKey()
    var onTrigger: (() -> Void)?
    private var ref: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    func register() {
        var id = EventHotKeyID(signature: 0x5157454E /* 'QWEN' */, id: 1)
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        // @convention(c) 回调经单例转发
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            HotKey.shared.onTrigger?()
            return noErr
        }, 1, &spec, nil, &handlerRef)
        RegisterEventHotKey(49 /* kVK_ANSI_Space */, UInt32(optionKey), id,
                            GetApplicationEventTarget(), 0, &ref)
    }
}

// 日志行用 UUID 作 id
struct LogLine: Identifiable {
    let id = UUID()
    let text: String
    init(_ t: String) { text = t }
}

// ---------- 外部配置：~/Qwen38/config.json（可选，缺省回落内置默认；改后重启 app 生效） ----------
enum Config {
    private static let dict: [String: Any] = {
        let url = URL(fileURLWithPath: NSHomeDirectory() + "/Qwen38/config.json")
        guard let d = try? Data(contentsOf: url),
              let j = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else { return [:] }
        return j
    }()
    // Ollama 模型标签（如 "qwen3.8:27b-mlx"）
    static var ollamaModel: String { dict["ollamaModel"] as? String ?? "qwen3.8:27b-mlx" }
    // ollama 可执行文件：brew 安装默认路径，config.json 可覆盖
    static var ollamaPath: String {
        (dict["ollamaPath"] as? String).flatMap { FileManager.default.fileExists(atPath: $0) ? $0 : nil }
            ?? "/opt/homebrew/bin/ollama"
    }
    // 可选：启动时默认选中的上下文档位（缺省 = 按内存动态计算的推荐档）
    // 经 OLLAMA_CONTEXT_LENGTH 环境变量注入 ollama serve
    static var context: Int? { dict["contextLength"] as? Int }
}

@MainActor
final class ServerManager: ObservableObject {
    static let shared = ServerManager()

    @Published var running = false
    @Published var startedAt: Date?
    @Published var logs: [LogLine] = []

    static let ollamaURL = URL(fileURLWithPath: Config.ollamaPath)
    // "模型就绪" = ollama 二进制存在（模型包缺失时 serve 也能起，首次请求自动拉取或按提示手动 pull）
    static var modelExists: Bool { FileManager.default.fileExists(atPath: ollamaURL.path) }

    // 按内存推荐上下文档（经 OLLAMA_CONTEXT_LENGTH 注入 serve）
    static func recommendedContext() -> Int {
        let ram = Double(ProcessInfo.processInfo.physicalMemory)
        let budget = ram * 0.7 - 19e9   // 模型权重 + 系统余量
        for (ctx, kv) in [(262144, 16.0), (131072, 8.0), (65536, 4.0), (32768, 2.0), (16384, 1.0)] {
            if budget >= kv * 1.15e9 { return ctx }
        }
        return 8192
    }

    private var proc: Process?
    private var memSrc: DispatchSourceMemoryPressure?
    private static var lastMemNag: Date?

    // 系统内存压力事件（免轮询）→ 服务仍在跑时发 macOS 通知提示手动释放（10 分钟去抖）
    func watchMemoryPressure() {
        let src = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        src.setEventHandler { [weak self] in
            guard let self, self.running else { return }
            if let last = Self.lastMemNag, Date().timeIntervalSince(last) < 600 { return }
            Self.lastMemNag = Date()
            let content = UNMutableNotificationContent()
            content.title = "⚠️ 系统内存压力大"
            content.body = "模型服务仍在运行（占用大量统一内存）。如需释放内存，请点菜单栏 ✨ → 停止服务。"
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
        src.resume()
        memSrc = src
    }

    func start(context: Int) {
        guard Self.modelExists, proc == nil else { return }
        // serve 已在跑（brew services / 手动）→ 只记日志接管状态；否则拉起
        if Self.serveUp() {
            proc = nil; running = true; startedAt = Date()
            // 接管时读 /api/ps 明示实际 ctx
            var line = "▶ ollama serve 已在运行（端口 11434），直接接管（外部进程，退出无法自动感知，状态点以页面轮询为准）"
            if let psCtx = Self.runningContext(), psCtx != context {
                line += "：实际 ctx=\(psCtx) 与所选 \(context) 不符（外部 serve 无法改 env，停掉它后由本 app 拉起即生效）"
            }
            logs = [LogLine(line)]
            return
        }
        let p = Process()
        p.executableURL = Self.ollamaURL
        p.arguments = ["serve"]
        var env = ProcessInfo.processInfo.environment
        env["OLLAMA_CONTEXT_LENGTH"] = String(context)
        // CORS 放行 *（file:// 页面 Origin=null；服务只绑 127.0.0.1）
        env["OLLAMA_ORIGINS"] = "*"
        p.environment = env
        let pipe = Pipe()
        p.standardOutput = pipe; p.standardError = pipe
        // pid 从 handler 收到的退出进程取（run() 之前 processIdentifier 恒 -1）
        p.terminationHandler = { [weak self] termProc in
            Task { @MainActor in
                // 只清自己的状态（proc 仍是本进程 = 崩溃或被外部终止）
                guard let self, self.proc?.processIdentifier == termProc.processIdentifier else { return }
                self.running = false; self.startedAt = nil; self.proc = nil
                self.logs.append(LogLine("⚠ ollama serve 已退出（崩溃或被外部终止）——点「启动服务」重试"))
            }
        }
        do {
            try p.run()
            proc = p; running = true; startedAt = Date(); logs = [LogLine("▶ 已启动 pid=\(p.processIdentifier) ctx=\(context)")]
            readPipe(pipe)
        } catch { logs.append(LogLine("启动失败: \(error.localizedDescription)（brew install ollama）")) }
    }

    // 探活 ollama serve（同步短超时，仅启动时调用一次）
    static func serveUp() -> Bool {
        let sem = DispatchSemaphore(value: 0)
        var up = false
        var req = URLRequest(url: URL(string: "http://127.0.0.1:11434/api/version")!)
        req.timeoutInterval = 1.5
        URLSession.shared.dataTask(with: req) { _, resp, _ in
            up = (resp as? HTTPURLResponse)?.statusCode == 200
            sem.signal()
        }.resume()
        sem.wait()
        return up
    }

    // 已加载模型的 context_length（/api/ps；模型未加载时返回 nil）
    static func runningContext() -> Int? {
        let sem = DispatchSemaphore(value: 0)
        var ctx: Int?
        URLSession.shared.dataTask(with: URL(string: "http://127.0.0.1:11434/api/ps")!) { data, resp, _ in
            if (resp as? HTTPURLResponse)?.statusCode == 200, let d = data,
               let j = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
               let models = j["models"] as? [[String: Any]], let first = models.first {
                ctx = first["context_length"] as? Int
            }
            sem.signal()
        }.resume()
        sem.wait()
        return ctx
    }

    // 停止 = 卸载模型（释放 ~18GB 统一内存），serve 进程常驻（自身 <200MB，下次秒起）
    func stop() {
        let p = Process()
        p.executableURL = Self.ollamaURL
        p.arguments = ["stop", Config.ollamaModel]
        try? p.run()
        // 若 serve 是本 app 拉起的也一并退出（brew services 场景不动它）
        if let own = proc, own.isRunning { own.terminate() }
        running = false; startedAt = nil; proc = nil
        logs.append(LogLine("■ 已卸载模型 \(Config.ollamaModel)"))
    }

    private func readPipe(_ pipe: Pipe) {
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let line = String(data: data, encoding: .utf8) else {
                handle.readabilityHandler = nil; return
            }
            Task { @MainActor in
                self?.logs.append(contentsOf: line.split(separator: "\n").suffix(3).map { LogLine(String($0)) })
                if (self?.logs.count ?? 0) > 200 { self?.logs.removeFirst((self?.logs.count ?? 0) - 200) }
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var server = ServerManager.shared
    @State private var context = Config.context ?? ServerManager.recommendedContext()   // 默认档：config.json 可覆盖
    @State private var now = Date()
    @AppStorage("autoStartModel") private var autoStartModel = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    // 运行时间随 now 每秒刷新
    private var uptimeText: String {
        guard let s = server.startedAt else { return "—" }
        let t = Int(now.timeIntervalSince(s))
        return String(format: "%02d:%02d:%02d", t/3600, (t%3600)/60, t%60)
    }

    // 两档制：推荐（按内存+模型体积动态计算）+ 极限（上一档，超预算需自行担风险）
    var contextOptions: [(Int, String)] {
        let rec = ServerManager.recommendedContext()
        let k = { (v: Int) in "\(v / 1024)K" }
        var opts: [(Int, String)] = [(rec, "推荐 · \(k(rec))")]
        if let next = [8192, 16384, 32768, 65536, 131072, 262144].first(where: { $0 > rec }) {
            opts.append((next, "极限 · \(k(next))"))
        }
        return opts   // 推荐已是最顶档（如大内存机器的 128K）时仅剩一档
    }

    var body: some View {
        VStack(spacing: 16) {
            // 状态区
            HStack(spacing: 10) {
                Circle().fill(server.running ? Color.green : Color.red).frame(width: 10, height: 10)
                Text(server.running ? "运行中 · 127.0.0.1:11434" : "已停止")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("运行时间").font(.caption2).foregroundStyle(.secondary)
                    Text(uptimeText).font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundStyle(server.running ? .primary : .secondary)
                }
            }
            .padding(.horizontal, 4)

            // 上下文选择
            GroupBox("上下文长度（重启后生效）") {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("", selection: $context) {
                        ForEach(contextOptions, id: \.0) { v, label in
                            Text(label).tag(v)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(server.running)
                    Text("推荐档按本机内存计算，经 OLLAMA_CONTEXT_LENGTH 注入 serve。"
                         + "模型 \(Config.ollamaModel)，vision 内嵌无需 mmproj；换模型改 ~/Qwen38/config.json 的 ollamaModel")
                        .font(.caption2).foregroundStyle(.secondary)
                }.padding(4)
            }

            // 极速启动：开机登录项 + app 启动即拉服务（模型加载 ~30 秒移到后台）
            GroupBox("启动") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("启动 app 时自动启动模型服务", isOn: $autoStartModel)
                    Toggle("开机自动启动 LocalLLMServer（登录项）", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { on in
                            do {
                                if on { try SMAppService.mainApp.register() }
                                else { try SMAppService.mainApp.unregister() }
                            } catch {
                                launchAtLogin = false   // 注册失败回退
                            }
                        }
                }.padding(4)
            }

            // 控制按钮
            HStack(spacing: 12) {
                Button(server.running ? "停止服务" : "启动服务") {
                    server.running ? server.stop() : server.start(context: context)
                }
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .tint(server.running ? .red : .accentColor)

                Button("我的桌面") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory() + "/Qwen38/dashboard.html"))
                }
                .controlSize(.large)
            }

            if !ServerManager.modelExists {
                Label("未找到 ollama（\(Config.ollamaPath)）。"
                    + "无本地模型也可用：PDF 提取与存档服务（:8081）随 app 启动自动运行，"
                    + "chat.html 设置里切换 DeepSeek 云端 API 即可对话；"
                    + "brew install ollama 并 ollama pull \(Config.ollamaModel) 后再点「启动服务」",
                    systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
            }

            // 日志
            GroupBox("服务日志") {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(server.logs) { line in
                                Text(line.text).font(.system(size: 10.5, design: .monospaced))
                                    .foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                                    .id(line.id)
                            }
                        }.padding(6)
                    }
                    .onChange(of: server.logs.count) { _ in
                        if let last = server.logs.last { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
        }
        .padding(16)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                Task { @MainActor in now = Date() }
            }
        }
    }
}
