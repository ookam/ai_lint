# Changelog

## 0.0.2 (2025-09-23)
- Fix: JSON 抽出の厳格化により、プロンプト内の例示 JSON（`"status":"ok|ng"`, `messages: ["..."]`）を無効として除外
- Change: 出力内の複数 JSON 候補から「最後の妥当な JSON」を採用
- Result: OK なのに `- ...` が表示され NG 扱いになる不具合を解消

## 0.0.1
- Initial release
