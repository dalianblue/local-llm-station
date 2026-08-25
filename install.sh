#!/bin/bash
# 一键安装：Homebrew + oMLX + 源码 + 模型下载（ModelScope 源）+ 编译 LocalLLMServer-oMLX.app
# 用法：bash install.sh
# 选项：SKIP_MODEL=1 bash install.sh   跳过模型下载（之后自行放模型到 ~/.omlx/models/mlx-community）
set -euo pipefail

WORK=~/Qwen38
REPO=https://github.com/dalianblue/local-llm-station.git
MODEL_DIR=~/.omlx/models/mlx-community
MAIN_MODEL=Qwen3.8-27B-nvfp4
DRAFTER_MODEL=Qwen3.8-27B-MTP-nvfp4

say(){ printf '\n\033[1;32m== %s\033[0m\n' "$*"; }
die(){ printf '\033[1;31m错误: %s\033[0m\n' "$*" >&2; exit 1; }

# ── 0. 环境检查 ──
say "环境检查"
[ "$(uname -s)" = "Darwin" ] || die "仅支持 macOS"
[ "$(uname -m)" = "arm64" ] || die "仅支持 Apple Silicon（M 系列芯片）。Intel Mac / Windows / Linux 见 README「在其他平台使用」"
[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 15 ] || die "oMLX 需要 macOS 15.0+"
MEM_GB=$(( $(sysctl -n hw.memsize) / 1024/1024/1024 ))
if [ "$MEM_GB" -lt 24 ]; then
  echo "⚠️  本机内存 ${MEM_GB}GB，跑默认 27B 模型会很吃力。"
  echo "   建议换 14B 及以下量化模型（README「换模型」），或仅安装框架稍后自选模型。"
  [ -t 0 ] && { read -r -p "仍要继续？[y/N] " a; [ "${a:-n}" = y ] || die "已取消"; }
fi
DISK_GB=$(df -g ~ | awk 'NR==2{print $4}')
[ "$DISK_GB" -ge 25 ] || die "磁盘剩余 ${DISK_GB}GB，不足（模型 + 缓存约需 25GB）"

# ── 1. Homebrew（首次安装会自动弹窗装命令行工具，点确认即可）──
say "Homebrew"
if ! command -v brew >/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
brew -v >/dev/null || die "brew 不可用"

# ── 2. oMLX 推理服务 + uv（模型下载工具；已有则跳过）──
say "安装 oMLX 与 uv（已有则跳过）"
brew tap jundot/omlx https://github.com/jundot/omlx
brew install omlx uv

# ── 3. 源码：本脚本若在仓库外运行则克隆到 ~/Qwen38 ──
say "获取源码 → $WORK"
SRC_DIR=$(cd "$(dirname "$0")" && pwd)
if [ -f "$SRC_DIR/build_omlx.sh" ]; then
  if [ "$SRC_DIR" != "$WORK" ]; then
    echo "检测到当前目录即源码（$SRC_DIR），但 app 硬编码工作目录为 $WORK，正在复制…"
    mkdir -p "$WORK"
    rsync -a --exclude .git "$SRC_DIR/" "$WORK/"
  fi
elif [ -d "$WORK/.git" ]; then
  git -C "$WORK" pull --ff-only || echo "⚠️  拉取更新失败，沿用本地版本"
else
  # ~/Qwen38 常已存在且非空，git clone 拒绝非空目录——先浅克隆到临时目录再同步过去
  mkdir -p "$WORK"
  TMP=$(mktemp -d)
  git clone --depth 1 "$REPO" "$TMP/src" && rsync -a --exclude .git "$TMP/src/" "$WORK/"
  rm -rf "$TMP"
fi
cd "$WORK"

# ── 4. 模型下载（主模型约 16GB + MTP drafter 267MB，ModelScope 源，断点续传）──
if [ "${SKIP_MODEL:-0}" != 1 ]; then
  mkdir -p "$MODEL_DIR"
  if [ ! -f "$MODEL_DIR/$MAIN_MODEL/config.json" ]; then
    say "下载主模型 $MAIN_MODEL（约 16GB，可 Ctrl-C 中断后重跑脚本续传）"
    uvx modelscope download --model mlx-community/$MAIN_MODEL --local_dir "$MODEL_DIR/$MAIN_MODEL"
  fi
  if [ ! -f "$MODEL_DIR/$DRAFTER_MODEL/config.json" ]; then
    say "下载 MTP drafter $DRAFTER_MODEL（267MB，投机解码 ~14 tok/s 的关键）"
    uvx modelscope download --model mlx-community/$DRAFTER_MODEL --local_dir "$MODEL_DIR/$DRAFTER_MODEL"
  fi
else
  say "已跳过模型下载（SKIP_MODEL=1）"
fi

# ── 5. 挂载 MTP drafter（直写 per-model 设置，重启 serve 仍保留）──
if [ -f "$MODEL_DIR/$MAIN_MODEL/config.json" ] && command -v python3 >/dev/null; then
  say "配置 MTP drafter（解码提速约 1.5 倍）"
  python3 - <<PYEOF || echo "⚠️  drafter 配置写入失败，可稍后在 http://127.0.0.1:8000/admin 手动开启"
import json, os
p = os.path.expanduser("~/.omlx/model_settings.json")
s = {}
if os.path.exists(p):
    try: s = json.load(open(p))
    except Exception: s = {}
s.setdefault("models", {}).setdefault("$MAIN_MODEL", {})
s["models"]["$MAIN_MODEL"].update({"vlm_mtp_enabled": True, "vlm_mtp_draft_model": "$DRAFTER_MODEL"})
json.dump(s, open(p, "w"), indent=2, ensure_ascii=False)
print("已写入", p)
PYEOF
fi

# ── 6. KaTeX 公式渲染资产（2.9MB，可离线渲染公式）──
if [ ! -d "$WORK/katex" ]; then
  say "下载 KaTeX 资产（可选，失败不影响使用）"
  curl -sL https://registry.npmjs.org/katex/-/katex-0.16.11.tgz -o /tmp/katex.tgz \
    && mkdir -p "$WORK/katex" \
    && tar xzf /tmp/katex.tgz -C "$WORK/katex" --strip-components=2 package/dist \
    || echo "⚠️  KaTeX 下载失败，公式将降级为原样文本，其余功能不受影响"
fi

# ── 7. 编译并启动 ──
say "编译 LocalLLMServer-oMLX.app（本地编译，无需处理签名）"
./build_omlx.sh

if [ -f "$MODEL_DIR/$MAIN_MODEL/config.json" ]; then
  say "安装完成，正在启动（菜单栏出现图标后点「启动服务」，首次请求加载模型约 30 秒）"
  open LocalLLMServer-oMLX.app
else
  say "框架安装完成。把模型目录放到 $MODEL_DIR 后，菜单栏 app 点「启动服务」即可"
fi

# ── 8. 可选：长上下文的 GPU 内存解锁（只解释，不自动执行）──
# ponytail: 绝不自动 sudo——涉及系统级参数，须用户知情后自行执行
if [ "$MEM_GB" -ge 32 ]; then
  CUR=$(sysctl -n iogpu.wired_limit_mb 2>/dev/null || echo "?")
  cat <<EOF

$(printf '\033[1;33m')💡 可选优化：32GB 机型跑 64K+ 长上下文$(printf '\033[0m')
  当前 GPU 可锁定内存上限: ${CUR}MB / 内存 ${MEM_GB}GB
  27B 模型（16GB）+ 长上下文 KV 缓存会顶到默认上限，oMLX 内存守卫会压低可用上下文。
  如需长上下文，请自行执行（需要输入密码，原因是修改内核参数）:

      sudo sysctl iogpu.wired_limit_mb=26624

  ⚠️  知情后再执行：
     · 该命令允许单个进程锁定更多统一内存，独占后其他应用可用内存变少
     · 数值设得过高（如超过物理内存的 ~70%）可能触发系统卡死或强制重启
     · 仅对本次开机生效，重启自动恢复系统默认；撤销可执行
       sudo sysctl iogpu.wired_limit_mb=0（0 表示恢复默认）
     · 本脚本不会替你执行任何 sudo 命令
EOF
fi
