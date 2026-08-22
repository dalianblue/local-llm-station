#!/usr/bin/env python3
# program_test.md 编程卷：temperature=0.0，思考关闭，只输出代码；并实际运行验证
import json, time, urllib.request, subprocess, os, re

URL = "http://127.0.0.1:8080/v1/chat/completions"
PY = "/tmp/qa_venv/bin/python"

def ask(q):
    body = json.dumps({
        "messages": [{"role": "user", "content": q}],
        "temperature": 0.0, "max_tokens": 4096,
        "chat_template_kwargs": {"enable_thinking": False},
    }).encode()
    req = urllib.request.Request(URL, data=body, headers={"Content-Type": "application/json"})
    r = json.load(urllib.request.urlopen(req, timeout=900))
    return r["choices"][0]["message"]["content"].strip()

RULE = "只输出完整可运行的Python代码块，不加任何解释。\n\n"
Q = [
    ("P1", RULE + "生成一段Python代码：1. 用 io.StringIO 创建以下CSV数据并读取：\n日期,销售额,成本,地区\n2024-01,100,80,北区\n2024-02,NaN,75,北区\n2024-03,130,90,南区\n2024-04,NaN,NaN,南区\n2. 销售额缺失值用前向填充，成本缺失值用该列均值填充。3. 新增一列 利润率 = (销售额-成本)/销售额。最后 print 整个 DataFrame。"),
    ("P2", RULE + "基于以下数据（先重建）：io.StringIO 的CSV（日期,销售额,成本,地区；2024-01,100,80,北区；2024-02,NaN,75,北区；2024-03,130,90,南区；2024-04,NaN,NaN,南区），销售额前向填充、成本均值填充后，1. 按地区分组计算销售额的均值、中位数、标准差；2. 先计算每月利润率=(销售额-成本)/销售额，再按地区求平均利润率，找出平均利润率最高的地区并输出该地区及其平均利润率。"),
    ("P3", RULE + "生成数据 np.random.seed(0); d = np.random.normal(170, 10, 200)（200人身高）。画直方图（概率密度），叠加核密度曲线(KDE)，并加一条红色竖线标记均值。图保存到 P3.png。"),
    ("P4", RULE + "使用数据：np.random.seed(42); categories=['A','B','C','D']; values=[23,45,38,52]。画柱状图：柱子颜色从浅蓝到深蓝渐变；每根柱子上方标注数值；移除顶部和右侧边框。图保存到 P4.png。"),
    ("P5", RULE + "生成数据：np.random.seed(123); x=np.random.rand(50)*100; y=2.5*x+np.random.randn(50)*30。画散点图，用 scipy.stats.linregress 添加线性回归拟合线，并在图例中显示R²。图保存到 P5.png。"),
    ("P6", RULE + "编写函数 plot_summary(data, title)，接收DataFrame和标题，自动画出该数据所有数值列的箱线图。要求：函数定义在顶部；底部添加 if __name__ == \"__main__\": 块，内部生成示例数据并调用函数（图保存到 P6.png）。"),
    ("P7", RULE + "请画一个饼图展示A、B、C三类占比为 30%、45%、25%。生成Python代码，图保存到 P7.png。"),
]

os.chdir("/tmp/qwen_prog_test") if os.path.isdir("/tmp/qwen_prog_test") else None
os.makedirs("/tmp/qwen_prog_test", exist_ok=True)
os.chdir("/tmp/qwen_prog_test")

out = []
for qid, q in Q:
    t0 = time.time()
    a = ask(q)
    # 提取第一个 python 代码块（无代码块围栏则原样）
    m = re.search(r"```(?:python)?\s*\n(.*?)```", a, re.S)
    code = m.group(1) if m else a
    with open(f"{qid}.py", "w") as f:
        f.write(code)
    r = subprocess.run([PY, f"{qid}.py"], capture_output=True, text=True, timeout=120,
                       env={**os.environ, "MPLBACKEND": "Agg"})
    ok = r.returncode == 0
    extra = "（含代码块外文字，多嘴）" if (a.strip() != f"```python\n{code}```".strip() and not a.startswith("```")) or len(re.sub(r"```.*?```", "", a, flags=re.S).strip()) > 20 else ""
    out.append(f"## {qid} {'✅运行成功' if ok else '❌运行失败'} {extra}（{time.time()-t0:.1f}s）\n\n**代码**：\n\n```python\n{code}\n```\n\n**stdout**：\n\n```\n{r.stdout[:800]}\n```\n\n**stderr**：\n\n```\n{r.stderr[:500]}\n```\n")
    print(f"{qid} {'ok' if ok else 'FAIL'} {extra}", flush=True)

with open("/Users/yuzhang/Qwen38/program_test_results.md", "w") as f:
    f.write("# program_test.md 编程卷结果（temperature=0.0，思考关闭，实际运行验证）\n\n" + "\n".join(out))
print("all done")
