---
name: pr-autofix
description: PRをsanity-reviewでレビューし、指摘を深刻度 x 修正難度でトリアージして、選んだ組み合わせだけをAIが修正・再レビューする。
argument-hint: "[PR-URL-or-number]"
disable-model-invocation: true
---

# PRのトリアージと自動修正

1本のpull requestについて、レビュー、トリアージ、修正、再レビューの往復を指揮する。このsessionは指揮役で、レビューと修正はsubagentに任せる。

自動修正は、直した箇所の周りに別の不具合や仕様の変化を持ち込みうる。どの組み合わせならその危険を許容できるかを決めるのはユーザーである。指揮役は、決められた範囲を自分では広げない。

## 依存

- plugin `sanity-review@shokai-agent-skills`: レビューに使う。Skill名は `sanity-review:sanity-review`
- plugin `codex-consultation@shokai-agent-skills`: sanity-reviewと、修正のpush前の確認に使う。Skill名は `codex-consultation:codex-consultation`

どちらかがSkill toolで呼べなければ、installをユーザーに依頼して止まる。

## 手順1: 実行環境とPRを確かめる

次を全て満たさなければ、満たさない条件をユーザーに伝えて止まる。

1. 自分のmodelがOpus以上のtierである。sanity-reviewも同じ条件で止まる
2. `printenv CODEX_HOME` が `$HOME/.codex-platform` に解決され、`test -n "$CODEX_API_KEY"` が成功する。キーの値は表示しない。レビュー時だけplatform.openai.comのAPIクレジットで課金するための設定で、キーはenvchainの `nastack-code-review` から起動時に渡す。満たさなければ、次のコマンドで起動し直すようユーザーに伝える

   ```sh
   envchain nastack-code-review sh -c 'CODEX_API_KEY="$NASTACK_CODE_REVIEW_OPEN_API_KEY" CODEX_HOME="$HOME/.codex-platform" exec claude'
   ```
3. PRがopenで、`gh pr view {PR} --json isCrossRepository` がfalseである。forkのbranchにはpushしない

引数が無ければ、現在のbranchのPRを対象にする。

PRのhead branchのworktreeを用意する。以降、レビューも修正もこのworktreeで行う。

- head branchが既にどこかのcheckoutにあれば、そのcheckoutを使う。`git worktree list` で探す
- 無ければ `git worktree add .worktrees/{branch} {branch}` で作る
- `git fetch` の後、worktreeを `origin/{branch}` にfast-forwardする。fast-forwardできない時と、commitされていない変更がある時は止まる。force pushをしないので、遅れたworktreeからのpushは失敗する

各往復の手順3の前にも、同じfast-forwardを行う。

## 手順2: 自動修正の範囲を決める

AskUserQuestionツールで、次の2つを訊く。ユーザーが起動時に指定していれば訊かない。

- 自動修正する深刻度と修正難度の組み合わせ。High x 1を勧め、Medium x 1を他の候補に挙げる。修正難度2と3は選択肢に挙げるが勧めない
- レビューと修正の往復の上限。3往復を勧める。1往復ごとにsanity-reviewとCodexへの相談でAPIクレジットを消費する

## 手順3: レビューをsubagentに任せる

往復ごとに新しいsubagentを起動する。前の往復の修正を知らないsubagentにレビューさせ、修正した本人の思い込みを持ち込まない。modelはOpus以上を指定する。

指示には次を含める。sanity-reviewが途中でユーザーに質問すると往復が止まるので、答えを先に渡す。

- worktreeの場所。sanity-reviewとCodexへの相談は、全てこのworktreeを作業ディレクトリにして行う。差分の周りのコードは手元のファイルから読まれるので、別のbranchのcheckoutで実行すると、修正前のコードをレビューする
- Skill toolで `sanity-review:sanity-review` を、引数 `{PR番号}` で実行する
- 報告書の出力先は「チャットとpull request」
- 対話コンテキストが見つからなければ、対話コンテキストなしで続行する
- 報告書の全文を、最終報告としてそのまま返す

報告書の「レビュー作業において発生した問題」を読む。codex-consultationから別の相談相手へのフォールバック、または「批判的思考の連鎖が機能していません」の警告があれば、修正に進まず止まる。APIクレジットの枯渇や通信障害で起きる。Codexを使わないレビューに切り替えない。

## 手順4: トリアージする

報告書の指摘を1件ずつ取り出し、深刻度と修正難度を付ける。指摘の拾い元は次の節である。

| 節 | 扱い |
| --- | --- |
| 説明と実装の整合性 | 拾う |
| 命名・設計パターンの一貫性 | 拾う |
| バグ・脆弱性の調査 | 拾う |
| 考慮漏れの確認 | 拾う |
| pull request概要欄の品質評価のNG | 拾うが、修正難度に関係なく人間に回す。実装者自身の理解を問う項目なので、AIが書き直すと検査の意味が失われる |
| 長期視点で命名・設計を考察する | 拾わない。議論のタネであり、指摘ではない |

全ての指摘に短い名前を付け、往復をまたいで同じ名前で呼ぶ。手順5で修正難度を付け直した指摘は、以降の往復でも付け直した修正難度のまま扱う。毎回新しいレビュアーが、元の修正難度を付け直す事があるためである。

### 深刻度

- High: データの消失・破損、セキュリティの欠陥、クラッシュ、主要な経路での誤った動作を起こす
- Medium: 発生には条件があるが影響が大きい。または設計上の弱点である
- Low: 直接の害は無いが、改善が望ましい。命名、読みやすさ、テストの不足等である

### 修正難度

修正に必要な仕様変更の意思決定を、誰が下す必要があるかで分ける。変更の量では分けない。

1. 仕様変更のための意思決定がほぼ無い、セオリー通り開発すれば直せる問題
2. 仕様変更のための中程度の意思決定が必要だが、開発チーム内での合意は容易な問題
3. データモデルやセキュリティモデルが大きく変化する、あるいはユーザーに周知が必要、等で設計から見直す必要がある問題

不正な入力にどのステータスコードを返すか、のように実装者がその場で決められる判断は1に含める。1と2で迷う指摘は2にする。

### トリアージの記録

深刻度 x 修正難度の表と、各指摘の名前・深刻度・修正難度・報告書での根拠を、PRにコメントする。2往復目以降は、前の往復から消えた指摘、残った指摘、新しく出た指摘を分けて書く。

## 手順5: 修正をsubagentに任せる

手順2で選んだ組み合わせの指摘が無ければ、手順6に進む。

あれば、新しいsubagentを1つ起動し、その往復の対象の指摘をまとめて任せる。modelはOpus以上を指定する。指示には次を含める。

- 担当する指摘の名前と、報告書での根拠
- 作業するworktreeの場所。ユーザーのcheckoutで、branchの切り替えもファイルの変更もしない
- repoの検証手順。`AGENTS.md` やREADMEが定めるbuildとtestを、push前に実行する
- commitはrepoとユーザーのcommit規約に従う。`commit-style` skillがあれば読む。指摘ごとにcommitを分ける
- pushの前に毎回、Skill toolで `codex-consultation:codex-consultation` を「よく相談して」の深さで呼び、差分を確認させる。Codexが利用制限や障害で止まったら、pushせずに止まって報告する
- force push、merge、draftとready for reviewの切り替え、レビュアーの指定はしない
- 判断の扱い:
  - 実装者がその場で決められる判断は自分で決め、判断と理由をcommit messageに書く
  - 仕様の判断が要ると分かった指摘は直さず、理由を報告する。その指摘は修正難度2以上に付け直す
  - 修正の中で見つけた別の問題は直さず、報告する
- 報告は10行以内。直した指摘、直さなかった指摘と理由、Codexに相談した回数、実行した検証とその結果

報告が来たら、`git -C {worktree} log` とPRのcommitで、pushされた内容が報告と一致する事を確かめる。

## 手順6: 続けるか止まるかを決める

次のいずれかに当たれば止まり、手順7に進む。当たらなければ手順3に戻る。

- 手順2で選んだ組み合わせの指摘が、最新の報告書に無い
- 往復の上限に達した
- 同じ名前の指摘が、修正した後の報告書にまた現れた。直し方が噛み合っていないので、人間が見る
- subagentがCodexの停止で止まった

## 手順7: 結果を伝える

PRに、最後の状態をコメントする。

- 自動修正した指摘と、そのcommit
- 人間に回す指摘。手順2で選ばなかった組み合わせ、修正難度を付け直した指摘、再発した指摘、概要欄のNGである
- 止まった理由

ユーザーには、同じ内容を短く伝える。人間に回す指摘は省かない。作ったworktreeは消さずに場所を伝える。消すのはPRがmergeされた後で、ユーザーが行う。
