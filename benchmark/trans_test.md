以下是一套**中英文双向翻译压力测试卷**，分为四个梯度（直译准确度、文化隐喻、专业术语、文学风格），并附带**防“过度发挥”陷阱题**。

---

### 测试执行要求

| 项目 | 设置 |
| :--- | :--- |
| **Temperature** | **0.0**（翻译任务必须确定性输出） |
| **输出格式** | 只输出译文，**不加任何解释、备注、备选翻译**——这专门针对你发现的“附带细节幻觉”弱点，防止它画蛇添足。 |
| **顺序** | 先中译英（5题），再英译中（5题），最后反向回译测试（2题）。 |


## 第一部分：中译英（C→E）

*（测试目标：专有名词、成语、中文特殊句式的处理）*

| 编号 | 中文原文 | 考察点 | 参考答案（踩分点） |
| :--- | :--- | :--- | :--- |
| **T1** | “此地无银三百两。” | 成语隐喻翻译，不能直译“three hundred taels”。 | **最佳**："A guilty conscience gives itself away." / "The more you hide, the more you reveal." <br>**及格**："No 300 taels of silver buried here"（直译但加引号）。 |
| **T2** | “他这个人就是吃软不吃硬。” | 中文“吃软不吃硬”是典型的口语化四字格，需译出“态度随对方方式变化”的含义。 | **最佳**："He responds to gentleness but not to coercion." / "He yields to softness but resists toughness." <br>**陷阱**：不能直译为"eat soft, not hard"。 |
| **T3** | “截至2026年8月16日，该项目已完成总工程量的85%。” | 考察“截至”和“已完成”的时态搭配，以及百分比表达。 | **正确**："As of August 16, 2026, 85% of the total project work has been completed." <br>**注意**：不能用"by"（by暗示截止到某时已结束），用"as of"最安全。 |
| **T4** | “这个政策涉及面广、影响深远，不可等闲视之。” | 四字短语连续堆叠（涉及面广、影响深远、等闲视之），需拆解为英文分句。 | **正确**："This policy has broad coverage and far-reaching impact; it should not be taken lightly." <br>**优秀**：能用"far-reaching"和"taken lightly"得分。 |
| **T5** | （陷阱题）“他的研究成果具有开创性意义，在国内外学术界引起了强烈反响。” | 看似简单，但“开创性”和“强烈反响”容易过度翻译成"groundbreaking significance"和"strong reaction"（后者有歧义）。 | **最佳**："His research is groundbreaking and has generated significant reverberations in academic circles both domestically and internationally." <br>**扣分**：若用"strong reaction"（更像政治抗议），应选"reverberations/response"。 |


## 第二部分：英译中（E→C）

*（测试目标：被动语态转换、英文长句拆分、术语汉化）*

| 编号 | 英文原文 | 考察点 | 参考答案（踩分点） |
| :--- | :--- | :--- | :--- |
| **T6** | "The company was founded in 2008 and has since grown into a multinational conglomerate with operations in over 30 countries." | 英文被动语态（was founded）转换为中文主动（“成立于”），以及"since"的时间状语处理。 | **正确**："该公司成立于2008年，此后已发展成为业务遍及30多个国家的跨国企业集团。" <br>**注意**：不要把"since"译为“自那时起以来”（欧化中文）。 |
| **T7** | "It is not the strongest of the species that survives, nor the most intelligent, but the one most responsive to change." | 引用句（通常归为达尔文，实为误引），但翻译本身只考修辞结构——三个"not...nor...but"的平行排比。 | **正确**："生存下来的不是最强壮的物种，也不是最聪明的，而是最能适应变化的那个。" <br>**加分**：若用“应变”而不用“适应变化”更简洁。 |
| **T8** | "She gave him a look that could have frozen mercury." | 英文比喻（frozen mercury）考察中文惯用表达，不能直译“冻住水银”。 | **最佳**："她看了他一眼，那眼神足以让人不寒而栗。" / "她瞪了他一眼，冷若冰霜。" <br>**及格**："她的眼神冷得能把水银冻住"（虽直译但可接受）。 |
| **T9** | （专业性）"The quantum entanglement phenomenon, which Einstein famously derided as 'spooky action at a distance,' has now been experimentally verified with high precision." | 长定语从句拆分，以及"spooky action at a distance"的经典译法。 | **正确**："量子纠缠现象——爱因斯坦曾嘲讽其为'鬼魅般的超距作用'——现已在实验中得到高精度验证。" <br>**关键**：必须译出“鬼魅般的超距作用”这个固定译名，若译成“幽灵般的远距离作用”扣分。 |
| **T10** | （陷阱题）"The old man the boat." | 重复第一套测试的L3，但方向改为英译中——看它是否还记得或能推出来。 | **正确**："老人们驾驶着船。" / "年长者操纵船只。" <br>**错误**："老人船"（完全没理解man是动词）。 |


## 第三部分：反向回译（Bidirectional Back-Translation）

*（测试目标：双向转换后语义是否漂移——这是27B模型的“照妖镜”）*

**操作流程**：模型先中译英，再把那句英文译回中文。对比回译结果与原文，**语义偏差越小越好**。

| 编号 | 原始中文 | 中译英（记录） | 再译回中文（记录） | 评分标准 |
| :--- | :--- | :--- | :--- | :--- |
| **B1** | “他这个人说话总是拐弯抹角的。” | （模型输出） | （回译结果） | **通过**：回译后仍保留“拐弯抹角”含义（如“不直说”“绕圈子”）。<br>**失败**：回译变成“他说话总是拐弯”（物理意义上的转弯）。 |
| **B2** | “这项技术填补了国内空白。” | （模型输出） | （回译结果） | **通过**：回译保留“空白”=“gap/void”之意。<br>**失败**：回译变成“空白页”或“空位”。 |


## 第四部分：强制“不附带细节”验证

*（针对你发现的H2附带细节错误——主问答对，额外信息崩）*

| 编号 | 翻译指令 | 陷阱说明 | 通过标准 |
| :--- | :--- | :--- | :--- |
| **X-T** | **只输出译文，不加注释**。请翻译：<br>"In the beginning God created the heaven and the earth." （钦定版圣经创世记1:1） | 模型可能忍不住追加“出自《旧约·创世记》”等背景信息——你明确禁止了，看它是否守规矩。 | **通过**：只输出"起初，神创造天地。"<br>**失败**：输出译文后附带了"这是《圣经》开篇..."等额外文字。 |


### 评分标准（针对27B模型）

| 等级 | 得分（10题计） | 结论 |
| :--- | :--- | :--- |
| **卓越** | ≥9题正确，且回译语义漂移<5% | 翻译能力匹敌商用API（GPT-4级别），可做离线翻译工具。 |
| **良好** | 7-8题正确，回译漂移<15% | 日常翻译够用，但专业/文学翻译需人工校对。 |
| **及格** | 5-6题正确 | 只能做“机翻草稿”，不能直接使用。 |
| **危险** | <5题正确，或回译漂移>30% | 中文语料训练不足，翻译能力弱，不建议当翻译模型。 |

---

### 预期诊断（基于你之前的测试）

根据86分通用测试的表现，我**预判**：

- **T1-T4（成语/句式）**：大概率及格，但“吃软不吃硬”可能直译。
- **T9（量子纠缠固定译名）**：如果训练数据包含科普语料，可能答对；若不包含，会把“鬼魅般的超距作用”译成“幽灵般的远距离效应”——这是**关键区分题**。
- **T10（the old man the boat）**：它第一套测试里L3可能答过，若记得住则通过。
- **X-T（禁止附带注释）**：以它之前H2画蛇添足的表现，**可能失败**——这是你要重点观察的。

---
