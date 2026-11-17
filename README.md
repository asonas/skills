# asonas/skills

Self-authored agent skills, published as the `asonas` plugin for Claude Code and Codex. Each skill lives in `skills/<name>/` with `SKILL.md` and any required references or scripts.

## Install

Claude Code:

```sh
claude plugin marketplace add asonas/skills
claude plugin install asonas@asonas-skills
```

Codex:

```sh
codex plugin marketplace add asonas/skills
codex plugin add asonas@asonas-skills
```

Skills are invoked with the plugin prefix in Claude Code, such as `/asonas:today`.

## Source and distribution

Edit skill sources here and publish reviewed changes to `main`; installed plugins pick them up on the next marketplace update. Do not edit installed copies in the plugin caches. Bundled scripts are referenced from the skill directory (`<skill-dir>`), never from a fixed install path, because the cache location differs between agents.

## Private runtime data

Skills may contain personal workflow conventions, but must not contain conversation exports, internal project records, search results, or real benchmark questions. Keep those in the local Vault. Wiki inspection records use `.agent-state/wiki-update/`; search benchmark data uses `.agent-state/vault-rag/`.

## Tests

```sh
mise exec -- ruby test/apple_interface_guidelines_scripts_test.rb
bash test/apple_interface_guidelines_skill_test.sh
bash test/herdr_lead_muse_task_test.sh
mise exec -- ruby test/vault_state_test.rb
```

Tests use synthetic fixtures and temporary directories, not the personal Vault. Validate skill metadata and inspect references before publishing, and check the manifests with `claude plugin validate .`.
