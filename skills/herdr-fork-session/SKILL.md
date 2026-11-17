---
name: herdr-fork-session
description: 現在のClaude Code / Codexセッションを、会話履歴を保ったまま新しいHerdrペインに分岐（fork）する。ユーザーが「このセッションを分岐したい」「別ペインで並行して試したい」「フォークして」「branch this session」などと言ったとき、または /herdr-fork-session として明示的に呼ばれたときに使う。旧TUI版herdr（HERDR_ENV=1）とHerdr.app（HC_TERMINAL_IDがありherdr-appが使える環境）で動作する。
---

# /herdr-fork-session - セッションをHerdrペインへフォーク

現在の会話履歴を引き継いだまま、新しいHerdrペインに独立したセッションを作る。元のセッションはそのまま変更されない。分岐後は、元のセッションでは触れずに別の方向性を試したり、並行して作業を進めたりできる。

出典: [herdr-fork-claude-session gist (miyagawa)](https://gist.github.com/miyagawa/cb1a9f6c8695d1219efba0c66d5f78f7)。Codex版はこのリポジトリで追加で書いたcompanionスクリプト。

## 前提条件

次のどちらかで実行していること。どちらでもなければ、Herdrの外からは分岐できない旨を伝えて終了する。

- **旧TUI版herdr**: `HERDR_ENV=1` のペイン。`herdr` CLIで分岐する。
- **Herdr.app（herdr-core）**: `HC_TERMINAL_ID` が設定され、`herdr-app` が使える端末。`herdr-app` で、この端末を含むペインを分割する（フォーカス中のペインではない）。`HC_TERMINAL_ID` があっても `herdr-app` がないマシン（herdr-core経由のリモートなど）では分岐できない。

両方が当てはまる場合は旧TUI版の経路を使う。

## 振る舞い

自分が今どちらのエージェントとして動いているかで、実行するスクリプトを切り替える。

- **Claude Codeとして動いている場合**: `~/bin/herdr-fork-claude-session [right|down]` を実行する。セッションIDは環境変数 `CLAUDE_CODE_SESSION_ID` から取得する。旧TUI版では、取得できない場合に `herdr agent list` のfocusedペインにフォールバックする。Herdr.appではフォールバックせずに終了する。
- **Codexとして動いている場合**: `~/bin/herdr-fork-codex-session [right|down]` を実行する。
  - 旧TUI版では、`HERDR_PANE_ID`（実行中の自分のペインid）を使って `herdr agent list` から自分のペインのセッションidを特定する。UIの「focused」状態には依存しない。
  - Herdr.appでは、Codexが実行するコマンドに渡す `CODEX_THREAD_ID` をセッションidとして使う。分岐先は herdr-core の決まりに従い `codex --no-daemon fork` で起動する。

引数は分岐先ペインの方向で、省略時は `right`。左右ではなく上下に分岐したい場合は `down` を渡す。

```bash
~/bin/herdr-fork-claude-session       # 右に分岐（デフォルト）
~/bin/herdr-fork-claude-session down  # 下に分岐
~/bin/herdr-fork-codex-session right
```

## 実行結果

スクリプトは新しいペインで `claude --resume <session-id> --fork-session`（Claude Code）または `codex fork <session-id>`（Codex。Herdr.appでは `--no-daemon` 付き）を起動し、`forked session <id> -> pane <pane-id>` を出力する。Herdr.appでは、ペインIDの後ろに新しい端末のIDが付く。この出力をそのままユーザーに伝える。

Herdr.appでは、この出力は端末が作られたことしか示さない。エージェントが起動したかは `hc get <端末ID>` か `hc read <端末ID>` で確かめてから伝える。

## 注意

- スクリプトが存在しない、または前提条件を満たさずエラー終了した場合は、エラーメッセージをそのままユーザーに見せる。推測で代替手段を試さない。
- 分岐は複製であって移動ではない。元のセッションはこの操作の影響を受けない。
