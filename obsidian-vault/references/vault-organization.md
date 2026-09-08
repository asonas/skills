# Obsidian Vault Organization

Vault path: `SKILL.md` の共通処理で解決した `$VAULT_DIR/`。

Rules for organizing the Obsidian vault. Covers directory layout, naming conventions, and maintenance procedures. For save destination defaults, link strategy, and writing style, see this skill's SKILL.md.

## Directory Layout

| Path | What goes here | What does NOT go here |
|---|---|---|
| Top level (`*.md`) | No standalone notes. Only specialized directories live at the top level | Any individual `.md` — Wiki hubs now live under `wiki/`, dated notes under their dated directories |
| `wiki/` | LLM-maintained Wiki hub. Frequently linked proper-noun and concept pages (`RubyKaigi.md`, `TDD.md`, `ExampleCompany.md`). Flat structure; classification is via frontmatter `type`. Managed by `/wiki-update` | Daily notes, work logs, drafts, anything ephemeral |
| `bookmarks/` | Raindrop.io から自動同期されたブックマーク。1 ファイル 1 ブックマーク（`{raindrop_id}.md`）。frontmatter にメタデータ、本文に defuddle で抽出した記事本文。`/raindrop-sync` で管理 | 手書きノート（同期で上書きされる） |
| `books/` | Apple Books のハイライトを取り込んだ読書記録。1 書籍 1 ファイル（`<title>（ハイライト）.md`）。frontmatter に書誌、本文に章ごとのハイライト引用。`/books-highlights` で管理（同期で上書きされる）。手書きの読書ノートも置いてよい | — |
| `daily/` | Daily notes (`YYYY-MM-DD.md`) | Weekly reviews, evergreen notes |
| `conversations/` | AIとの会話を読み返すためのMarkdown。会話ごとに直接配置し、要約を付ける場合は本文と区別する。原文保護と発言者・日時・元セッションの扱いは `SKILL.md` に従う | AIランタイムの元JSONLや大量のツール実行ログそのもの。元ログは既存の場所に保持する |
| `activities/` | Machine-generated activity logs (`YYYY-MM-DD.md`)。カレンダー予定、GitHub、ブラウザ履歴、Claude Code、Bluesky、Scrapbox を asonas/activities リポジトリのツール（launchd ジョブと `/today`・`/wrapup`）が集約・上書き描画する。daily note から `![[activities/YYYY-MM-DD#カレンダー]]` で transclude される | 手書きノート（セクションが再描画で上書きされる） |
| `weekly/` | Weekly retros (`YYYY-Wnn.md`) | Daily notes, evaluations |
| `blog/` | Blog post drafts intended for public publication | Unpublished essays, work logs |
| `essays/` | Column-like prose, opinion pieces, and personal essays not intended for public blog publication (or undecided). May be promoted to `blog/` later | Work logs, investigations |
| `1on1/` | 1on1 meeting notes | Retrospectives, group meetings |
| `goals/` | Quarterly and annual goal-setting | Evaluations (use `evaluations/`) |
| `evaluations/` | Performance reviews, 360 feedback, quarterly evaluations | Goal planning (use `goals/`) |
| `pr-reviews/` | Per-PR review records (`PR-<repo>-<num>.md`) | General reviewing philosophy |
| `notes/` | Single-shot investigations, work logs, troubleshooting records | Wiki concept nodes, multi-note projects |
| `external/` | Info hubs for other companies, products, services (Azure AD, cookpad-partner, etc.) | Notes about your own employer or projects |
| `companies/<name>/` | Employer-specific notes not tied to a project: ADRs, onboarding, offboarding, 1on1 history, internal policies. `<name>` follows the brand's canonical casing (`companies/ExampleCompany/`, `companies/ExampleStudio/`, `companies/ExampleOrg/`). Both current and past employers go here | Specific project work (use `projects/<name>/`) |
| `projects/<name>/` | Explicit deliverables with continuous work. Keep flat regardless of employer | Single-shot investigations, archival notes |
| `archive/YYYY/` | Notes past their active life, preserved for reference. `YYYY` is the last-modified year or the year you left the associated employer | Anything still actively referenced |
| `images/` | All image assets (screenshots, pasted images) | Anything else |
| `template/` | Note templates | Populated template instances |
| `contexts/` | Claude Code contextLoad payloads | Arbitrary markdown notes |
| `scripts/` | Scripts and script-related notes | Other kinds of code |

Directories not listed here (e.g. `oksskolten/`, `the-floor/`) have bespoke purposes and are left untouched by default.

## Decision Flow for New Notes

Apply in order; stop at the first match.

AIとの会話そのものの記録は、話題が特定プロジェクトに関する場合でも `conversations/` に保存する。会話から別途作成する仕様書や調査ノートは、以下の内容別の保存先を使う。

1. Is this part of a continuing explicit deliverable? → `projects/<name>/`
2. Is this a daily note, weekly retro, 1on1, evaluation, or blog draft? → the matching specialized directory
3. Is this column-like prose or a personal essay not intended for public publication? → `essays/`
4. Is this a single-shot investigation or work log? → `notes/`
5. Is this info about an external company, product, or service? → `external/`
6. Is this an employer-specific note that is not tied to a specific project? → `companies/<name>/`
7. Is this a Wiki-style concept hub that will attract inbound links? → `wiki/` (created or updated by `/wiki-update`, not by hand in most cases)

If none of these apply, the note probably should not be saved yet. Clarify intent before creating it.

## Naming Conventions

- Directory names are English plural nouns, single word when possible (`notes/`, `projects/`, `evaluations/`). Use hyphens only when a single word is not meaningful (`pr-reviews/`).
- Company directories are `companies/<name>/` using the brand's canonical casing (`companies/ExampleCompany/`, `companies/ExampleStudio/`, `companies/ExampleOrg/`).
- Filenames may be Japanese or English. Keep them unique across the vault so `[[bare-name]]` wikilinks resolve unambiguously.
- Do not add an H1 heading (`# YYYY-MM-DD`) to daily notes — the filename is the title and adding an H1 duplicates it.
- Avoid paths longer than two levels under `projects/`, `companies/`, or `notes/` unless there is a clear grouping need.

## Top-Level Criteria

The top level holds no standalone `.md` files. All notes belong in a specialized directory:

- Wiki-style hubs and concept nodes → `wiki/` (managed by `/wiki-update`)
- Dated notes (daily, weekly, evaluations) → their dated directories
- One-off work logs, investigations, or drafts → `notes/` or a project
- Image assets → `images/`
- Stubs and untitled scratch (`Untitled.md`, `新しいフォルダ.md`) → delete or rename before committing

Historical context: top-level `.md` files were previously used as Wiki hubs (`ExampleCompany.md`, `RubyKaigi.md` etc.). On 2026-05-20 these were migrated into `wiki/` and the top level was emptied of standalone notes.

## Wiki Directory

`wiki/` is an LLM-maintained knowledge base inspired by karpathy's "LLM Wiki" pattern. Conventions:

- **Flat structure.** No subdirectories under `wiki/`. Pages are classified via frontmatter `type` (entity / concept / event / org / comparison / summary), not by directory.
- **Two special files.** `wiki/index.md` is the auto-regenerated catalog (rebuilt by `/wiki-update rebuild-index`); `wiki/log.md` is an append-only operation log.
- **Citations are mandatory.** Every wiki page has a `sources:` frontmatter array of wikilinks to the originating notes (`[[daily/2026-05-19]]`, `[[notes/foo]]`). Body paragraphs reference their sources inline as well.
- **Wiki is a derived layer.** Source notes (`daily/`, `notes/`, `essays/`, `conversations/`, etc.) are preserved. Conversation records are evidence of who said what, not proof that every statement is true; keep attribution and distinguish proposals, interpretations, and confirmed agreements. The wiki summarizes and integrates with source references; it does not invent facts or replace the original records.
- **Editing convention.** Wiki pages are created and updated by the `/wiki-update` skill (ingest / lint / rebuild-index modes), driven by `/today`, `/wrapup`, or manual invocation. Manual hand-editing is allowed but should be infrequent.

## Employer-Affiliated Notes

Two buckets depending on continuity:

- `companies/<name>/` for ADRs, onboarding docs, offboarding notes, policy memos, and other employer-specific content without a dedicated project
- `projects/<name>/` for explicit projects with continuous work. Keep flat (e.g. `projects/example-project/`, not `projects/example-org-example-project/`)

The employer Wiki hub (`wiki/ExampleCompany.md`, `wiki/ExampleOrg.md`) lives under `wiki/` and is managed by `/wiki-update`. Since Obsidian resolves `[[bare-name]]` vault-wide, the Graph View connects employer → projects and employer → company notes via wikilinks regardless of directory.

When you leave an employer, the notes stay in `companies/<name>/` — no migration to `archive/` is needed solely because you changed jobs. Archival is driven by the age and relevance criteria below, not by employment status.

## Move / Rename Checklist

Before moving or renaming files, run these checks in order:

1. **Backup.** The vault is not git-managed. Create a snapshot:
   ```bash
   tar czf ~/tmp/vault-backup-$(date +%F).tar.gz -C "$VAULT_DIR" .
   ```
2. **Filename uniqueness.** Obsidian resolves `[[bare-name]]` by filename. Moving across directories is safe only when the filename is unique vault-wide:
   ```bash
   find "$VAULT_DIR" -name '*.md' -type f -exec basename {} \; | sort | uniq -d
   ```
3. **Path-qualified wikilinks.** If any note links via `[[folder/name]]`, the move breaks it. Grep for path-qualified links referencing the directories you touch:
   ```bash
   grep -rn --include='*.md' -E '\[\[(old-folder-name)/' "$VAULT_DIR"
   ```
   Rewrite to the new path after the move.
4. **Backlinks for deletions.** When deleting a note, confirm no backlinks exist or accept that `[[name]]` will become an "unresolved" link after deletion.
5. **Image references.** Images use `![[filename.png]]`. Moving images between directories is safe when the reference is filename-only. Path-qualified image references need rewriting.

Prefer `/bin/mv` (via the shell) over interactive renaming when scripting moves. The shell alias for `mv` may be interactive (`mv -i`) — use `command mv` or `/bin/mv` to bypass.

## Archive Criteria

Move a note to `archive/YYYY/` when:

- The last meaningful modification was two or more years ago, **and**
- No active note links to it, **and**
- You do not expect to reference or update it again

`YYYY` is the year of last modification. Employer-specific notes for former employers may also be archived if they meet these criteria, but archival is driven by age and relevance, not by the employment change itself.

When archiving, run the Move / Rename checklist first. Archived notes retain their filenames so existing `[[bare-name]]` links keep resolving.

## Related Rules

- General save destination, tool choice (`obsidian` CLI vs Read+Edit), writing style, and Graph View linking strategy: this skill's SKILL.md
- Daily note workflow: invoked through `/today` and `/wrapup` skills
