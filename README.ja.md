# disparPDF

2つのPDFファイルのテキストまたは外観を比較するツールです．

**disparPDF**はLuca Bellondaによる[ConfrontaPDF](https://github.com/lbellonda/ConfrontaPDF)（2015年）をQt6に移植したものです．ConfrontaPDF自体はMark Summerfieldによる[DiffPDF](http://www.qtrac.eu/diffpdf-foss.html)（2008–2013年）のフォークです．

このQt6移植版はYuwsuke Kiedaが2026年にAIツール（Claude by Anthropic）の支援を受けて作成しました．

## 機能

- 2つのPDFをページ単位で比較（テキストモード・外観モード）
- 単語単位・文字単位の比較
- ページ範囲の指定
- バッチ・コマンドラインモード（`disparPDFc`）
- マージン除外

## Homebrewによるインストール（推奨）

```sh
brew tap yuw/disparPDF
brew trust yuw/disparPDF
brew install yuw/disparPDF/disparPDF
```

`disparPDF` / `disparPDFc`コマンドはこの時点で使えます．Finder・Dock・Spotlightから
使えるよう`/Applications`にも置く場合は，手動でコピーします：

```sh
ditto /opt/homebrew/opt/disparpdf/disparPDF.app /Applications/disparPDF.app
```

macOSのApp Management保護により，`/Applications`にある既存の.appバンドルをHomebrewから
書き換えることはできません．**そのため`brew upgrade`のたびに上のコマンドを
実行してください**（しないとFinder側だけ旧バージョンのまま残ります）．

`cp -r`ではなく`ditto`を使ってください．既存バンドルがある状態で`cp -r`を使うと，
置き換えではなく古いバンドルの中に入れ子でコピーされてしまいます．`ditto`は
コード署名を保持するため，再署名は不要です．

インストール後の配置：

| 場所 | 説明 |
|---|---|
| `/Applications/disparPDF.app` | GUIアプリ（Finder用） |
| `/opt/homebrew/opt/disparPDF/disparPDF.app` | Homebrew管理下のコピー |
| `/opt/homebrew/bin/disparPDF` | CLIラッパー（GUIを起動） |
| `/opt/homebrew/bin/disparPDFc` | CLIバッチモード |

## アップグレード

```sh
brew update
brew upgrade yuw/disparPDF/poppler-qt6 yuw/disparPDF/disparPDF
```

`disparPDF` / `disparPDFc`コマンドはこれだけで最新になります．

**`poppler-qt6`だけが更新された場合**は，新しいバインディングに対してビルドし直してください．Homebrewは
依存先が更新されただけではformulaを再ビルドしないため，そのままでは古いPopplerに対して
リンクされたバイナリが使われ続けます：

```sh
brew reinstall yuw/disparPDF/disparPDF
```

**`/Applications`にコピーを置いている場合**は，アップグレードのたびに更新してください．macOSは`/Applications`にある
既存の.appバンドルへのHomebrewからの書き込みを許可しないため，この手順は自動化できません：

```sh
ditto /opt/homebrew/opt/disparpdf/disparPDF.app /Applications/disparPDF.app
```

インストール状況の確認と，入れ替わって不要になった旧バージョンの削除：

```sh
brew list --versions disparPDF poppler-qt6
brew cleanup
```

## 手動インストールからHomebrewへの移行

手動でビルド・インストールした環境からHomebrewに移行する手順です．

```sh
# 1. Homebrew tapでインストール
brew tap yuw/disparPDF
brew trust yuw/disparPDF
brew install yuw/disparPDF/disparPDF

# 2. インストールの確認
brew info yuw/disparPDF/disparPDF
ls /opt/homebrew/bin/disparPDF
ls /opt/homebrew/bin/disparPDFc

# 3. 手動インストール分を削除
sudo rm -f /usr/local/bin/disparPDF
sudo rm -f /usr/local/bin/disparPDFc
sudo rm -rf /usr/local/disparPDF.app
sudo rm -rf /Applications/disparPDF.app

# 4. /Applicationsにコピー
ditto /opt/homebrew/opt/disparpdf/disparPDF.app /Applications/disparPDF.app

# 5. 動作確認
open /Applications/disparPDF.app
disparPDFc -b 2>&1 | head -1
```

## ソースからのビルド

### 依存関係のインストール（macOS / Homebrew）

Homebrewの`poppler`はQt6バインディングを含まないため，
このリポジトリの`packaging/homebrew/poppler-qt6.rb`を使って個人tapからインストールします．

```sh
brew install qt@6

mkdir -p ~/homebrew-disparPDF/Formula
cp packaging/homebrew/poppler-qt6.rb ~/homebrew-disparPDF/Formula/
cd ~/homebrew-disparPDF
git init
git add Formula/poppler-qt6.rb
git commit -m "Add poppler-qt6 formula"
cd -

brew tap yuw/disparPDF ~/homebrew-disparPDF
brew install yuw/disparPDF/poppler-qt6
```

### ビルド

macOSではHomebrewのkeg-onlyな`qt@6` / `poppler-qt6`をCMakeが自動的に
探索するため，環境変数の設定は不要です:

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j$(sysctl -n hw.logicalcpu)
```

別の場所にあるQt / Popplerを使う場合は明示的に指定します．明示指定した`CMAKE_PREFIX_PATH`は
自動探索したパスより優先されます:

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="/path/to/qt6;/path/to/poppler-qt6"
```

### インストール

```sh
# /usr/localにインストール
sudo cmake --install build --prefix /usr/local

# インストール後に再署名（macOS 26以降で必要）
codesign --force --sign - /usr/local/disparPDF.app/Contents/MacOS/disparPDF

# /Applicationsにコピー（任意）
# dittoは既存バンドルを置き換え，署名も保持する
# （cp -rだと古いバンドルの中に入れ子でコピーされてしまう）
ditto /usr/local/disparPDF.app /Applications/disparPDF.app

# CLIから呼び出せるようにシンボリックリンクを作成（任意）
sudo ln -sf /usr/local/disparPDF.app/Contents/MacOS/disparPDF /usr/local/bin/disparPDF
```

## 使い方

### GUI

```sh
# Finderから起動
open /Applications/disparPDF.app

# ターミナルからファイルを指定して起動
disparPDF a.pdf b.pdf
```

### コマンドライン（バッチモード）

```sh
# 同一なら0，差異があれば非0を返す
disparPDFc -b a.pdf b.pdf

# 詳細出力
disparPDFc -b --outType=1 a.pdf b.pdf

# XML出力
disparPDFc -b --xmlResult=result.xml a.pdf b.pdf
```

## ライセンス

GPL-2.0-or-later

Copyright © 2026 Yuwsuke Kieda  
Based on ConfrontaPDF © 2015 Luca Bellonda  
Based on DiffPDF © 2008–2013 Qtrac Ltd. (Mark Summerfield)
