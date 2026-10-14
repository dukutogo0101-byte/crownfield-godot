# 共同開発ガイド（Codex / Grok / 人間の開発者）

更新日: 2026-10-15。

## 正本と入口

- ソース正本: https://github.com/dukutogo0101-byte/crownfield-godot の最新ブランチ。
- ゲームの現行仕様: [GAME_SYSTEM.md](GAME_SYSTEM.md)。
- ブラウザ版: https://crownfield-four-kingdoms.duketogo0101.chatgpt.site （所有者用公開）。
- `distributions/` の元ZIP・分割APKは旧版保存用。これを最新ソースへ上書きしない。
- `SPEC_CANONICAL_JA.md` は原作調査の基準であり、現行実装の保証ではない。原作確定A、仮説B、独自補完Cを混同しない。

## コードの責務

| ファイル | 責務・主な入口 |
|---|---|
| project.godot / main.tscn | Godot設定、UIの起動 |
| core/simulation.gd | 整数状態・全ルール。`new_game`、`issue`、`step`、`snapshot`、`restore`、`export_replay` |
| core/pathfinder.gd | 4方向BFS。乱数なし、同距離では既定の上/左/右/下順 |
| core/combat_resolver.gd | 純粋関数による戦闘損害 |
| ui/game.gd | 入力、選択、命令予約、HUD、モーダル、実時間速度、保存、UI形式のリプレイ |
| ui/board.gd | 地図描画、座標変換、選択・長押し・パン・ピンチ・ミニマップ。状態のルール変更を行わない |
| data/maps/four_rivers.json | マップと初期状態 |
| data/rulesets/playable_experimental.json | 実行する周期・費用・閾値と確度・出典区分 |
| data/rulesets/win_online_canon.json | 原作研究用の未確定値をnullで保持。プレイ用ではない |
| tests/test_runner.gd | コアの単体・統合・golden回帰 |
| tests/ui_smoke.gd | 画面操作からコアへの命令、保存、税率、リプレイ、横持ちHUDの回帰 |
| tests/sim_stats.gd | 実マップ1200 tick × 3回の決定論・規模確認 |
| tests/record_golden.gd | 開発者が明示的に実行するgolden更新。通常テストでは実行しない |
| web/shell.html | 全画面起動、横向きロック、ブラウザのファイル選択、HTMLローダー |
| web/viewport.js | CSSとWebGLの寸法を同時更新。回転、全画面、DPR、ブラウザのサイズ変更に追従 |
| web/compressed_wasm.js | `.wasm`要求を`.wasm.gz`へ送り、gzipを復元してエンジンに渡す |
| web/prepare_web.py | Web出力の圧縮、PWAキャッシュ・横向きマニフェスト・版識別クエリの調整、サイズ・SHA-256確認 |
| tools/run_tests.sh / tools/build_web.sh | 再現可能な検証とブラウザ版の書き出し |

## 状態モデル

`simulation.state` はDictionary。位置は整数ID、金額・人口・兵力・耐久は整数。JSONから読み込む整数相当のfloatは `_integers` で正規化する。

| キー／配列 | 代表フィールド |
|---|---|
| state | w, h, tick, day, next_id, limit_days, result, winner |
| cells | terrain, owner, bridge, bridge_built, fence |
| factions | id, name, funds, tax, home, alive, initial_order |
| bases | id, team, pos, pop |
| units | id, team, pos, power, order, target, manual, king=false, auto_mode, ai_job |
| leaders | id, team, pos, power, order, target, manual, king=true, alive |
| events | tick, message（最大30件） |
| losses / combat_losses | 国別の総損害／戦闘損害 |

`manual` は手動命令かどうか。`auto_mode` は自動化の意図（空文字、auto、develop）。`order` は現在の作業であり、建設途中にbuild_baseでもauto_mode=developを失わない。`ai_job` は集結・開発・攻撃判断の補助情報。王兵力を通常人口に加えない。

## 命令契約

`issue` はコアを進めず、**命令Dictionaryそのもの**を返す。`.command`というラッパーはない。

```gdscript
var command = sim.issue("move", [4], 128)
if command.accepted:
    pending.append(command)
# 次の論理tickで、一度だけ渡す。
sim.step(pending)
pending.clear()
```

受理された命令の概略:

```json
{
  "tick": 1,
  "sequence": 1,
  "action": "move",
  "actors": [4],
  "actor_ids": [4],
  "target": 128,
  "extra": {},
  "accepted": true,
  "reason": "Order ready"
}
```

- `tick` は入力時の次tick。`sequence` は増加し、同一sequenceの二重適用を防ぐ。
- UIから入力可能な部隊はteam 0。CPUは内部 `_ai` で計画する。
- 王はmove/waitだけ。王を含む複数選択で建設・オートを与えない。
- wait/auto/developには目的地不要。税率は `extra.value`、出兵時行動は `extra.order`。
- メニュー・パン・ズーム・一時停止・選択・ファイルUIから直接stateを変更しない。
- UI側pendingと、コア側の未来tick用pendingは別。保存データでは両方の扱いに注意。

## 保存とリプレイ

`sim.snapshot()` はschema=1、state、rules、issued_sequence、command_log、pending、必要ならreplay_origin、checksumを含む。`restore` は正規化・型・範囲・チェックサム等を検証する。

ハッシュは用途が違う:

- `state_hash()` = canonical(state + rules) のSHA-256。リプレイの進行状態を比較。
- `snapshot_hash()` = checksumフィールドを除くスナップショット全体のSHA-256。保存整合性を比較。
- `snapshot_state_hash(saved)` = 任意のスナップショットのstate/rules部分の状態ハッシュ。

リプレイは現在2形式ある。勝手に混ぜない。

| 形式 | 初期状態 | 命令 | 読込 |
|---|---|---|---|
| コア `export_replay()` | initial_state | コア命令の配列 | `sim.load_replay()` |
| UI `_replay_document()` | initial_snapshot | `{apply_tick, command}`の配列 | `game._start_playback()` |

両方format=1、ruleset_id、rng_state=unused、initial_hash相当、checkpoints、final_tick/final_hashを持つが、フィールド名と命令配列は異なる。UI形式の初期ハッシュにはsnapshot_state_hashを使う。Webのファイル取込は現状UI形式のリプレイまたは保存スナップショットを扱う。

保存場所は `user://crownfield_save.json`、リプレイは `user://crownfield_replay.json`。Webではブラウザの保存領域。ブラウザデータ削除やキャッシュ破棄に備え、記録メニューのJSONダウンロードで外部保存できる。APK版とWeb版で自動同期はしない。ルール・AI変更後の旧リプレイは同じ結果になる保証がない。

## 起動・テスト・Webビルド

Godot **4.5.2 stable**、Python3、Web出力には同版の `web_nothreads_release.zip` export templateを用意する。追加Godotプラグインは不要。

```bash
GODOT_BIN=/path/to/godot ./tools/run_tests.sh
GODOT_BIN=/path/to/godot ./tools/build_web.sh
# 別の配信用ディレクトリへ出力する場合
GODOT_BIN=/path/to/godot ./tools/build_web.sh /absolute/path/to/dist
```

コア単独なら `godot --headless --path . --script res://tests/test_runner.gd`。結果JSONの失敗一覧と終了コードを確認する。エディターや出力ログのSCRIPT ERROR/Parse Errorを無視しない。

ブラウザ用はCompatibility描画、スレッド/GDExtensionなし。HTML・JS・PCK・gzipエンジン・アイコン・PWAサービスワーカーを**まとめてHTTPS配信**する。HTMLだけコピーしても動かない。配信用ファイルは各25MiB未満にする。`build.json`に成果物のサイズ・SHA-256を記録する。

PCKとHTMLシェル・補助JSのSHA-256から版識別を作り、JS/PCK/圧縮WASMへの要求とPWAキャッシュを一致させる。旧版のサービスワーカーから古いゲームデータが返ることを避ける。保存領域は同じoriginで維持する。

表示の基準サイズは720×320、stretchはcanvas_items/expandに固定する。回転時にcontent_scale_sizeを書き換えない。ブラウザのcanvasResizePolicyは0とし、web/viewport.jsだけがCSS寸法とDPRを掛けたWebGL寸法を更新する。Godotはこの実寸を読み、縦横を同じ倍率で拡大して余白なく表示する。サイズ設定をGodotとJSの両方で管理すると回転時に競合する。

UI回帰テストは `godot --headless --path . --script res://tests/ui_smoke.gd`。同一ゲームを縦→横→縦→横と切り替え、DPR=3相当も含め、実画面を埋めるか、セルが潰れないか、画面座標を戻せるかを確認する。Webビルド後は `node tests/web_viewport.mjs /absolute/path/to/dist` で配信用JSとGodotの実際の表示サイズ関数を検証する。これらは実ブラウザ・実機の全画面権限やタッチ確認の代わりにはならない。

公開先Sitesの配信用ソースにはコンパイル済みWeb出力があり、ゲームのGDScript正本はGitHubにある。GDScriptを変更したらWebを書き出し直して配信先も更新する。旧APKを自動更新した扱いにしない。

## Grokと共同作業する手順

1. GitHub最新HEADとこの2文書を読む。担当範囲（例: AI、経済、UI、マップ）を明示する。
2. 作業ブランチを分ける。同じファイルを同時に変更する場合は変更を取り込んでから次の担当が着手する。
3. UI改良なら原則ui/web、ルール変更ならcore/data。ルールを描画側へ複製しない。
4. 追加数値は実行ルールJSONに置き、Cの独自調整として記録。未実測の原作値をAに昇格しない。
5. 修正の引き金と期待結果をテストする。UIなら「ボタン/タップ→pending→step→状態」まで検証。
6. コア挙動を意図的に変えた場合は、まず失敗の理由を調べる。goldenを更新するなら変更理由を記録して明示的にrecord_goldenを実行し、その後別のテストを実行する。単にテストを通すためにgoldenを書き換えない。
7. 保存形式の変更では互換性、JSON正規化、チェックサム、リプレイの扱いを説明する。旧形式を黙って破棄しない。
8. PR/変更報告に、変更ファイル・動作例・実行テスト・実機で未確認の項目を書く。ゲーム変更時はGAME_SYSTEMも更新する。

## 現在の課題

原作との差分・未確定値、複数面、魔物、同盟、難易度、実機でのタッチ・速度・保存・PWA検証。古いOPEN_QUESTIONSには現行コードと違う記述がある（AI優先順位、王分裂の未実装記述など）。判断時は現在の実装とGAME_SYSTEMを優先して照合する。
