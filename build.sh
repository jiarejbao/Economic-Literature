#!/usr/bin/env bash
# ===================================================================
# build.sh — 本地编译 main.tex 并清理编译中间文件
#
# 编译链与 Overleaf 一致：latexmk -xelatex（ctex 中文依赖 XeLaTeX；
# bibunits 的章末文献表由 latexmk 自动跑 bibtex 处理 bu*.aux；
# imakeidx 的索引按默认配置自动处理，见 CONTRIBUTING.md「编译与 Overleaf 对接」）。
#
# 用法：
#   ./build.sh            编译，成功后清理中间文件，保留 main.pdf
#   ./build.sh --keep     编译但保留中间文件（排查错误用）
#   ./build.sh --clean    干净构建：先清理旧中间文件（避免陈旧 aux 干扰），
#                         再完整编译，成功后再次清理中间文件
#
# 编译失败时不清理，保留 main.log 供排查；成功后清理的扩展名与
# .gitignore 保持一致（另含 bcf / run.xml 两个可能出现的文件）。
# ===================================================================
set -euo pipefail
cd "$(dirname "$0")"

exts='aux bbl blg fdb_latexmk fls idx ilg ind log out synctex.gz toc xdv bcf run.xml'

clean() {
  for ext in $exts; do
    find . -name "*.$ext" -not -path './.git/*' -delete
  done
}

case "${1:-}" in
  --clean)
    # 干净构建：先清旧中间文件，再落到下面的正常编译流程（成功后自动再清理）
    clean
    keep=0
    ;;
  --keep)
    keep=1
    ;;
  '')
    keep=0
    ;;
  *)
    echo "未知参数：$1（用法见文件头注释）" >&2
    exit 2
    ;;
esac

# 选 latexmk 的调用方式：Git Bash 里 PATH 中就有 latexmk；从 PowerShell 敲
# `bash build.sh` 进的是 WSL 的 bash——Windows PATH 未并入 WSL，找不到 latexmk，
# 但 Windows 的 exe 经 interop 可直接运行，故借 cmd.exe 按 Windows 的 PATH 解析。
# （不用 cmd.exe 的 where 反查：其输出在 WSL 管道里是 UTF-16，解析不可靠。）
if command -v latexmk >/dev/null 2>&1; then
  latexmk_cmd=(latexmk)
elif grep -qi microsoft /proc/version 2>/dev/null && [ -x /mnt/c/Windows/System32/cmd.exe ]; then
  echo "WSL 内未找到 latexmk，改经 cmd.exe 调用 Windows 侧的 MiKTeX"
  latexmk_cmd=(/mnt/c/Windows/System32/cmd.exe /c latexmk)
else
  echo "未找到 latexmk：请确认 TeX 发行版（本机为 MiKTeX）在 PATH 中；" \
       "若在 PowerShell/WSL 里运行，请改用 Git Bash（D:\\Git\\bin\\bash.exe）" >&2
  exit 1
fi

# -halt-on-error：出错即停，不空转跑满轮数
if "${latexmk_cmd[@]}" -xelatex -interaction=nonstopmode -halt-on-error main.tex; then
  echo "编译成功：main.pdf"
  if [ "$keep" -eq 0 ]; then
    clean
    echo "已清理编译中间文件"
  fi
else
  echo "编译失败：保留编译中间文件，查 main.log；排查后可用 ./build.sh --clean 干净重建" >&2
  exit 1
fi
