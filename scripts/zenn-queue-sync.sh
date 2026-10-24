#!/usr/bin/env bash
# Zenn の投稿上限で同期が止まったときの「1日1本ずつ流す」キュー処理。
#
# 前提: Zenn の GitHub 連携は push がトリガー。上限で弾かれた記事は
#       リポジトリに残るが取り込まれないので、上限が回復したあとに
#       改めて push してやる必要がある。
#
# 動作（1回の実行で最大1本）:
#   1. articles/*.md のうち Zenn API に無い slug を「待機中」と判定
#   2. 待機中が無ければ notes/pending/*.md から1本だけ articles/ へ昇格
#   3. 待機中の先頭1本に無害な変更（末尾改行のトグル）を入れて commit + push
#   4. 反映は次回実行時に確認（API に現れていれば昇格を進める）
#
# 使い方:
#   scripts/zenn-queue-sync.sh            # 実行
#   scripts/zenn-queue-sync.sh --dry-run  # 判定だけ表示
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"
PY=/usr/bin/python3
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0 Safari/537.36"

# 1) 状態判定
mapfile -t STATE < <($PY - <<'PY'
import json, pathlib, re, urllib.request, sys
UA={"User-Agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0 Safari/537.36"}
def live():
    try:
        d=json.loads(urllib.request.urlopen(urllib.request.Request(
            "https://zenn.dev/api/articles?username=neomaru&count=100", headers=UA), timeout=30).read())
        return {a.get("slug") for a in d.get("articles",[])}
    except Exception as e:
        print("ERR", e); sys.exit(3)
have = live()
arts = {}
for p in pathlib.Path("articles").glob("*.md"):
    t = p.read_text(encoding="utf-8")
    m = re.search(r'^published_at: (.*)$', t, re.M)
    arts[p.stem] = (m.group(1) if m else "9999")
queued = sorted((k for k in arts if k not in have), key=lambda k: arts[k])
print("HAVE", len(have))
for q in queued: print("QUEUED", q, arts[q])
pend = sorted(pathlib.Path("notes/pending").glob("*.md")) if pathlib.Path("notes/pending").exists() else []
for p in pend:
    t = p.read_text(encoding="utf-8")
    m = re.search(r'^published_at: (.*)$', t, re.M)
    print("PENDING", p.name, m.group(1) if m else "9999")
PY
)

echo "== Zenn queue state =="
printf '%s\n' "${STATE[@]}"

QUEUED=(); PENDING=()
for line in "${STATE[@]}"; do
  case "$line" in
    QUEUED\ *)  QUEUED+=("${line#QUEUED }") ;;
    PENDING\ *) PENDING+=("${line#PENDING }") ;;
  esac
done

TARGET=""
if [ ${#QUEUED[@]} -gt 0 ]; then
  TARGET="${QUEUED[0]%% *}"
  echo "== 待機中の先頭を再push: $TARGET"
elif [ ${#PENDING[@]} -gt 0 ]; then
  # 待機ゼロ = 前回の記事が反映された -> 次の pending を1本だけ昇格
  FILE="${PENDING[0]%% *}"
  echo "== pending から昇格: $FILE"
  [ $DRY -eq 1 ] && { echo "(dry-run) git mv notes/pending/$FILE articles/$FILE"; exit 0; }
  git mv "notes/pending/$FILE" "articles/$FILE"
  TARGET="${FILE%.md}"
else
  echo "== キューは空（昇格待ちも無し）"
  exit 0
fi

[ $DRY -eq 1 ] && { echo "(dry-run) nudge + commit + push: articles/$TARGET.md"; exit 0; }

# 2) 無害な変更で sync を再トリガー（末尾の改行数トグル）
$PY - "$TARGET" <<'PY'
import pathlib, sys
p = pathlib.Path(f"articles/{sys.argv[1]}.md")
t = p.read_text(encoding="utf-8")
p.write_text(t[:-1] if t.endswith("\n\n") else t + "\n", encoding="utf-8")
print("nudged:", p, len(p.read_text(encoding='utf-8')))
PY

git add -A
if git diff --cached --quiet; then
  echo "== 変更なし（スキップ）"; exit 0
fi
git -c user.name=hermes -c user.email=hermes@localhost commit -q -m "zenn: queue sync trigger ($TARGET)"
git push origin main
echo "== pushed（反映は次回実行時に API で確認）"
