#!/usr/bin/env python3
# trans_test.md 翻译卷：temperature=0.0，关闭思考模式，只输出译文
import json, time, urllib.request

URL = "http://127.0.0.1:8080/v1/chat/completions"

def ask(q):
    body = json.dumps({
        "messages": [{"role": "user", "content": q}],
        "temperature": 0.0, "max_tokens": 2048,
        "chat_template_kwargs": {"enable_thinking": False},
    }).encode()
    req = urllib.request.Request(URL, data=body, headers={"Content-Type": "application/json"})
    r = json.load(urllib.request.urlopen(req, timeout=900))
    return r["choices"][0]["message"]["content"].strip()

RULE = "只输出译文，不加任何解释、备注、备选翻译。\n\n"
E2C = RULE + "请将下面的英文翻译成中文：\n"
C2E = RULE + "请将下面的中文翻译成英文：\n"

Q = [
    ("T1", C2E, "此地无银三百两。"),
    ("T2", C2E, "他这个人就是吃软不吃硬。"),
    ("T3", C2E, "截至2026年8月16日，该项目已完成总工程量的85%。"),
    ("T4", C2E, "这个政策涉及面广、影响深远，不可等闲视之。"),
    ("T5", C2E, "他的研究成果具有开创性意义，在国内外学术界引起了强烈反响。"),
    ("T6", E2C, "The company was founded in 2008 and has since grown into a multinational conglomerate with operations in over 30 countries."),
    ("T7", E2C, "It is not the strongest of the species that survives, nor the most intelligent, but the one most responsive to change."),
    ("T8", E2C, "She gave him a look that could have frozen mercury."),
    ("T9", E2C, "The quantum entanglement phenomenon, which Einstein famously derided as 'spooky action at a distance,' has now been experimentally verified with high precision."),
    ("T10", E2C, "The old man the boat."),
    ("X-T", E2C, "In the beginning God created the heaven and the earth."),
]

# B1/B2: 中→英→中 回译
BACK = [("B1", "他这个人说话总是拐弯抹角的。"), ("B2", "这项技术填补了国内空白。")]

out = []
for qid, prompt, src in Q:
    t0 = time.time()
    a = ask(prompt + src)
    out.append(f"## {qid}\n**原文**：{src}\n\n**译文**（{time.time()-t0:.1f}s）：\n\n{a}\n")
    print(f"{qid} done", flush=True)

for qid, src in BACK:
    t0 = time.time()
    en = ask(C2E + src)
    zh = ask(E2C + en)
    out.append(f"## {qid} 回译\n**原文**：{src}\n\n**中→英**：{en}\n\n**英→中**（{time.time()-t0:.1f}s）：\n\n{zh}\n")
    print(f"{qid} done", flush=True)

with open("trans_test_results.md", "w") as f:
    f.write("# trans_test.md 翻译卷结果（temperature=0.0，思考模式关闭）\n\n" + "\n".join(out))
print("all done")
