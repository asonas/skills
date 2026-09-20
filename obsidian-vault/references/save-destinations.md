# Save destinations

Apply these rules when creating a note or reviewing its location. Explicit user destinations take precedence. Preserve filenames, original text, attribution, and the distinction between drafts and confirmed records.

## Fixed destinations

Route known document kinds directly, without semantic classification:

| Kind | Destination |
|---|---|
| AI conversation transcript, regardless of topic | `conversations/` |
| Daily note / weekly retrospective | `daily/` / `weekly/` |
| Generated activity log | `activities/` |
| Raindrop bookmark | `bookmarks/` |
| Book text, highlights, reading notes | `books/` |
| Derived, source-linked Wiki page | `wiki/` |
| Coaching session or personal coaching goal | `coaching/` |
| Note template | `template/` |

Keep handwritten additions separate from files owned by importers or generators. Resolve attachment placement through the existing attachment workflow.

## Content routing

Apply the first matching rule:

1. User-authored prose, including short drafts and AI-assisted editing: `essays/`. Publication intent does not change this destination. Use declared authorship and purpose, not prose style, to distinguish an essay from an AI-authored report.
2. Job-search preparation, interviews, correspondence, and selection records: the relevant activity under `career/`.
3. Work goals, self-assessments, performance reviews, 360 feedback, and review-related meetings: `career/performance/<company>/<period>/`. Keep separate notes together by company and review period. Use `YYYY`, `YYYY-H1`, or `YYYY-Q1` as appropriate; retain a `360fb/` subgroup when useful. Infer neither missing company nor missing period.
4. Designs, investigations, and work records belonging to an existing project: `projects/<project>/`, including one-off tasks. Project execution plans belong here; personal performance targets belong in rule 3.
5. Employer policies, evaluation frameworks, onboarding, offboarding, and company-specific meeting records: `companies/<company>/`. Individual performance records belong in rule 3.
6. Other investigations, organized reports, and work records: `notes/`.

Reuse existing company and project names, including their casing. Other established specialist folders retain their existing purposes; leave them in place when their purpose is unknown. Root-level standalone notes and new root categories require a separate organization decision.

## Location review

Review new, unreviewed notes since the last completed review, including missed days. Skip explicit destinations and generator-owned files. Keep a valid current location; moving to another acceptable location alone is not an improvement.

For semantic classification, provide the note's original-language content, declared purpose and authorship, current path, and relevant existing destination descriptions. Use concise English instructions. Include `keep_current` and `needs_review` outcomes. Build candidates from existing directories only. Code handles fixed routing, candidate construction, and filesystem operations; Jev only selects among supplied candidates. Unknown ownership or missing destination evidence requires review, not an invented path.

Initially present proposed moves in wrapup for approval. Confidence alone does not authorize a move. Before applying, back up files, check destination collisions and source freshness, then update links and attachment references. Preserve conversation and quotation originals. Verify file preservation and reference targets before refreshing downstream indexes. Update path-based exclusions when moving private records.
