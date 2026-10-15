// ============================================================
// 学科皮肤 DIY 模板（复制本文件 → 改名如 physics.js → 逐字段填写）
// 三步上线：
//   1. 复制本文件为 disciplines/<你的id>.js，把下方 id 与 DISCIPLINES.medicine
//      的键名一起改成 <你的id>（小写字母/数字/-/_，与文件名一致）
//   2. 填写各字段——所有提示词原样迁移自医学口，换成你学科的表达即可
//   3. 打开 disciplines/index.js，把 <你的id> 加进数组
// 刷新 dashboard 即可在「学科」里看到；详细指南见 docs/discipline.md
// ============================================================
window.DISCIPLINES = window.DISCIPLINES || {};
DISCIPLINES.medicine = {   // ← 键名与 id 都改成你的学科 id
  id: "medicine",          // 学科唯一 id（小写字母/数字/-/_）
  name: "学科显示名",       // 选择层与按钮上显示
  desc: "一句话说明（首启选择层的副标题）",
  icon: "🎓",              // 选择层图标

  // —— chat 页：附文献时的 AI 身份 ——
  paperPersona: "你是一位……（学科身份+资历）。直入内容不加套话……",

  // —— chat 页：/证据提取 与 /观点提取 两条命令的模板 ——
  // 通用约束块（防脑补/观点与数据分离）由页面自动拼接，这里只写学科维度
  extractRct: "你是一位……（实验/实证类文献的提取框架，列出维度）",
  extractView: "你是一位……（批判性阅读的观点提取框架，列出维度）",

  // —— chat 页：附文献直接发送（无提问）时的默认解读模板 ——
  paperDefaultQ: "请用中文按固定四段结构总结……",

  // —— chat 页：附文献后输入框的占位提示 ——
  paperPlaceholder: "已附文献 📄 直接发送＝默认解读（……），或输入具体问题",

  // —— 通用能力边界规范的学科附加条款（chat/editor 共用）——
  // 如学科有高危输出（医学剂量/法律条文/工程规范），在此声明边界
  boundaryExtra: "- <学科>：……",

  // —— editor 页：模拟审稿的视角菜单（数量不限，按需增删）——
  reviewers: [
    {id: "general", icon: "🧑‍⚖️", name: "综合审稿人", desc: "菜单副标题",
     prompt: "综合审稿人：从……全维度审", tag: "综合"},   // tag 用于报告文件名（审稿-<tag>-日期.md）
  ],

  // —— UI 示例文案（没有对应功能可留空字符串）——
  hints: {
    reviewTopic: "综述话题的选题建议（editor 综述向导）",
    reviewExample: "综述话题示例（dashboard 新建综述）",
    projectExample: "写作项目名示例（dashboard 新建写作）",
  },

  // —— 检索源：crossref/openalex 全学科常驻（页面固定），这里只勾选学科专属源 ——
  // 可选值：pubmed（含引文校验的 PubMed 交叉验证）/ europepmc / ctgov（临床试验）
  // 两个键都可整段省略——省略时仅用通用底座检索
  search: {
    sources: [],
    queryStyle: "检索式构造提示（如：主题词 + 同义词，OR 连接）",
  },
};
