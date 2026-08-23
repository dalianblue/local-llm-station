#!/bin/bash
# PDFImages 纯函数单测：抽 enum 拼 tests/ 编译运行（不依赖 @main 与 PDF 文件）
set -e
cd "$(dirname "$0")/.."
OUT=$(mktemp -d /tmp/pdftests.XXXX)
awk '/^enum PDFImages \{/{f=1} f{print} f && /^\}/{exit}' LocalLLMServer.swift > "$OUT/enum.swift"
{
  echo 'import PDFKit'
  echo 'import CryptoKit'
  echo 'import CoreGraphics'
  echo 'import Vision'
  echo 'import Compression'
  echo 'import Foundation'
  cat "$OUT/enum.swift"
  cat tests/pdftests.swift
} > "$OUT/main.swift"
swiftc -O -o "$OUT/pdftests" "$OUT/main.swift" 2>&1 | grep -v '^$' || true
"$OUT/pdftests"
