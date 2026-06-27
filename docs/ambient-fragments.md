# 移動時アンビエント断章

## 実装入口

- 選出: `scripts/systems/ambient_fragment.gd`
- 表示/遷移制御: `scenes/map/map_screen.gd`
- 直近同行者文脈: `GameManager.recent_companion_event`, `recent_companion_id`, `recent_companion_type`

## 発火順

1. マップでノード選択。
2. 移動コスト支払い。
3. `GameManager.advance_node()`。
4. 追跡発生時は追跡通知を優先し、断章は出さず戦闘へ進む。
5. 燃料発見通知があれば先に表示。
6. 条件付きプールから断章を選出し、モーダルで表示。
7. 閉じたら本来のノード処理へ進む。

## 選出方針

- 直近同行者イベント、同行者あり、PC 固有、ノード種/Act 汎用の順で優先度を付ける。
- 同行者なしは低確率、同行者ありは中確率、直近同行者イベントは確定表示。
- `once_per_run` は `GameManager.event_flags` に `ambient_seen_*` を立てて重複を避ける。
- 将来は `resources/ambient_fragments/*.tres` 化する。現時点ではコード内プール。

## LOVE_SLAVE

- ホタル + LOVE_SLAVE は移動時のエクスタシー +6 と連動する。
- 断章は直接、間接、無言、消耗、依存、離脱後の空席感を混ぜる。
- 追跡など緊急イベントが出た場合は断章より緊急イベントを優先する。
