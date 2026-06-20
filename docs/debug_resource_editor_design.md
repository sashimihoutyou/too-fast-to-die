# デバッグリソースエディター 設計書

## 1. 概要

Godot上で動作するインゲームリソースエディター。デバッグビルド時のみ利用可能で、`resources/`フォルダ以下の全`.tres`リソースファイルを閲覧・編集・作成・削除できる。Resourceクラスの`@export`プロパティをリフレクションで自動検出し、任意のResourceサブクラスに対応する汎用設計とする。

## 2. 確定仕様

| 項目 | 決定 |
|---|---|
| 起動方法 | タイトル画面ボタン + 全画面共通ショートカット(F12) |
| 表示方式 | オーバーレイ（ゲーム画面の上に重ねて表示） |
| ビューポート | 1080x600 → 1920x1080に拡大（**別フェーズ**で実施。エディターは現行解像度でも動作する設計とする） |
| Texture2D編集 | プレビュー表示 + FileDialogで画像選択 |
| リソース対応 | 汎用（`get_property_list()`でリフレクション） |
| 保存方式 | 保存ボタン + 確認ダイアログ → `ResourceSaver.save()` |
| ホットリロード | 保存後にDatabase系Autoloadを即時リロード |
| CRUD | 新規作成・複製・削除（削除時も確認ダイアログ） |
| アクセス制御 | `OS.is_debug_build()` 時のみ有効 |

## 3. 対象リソース

| フォルダ | クラス | 備考 |
|---|---|---|
| `resources/cards/` | `CardData` | キャラ別サブフォルダ(7種)+shared+starter+contamination |
| `resources/events/` | `EventData` | サブリソース`EventChoiceData`を内包 |
| `resources/enemies/` | `EnemyData` | act1-5別サブフォルダ |
| `resources/bike_parts/` | `BikePartData` | `stats: Dictionary`（自由形式） |
| `resources/characters/` | `CharacterData` | 5キャラ |
| `resources/companions/` | `CompanionData` | |
| `resources/items/` | `ItemData` | 新規追加（消耗品+レリック） |

## 4. アーキテクチャ

### 4.1 コンポーネント構成

```
DebugEditorManager (Autoload)
│   F12キー監視、オーバーレイの表示/非表示制御
│
└── ResourceEditorOverlay (CanvasLayer, layer=100)
    │   全画面オーバーレイ、背景半透明
    │
    └── EditorPanel (Panel)
        ├── ToolBar (HBoxContainer)
        │   ├── 新規作成ボタン
        │   ├── 複製ボタン
        │   ├── 保存ボタン
        │   ├── 削除ボタン
        │   └── 閉じるボタン
        │
        ├── ResourceBrowser (左パネル: VSplitContainer)
        │   ├── SearchBar (LineEdit)
        │   └── ResourceTree (Tree)
        │       resources/以下のフォルダ・ファイルをツリー表示
        │
        └── PropertyEditor (右パネル: ScrollContainer)
            ├── ResourceHeader (id, クラス名, ファイルパス)
            └── PropertyList (VBoxContainer)
                動的に生成されるプロパティウィジェット群
```

### 4.2 ファイル構成

```
scenes/debug/
├── debug_editor_overlay.tscn    # エディターオーバーレイシーン
└── debug_editor_overlay.gd      # メインエディタースクリプト

scripts/debug/
├── debug_editor_manager.gd      # Autoload: F12監視、オーバーレイ管理
├── resource_browser.gd          # リソースツリー管理
├── property_editor.gd           # プロパティエディター管理
├── property_widgets.gd          # 各種プロパティウィジェット生成
└── resource_hot_reload.gd       # ホットリロード処理
```

### 4.3 Autoload登録

`project.godot` の `[autoload]` セクション末尾に追加:

```ini
DebugEditorManager="*res://scripts/debug/debug_editor_manager.gd"
```

## 5. 詳細設計

### 5.1 DebugEditorManager

```
責務:
- OS.is_debug_build() チェック（非デバッグ時は何もしない）
- F12キー入力でオーバーレイの表示/非表示トグル
- オーバーレイシーンの遅延ロード（初回F12時に生成）
- タイトル画面へのエディターボタン追加

ライフサイクル:
1. _ready(): デバッグビルドでなければ即return
2. _unhandled_input(): F12検知 → toggle_editor()
3. toggle_editor(): オーバーレイの表示/非表示切替
   - 表示時: get_tree().paused = true（ゲームを一時停止）
   - 非表示時: 未保存変更チェック → 確認ダイアログ表示後にget_tree().paused = false
4. 閉じる時の未保存チェック:
   - dirty flag が立っている場合、「保存されていない変更があります」ダイアログ表示
   - [保存] → 保存処理実行後に閉じる
   - [破棄] → 変更を破棄して閉じる
   - [キャンセル] → エディターを開いたままにする

注意: process_mode = PROCESS_MODE_ALWAYS に設定し、
      ポーズ中も入力を受け付ける
```

### 5.2 ResourceBrowser

```
責務:
- resources/ 以下のディレクトリ構造をTree UIで表示
- フォルダの展開/折りたたみ
- .tres ファイル選択時にPropertyEditorへ通知
- 検索フィルタ（ファイル名 + id + display_name の部分一致）

検索インデックス:
- ツリー構築時に各.tresをロードし、id/display_nameをメタデータに保持
- 検索時はメタデータをフィルタ（リソースの再ロード不要）

ツリー構造:
resources/
├── cards/
│   ├── beast_master/
│   │   ├── bm01 (CardData)
│   │   └── ...
│   └── shared/
│       └── ...
├── events/
│   └── settlement/
│       └── beast_threat (EventData)
└── ...

各ツリーアイテムのメタデータ:
- file_path: String        # res:// パス
- resource_class: String   # "CardData", "EventData" 等
- is_directory: bool

シグナル:
- resource_selected(path: String)  # .tres選択時
```

### 5.3 PropertyEditor

```
責務:
- 選択されたリソースを読み込み、@exportプロパティをUI化
- プロパティ変更をメモリ上のリソースに反映
- 未保存状態の追跡（dirty flag）

プロパティ検出フロー:
1. resource.get_property_list() で全プロパティ取得
2. usage に PROPERTY_USAGE_STORAGE を含むものをフィルタ
3. 各プロパティの type, hint, hint_string から適切なウィジェットを生成

ウィジェット マッピング:
┌─────────────────┬──────────────────────────────────────────────┐
│ 型/ヒント        │ ウィジェット                                   │
├─────────────────┼──────────────────────────────────────────────┤
│ TYPE_INT         │ SpinBox (min/max をhint_stringから解析)       │
│ TYPE_FLOAT       │ SpinBox (step=0.01)                         │
│ TYPE_STRING      │ LineEdit (短文) / TextEdit (description等)    │
│ TYPE_STRING_NAME │ LineEdit                                     │
│ TYPE_BOOL        │ CheckBox                                     │
│ TYPE_INT + ENUM  │ OptionButton (enumメンバをhint_stringから解析) │
│ TYPE_ARRAY + ENUM│ CheckBoxGroup (複数選択)                      │
│ TYPE_OBJECT +    │ TexturePreview + FileDialogボタン             │
│   Texture2D      │                                              │
│ TYPE_DICTIONARY  │ キー・値ペアの動的リスト                        │
│ TYPE_ARRAY +     │ インライン子エディター (展開/折りたたみ可能)      │
│   SubResource    │                                              │
└─────────────────┴──────────────────────────────────────────────┘

除外プロパティ:
- resource_local_to_scene, resource_path, resource_name, script
- instance_id などの非@exportプロパティ
```

### 5.4 プロパティウィジェット詳細

#### 5.4.1 Enum プロパティ (OptionButton)

```
hint_string の形式: "VAL_A:0,VAL_B:1,VAL_C:2"
→ OptionButton のアイテムとして追加
→ 選択変更時に resource.set(property_name, selected_value)
```

#### 5.4.2 Array[Enum] プロパティ (CheckBoxGroup)

```
例: tags: Array[Tag] → [MELEE, RANGED, BIKE, DEFENSE, SKILL, CHARACTER]
各enum値ごとにCheckBoxを生成
チェック状態から配列を再構築して resource.set()
```

#### 5.4.3 サブリソース (EventChoiceData等)

```
Array[EventChoiceData] の場合:
├── [0] EventChoiceData ▼ (折りたたみヘッダー + 削除ボタン)
│   ├── label: LineEdit
│   ├── requirement: LineEdit
│   ├── result_text: TextEdit
│   ├── fuel_change: SpinBox
│   └── ...
├── [1] EventChoiceData ▼
│   └── ...
└── [+ 追加] ボタン

追加時: EventChoiceData.new() を生成して配列に追加
削除時: 配列から除去、UIを再構築
```

#### 5.4.4 Dictionary プロパティ (BikePartData.stats等)

```
既存エントリ:
├── キー: LineEdit | [int ▼] 値: SpinBox  [×削除]
├── キー: LineEdit | [float▼] 値: SpinBox  [×削除]
└── [+ エントリ追加] ボタン

型の扱い:
- 既存エントリ: typeof() で現在の値の型を検出し、適切なウィジェットを自動選択
  - TYPE_INT → SpinBox (整数)
  - TYPE_FLOAT → SpinBox (step=0.01)
  - TYPE_STRING → LineEdit
- 新規エントリ: 型選択ドロップダウン [int / float / String] を表示
  → 型を選択してからウィジェットを生成
- 文字列からの型推定は行わない（"01"→1 等の誤変換を防止）
```

#### 5.4.5 Texture2D プロパティ

```
┌──────────────────────────────────┐
│ [128x128 プレビュー]              │
│ パス: res://art/cards/bm01.png   │
│ [変更...] [クリア]                │
└──────────────────────────────────┘

[変更...] → FileDialog (フィルタ: *.png, *.jpg, *.svg, *.webp)
            root: res://
[クリア]  → null を設定
```

### 5.5 CRUD操作

#### 新規作成

```
1. ToolBarの「新規作成」ボタン押下
2. リソースタイプ選択ダイアログ表示
   - CardData, EventData, EnemyData, BikePartData,
     CharacterData, CompanionData, ItemData
   - （汎用設計のため将来追加されたクラスも検出可能にする）
3. 保存先フォルダ選択（ResourceBrowserで現在選択中のフォルダをデフォルト）
4. ファイル名入力
5. 新規Resourceインスタンス生成 → PropertyEditorに表示
6. 保存操作で.tresファイルを作成
```

#### 複製

```
1. 現在開いているリソースの duplicate(true) を生成
2. id を "元id_copy" に変更
3. PropertyEditorに表示（未保存状態）
4. 保存時にファイル名を入力
```

#### 削除

```
1. 確認ダイアログ:「(ファイル名) を削除しますか？この操作は元に戻せません。」
2. OK → DirAccess.remove_absolute() でファイル削除
3. ResourceBrowser のツリーを更新
4. ホットリロード実行
```

### 5.6 保存フロー

```
1. 「保存」ボタン押下
2. バリデーション実行
   - id が空でないこと
   - id が他リソースと重複していないこと（同一フォルダ内）
   - 必須フィールドチェック（display_name等）
3. バリデーションエラー → エラーメッセージ表示、保存中断
4. 確認ダイアログ:「(ファイルパス) に保存しますか？」
   - 新規の場合: ファイルパス入力フィールド付き
   - 既存の場合: 上書き確認
5. OK → ResourceSaver.save(resource, path)
6. ホットリロード実行
7. dirty flag クリア、タイトルバーの * マーク除去
```

### 5.7 ホットリロード

```
保存完了後に以下を実行:

1. 保存したリソースのパスからどのDatabaseに属するか判定
   resources/cards/     → CardDatabase
   resources/enemies/   → EnemyDatabase
   resources/bike_parts/→ BikePartsDatabase
   resources/events/    → EventManager
   (その他は個別のAutoloadが無いためスキップ)

2. 該当Databaseの内部データを再ロード
   - CardDatabase: _cards辞書をクリア → _load_cards_from_directory() を再実行
   - EnemyDatabase: 同様のリロードメソッド呼び出し
   - 等

3. 必要に応じてリロード完了シグナルを発行
   → UIが更新される場合に備える

注意:
- 進行中の戦闘やイベントが保持する既存のResourceインスタンス参照は
  更新されない（次回参照時に新データを使用）
- GameManager.current_state == COMBAT の場合、保存成功後に
  「戦闘中の変更は次回の戦闘から反映されます」という警告トーストを表示
- リロード自体は常に実行する（Database経由の新規参照には即反映）
```

## 6. UI レイアウト

### 6.1 ビューポート変更（別フェーズ — Phase 0）

エディターとは独立した改修として切り出す。

```
変更前: 1080 x 600
変更後: 1920 x 1080 (フルHD)

project.godot:
  window/size/viewport_width=1920
  window/size/viewport_height=1080
```

既存UIへの影響調査結果:

| シーン | レイアウト方式 | 影響 |
|---|---|---|
| title_screen | CENTER アンカー | 自動追従、**修正不要** |
| character_select | 要確認 | 要確認 |
| combat_screen | offset固定 (EnemyArea=1060, PlayerHUD=350) | **要修正** |
| map_screen | offset固定 (MapScroll=1080) | **要修正** |
| event_screen | CENTER_TOP アンカー | 自動追従、**修正不要** |
| shop_screen | CENTER_TOP アンカー | 自動追従、**修正不要** |
| rest_screen | 要確認 | 要確認 |
| game_over | 要確認 | 要確認 |

主な修正対象:
- `combat_screen.tscn`: EnemyArea の offset_right を画面幅追従に変更
- `map_screen.tscn`: MapScroll の offset_right をアンカーベースに変更

### 6.2 エディターレイアウト

エディターは**ビューポートサイズに依存しない**レイアウトとする。
アンカーとマージンを使い、1080x600でも1920x1080でも動作する。

左パネル: 画面幅の30%（最小250px、最大400px）
右パネル: 残り幅

```
┌─────────────────────────────────────────────────────────────────────┐
│ ToolBar  [新規▼] [複製] [保存] [削除]               [×閉じる]       │
├───────────────────┬─────────────────────────────────────────────────┤
│ ResourceBrowser   │ PropertyEditor                                  │
│ (幅: 350px)       │ (残り幅)                                        │
│                   │                                                 │
│ [🔍 検索...]      │ ┌─ CardData: bm01 ─────────────────────────┐   │
│                   │ │ パス: res://resources/cards/beast_master/ │   │
│ ▼ resources/      │ │      bm01.tres                    [*未保存]│  │
│   ▼ cards/        │ └────────────────────────────────────────────┘  │
│     ▼ beast_master│                                                 │
│       ● bm01      │ id          [bm01                          ]    │
│       ● bm02      │ display_name[ビーストラッシュ                ]    │
│       ○ bm03      │ description [敵1体に8ダメージ                ]   │
│     ▶ conqueror   │ ap_cost     [▼ 1 ▲]                            │
│     ▶ shared      │ fuel_cost   [▼ 0 ▲]                            │
│   ▶ enemies/      │ tags        ☐MELEE ☑RANGED ☐BIKE ☐DEFENSE     │
│   ▶ events/       │ rarity      [COMMON      ▼]                    │
│   ▶ bike_parts/   │ restriction [BEAST_MASTER ▼]                   │
│   ▶ characters/   │ is_starter  ☐                                  │
│   ▶ companions/   │ is_exhaustible ☐                               │
│   ▶ items/        │ base_damage [▼ 8 ▲]                            │
│                   │ base_block  [▼ 0 ▲]                            │
│                   │ ...                                             │
│                   │ art         [プレビュー] [変更...] [クリア]       │
│                   │                                                 │
├───────────────────┴─────────────────────────────────────────────────┤
│ ステータスバー: resources/cards/beast_master/bm01.tres | CardData    │
└─────────────────────────────────────────────────────────────────────┘
```

## 7. エラーハンドリング

| 場面 | 処理 |
|---|---|
| .tres の読み込み失敗 | ステータスバーにエラー表示、PropertyEditorをクリア |
| バリデーションエラー | プロパティ名を赤ハイライト + エラーメッセージ |
| 保存失敗 | 確認ダイアログでエラー内容を表示 |
| ファイル削除失敗 | エラーダイアログ表示 |
| リフレクションで未対応の型 | "未対応の型: TYPE_XXX" ラベルを表示、編集不可 |

## 8. 実装順序

### Phase 0: ビューポート変更（独立タスク — エディターと別ブランチ推奨）

1. `project.godot` のビューポートサイズを 1920x1080 に変更
2. `combat_screen.tscn` のレイアウト修正（offset固定 → アンカーベース）
3. `map_screen.tscn` のレイアウト修正（MapScroll, HUD）
4. その他画面の確認・調整（character_select, rest_screen, game_over）
5. 全画面の動作確認

※ Phase 0 はエディターの前提条件ではない。エディターは現行1080x600でも動作する。

### Phase 1: 基盤（MVP最小構成）

1. `DebugEditorManager` Autoload作成（F12トグル、ポーズ制御、未保存チェック付き閉じる）
2. `ResourceEditorOverlay` シーン・基本レイアウト作成（アンカーベース、解像度非依存）

### Phase 2: リソースブラウザ

3. `resources/` 以下のディレクトリスキャン → Treeノード生成
4. フォルダ展開/折りたたみ
5. .tres ファイル選択 → シグナル発火
6. 検索フィルタ（ファイル名 + id + display_name）

### Phase 3: プロパティエディター

7. `get_property_list()` によるプロパティ検出・フィルタリング
8. 基本ウィジェット生成（int, float, String, StringName, bool, enum）
9. 配列ウィジェット（Array[Enum]）
10. Dictionaryウィジェット（既存エントリ: typeof()で型検出、新規: 型選択ドロップダウン）
11. Texture2Dウィジェット（プレビュー + FileDialog）
12. サブリソースウィジェット（EventChoiceData等）

### Phase 4: 保存・CRUD

13. 保存機能（バリデーション + 確認ダイアログ + ResourceSaver）
14. 未保存マーク（`*`）・ステータスバー
15. 新規作成（タイプ選択 + ファイルパス入力）
16. 複製機能（duplicate(true) → EventData等のサブリソース複製テスト必須）
17. 削除機能（確認ダイアログ付き）

### Phase 5: ホットリロード

18. Database系Autoloadのリロード処理
19. 戦闘中保存時の警告トースト
20. リロード完了シグナル発行

### Phase 6: 仕上げ・追加機能

21. タイトル画面へのエディターボタン追加
22. エッジケース対応・テスト
23. （将来）Undo/Redo（GodotのUndoRedoクラスを利用）
