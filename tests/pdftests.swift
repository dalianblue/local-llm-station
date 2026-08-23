// PDFImages 纯函数单测（由 scripts/run_pdftests.sh 拼 enum 后编译运行）
// 覆盖：图注/表题正则、字节扫描、PNG 反滤波、zlib 解压
var gFails = 0, gTotal = 0
func ok(_ cond: Bool, _ name: String) {
    gTotal += 1
    if !cond { gFails += 1; print("FAIL: \(name)") }
}

extension PDFImages {
    static func isCaption(_ s: String) -> Bool {
        let ns = s as NSString
        return captionRe!.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) != nil
    }
    static func isTable(_ s: String) -> Bool {
        let re = try! NSRegularExpression(pattern: tabCaptionPattern)
        let ns = s as NSString
        return re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) != nil
    }

    static func runTests() {
        // ---- 图注正则：应命中（历史踩坑形态全集）----
        ok(isCaption("Fig. 3 Effect of treatment on survival"), "带号 Fig. 3")
        ok(isCaption("Fig. 1 | Markers of immune activation"), "Nature 竖线分隔")
        ok(isCaption("Figure. Flow chart."), "无号单图")
        ok(isCaption("FIGURE 1 Baseline characteristics of patients"), "JACC 全大写")
        ok(isCaption("Figure 2: Study design and follow-up"), "Figure+冒号")
        ok(isCaption("Fig. S1 Additional subgroup analyses"), "S1 补充材料")
        ok(isCaption("Supplementary Fig. 2 Sensitivity analysis"), "Supplementary 前缀")
        ok(isCaption("Extended Data Fig. 1 Association of variants"), "Extended Data 前缀")
        ok(isCaption("Fig. 1A Kaplan-Meier curves by subgroup"), "面板号 1A")
        ok(isCaption("图 3 两组疗效与安全性对比"), "中文 图 3")
        ok(isCaption("图 S1 补充方法示意图"), "中文 图 S1")
        ok(isCaption("   Fig. 2 Consort diagram"), "行首 ≤4 空格缩进")

        // ---- 应拒绝 ----
        ok(!isCaption("(Fig. 4C) showed no difference"), "括号内面板引用")
        ok(!isCaption("4C) showed no difference between groups"), "换行顶到行首的面板引用")
        ok(!isCaption("Figures were prepared as described elsewhere"), "无号复数")
        ok(!isCaption("The figure legend describes the staining"), "句中 figure")
        ok(!isCaption("     Fig. 2 Deep indentation"), "行首 5 空格（超上限）")
        ok(!isCaption("As shown in Fig. 2, patients improved"), "正文引用行")

        // ---- 表题正则 ----
        ok(isTable("Table 1 Baseline characteristics"), "Table 1")
        ok(isTable("TABLE 2 Comparison of outcomes"), "全大写 TABLE")
        ok(isTable("表 1 两组患者基线资料"), "中文 表 1")
        ok(!isTable("Table of contents will follow"), "无号 Table")
        ok(!isTable("See Table 3 for details"), "句中引用")
        ok(!isTable("Tablets were administered twice daily"), "前缀误配")

        // ---- 字节扫描 ----
        let b = Array("xx << /Subtype /Image /Width 640 /Height 480 /BitsPerComponent 8".utf8)
        ok(intAfter(b, "/Width") == 640, "intAfter 常规")
        ok(intAfter(b, "/Height") == 480, "intAfter 多键")
        ok(intAfter(b, "/Missing") == nil, "intAfter 缺失返回 nil")
        ok(find(b, Array("/Height".utf8), 0) != nil, "find 命中")
        ok(find(b, Array("/Height".utf8), b.count) == nil, "find 起始越界")
        ok(find(b, Array("/Nothing".utf8), 0) == nil, "find 未命中")
        let kw = Array("/Image".utf8)
        if let i = find(b, kw, 0) {
            ok(findRev(b, [0x3C, 0x3C], i) != nil, "findRev 向前找 <<")
        } else { ok(false, "find /Image（前置失败）") }

        // ---- PNG 反滤波 ----
        let noneRows = pngUnfilter([0,1,2,3,4, 0,5,6,7,8], colors: 1, cols: 4, rows: 2)
        ok(noneRows == [1,2,3,4,5,6,7,8], "filter=0 None 透传")
        let subRow = pngUnfilter([1,10,1,1,1], colors: 1, cols: 4, rows: 1)
        ok(subRow == [10,11,12,13], "filter=1 Sub 左邻累加")
        let upRow = pngUnfilter([0,1,2,3,4, 2,1,1,1,1], colors: 1, cols: 4, rows: 2)
        ok(upRow == [1,2,3,4, 2,3,4,5], "filter=2 Up 上行累加")
        ok(pngUnfilter([0,1,2], colors: 1, cols: 4, rows: 1) == nil, "数据不足返回 nil")
        ok(pngUnfilter([9,1,2,3,4], colors: 1, cols: 4, rows: 1) == nil, "非法 tag 返回 nil")

        // ---- zlib 解压 ----
        // zlib(b"A"*1000 + b"B"*40) = 789c 73741c05a360140c77e04240000 b430848 + adler32
        let zhex = "789c73741c05a360140c77e0442400000b430848"
        var zbytes = [UInt8]()
        var hex = zhex
        while hex.count >= 2 { zbytes.append(UInt8(hex.prefix(2), radix: 16)!); hex = String(hex.dropFirst(2)) }
        if let out = inflateZlib(Data(zbytes), expect: 1024) {
            ok(out.count == 1040, "解压长度 1040（实际 \(out.count)）")
            ok(out[0] == 65 && out[999] == 65 && out[1000] == 66 && out[1039] == 66, "解压内容 A*1000+B*40")
        } else { ok(false, "inflateZlib 有效流解压") }
        ok(inflateZlib(Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]), expect: 10) == nil, "非 zlib 头返回 nil")
    }
}

PDFImages.runTests()
print("\(gTotal - gFails)/\(gTotal) passed")
exit(gFails == 0 ? 0 : 1)
