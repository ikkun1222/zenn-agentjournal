# zenn-agentjournal

agentjournal.dev の Zenn 記事リポジトリ。GitHub連携で `articles/*.md` を push → Zenn 自動公開。

## 運用（監修型・2-4本/月）

1. `python3 scripts/zenn-publish.py new --slug <slug> --title "..." --emoji "🤖" --type tech --topics "agent,llm,automation" --draft articles/<slug>.md`
   - `published: false` で draft 生成（相互リンク末尾に自動付与）
2. 本文執筆（実録ジャーナル — 現場の一次情報・ログ・実運用事例ベース・誇張なし）
3. `python3 scripts/zenn-publish.py verify articles/*.md` で品質ゲート
4. レビュー後 `python3 scripts/zenn-publish.py publish articles/<slug>.md --at "2026-08-20 19:00"` → `published: true`
5. `git push` で Zenn に反映

## Zenn側 設定

- Zennダッシュボード → GitHub連携 → このリポジトリ（`zenn-agentjournal`）の `main` を登録
- Publication `agent-journal` 推奨（未作成なら個人 `ikkun1222` でOK）

## 声

- 英語の本家（agentjournal.dev）と同じく実録・一次情報ベース。日本語版は `です・ます` で建設的に。
- 未検証の数字は `[数字+出典]` プレースホルダにせず、事実ベースの定性表現で出す。

## 文体

です・ます調で統一。
