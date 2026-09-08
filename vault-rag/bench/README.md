# 検索品質の測定

実際の質問と正解ノートの組はVaultの `.agent-state/vault-rag/vault-fixture.json` に保存します。測定結果・比較記録も同じローカル領域に置き、公開スキルには含めません。

## 手順

1. 対象Vaultに存在するノートから質問と正解を作り、`verify-fixture.rb` で検査します。
2. qmdのインストール済みバージョンの `qmd bench --help` を確認し、同じ質問セットで変更前後を測ります。
3. JSON結果を `report.rb` で比較します。質問セットが違う測定は同条件の比較として扱いません。

```sh
mise exec -- ruby verify-fixture.rb
mise exec -- ruby verify-fixture.rb /absolute/path/to/local-fixture.json
mise exec -- ruby report.rb /absolute/path/to/before.json /absolute/path/to/after.json
```

`OBSIDIAN_VAULT` を指定する場合も `obsidian-vault` の共通処理で登録先との一致を検証します。既定の質問ファイルはそのVaultから解決します。ファイルがない場合は測定を保留し、架空の例を実際の検索品質の証拠にしません。

## 質問の形式

以下は架空の例です。実際に存在するノートと、本文から独立に確認した正解を使ってください。

```json
{
  "collection": "example",
  "queries": [{
    "id": "example-note",
    "type": "exact",
    "query": "lex: Example\nvec: Exampleという道具の設定手順",
    "expected_files": ["wiki/Example.md"],
    "expected_in_top_k": 3
  }]
}
```

検査対象は、正解ファイルの存在、クエリの `lex:`・`vec:` 行、相対パス、IDの重複です。Wikiの状態を点検する手順は `wiki-update/health/README.md` を参照してください。
