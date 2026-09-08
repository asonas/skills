# Wikiの点検

`wiki-health.rb` はWikiの構造・更新状況、`mentions.rb` は言及の取りこぼし、`verify-sources.rb` は出典の要確認箇所を調べます。検索品質は `vault-rag/bench/` の担当です。

## 実行

このディレクトリを作業ディレクトリにして実行します。

```sh
mise exec -- ruby wiki-health.rb
mise exec -- ruby wiki-health.rb --json
mise exec -- ruby mentions.rb daily/YYYY-MM-DD.md
mise exec -- ruby mentions.rb --candidates daily/YYYY-MM-DD.md
mise exec -- ruby verify-sources.rb --quiet
```

`mentions.rb` の引数はVault相対パスです。候補にはノイズがあるため、本文を読んでページ化を判断します。`verify-sources.rb` はページ名や別名への言及を検査する補助であり、NGは誤りの確定ではありません。出典本文を読んで確認してください。

## ローカルの検査記録

結果の要約は `/wiki-update` の指示に従って `wiki/log.md` に記録します。比較用JSONや確認済みの例外はVaultの `.agent-state/wiki-update/` に保存します。配布スキルのディレクトリには実データを書き込みません。

- `baseline.json`: 比較用の測定値。存在しない場合は比較を保留します。
- `verify-sources-accepted.tsv`: 出典本文を確認した例外。各行は `ページ名<TAB>Vault相対パス<TAB>判断理由` です。

`verify-sources.rb` は例外ファイルがなくても動作します。削除された例外は自動復元せず、再び出た指摘を本文から確認します。`--show-accepted` で抑止した項目も表示できます。別名ではない語をaliasesに追加して指摘を抑止しないでください。

検査対象は `obsidian-vault` の共通処理で登録先から解決します。`OBSIDIAN_VAULT` を指定する場合も登録先との一致を検証します。テストでは一時的な架空Vaultと登録情報を使い、個人のVaultを検査しません。
