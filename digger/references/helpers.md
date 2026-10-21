# 取得補助と新着確認

Pythonは設定の実行経路を使う。以下の変数は実際のパスへ置き換える。スクリプトはconfig.jsonを自動で読まず、実行者が選択機能・保存先・認証・保持方針を適用する。

```sh
mise exec -- python3 "$DIGGER_SKILL_DIR/scripts/fetch.py" "$TOPIC_DIR/sources" "author-year-title" "https://example.org/article"
mise exec -- python3 "$DIGGER_SKILL_DIR/scripts/chain.py" find "論文の題名"
mise exec -- python3 "$DIGGER_SKILL_DIR/scripts/chain.py" refs "10.example/doi"
mise exec -- python3 "$DIGGER_SKILL_DIR/scripts/chain.py" cites "W123456789"
mise exec -- python3 "$DIGGER_SKILL_DIR/scripts/chain.py" author "著者名"
mise exec -- python3 "$DIGGER_SKILL_DIR/scripts/watch.py" add "$TOPIC_DIR" "https://example.org/feed.xml"
mise exec -- python3 "$DIGGER_SKILL_DIR/scripts/watch.py" check "$TOPIC_DIR" --days 14
mise exec -- python3 "$DIGGER_SKILL_DIR/scripts/watch.py" list "$TOPIC_DIR"
```

`fetch.py` はPDF・文字層・OCR・Web本文・原言語字幕を扱う。元版の文字数下限や取得失敗の判定を残すので、短いが有効な記事も失敗する場合がある。そのときはWeb/axで本文を確認し、手動取得であることを記録する。原典URL・取得方法・日時・取得範囲は実行者がmetadataへ追記する。

OCRは選択済みの場合だけ環境変数 `DIGGER_OCR=1` を対象プロセスに渡す。未選択時は自動OCRを行わない。字幕だけなら動画本体は取得しない。PDF原本は取得直後には本文と同じ場所に残るため、別の原本ルートや保持しない設定は、抽出を確認してから実行者が適用する。既存ファイルとユーザー提供原本を削除しない。

`chain.py` はOpenAlexの結果を整形する。APIの認証や利用条件はセットアップ時に現行情報を確認する。この版は認証付きAPI呼び出しを実装していない。公開アクセスで使えない場合は未確認/利用不可と記録し、本文の参考文献や著者一覧をたどる。秘密をURLの引数に埋め込まない。

`watch.py` は `watch.tsv`、`watch-state.json`、`watch/` を話題ディレクトリに保持する。新着確認は継続調査を依頼された場合に使い、定期実行は自動登録しない。新着一覧だけで原典を取得済みと数えず、必要な記事を取得して通常の調査へ戻す。

## 元版との差分と取得経路の限界

4本はMaryCache/imozuruのコミット `ecb82c71b611872a0f49e783eda3bec987c80d91` 由来。`report.py` はそのまま、他3本は手動User-Agent指定を除いた。fetchには未選択OCRの抑止と取得VTTの保持を加え、User-Agentを変えるPDF取り直しを削除した。必要ならPDFの直接リンクを別途取得する。追加のpipパッケージは不要。

ページの探索・取得は [取得・変換手順](acquisition.md) のWeb機能またはaxを優先する。補助スクリプトに残るHTTP処理はPython標準ライブラリを使い、元版の公開URL・各リダイレクト先・取得サイズ・途中切断の検査を維持している。HTMLからの本文抽出はaxを使う。取得スクリプトの直接通信が実行環境の規約に合わない場合は直接実行せず、Web/axで原本を取得してローカル変換を行う。取得経路を黙って切り替えない。

字幕取得時のyt-dlp内部の転送まではこのPythonコードで検査しない。OpenAlexやフィードへ認証情報を渡す実装は含まない。取得制限、文字化け、不完全な本文を確認したら未取得・部分取得として残し、成功件数に含めない。
