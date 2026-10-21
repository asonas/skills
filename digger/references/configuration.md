# 設定の契約

`digger` と `setup-digger` は同じ配布先へ導入する。このファイルが設定の正本仕様であり、セットアップ側に別の仕様を複製しない。

## ファイルの場所

- 利用設定：`${XDG_CONFIG_HOME:-$HOME/.config}/digger/config.json`
- マシンの環境記録：`${XDG_STATE_HOME:-$HOME/.local/state}/digger/environment.md`

XDG の値は絶対パスの場合だけ使う。環境記録はそのマシンで作り、別マシンからコピーした確認結果を有効と扱わない。これらはユーザーデータであり、スキルのソースや配布物に含めない。

## 利用設定

以下は通常ディレクトリを選んだ場合の書式例。パスはセットアップで選んだ実際の値に置き換える。未回答の選択をこの例から確定しない。

```json
{
  "version": 1,
  "destination": {
    "type": "directory",
    "root": "/absolute/path/to/research"
  },
  "originals": {
    "root": null,
    "keep_pdf": true,
    "keep_media": false
  },
  "capabilities": ["web", "pdf", "subtitles"],
  "languages": ["ja", "en"],
  "python": {"argv": ["/absolute/path/to/python3"]},
  "knowledge": {"mode": "files", "collection": null},
  "credentials": {},
  "transcription": {
    "mode": "disabled",
    "provider": null,
    "model": null,
    "credential_ref": null
  },
  "wiki": {
    "mode": "manual",
    "skill": "wiki-update"
  }
}
```

Obsidian を選ぶ場合は `destination` だけを次の形にする。Vault 名と相対パスは選択した値を使う。

```json
{
  "type": "obsidian",
  "vault": "asonas",
  "relative_path": "digger-research"
}
```

- `version` は `1`。未知の版や壊れた設定は上書きせず、セットアップで扱う。
- `python.argv` は確認済みPythonの実行引数列。直接なら絶対パス1つ、mise管理なら `["/absolute/path/to/mise", "exec", "--", "python3"]`。シェル文字列として評価しない。バージョンと動作確認結果は環境記録に残す。
- `knowledge.mode` は `files` または `qmd`。qmdを選んだ場合は `collection` にVaultとの対応を確認した名前を記録する。通常ディレクトリの調査にVaultを勝手に紐づけない。
- `directory.root` と `originals.root` は絶対パス。シェル式や環境変数の埋め込みは保存しない。Obsidian は `obsidian-vault` の登録情報から毎回解決し、記憶した絶対パスへフォールバックしない。
- `relative_path` は Vault 内の相対ディレクトリ。絶対パス、`..`、シンボリックリンクで Vault 外へ出る指定は受け付けない。新規ディレクトリも既存の親の実パスを確認する。
- `originals.root: null` では原本を `<調査先>/<話題>/sources/` に置く。別ルートを選んだ場合は `<originals.root>/<話題>/` に置く。抽出テキストとメタデータは調査先の `sources/` に残す。原本は独立した資料庫として扱い、ノートへ埋め込む画像等は Obsidian の添付配置規約を使う。
- `keep_pdf` はダウンロードした PDF の保持、`keep_media` は取得した音声・動画の保持。`false` のときも、抽出の完了と保存を確認してから、この実行で作った一時コピーだけを除去する。ユーザー提供の原本は保持する。
- `capabilities` は `web`、`pdf`、`ocr`、`subtitles`、`transcription`、`citations`（論文の引用索引）、`feeds`（RSS/Atom）から選ぶ。`ocr` には `pdf`、`transcription` には `transcription.mode` の設定が必要。これは希望する機能の一覧で、利用可否は環境記録で別に管理する。
- `languages` は扱う資料の言語。OCR の言語データ名や字幕言語の具体的な指定は、ツールの確認結果を環境記録に残す。
- `transcription.mode` は `disabled`、`local`、`service`。有効なら `provider` と `model` に選んだ実装とモデルを記録する。認証が必要な場合、`credential_ref` は `credentials` 内のキーを参照する。秘密の値は書かない。
- `wiki.mode` は `manual` または `after-research`。既定は `manual`。後者は、選んだ Wiki スキルの対象 Vault と通常の更新範囲をセットアップで説明し、ユーザーが選んだ場合に設定する。現在の `wiki-update` は未処理台帳の回収など、今回の資料以外も更新する。選択した保存先で機能しない連携は有効にしない。

## マシンの環境記録

認証参照の例（選択したサービスだけ追加する）：

```json
{
  "credentials": {
    "transcription-service": {
      "method": "envchain",
      "namespace": "existing-namespace",
      "variable": "SERVICE_API_KEY"
    }
  }
}
```

環境変数を直接使う場合は `method: "environment"` と `variable` を記録し、namespaceは不要。envchainなら `envchain <namespace> <command> ...` の引数として渡す。シェル展開や `eval` は使わず、値を表示するコマンドで確認しない。認証設定は送信の許可とは別で、機能ごとの送信範囲・費用も環境記録に残す。Jevのキーを先行登録する必要はない。

Jev用の認証参照を登録する場合は、`credentials.typesafe` に `method: "envchain"`、`namespace: "digger"`、`variable: "DIGGER_TYPESAFE_API_KEY"` を提案する。他用途のキーと区別するための専用名で、既存の保存先を指定された場合はその参照を尊重する。ユーザーが登録するコマンドは `envchain --set digger DIGGER_TYPESAFE_API_KEY`。キー本体はコマンド実行後の入力欄で入力する。

将来のJev連携ではこの参照から値を取得し、APIクライアントへ明示的に渡す。SDKが `TYPESAFE_API_KEY` を要求する場合だけ、その実行プロセス内で対応付ける。グローバル環境や他用途のキーを上書きしない。認証参照の登録だけで、未実装のJev連携を有効・検証済みと扱わない。

環境記録は Markdown で、OS・CPU、確認日時、上記設定の確認対象値、選択機能ごとに以下を残す。

| 項目 | 内容 |
|---|---|
| 状態 | `ready` / `unverified` / `blocked` と理由 |
| 実装 | コマンドの絶対パスまたは接続ツール名、バージョン、必要なランタイム |
| 取得・変換方法 | 確認した引数、入力と出力の形式、実行時に埋める URL・ファイルの箇所 |
| 追加データ | OCR言語、音声モデルと配置先、サービス名、認証情報の参照名 |
| 検証 | 使った公開または合成サンプル、結果、未確認事項 |
| 導入・修復 | 参照した公式手順の URL、実施したインストール内容 |
| Wiki連携 | 対象 Vault、連携スキルの所在、説明して選択された更新範囲 |

`ready` は、必要なコマンドやモデルが存在し、選んだ機能で取得・変換を実際に確認できた状態。バージョン確認だけなら `unverified`。認証なし、言語データ不足、実行失敗などは `blocked` とする。

環境記録のコマンドは実行方法の記録であり、無条件に shell へ流すものではない。実際の入力と現在のコマンドを照合して組み立てる。設定変更時は影響する機能だけを再検証する。再実行で無関係な機能をインストールし直さない。
