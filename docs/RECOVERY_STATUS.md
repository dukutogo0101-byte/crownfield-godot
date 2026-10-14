# 復旧・GitHub保存状況（2026-10-15）

## 取得して保存した内容

- 添付 `Crownfield_Godot_Project.zip`（106エントリ）を展開。ゲーム処理、UI、マップ、ルールセット、素材、テスト、調査資料と書き出し設定を保存。
- Pythonの生成キャッシュ1ファイルは展開ソースの管理対象から除外。元ZIPはそのまま保存。Godotの `.import` / `.uid` と日本語フォントも保持。
- 既存の `README.md` は保存状況の案内を先頭に追加し、本文は保持。
- Androidの元 `Crownfield-debug.apk` を取得。ZIP CRC検査とARM64ライブラリ、ゲーム処理リソース、マップの同梱を確認。実機起動と署名の再検証は未実施。
- 元ソースZIPは `distributions/`、APKは `distributions/android/` に4分割で保存。GitHubのblob APIが約43MBのAPKをサイズ超過で拒否したため、12MiBごとの分割を使用。`python3 distributions/restore_android.py` で `distributions/Crownfield-debug.apk` を復元できる。分割前後のSHA-256を確認済み。`distributions/SHA256SUMS` で元ファイルとの一致を照合できる。APKと添付ソースが同一ビルドに由来するかは未確認。

## 未取得

- `Crownfield_Windows.zip`
- `Crownfield_Linux.zip`

上記2ファイルは正確な名前と `Crownfield` の名前検索で見つからなかった。削除されたことや、以前生成されなかったことを断定するものではない。今回再ビルドは行っていない。

## 旧READMEと添付の差

旧READMEには以下の参照があるが、取得したソースZIPには含まれていない。旧READMEの172件テストや勝利リプレイの記述を今回検証したものとして扱わない。

- `tools/run_tests.sh`
- `tools/visual_smoke.gd`
- `tests/golden/winning_playthrough.json`
- `tests/validation_summary.json`
- `docs/FINAL_DIFF.md`
- `docs/VALIDATION.md`
- `builds/build_manifest.json` とビルドログ

添付には `tests/test_runner.gd`、`tests/win_playthrough.gd`、`tests/golden/regression.json`、過去の `tests/test_results.json` はある。この保存済み結果は149件中142件成功・7件失敗（golden checkpointの不一致）であり、現在の再テスト結果ではない。Godot 4.5.2と対応するエクスポートテンプレート等を用意すると、`docs/EXPORT.md` の手順で書き出せる。
