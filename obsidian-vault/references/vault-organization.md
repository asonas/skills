# Obsidian Vault Organization

Vault path: `SKILL.md` の共通処理で解決した `$VAULT_DIR/`。

Rules for organizing the Obsidian vault. Covers directory layout, naming conventions, and maintenance procedures. For save destination defaults, link strategy, and writing style, see this skill's SKILL.md.

## Save Destinations

Before creating a note or reviewing its location, read [save-destinations.md](save-destinations.md). It is the canonical policy for routing precedence, directory purposes, and location review.

## Naming Conventions

- Directory names are English plural nouns, single word when possible (`notes/`, `projects/`, `companies/`). Use hyphens only when a single word is not meaningful (`job-search-2026/`).
- Reuse existing company directory names and casing. Performance records use the same company key under `career/performance/`.
- Filenames may be Japanese or English. Keep them unique across the vault so `[[bare-name]]` wikilinks resolve unambiguously.
- Do not add an H1 heading (`# YYYY-MM-DD`) to daily notes — the filename is the title and adding an H1 duplicates it.
- Avoid paths longer than two levels under `projects/`, `companies/`, or `notes/` unless there is a clear grouping need.

## Top-Level Criteria

The top level holds no standalone `.md` files. All notes belong in a specialized directory:

- Wiki-style hubs and concept nodes → `wiki/` (managed by `/wiki-update`)
- Daily notes and weekly retrospectives → their dedicated directories; work goals and evaluations → `career/performance/<company>/<period>/`
- Route prose, investigations, and work records using `save-destinations.md`
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

Route employer-affiliated records by purpose:

- `career/performance/<company>/<period>/` for work goals, individual evaluations, feedback, and related meetings
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
