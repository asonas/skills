---
name: jev-qmd
description: Rerank selected qmd results with Jev when the user requests an optional Jev comparison. Preserve normal local search and review outgoing document text before using TypeSafe.
---

# Optional Jev reranking

Run this workflow only when the user requests Jev evaluation; keep ordinary Vault searches on the local path.

Use `vault-rag` for retrieval and `obsidian-vault` to resolve and verify the Vault before running qmd. This skill adds an optional external evaluation; it does not replace normal qmd search.

Scripts are relative to this skill's deployed directory. Run Ruby with `mise exec -- ruby`. Required tools are qmd and Ruby; paid execution additionally needs `TYPESAFE_API_KEY` (available through `envchain typesafe` on the user's Mac). Never store the key in a snapshot or configuration repository.

## Workflow

1. Identify exact candidate URIs from local search and obtain permission for the specific documents before external transmission. Skill invocation alone is not consent to transmit the Vault. Keep runtime snapshots outside the skill directory and source repositories, in a private temporary directory or an explicitly selected local location.
2. Collect only those URIs with `scripts/compare.rb collect --question TEXT --query QUERY --collection asonas --allow URI`. Repeat `--allow` for each document. Save stdout as a snapshot using file-editing tools. Queries can use structured `lex:` and `vec:` lines. Collection is local and retains qmd's usual reranking. The URI filter can omit a relevant result; it never inserts missing documents.
3. Run `scripts/rerank.rb preview --input SNAPSHOT`. Review the full outgoing question and bodies, not just filenames. Show the exact target set to the user if it exceeds their existing permission. Stop for approval in that case.
4. After review, run `envchain typesafe mise exec -- ruby <skill-directory>/scripts/rerank.rb run --input SNAPSHOT --approve REVIEWED_SHA256`. Use the hash from the reviewed preview; do not automatically pipe a generated hash into execution. Input or judgment changes require a new preview.
5. Report original and revised ranks, elapsed time and estimated cost. Read the selected evidence before answering; a high score does not verify a source's factual claims. Preserve speaker attribution when a candidate is a conversation.

The runner evaluates one document per request, up to four concurrently. All selected candidates remain in the output, including low scores; ties retain input order. The limit is 20 candidates within the 60 KB experimental payload cap. Oversized inputs fail without silently removing text.

Errors stop the run without returning a partial ranking or retrying. Already dispatched requests can still incur cost. Preserve the original local result; ask before another paid attempt. `compare.rb run` is the old batched experiment without the preview gate; use `rerank.rb run` for this workflow.

## Distribution boundary

APM deploys this skill and its scripts. The enabled dependency belongs in the live `~/.apm/apm.yml` tracked through asonas/config. Keys, snapshots, real questions, conversation exports, and benchmark results stay local. Do not create a parallel copy under `~/bin` or edit APM's deployed output.
