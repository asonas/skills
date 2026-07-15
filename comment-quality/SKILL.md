---
name: comment-quality
description: This skill should be used when the user asks to "check comment quality", "review comment/doc wording", run a "pre-commit/PR comment check", or before committing/opening a PR. It diff-reviews newly added or changed code comments, PR bodies, commit messages, and docs prose — in any language — flagging (R1) references to undecided future plans, (R2) jargon / coined terms / uncommon vocabulary, (R3) self-invented roadmap / milestone / phase numbers leaking into PRs, commits, or docs, (R4) excessive backtick usage on non-code words, (R5) diff-relative comments that leak PR/session context (justifying absent code or narrating the edit) and read as noise after merge, and (R6) comments that merely restate what a framework / language / library feature does.
---

<!-- Source: takai (https://gist.github.com/takai/f17b43412243221f918509e989df0a3b). Vendored into asonas/skills for personal apm distribution. Keep in sync with upstream. -->

# Comment Quality

Review the wording of newly written comments and prose in a diff, and surface phrasing that will
rot or mislead after merge. Report findings only — never auto-fix.

The rules are **language-agnostic**. Apply them equally to English, Japanese, or any other
language the comment or prose is written in. The examples below are illustrative, not a closed
list — match the underlying intent of each rule, not just the literal example strings.

## Scope

- **In scope**: lines *added or changed in the current diff* — code comments, plus prose in
  changed `*.md` files, the PR body, and commit messages.
- **Out of scope**: pre-existing comments inherited from other PRs (do not flag wording that the
  current diff did not introduce or touch), and number-labeled plan docs under `tmp/` (working
  scratch space — see R3).

## Check rules (R1–R6)

### R1 — No undecided future plans

A comment must state only facts that are true at the time of writing. Flag references to work
that is not yet decided, belongs to a separate task, or is merely intended.

Trigger phrasing (any language), e.g.:
- "future work", "future task", "later", "eventually", "for now / temporarily until…"
- "to be added", "planned to…", "intend to…", "will switch to DB someday"
- Japanese: 「将来の課題」「将来の別作業」「cutover は将来」「後に追加する」「〜する想定」「いずれ DB 化」

Rewrite to the present fact only. Example:
- Bad: "Not wired to access control yet — will switch to a DB lookup later."
- Good: "Not wired to access control. The decision reads from Settings."

### R2 — No jargon, coined terms, or uncommon vocabulary

Replace invented words, transliterated loanwords, and internal jargon with plain wording that a
first-time reader understands.

Illustrative replacements:
- English: "leverage" → "use", "materialize" → "load" / "read", "human-readable" → "user-facing",
  "prospective record" → "unsaved draft record"
- Japanese: 本作業時点では → 現時点では / CTA → リンク / self-service → 申請者本人(による操作) /
  prospective なレコード → 未保存の仮レコード / materialize する → 読み込む /
  人間可読 → 利用者向け / row レベル → 行レベル / 新世代・現世代 → 新しい attempt・現在の attempt

### R3 — No self-invented roadmap / milestone / phase numbers in PRs, commits, or docs

Numbers an author assigned only for their own internal tracking (phases, milestones, PR sequence)
mean nothing to a reviewer or future reader. Flag them in PR bodies, PR titles, commit messages,
and committed docs.

Trigger phrasing, e.g.: "Phase N", "Milestone X", "M00n", "the Phase 3 implementation".

Rewrite content-based — name the model, screen, behavior, or file instead:
- Bad: "Implements Phase 1." / "Start with the Phase 0 rename PR."
- Good: "Adds the Admin::Privilege model and dual-read." / "First, rename Backyard::LegacyAdmin to Backyard::Admin."

Numbering *inside* throwaway plan docs under `tmp/` is fine and out of scope.

### R4 — Minimal backticks: only on text extracted from program code

Reserve backticks for text extracted verbatim from program code: identifiers (class, method,
variable, column names), enum/literal values, and code fragments. Flag backticks on everything
else — ordinary words, domain terms, emphasis, and **file paths** (write paths as plain text:
app/models/foo.rb, not `app/models/foo.rb`).

- Bad: "The `admin` user opens the `Backyard` screen and the `request` is `approved`."
- Bad: "See `docs/wiki/AuditLog.md` for details."
- Good: "The admin user opens the Backyard screen and the request is approved. The record's
  `status` column moves to `approved`. See docs/wiki/AuditLog.md for details."

Wrap a word only when it refers to the code symbol itself (e.g. the `approved` enum value), not
when it is used as a plain word. Product/screen names, role names, file paths, and domain
vocabulary are prose — no backticks.

### R5 — No diff-relative comments that leak PR/session context

A *code comment* (and committed docs prose) is read independently of the PR that introduced it.
Flag comments that only make sense if you know what just changed in this diff — they become
meaningless or misleading once the PR context is gone. The giveaway: the comment explains an
**absence** ("why we do NOT do X here") or **narrates the change** ("used to…", "moved to…",
"no longer needed"), rather than stating a durable fact about the code as it now stands.

This rule applies to code comments and committed docs only. PR bodies and commit messages are
*supposed* to describe the change — do not flag them under R5 (R1–R4 still apply there).

Trigger shapes (any language):
- Justifying the absence of an action: "no processing needed here", "no downcase needed", "nothing
  to do here because…". JP: 「ここでの加工は不要」「ここでは downcase しない」「〜する必要はない」
- Narrating the edit / past state: "removed X", "moved to the model", "previously did Y",
  "changed from A to B". JP: 「〜に移動した」「以前は〜していた」「もう〜しない」「〜に変更した」
- Restating a fact that is owned and documented elsewhere, only to explain why this spot does
  nothing (e.g. pointing at another class's `normalizes` to justify not normalizing here).

Rewrite: delete it. If it carries a genuinely non-obvious, durable fact, move that fact to where
it is owned (e.g. the `normalizes` declaration) and phrase it as a present fact, not relative to
the change.

- Bad: "email の大文字小文字は normalizes が検索キー・保存値とも正規化するため、ここでの加工は不要。"
  (justifies the absence of a downcase that was removed in this PR — noise to a fresh reader)
  Rewrite: delete; the normalization fact belongs on the `normalizes` declaration.
- Bad: "email は Admin::Privilege の normalizes で小文字化される (find_or_initialize_by の検索キー・保存値とも)。"
  (explains why this call site does not downcase — diff artifact) Rewrite: delete.

Do NOT flag a durable "why not" caveat that a future editor needs in order to avoid
re-introducing a bug, when its reason stands on its own without PR context. These state a present
requirement, not the edit:
- OK: "Don't memoize — must re-read per request because the value changes mid-request."
- OK: "Skip validation here; the batch importer guarantees these rows are already sanitized."

### R6 — No comments that merely restate a framework / language / library feature

Flag comments whose entire content is the documented behavior of a built-in framework, language,
or library feature — the kind of thing a reader already knows, or can look up in that tool's docs.
Such comments carry no project-specific information and would read identically in any codebase
using the same feature. The giveaway: remove the surrounding code and the comment is still a
generic, true statement about the tool.

Trigger shapes (any language):
- Restating what an attribute / function / keyword does: "ignore_changes に入れた属性は plan の
  差分から無視される", "before_save はレコード保存前に呼ばれる", "この map は新しい配列を返す",
  "prevent_destroy は destroy をブロックする", "async makes this function return a promise".

Rewrite: delete it. Keep a comment only if it states a project-specific reason that is NOT obvious
from the feature itself — and phrase it as that reason, not as the mechanic.

- Bad: "engine_version は ignore_changes に含めると plan に反映されなくなる。" (restates how
  ignore_changes works) Rewrite: delete.
- OK: "num_cache_clusters は運用側で手動スケールするため無視する。" (project-specific reason this
  particular attribute is ignored — not a description of the ignore_changes mechanic)

The line between R6 and a useful "why" comment: R6 explains *what the feature does*; a useful
comment explains *why this code uses it here* in a way the feature itself does not reveal. When the
"why" is itself self-evident from the value (e.g. ignoring a count that is obviously hand-managed),
drop the comment entirely.

## Workflow (diff-review)

### STEP 1 — Collect changed lines

```bash
BASE="$(git merge-base main HEAD)"
git diff "$BASE"...HEAD
```

- **Comments**: from the added lines (`+`), pick lines containing comment syntax — `#`, `//`,
  `/* … */`, and YAML / ERB comments.
- **Prose**: added lines of changed `*.md` files (especially under `docs/`), plus the PR body and
  commit messages when available.

### STEP 2 — Match against R1–R6

Check only lines added or changed in this diff. Skip pre-existing wording the diff did not touch.

### STEP 3 — Report findings

List each hit, tagged with the rule it breaks (R1 / R2 / R3 / R4 / R5 / R6) and a suggested rewrite.
When a section has zero hits, write `None` explicitly — do not leave it blank.

## Output format

Follow these conventions (mirrors the repo's `billing-review` skill):

- findings-first; no emoji
- quote code as `file_path:line`
- report and suggested rewrite only — no auto-fix
- match the output language to the target/conversation (default English; Japanese if the request is in Japanese)

### Output template

```markdown
## Findings

- [R1] app/models/foo.rb:42 — "将来 DB 化する想定" references an undecided plan.
  Rewrite: state only the present behavior, e.g. "判定は Settings を参照する".
- [R2] app/services/bar.rb:88 — "materialize the record" is jargon.
  Rewrite: "load the record".
- [R3] PR body — "Implements Phase 1" uses a self-invented phase number.
  Rewrite: name the change, e.g. "Adds the Admin::Privilege model".
- [R4] docs/foo.md:12 — "`管理者` が `申請` を承認する" wraps plain words in backticks.
  Rewrite: "管理者が申請を承認する" (keep backticks only on code symbols).
- [R5] app/models/admin/privilege.rb:56 — "normalizes が正規化するため、ここでの加工は不要" justifies
  a downcase removed in this PR; meaningless to a fresh reader. Rewrite: delete (the fact belongs on
  the `normalizes` declaration).
- [R6] live/pro/web/elasticache.tf:108 — "engine_version は ignore_changes に含めると plan に反映され
  なくなる" merely restates how ignore_changes works. Rewrite: delete.

## Notes

None
```

When nothing is found, output `## Findings` followed by `None`.
