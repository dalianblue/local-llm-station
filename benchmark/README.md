# benchmark · 公众号渲染流程（踩坑笔记）

把 `report.html`（模型能力评估报告）的内容渲染成微信公众号可直接粘贴的 inline-styled HTML。下次接到类似任务（"把这个报告转成公众号文章"），按本文档执行即可。

## 产物

| 文件 | 用途 |
|---|---|
| `report.html` | 能力边界报告原稿（浏览器直读的独立样式版） |
| `report_wechat.html` | **最终交付物**。浏览器打开 → 全选 → 复制 → 粘贴到公众号编辑器 |
| `scripts/wechat_render.py` | 一键渲染脚本（Markdown 源内嵌在脚本的 `MD_CONTENT`，无独立 .md——本仓库 hook 禁止新建非 README 的 .md） |
| `/tmp/wechat-custom.css` | 从 ystherr 仓库拉的样式表，丢了重拉（见下） |

## 核心决策（踩出来的）

### 1. 不要直接把 report.html 转公众号

`report.html` 是带 `<style>` 块的独立样式报告。微信公众号编辑器**不支持**外部 `<style>`、CSS Grid 等，直接粘贴全部崩掉。正确做法是**改写成 Markdown，走渲染服务**。

### 2. 用 bm.md 渲染服务，不要手工 inline CSS

- 端点：`POST https://bm.md/api/markdown/render`
- 必传参数：`markdown`, `markdownStyle="green-simple"`, `platform="wechat"`, `customCss`
- 输出：JSON `{"result": "<section id='bm-md'>...</section>"}`，所有样式已 inline（本项目渲染结果 221 处 `style=`），公众号原生支持
- **必须带浏览器 UA**：默认 Python-urllib UA 被挡，返回 403

### 3. 本项目无图片，base64 内联步骤天然跳过

若以后报告加图表：实测本机网络环境挡了所有公开图床（catbox.moe → Connection reset、0x0.st → uploads disabled、tmpfiles.org → Connection reset）。解法是渲染后用 regex 把 `<img src="本地路径">` 替换成 `data:image/png;base64,...`——浏览器粘贴到公众号时，公众号自动接管上传到微信 CDN。图床通了再换回 URL 减体积。

### 4. bm.md 输出的是 HTML 片段，必须包一层 charset 声明

bm.md 返回的 `<section>` 没有 `<!DOCTYPE>`、没有 `<meta charset>`，浏览器可能按 GBK 解码导致中文乱码。**"字体乱码"的根因是编码声明缺失，不是字体配置。** 脚本已用骨架包装（`<!DOCTYPE html>` + `<meta charset="UTF-8">`），粘贴时公众号编辑器自动丢弃外层标签，无副作用。

### 5. 不要机械安装 wechat-article-formatter-skill

GitHub 上 `ystherr/wechat-article-formatter-skill` 等仓库的 SKILL.md 本质就是：读 custom.css + 调 bm.md API + 上传图片 +（可选）调微信 draft/add API 发草稿。直接复用其 custom.css + 自己写 30 行 Python 比装整个 skill 简单。除非明确要直发草稿，否则不要碰 WECHAT_APP_ID/SECRET 和 IP 白名单那套。

## 复现命令

```bash
# 1. 拉 custom.css（一次即可，缓存在 /tmp/wechat-custom.css；脚本缺失时会提示此命令）
gh api repos/ystherr/wechat-article-formatter-skill/contents/styles/custom.css \
  --jq '.content' | base64 -d > /tmp/wechat-custom.css

# 2. 渲染（脚本已处理 UA、charset 包装；改内容直接编辑脚本里的 MD_CONTENT）
python3 scripts/wechat_render.py

# 3. 浏览器打开产物，全选复制粘贴到公众号
open report_wechat.html
```

## 已知遗留 / 升级路径

- **报告内容更新后需手动同步**：`report.html` 与脚本内嵌的 `MD_CONTENT` 是两份内容，改了报告要同步改 MD_CONTENT 再重渲染。若更新频繁，可把 MD_CONTENT 抽成独立源文件（需先调整仓库 hook 对 .md 的限制）。
- **宽表在手机端偏挤**：总成绩表、场景推荐表在手机上读得有点挤。有阅读反馈时回头把宽表拆成短表或列表，再重渲染。
- **直发草稿路径未实现**：当前只要"能粘贴的 HTML"。要直发，参照 iamzifei/wechat-article-formatter-skill 的 SKILL.md Step 2/3/5（token → media/uploadimg → draft/add），需要 `~/.env` 配 WECHAT_APP_ID/SECRET 和 IP 白名单。

## 流程图（一图速读）

```
MD_CONTENT（内嵌于脚本）──► bm.md API ──► HTML 片段（221 处 inline style）──► 包 charset 骨架 ──► report_wechat.html
custom.css ──────────────────┘
（本项目无图片，base64 内联步骤跳过）
```
