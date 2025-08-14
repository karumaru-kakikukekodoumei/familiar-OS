# familiar-OS

**familiar OS** は、x86向けに一から自作しているシンプルなブート可能OSです。  
NASMでアセンブリを書き、QEMUで動作確認しています。

![familiar OS スクリーンショット](docs/screenshot.png)

---

## 特徴
- ハードウェア初期化とA20ライン有効化を行うブートローダ
- リアルモード (16bit) からプロテクトモード (32bit) への移行
- ディスクから独自カーネルをロード＆実行
- VGAテキストモードでの文字表示
- 今後の予定機能:
  - キーボード入力
  - familiar風プロンプト
  - 簡易ファイルマネージャ

---

## 必要環境
- **Windows / macOS / Linux**
- [NASM](https://www.nasm.us/) – アセンブラ
- [QEMU](https://www.qemu.org/) – エミュレータ
- GNU Make（自動ビルド用・任意）

---

## ビルド & 実行
```bash
# ブートローダをアセンブル
nasm -f bin boot.asm -o boot.bin

# カーネルをアセンブル
nasm -f bin kernel.asm -o kernel.bin

# 1つのブート可能イメージに結合
cat boot.bin kernel.bin > os-image.img

# QEMUで実行
qemu-system-x86_64 -drive format=raw,file=os-image.img

Windows (PowerShell) の場合:
nasm -f bin boot.asm -o boot.bin
nasm -f bin kernel.asm -o kernel.bin
cmd /c copy /b boot.bin+kernel.bin os-image.img
qemu-system-x86_64 -drive format=raw,file=os-image.img

ライセンス
MIT License.
自由に利用・改変・再配布できます。