# Jevによる根拠と引用の確認

`jev.enabled: true` なら、調査前の既存資料確認と、抜き書きの文字列照合後に `scripts/jev.py` を実行する。キーの存在だけでは有効化しない。通常の調べものすべてで起動する機能ではなく、diggerの手順内で実行者が呼ぶ補助である。

## 設定

`config.json` の既存設定に次を追加する。値はセットアップで選ぶ。以下の上限は初期提案で、金額の上限ではない。

```json
{
  "jev": {
    "enabled": true,
    "model": "jev-latest",
    "credential_ref": "typesafe",
    "allowed_roots": ["/absolute/path/to/research"],
    "max_requests_per_topic": 8,
    "max_request_bytes": 60000
  },
  "credentials": {
    "typesafe": {
      "method": "envchain",
      "namespace": "digger",
      "variable": "DIGGER_TYPESAFE_API_KEY"
    }
  }
}
```

`allowed_roots` は問い・主張・資料本文をTypeSafeへ送信してよいディレクトリの絶対パス。調査先に加え、既存Wikiや原典を送るならその範囲も個別に選ぶ。Vault全体を暗黙に許可しない。各入力ファイルと原典の実パスを検査し、範囲外へのsymlinkも拒否する。許可されていない文章を許可済みフォルダにコピーして回避しない。

Python 3.10以上の標準ライブラリで固定の `https://api.typesafe.ai/v1/systemone` にPOSTする。SDK、uv、仮想環境は不要。envchain方式ならコマンドの存在を確認し、スクリプトが指定namespaceで自身を再実行する。キーは指定変数からAuthorizationヘッダーへ渡し、`TYPESAFE_API_KEY` の上書きはしない。直接通信が禁止された実行環境では実行せず、未確認として読解へ戻す。

`model` はセットアップ時に利用可能なものを確認して選ぶ。`jev-latest` は追随する別名なので、比較評価では固定バージョンを選ぶ。料金は[公式情報](https://docs.typesafe.ai/models)で確認し、回数・送信量とともに環境記録に残す。

## 調査前：既存資料の不足と鮮度

qmdまたはファイル検索で候補を探し、Wikiから原典まで読んだ後、調査ディレクトリに `knowledge.json` を作る。`file` はそのディレクトリからの相対パス、または許可範囲内の絶対パス。`line` / `end` は1始まり・両端を含む。本文の日付や版、適用条件、反証も含め、要約だけを根拠にしない。

```json
{
  "question": "日本語の測定条件は確認できるか",
  "as_of": "2026-10-21",
  "freshness_requirement": "",
  "claims": [{
    "claim": "日本語の測定条件が明記されている",
    "evidence": [{"file": "sources/study.md", "line": 1, "end": 30}]
  }]
}
```

鮮度の要求がなければ空文字。資料なしの論点は `evidence: []` とする。送信するのは問い・論点・指定範囲の原文・時点と鮮度要求で、ローカルパスは送らない。

設定したPython実行経路で、スキルの実パスを使って実行する（以下はmise環境の例）。

```sh
mise exec -- python3 /path/to/digger/scripts/jev.py gaps /path/to/topic --preview
mise exec -- python3 /path/to/digger/scripts/jev.py gaps /path/to/topic
```

`--preview` は通信・認証取得・記録を行わず送信内容を表示する。セットアップで範囲を確認済みなら毎回承認を取り直さない。内容を会話に貼る必要はない。

各論点に `sufficient / missing / conflicting / uncertain`、別の質問で鮮度を `current / refresh / unknown / not_required` と判定する。根拠と対応させて読み、不足・矛盾は次の探索へ、更新の必要は最新確認へ回す。鮮度要求があるのに `unknown` なら日付・版を確認する。`sufficient` だけを理由に探索を終了しない。

## 取得後：抜き書きの文脈

```sh
mise exec -- python3 /path/to/digger/scripts/report.py /path/to/topic --check
mise exec -- python3 /path/to/digger/scripts/jev.py citations /path/to/topic
```

`extracts.json` のclaimsとdisagreementsの全引用を再照合し、1件でも不一致なら一切送信しない。Jevには論点・引用と原典本文を渡す。既定は原典全体。長すぎる場合は引用に `context_start` / `context_end` を付け、節や前後の段落を含む範囲を選ぶ。元の行番号は保持し、否定や条件を切り落とさない。無指定の終端は末尾。省略した文脈があることはモデルへも知らせる。自動切り詰めはしない。

判定は `supported / qualified / contradicted / unsupported / uncertain`。条件不足なら周辺を読み直して引用範囲か説明を修正し、矛盾なら両方の原典を残す。`supported` も実行者が原文を確認する。Jevは翻訳・原文・claimのstatusを書き換えない。修正後の判定が必要なら再実行する。

## 記録と失敗時

1実行で最大24項目を1リクエストにまとめる。サイズ超過は送信前に止める。上限を上げるより、必要なまとまった節を選ぶ。抜き書きを黙って除外して「全件確認済み」にしない。

`topic/jev/attempts.jsonl` に送信前の予約を追記し、ファイルロックで同時実行時の上限も守る。API失敗・中断も1回に数え、自動再試行しない。上限はtopic全体・両モード共通で、削除や別topicへのコピーで回避しない。増額が必要ならセットアップで上限を変更する。

結果は毎回別の `topic/jev/result-*.json` に保存する。mode、原典位置、送信内容のSHA-256、要求モデル、実際のモデル、全選択肢の確率、confidence、使用トークン数、時刻を残す。`log.md` へ結果パスと実行者の判断を追記する。既存のレポートや原典は上書きしない。原典・引用・問い・モデルを変更したら古い結果を使わず、previewのハッシュで同じ入力か確認する。

終了コード0は判定取得成功または無効、1は未確認・失敗。API失敗は `unverified` の記録を残す。設定・入力・認証の失敗は通信せずstderrで知らせるので、実行者がlogへ記録する。`disabled`、未設定、API失敗、上限到達では通常の原典読解を続け、Jev確認済みと書かない。

全判定は `requires_review: true`。confidenceは分布の集中度で、正しさや調査の網羅率ではない。閾値で自動採用・自動終了しない。従来の終了条件を維持し、日本語を含む実資料で精度を評価してから変更を検討する。

実装根拠：[System One API](https://docs.typesafe.ai/api/system-one)、[Choice](https://docs.typesafe.ai/primitives/choice)、[引用チェック](https://docs.typesafe.ai/cookbooks/citation_check)、[confidence](https://docs.typesafe.ai/confidence)。2026-10-21確認。
