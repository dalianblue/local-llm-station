#!/bin/bash
# 一键安装：Homebrew + llama.cpp + 源码 + 模型下载 + 编译 QwenServer.app
# 用法：bash install.sh   （可先 export HF_ENDPOINT=https://hf-mirror.com 加速国内下载）
# 选项：SKIP_MODEL=1 bash install.sh   跳过模型下载（之后自行放 GGUF 到 ~/Qwen38）
set -euo pipefail

WORK=~/Qwen38
REPO=https://github.com/dalianblue/local-llm-station.git
MODEL_REPO=unsloth/Qwen3.8-27B-GGUF
MODEL_FILE=Qwen3.8-27B-UD-Q4_K_XL.gguf
MMPROJ_FILE=mmproj-F16.gguf

say(){ printf '\n\033[1;32m== %s\033[0m\n' "$*"; }
die(){ printf '\033[1;31m错误: %s\033[0m\n' "$*" >&2; exit 1; }

# ── 0. 环境检查 ──
say "环境检查"
[ "$(uname -s)" = "Darwin" ] || die "仅支持 macOS"
[ "$(uname -m)" = "arm64" ] || die "仅支持 Apple Silicon（M 系列芯片）。Intel Mac / Windows / Linux 见 README「在其他平台使用」"
MEM_GB=$(( $(sysctl -n hw.memsize) / 1024/1024/1024 ))
if [ "$MEM_GB" -lt 24 ]; then
  echo "⚠️  本机内存 ${MEM_GB}GB，跑默认 27B 模型会很吃力。"
  echo "   建议换 14B 及以下量化模型（README「换模型」），或仅安装框架稍后自选模型。"
  [ -t 0 ] && { read -r -p "仍要继续？[y/N] " a; [ "${a:-n}" = y ] || die "已取消"; }
fi
DISK_GB=$(df -g ~ | awk 'NR==2{print $4}')
[ "$DISK_GB" -ge 40 ] || die "磁盘剩余 ${DISK_GB}GB，不足（模型 + 缓存约需 40GB）"

# Python：仅为检测引导，不自动安装（mock_server.py 联调与未来插件用）
if command -v python3 >/dev/null; then
  echo "Python3: $(python3 --version 2>&1) —— mock_server 联调与未来插件可用"
else
  echo "ℹ️  未检测到 python3（不影响本站核心功能）。如需前端联调（mock_server.py）或未来插件，可运行: brew install python"
fi

# ── 1. Homebrew（首次安装会自动弹窗装命令行工具，点确认即可）──
say "Homebrew"
if ! command -v brew >/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
brew -v >/dev/null || die "brew 不可用"

# ── 2. llama.cpp + HF 下载工具 ──
say "安装 llama.cpp 与下载工具（已有则跳过）"
brew install llama.cpp huggingface-cli

# ── 3. 源码：本脚本若在仓库外运行则克隆到 ~/Qwen38 ──
say "获取源码 → $WORK"
SRC_DIR=$(cd "$(dirname "$0")" && pwd)
if [ -f "$SRC_DIR/QwenServer.swift" ]; then
  if [ "$SRC_DIR" != "$WORK" ]; then
    echo "检测到当前目录即源码（$SRC_DIR），但 app 硬编码工作目录为 $WORK，正在复制…"
    mkdir -p "$WORK"
    rsync -a --exclude .git "$SRC_DIR/" "$WORK/"
  fi
elif [ -d "$WORK/.git" ]; then
  git -C "$WORK" pull --ff-only || echo "⚠️  拉取更新失败，沿用本地版本"
else
  # ~/Qwen38 常已存在且非空（用户手动下过模型），git clone 拒绝非空目录——
  # 先浅克隆到临时目录再同步过去
  mkdir -p "$WORK"
  TMP=$(mktemp -d)
  git clone --depth 1 "$REPO" "$TMP/src" && rsync -a --exclude .git "$TMP/src/" "$WORK/"
  rm -rf "$TMP"
fi
cd "$WORK"

# ── 4. 模型下载（约 17GB，支持断点续传；SKIP_MODEL=1 跳过）──
if [ "${SKIP_MODEL:-0}" != 1 ] && [ ! -f "$WORK/$MODEL_FILE" ]; then
  say "下载模型 $MODEL_FILE（约 17GB，可 Ctrl-C 中断后重跑脚本续传）"
  HF=$(command -v hf || command -v huggingface-cli)
  "$HF" download "$MODEL_REPO" "$MODEL_FILE" "$MMPROJ_FILE" --local-dir "$WORK"
else
  say "模型已存在或已跳过下载"
fi

# ── 5. KaTeX 公式渲染资产（2.9MB，可离线渲染公式）──
if [ ! -d "$WORK/katex" ]; then
  say "下载 KaTeX 资产（可选，失败不影响使用）"
  curl -sL https://registry.npmjs.org/katex/-/katex-0.16.11.tgz -o /tmp/katex.tgz \
    && mkdir -p "$WORK/katex" \
    && tar xzf /tmp/katex.tgz -C "$WORK/katex" --strip-components=2 package/dist \
    || echo "⚠️  KaTeX 下载失败，公式将降级为原样文本，其余功能不受影响"
fi

# ── 6. 编译并启动 ──
say "编译 QwenServer.app（本地编译，无需处理签名）"
./build.sh

if [ -f "$WORK/$MODEL_FILE" ]; then
  say "安装完成，正在启动（浏览器会自动打开对话界面）"
  open QwenServer.app
else
  say "框架安装完成。把模型 GGUF 放到 $WORK 后编辑 QwenServer.swift 顶部路径，再跑 ./build.sh"
fi

# ── 7. 可选：极限上下文档的 GPU 内存解锁（只解释，不自动执行）──
# ponytail: 绝不自动 sudo——涉及系统级参数，须用户知情后自行执行
if [ "$MEM_GB" -ge 32 ]; then
  CUR=$(sysctl -n iogpu.wired_limit_mb 2>/dev/null || echo "?")
  cat <<EOF

$(printf '\033[1;33m')💡 可选优化：解锁「极限档」上下文（128K/256K）$(printf '\033[0m')
  当前 GPU 可锁定内存上限: ${CUR}MB / 内存 ${MEM_GB}GB
  QwenServer 启动面板默认只列「推荐档」；极限档需提高 macOS 允许 GPU 锁定的统一内存上限，
  否则推理回退 CPU、速度暴跌。如需启用，请自行执行（需要输入密码，原因是修改内核参数）:

      sudo sysctl iogpu.wired_limit_mb=26624

  ⚠️  知情后再执行：
     · 该命令允许单个进程（这里是 llama-server）锁定更多统一内存，独占后其他应用可用内存变少
     · 数值设得过高（如超过物理内存的 ~70%）可能触发系统卡死或强制重启
     · 仅对本次开机生效，重启自动恢复系统默认；撤销可执行
       sudo sysctl iogpu.wired_limit_mb=0（0 表示恢复默认）
     · 本脚本不会替你执行任何 sudo 命令
EOF
fi
