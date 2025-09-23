# 注意

これは個人的に使っている gem です。ノーサポート、ノー後方互換性なのでもし使いたい人がいたら fork をおすすめします。

# ai_lint

AI にコードレビューをさせるための **シンプルな CLI ツール**
ルール（Markdown）、AI エンジン、並列数を必ず指定し、対象ファイルを渡すだけでレビューを実行します

---

## インストール

Gemfile に追加:

```ruby
gem "ai_lint", github: "your/repo"
```

またはローカルで実行権限を付与:

```bash
chmod +x bin/ai_lint
```

---

## 使い方

```bash
ai_lint -r RULE.md -a (claude|codex) -j NUM FILE [FILE...]
```

### 必須オプション

- `-r, --rule PATH`
  ルール Markdown ファイル

- `-a, --ai ENGINE`
  使用する AI エンジン (`claude` または `codex`)

- `-j, --jobs NUM`
  並列ジョブ数（整数）

### 引数

- `FILE...` : チェック対象ファイル（1 つ以上）

---

## 使用例

### Rails の MVC ルールでモデルとコントローラをチェック

```bash
ai_lint -r lint/rails_mvc.md -a claude -j 5 app/models/user.rb app/controllers/users_controller.rb
```

### Haml ビューを Codex で並列 3 ジョブ実行（明示パス指定）

```bash
ai_lint --rule lint/haml_style.md --ai codex --jobs 3 app/views/posts/new.html.haml app/views/posts/edit.html.haml
```

---

## ファイル指定について（重要）

- この CLI は「特定のファイルパス」を引数として渡す仕様です。
- グロブ（`**/*.rb` 等）やディレクトリを渡す使い方は想定していません。対象ファイルは明示的に列挙してください。

## 出力

- 問題がないファイル

  ```
  ✅ app/models/user.rb に問題はありません
  ```

- 問題があるファイル

  ```
  ❌ app/controllers/users_controller.rb に問題があります
     - Fat Controller: アクションが肥大化しています
     - before_action の副作用が不明確です
  ```

- 全体の結果

  ```
  🎉 AI Lint 通過
  ```

  または

  ```
  ❌ AI Lint 失敗: app/controllers/users_controller.rb に問題があります
  ```

終了コードは **成功で 0、失敗で 1** を返します。

---

## ルールファイルの例

`lint/rails_mvc.md`

```markdown
# Rails MVC Lint

- Fat Controller を避け、責務を分割すること
- before_action の副作用は最小限で明示的にすること
- View にロジックを持たせないこと
```

### シンプルなテスト用ルール例

`spec/fixtures/rule.md`

```markdown
# AI Lint ルール（テスト用）

- 先頭に `#` で始まるコメント行を必ず 1 行以上含めること。
- コードはすべて日本語の文字のみで記述されていること（アルファベット・数字・記号は一切不可）。
```

設計方針: ルールファイルには「審査基準（ポリシー）」のみを書きます。出力形式（JSON スキーマや `status`/`messages` のキー）はエンジンアダプタ側のプロンプトで統一的に指示し、中央でパース/検証します。

```

---

## 注意事項
- `claude` または `codex` CLI が事前にインストールされている必要があります
- APIは使いません
- JSON 出力が得られなかった場合は NG として扱われます
- 並列実行数は指定必須です (`-j`)

ヒント: ルールファイルは純粋にプロジェクトの規約だけを書いてください。出力形式（JSONのみ等）の指示はエンジン側のプロンプトで自動付与されます。

---

## ライセンス

MIT

```
