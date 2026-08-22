#!/usr/bin/env python3
# 渲染 benchmark/report.html 的内容为公众号可粘贴 HTML
# 流程（见 benchmark/README.md 踩坑笔记）：md → bm.md API（green-simple + custom.css + 浏览器 UA）→ charset 骨架
import json, re, urllib.request, pathlib

MD = pathlib.Path(__file__).resolve().parent.parent / "report_wechat_src.md"
OUT = pathlib.Path(__file__).resolve().parent.parent / "report_wechat.html"
CSS = pathlib.Path("/tmp/wechat-custom.css")

MD_CONTENT = """# Qwen3.8-27B（UD-Q4_K_XL）本地模型能力评估报告

> 测试环境：Mac（Apple Silicon，32GB）· llama.cpp · 上下文 64K · 完全离线
> 测试日期：2026-08-16 · 四套人工评分卷共 56 题，逐题对照踩分点人工评分

---

## 一、总成绩

| 测试卷 | 题数 | 设置 | 得分 | 评级 |
|---|---|---|---|---|
| 通用知识压力测试 | 22 | temp 0.1 · 思考关 | 86% | 良好+ |
| 医学专项（执业医师级） | 17 | temp 0.2 · 思考开 | 91% | 合格偏上，安全项踩线 |
| 中英双向翻译 | 14 | temp 0.0 · 思考关 | 8 全对 + 2 半对，回译零漂移 | 良好偏上 |
| 数据分析编程（实测运行） | 7 | temp 0.0 · 思考关 | 100% 可运行 | **卓越** |

---

## 二、能力边界

### ✅ 可靠区（它擅长什么）

**1. 代码生成**：pandas / matplotlib / scipy 代码 7/7 直接可运行，能避开常见陷阱（dropna 滥用、饼图密度轴、seaborn 误差线），`__main__` 规范写法一个不漏。

**2. 日常中英互译**：成语隐喻意译到位（“此地无银三百两”→“The more you hide, the more you reveal”），中文欧化抑制好，双向回译语义零漂移。

**3. 指令纪律**：temp 0 + 明确指令（“只输出译文/代码”）下完全不多嘴，两套陷阱题均守规矩。

**4. 逻辑推理与陷阱识别**：能识破数学题的矛盾条件并宣告“无解”、识破错误预设（伪名人名言）、拒答未知事件（2025 诺奖）——27B 里幻觉抵抗属优秀。

**5. 高频知识**：TCA 循环、心电图定位、DKA 补液原则等教科书级内容记忆扎实。

### ⚠️ 半可靠区（需人工核对）

- **长尾事实**：冷门细节会“自信地错”——把《肖申克的救赎》藏锄头的圣经卷答成《马太福音》（实为《出埃及记》）；四色定理证明人名编成“肯普和科恩”（实为 Appel & Haken）
- **固定译名**："spooky action at a distance" 译成“幽灵般的超距作用”，标准译名是“鬼魅般的超距作用”
- **医学教育问答**：基础/药理记忆好，但具体用药切换出现方向性错误（华法林换 NOAC 的 INR 时机说反、达比加群餐前餐后说反）
- **低频中文搭配**：“她**地**跑向终点”这类“的得地”边缘用法会出错

### ❌ 禁用区（不要让它做）

- **替代搜索引擎 / 离线百科**：长尾事实幻觉率不可接受，查事实请用 RAG 或搜索
- **临床决策与用药方案**：毒性剂量问题最终仍会给出具体数字（">10 ng/mL"），换药方案有方向性错误——只能做学习辅助，不能做诊疗依据
- **时事与新知识**：截止日期之后的一切（新指南、新获奖者）它一无所知，且答案真假难辨
- **高精度专业翻译**：法律、医学文献的固定术语需专业校对

---

## 三、使用场景推荐

| 场景 | 推荐度 | 推荐配置 |
|---|---|---|
| 数据分析 / 画图代码生成 | ✅ 放心用 | temp 0.0 · 思考关 · 指令写明“只输出代码” |
| 日常中英互译、邮件润色 | ✅ 放心用 | temp 0.0 · 思考关 |
| 写作、头脑风暴、结构化改写 | ✅ 放心用 | temp 0.7+ · 思考开 |
| 数学/逻辑推演、找题目漏洞 | ✅ 放心用 | 思考开（单题可长达 6 分钟） |
| 编程学习答疑、概念解释 | ⚠️ 可用 | API 版本细节需核对文档 |
| 医学/专业知识学习 | ⚠️ 谨慎用 | 用药/剂量/方案必须查权威来源 |
| 查证事实、引用出处 | ❌ 不要用 | 换 RAG / 搜索引擎 |
| 诊疗参考、用药决策 | ❌ 不要用 | 无替代方案，禁用 |

---

## 四、关键工程结论

**最重要的发现：温度与思考模式的组合决定可用性。**

翻译/代码类任务用 **temp 0.0 + 关闭思考**（`chat_template_kwargs: {"enable_thinking": false}`）：精度最高、零多嘴、速度快约 **20 倍**（14 题翻译 1.5 分钟 vs 医学卷 17 题 90 分钟）。思考模式留给需要深度推演的数学/逻辑题。

其他结论：

- 速度参考（64K 上下文，本地 27B）：短答案 5-20 秒，长推理 2-6 分钟/题
- 模型在“未知事件”上全部正确拒答，说明幻觉主要发生在**长尾事实的中间层**（听过的领域 + 记不清的细节），而非彻底的编造癖
- 所有测试脚本可复现：`benchmark/run_*.py`（需本地 llama-server 运行在 8080 端口）

---

*评卷依据与原始答案见 benchmark/ 目录下各 \\*_results.md · 评分为人工对照踩分点判定 · 量化（Q4_K_XL）对长尾记忆的影响未单独评估*
"""

custom_css = CSS.read_text() if CSS.exists() else ""
if not custom_css:
    raise SystemExit("/tmp/wechat-custom.css 不存在，先执行: gh api repos/ystherr/wechat-article-formatter-skill/contents/styles/custom.css --jq .content | base64 -d > /tmp/wechat-custom.css")

body = json.dumps({
    "markdown": MD_CONTENT,
    "markdownStyle": "green-simple",
    "platform": "wechat",
    "customCss": custom_css,
}).encode()
req = urllib.request.Request(
    "https://bm.md/api/markdown/render", data=body,
    headers={"Content-Type": "application/json",
             "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"})  # ponytail: UA 必带，否则 403
html = json.load(urllib.request.urlopen(req, timeout=60))["result"]

doc = ('<!DOCTYPE html>\n<html lang="zh-CN">\n<head>\n<meta charset="UTF-8">\n'
       '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
       '<title>Qwen3.8-27B 本地模型能力评估报告</title>\n</head>\n<body>\n'
       + html + '\n</body>\n</html>\n')
OUT.write_text(doc)
print(f"OK {OUT} ({len(doc)//1024}KB, inline style {len(re.findall(chr(115)+'tyle=', doc))} 处)")
