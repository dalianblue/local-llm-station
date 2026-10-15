# 学科皮肤（Discipline Skins）

四页（chat / editor / dashboard / newchat）的提示词与学科相关 UI 全部从
`disciplines/` 目录的「皮肤」文件读取——页面是结构（HTML），皮肤是样式（CSS），
换学科不改页面代码。

首次打开 dashboard 会弹出学科选择层（必须选一个）；之后随时从顶栏
「🎓 学科」切换。选择存在 `localStorage.qwen_discipline`，三页共享。

## 目录

| 文件 | 作用 |
|---|---|
| `medicine.js` | 医学口（内置兜底，功能最全），未选/加载失败时回退到它 |
| `template.js` | DIY 模板——每个字段的填写说明见文件内注释 |
| `index.js` | 学科清单；dashboard 首启选择层按此预载并列出全部学科 |
| `你的学科.js` | 你自己建的 |

## 自建学科三步

1. **复制** `template.js` 为 `disciplines/<id>.js`（id 限小写字母/数字/`-`/`_`，
   与文件名一致），把对象键名 `DISCIPLINES.medicine` 与 `id` 字段改成 `<id>`。
2. **填字段**：学科身份（`paperPersona`）、提取模板（`extractRct`/`extractView`）、
   默认解读（`paperDefaultQ`）、边界条款（`boundaryExtra`）、审稿视角
   （`reviewers`，数量不限）、UI 示例（`hints`）。各字段 consumed 的位置见
   template.js 注释。
3. **注册**：把 `<id>` 加进 `index.js` 的数组。

刷新 dashboard，顶栏「🎓 学科」里即可看到并选用。

## 字段去哪了（消费点速查）

| 字段 | chat.html | editor.html | dashboard.html |
|---|---|---|---|
| `paperPersona` / `paperDefaultQ` / `paperPlaceholder` | 附文献身份 / 默认解读 / 输入框占位 | — | — |
| `extractRct` / `extractView` | `/证据提取` `/观点提取` 命令 | — | — |
| `boundaryExtra` | 能力边界规范拼接 | 同左（两页共享同一条款） | — |
| `reviewers` | — | 🕵️ 审稿菜单 + 审稿 prompt + 报告文件名 | — |
| `hints.*` | — | 综述向导话题提示/示例 | 新建写作/综述项目示例 |

## 检索源说明（P2 待参数化）

目前文献检索四源（PubMed / OpenAlex / Europe PMC / ClinicalTrials.gov）仍为
医学口硬编码，随页面而非皮肤走。其中 Crossref / OpenAlex 本身是全学科库，
非医学学科可正常使用「引文校验」与基础检索；PubMed/ClinicalTrials 的专属
链路对其他学科只是多出冗余结果，不影响使用。检索源参数化后在皮肤中配置。

## 注意

- 页面在 `file://` 下运行，**皮肤必须用 `.js` + `<script>` 加载**，
  不能写成 `.json` 再 fetch（浏览器拦截 file:// fetch）。
- 皮肤加载失败（文件被删/语法错误）时三页静默回退医学口，
  顶栏「🎓 学科」的 title 会显示实际生效学科。
