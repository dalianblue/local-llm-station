#!/bin/bash
# PDF 图表提取语料回归：对 pdf_corpus/ 的基线 PDF 复刻 /pdf 端点提取管道（不含 OCR），张数对照期望值
# 用法：scripts/pdf_regress.sh [语料目录]   （默认 pdf_corpus/，已 gitignore；CI 无语料自动跳过）
set -e
cd "$(dirname "$0")/.."
DIR="${1:-pdf_corpus}"
if [ ! -d "$DIR" ]; then echo "SKIP: 语料目录 $DIR 不存在（pdf_corpus 不入库，仅本机回归）"; exit 0; fi

# 期望值：2026-08-23 手工目检基线（imgs 总张数 = DCT 位图 + Flate 直取 + 矢量/扫描兜底）
expect() { case "$1" in
  yinxiebing) echo 8;; s12967) echo 8;; wuyingdeng) echo 1;;
  mills) echo 7;; neddylation) echo 1;; jacc) echo 4;;
esac }

OUT=$(mktemp -d /tmp/pdfregress.XXXX)
awk '/^enum PDFImages \{/{f=1} f{print} f && /^\}/{exit}' LocalLLMServer.swift > "$OUT/enum.swift"
{
  echo 'import PDFKit'
  echo 'import CryptoKit'
  echo 'import CoreGraphics'
  echo 'import Vision'
  echo 'import Compression'
  echo 'import Foundation'
  cat "$OUT/enum.swift"
  cat <<'MAIN'
let path = CommandLine.arguments[1]
let data = try! Data(contentsOf: URL(fileURLWithPath: path))
guard let doc = PDFDocument(data: data) else { fatalError("no doc") }
var scanPages = 0
for i in 0..<doc.pageCount { if (doc.page(at: i)?.string ?? "").count < 100 { scanPages += 1 } }
let jpeg = PDFImages.extract(data, limit: 20)
let flate = PDFImages.extractFlate(data, limit: 20 - jpeg.count)
var imgs = jpeg + flate
var timgs = 0
if scanPages >= 3 {
    imgs += PDFImages.scannedFallback(doc).1
} else {
    if imgs.count < 4 { imgs += PDFImages.vectorFigures(doc, limit: 20 - imgs.count) }
    timgs = PDFImages.vectorFigures(doc, limit: 8, tables: true).count
}
print("imgs=\(imgs.count) timgs=\(timgs) jpeg=\(jpeg.count) flate=\(flate.count)")
MAIN
} > "$OUT/main.swift"
swiftc -O -o "$OUT/cli" "$OUT/main.swift" 2>/dev/null

fail=0
for pdf in "$DIR"/*.pdf; do
  base=$(basename "$pdf" .pdf)
  line=$("$OUT/cli" "$pdf")
  got=$(echo "$line" | sed 's/imgs=\([0-9]*\).*/\1/')
  exp=$(expect "$base")
  if [ -z "$exp" ]; then
    echo "??   $base  $line（语料未登记期望值，仅展示）"
  elif [ "$got" = "$exp" ]; then
    echo "OK   $base  $line"
  else
    echo "FAIL $base  $line  期望 imgs=$exp"; fail=1
  fi
done
[ $fail -eq 0 ] && echo "回归全部通过" || echo "存在回归，见 FAIL 行"
exit $fail
