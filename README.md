> **敵AI・税率更新（2026-10-15）**: 継続内政・戦力集結・防衛／退避・架橋と障害突破・CPU税率調整を統合。税収は村人口を期間中に積算し、端数を持ち越します。税率ボタンで徴税路と経済の概算を確認できます。詳細は [検証結果](docs/AI_ECONOMY_UPDATE.md)。

> **横持ちUI更新（2026-10-15）**: 盤面を全画面に拡大。☰メニュー、再開/停止1ボタン、税率スライダー、選択→地点タップで移動、コンパクトな命令バーへ変更しました。共同開発は [ゲームシステム](docs/GAME_SYSTEM.md) と [開発ガイド](docs/DEVELOPMENT.md) から開始してください。

> **2026-10-15 ゲーム更新**: 住居建設AI・戦力比較・「住居オート」・岸からの橋／柵作業を修正しました。最新の変更・検証結果は [更新内容](docs/UPDATE_2026-10-15.md) を参照してください。ブラウザ版: https://crownfield-four-kingdoms.duketogo0101.chatgpt.site 。`distributions/` のZIPとAPKは復旧時の旧版で、今回の修正は含みません。

> **2026-10-15 保存状況**: 添付ソースを展開して登録しました。元のソースZIPは `distributions/`、Android APKは `distributions/android/` に4分割で保存しています。`python3 distributions/restore_android.py` で元APKを復元できます。Windows/Linux版の元ZIPは未取得です。詳しい復旧内容と、以下の旧READMEが参照する未取得ファイルは [docs/RECOVERY_STATUS.md](docs/RECOVERY_STATUS.md) を参照してください。実機プレイの再検証は行っていません。

# CROWNFIELD — 四国の境界

**マップ追加**: 開始画面、またはゲームメニューの「マップ選択・新しいゲーム」から、従来の「四つの川」とGrok制作の「開けた野」「二つの渡し」「境界の半島」を選べます。選択後に「このマップで開始」。途中のゲームを残す場合は先に保存してください。詳細は[マップ一覧](docs/MAPS.md)。
Godot 4.5.2製、Windows Onlineのゲームルールを研究基準としたクリーンルームRTS。4国が争う独自マップ4面を、タイトルから勝敗まで遊べます。**原作完全一致版ではなく、未同定数値を明示した実験用版**です。

## 起動
- Windows ZIPを展開し `Crownfield.exe` を起動。
- Linux ZIPを展開し `chmod +x Crownfield.x86_64` → `./Crownfield.x86_64`。
- AndroidはARM64 / Android 7以上用のデバッグ署名APK。実機起動・操作・性能は未検証。既存の同名アプリと署名が違う場合は別途移行が必要です。
- ソースはGodot **4.5.2 stable**で `project.godot` をインポートしてF6/F5で起動。追加プラグイン不要。

「実験用ルールでプレイ」後は一時停止状態。盤面を確認し「再開」で進めます。青国を指揮し、600日以内に敵3人の王を倒してください。青国王の喪失・期限切れは敗北です。

## 操作と遊び
クリック／タップで部隊を選択 → 命令 → 目的地。待機とオートは即予約。一時停止中の命令は再開後に反映。王に出せる命令は移動のみ。

PC: 左ドラッグで範囲選択、Shift追加、右ドラッグでパン、右クリック取消、ホイールズーム、Space停止、F全景、Ctrl+A全部隊、Ctrl+S保存。
タッチ: タップ選択、長押し詳細、2本指パン／ピンチ。2本指操作は目的地指定を取消し、離指で命令しません。「範囲選択」ON時は1本指で囲みます。縦横画面にレイアウト変更。

村の人口増加→領土拡張→出兵→合流／建設／戦闘→王撃破／資産接収の循環を実装。村人口限界は `(周囲の領地数+1)*16`、村建設費100。低税率で増兵、高税率で資金を重視。税収には王が城中央にいて自国の税路が通る必要があります。橋や柵で税路・進軍経路が変わります。自国村に待機して消耗を抑え、援軍で兵力をまとめ、強い城へ十分な戦力で攻めてください。CPUも拡張・建設・村攻撃・合流します。

13種類の盤面命令、税率、出兵時命令、全部隊／命令中除外／範囲選択、保存・読込、JSONリプレイの書出・再生・状態ハッシュ照合を実装。

旧AIでの勝利手順資料は `tests/golden/winning_playthrough.json`（通常命令79件、2080 tick／346日）。AI停滞修正前の履歴資料で、正確な再生には旧コミットが必要です。通常の保存データは新AIでも読み込めます。人間による面白さ・難易度の十分な試遊は今後の課題です。

## 原作と実験用値を分離
`data/rulesets/win_online_canon.json` は原作基準の未確定値をnullとして保持し、プレイ用にしません。実行する `playable_experimental.json` はC補完値を使い、各値に確度・出典・版・確認状態を記録。B仮説をAへ昇格していません。原作のPC98/MDの値をWindows確定値として混ぜていません。確度台帳は `docs/RULE_STATUS.csv`、要求仕様は `docs/SPEC_CANONICAL_JA.md`、今回の実装範囲は `docs/FINAL_DIFF.md`。

## 開発・テスト
`GODOT_BIN=/path/to/godot ./tools/run_tests.sh`。コア回帰、UI操作、反復1200 tick×3を検査。AI停滞は `godot --headless --path . --script res://tests/ai_progression.gd` で旧保存からの再開と新規ゲームを検査します。現行の結果は `tests/test_results.json`、`tests/ui_smoke_results.json`、`tests/ai_progression_results.json`。以前のvalidation_summaryと勝利資料は旧AIの検証記録です。Python3も必要。
`tools/visual_smoke.gd` は表示可能なGodotで実行し、実際のGUIへマウス／タッチイベントを投入します。出力は `verification/`。実機Android試験の代わりにはなりません。
ビルド手順は `docs/EXPORT.md`。`GODOT_BIN` を指定して `tools/build.sh`。Godotテンプレート・JDK17・Android SDK35が必要。ソース整合性とバイナリSHA256は `builds/build_manifest.json` に記録。

## 権利と残作業
画像・マップ・効果音は新規制作。GodotおよびNotoフォントのライセンス通知を同梱。日本ファルコムの原作画像、音楽、地図、商標ロゴ、原作EXEは含みません。非公式の研究実装です。
原作実機との数値照合、Android実機、Windows実機、PC/Android相互リプレイ、音声出力は未検証。魔物出現・同盟・複数面／次面繰越・Advanced王退路遮断AIは未実装。次の優先順は「実機数値同定→端末試験と難易度改善→未実装ルール→複数面」。詳細は `docs/VALIDATION.md`、`docs/OPEN_QUESTIONS.md`、`docs/ORIGINAL_TEST_PLAN.md`。

