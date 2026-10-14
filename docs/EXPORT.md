# ネイティブビルドと再現手順

Godot 4.5.2 stable の公式テンプレートを使用する。プロジェクト内にエンジン、SDK、JDK、秘密鍵は同梱しない。

## 必要なツール

- Godot 4.5.2 stable と同版の export templates
- Linux/Windows: `linux_release.x86_64` / `windows_release_x86_64.exe`
- Android: JDK 17、Android SDK platform 35、build-tools 35.0.0、platform-tools、`android_debug.apk`

```bash
GODOT_BIN=/path/to/Godot_v4.5.2-stable_linux.x86_64 \
JAVA_HOME=/path/to/jdk17 \
ANDROID_SDK_ROOT=/path/to/android_sdk \
./tools/build.sh
```

このスクリプトはエディターに Android SDK の場所を設定し、Linux/Windows のリリースビルドと Android デバッグ APK を出力する。APK の既定鍵はユーザーのホームディレクトリに作成する。デバッグ署名は配布ストア公開用ではない。

`builds/build_manifest.json` にソースと各成果物の SHA-256 を記録する。ビルド開始・終了時の runtime ソースを比較し、変更があれば失敗させる。資料・テスト・研究ファイルはネイティブビルドの配布対象から除く。

## PC

Windows は `Crownfield.exe` を起動する。Linux は `chmod +x Crownfield.x86_64` の後に起動する。PCK はバイナリへ埋め込み、素材と外部 JSON を含む。Windows 実機での起動は、この環境では未検証。

## Android

APK は ARM64 のみ、横画面、パッケージ名 `com.hiro.crownfield`。インターネット権限を要求しない。ローカルのセーブはアプリ専用領域へ保存する。Android実機でのタッチ・性能・縦横遷移の検証は別途必要。4.4.1 の公式 ARM64 テンプレートが 4 KB LOAD alignment だったため、本成果物は Godot 4.5.2 へ更新した。16 KB ELF LOAD/ZIP alignment を静的に検証する。16 KB 端末の実機起動は未検証。

```bash
adb install -r builds/Crownfield-debug.apk
adb shell am start -n com.hiro.crownfield/com.godot.game.GodotApp
adb logcat -s godot
```

エディターから書き出す場合は `export_presets.cfg` の Android を使用する。署名鍵の場所を Editor Settings → Export → Android に設定する。初回インポートでは ETC2/ASTC を有効にする（プロジェクトに設定済み）。Android APK はデバッグ署名済みであり、未知のアプリのインストール許可が必要な場合がある。

## 検証の区別

- Linux: エクスポート後にバイナリをヘッドレス起動し、同梱リソースの解決を確認する。画面検証はソースプロジェクトの Xvfb スクリーンショットで実施する。
- Windows: PE ファイル生成を確認する。Windows ネイティブ起動は未検証。
- Android: `apksigner verify`、`aapt dump badging/permissions`、同梱アセット、ARM64 ELF の LOAD alignment を確認する。実機起動確認とは区別する。

実施結果の詳細は `docs/VALIDATION.md` と `builds/` のログを参照する。
