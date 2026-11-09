# asonas/skills

Self-authored agent skills distributed through APM. Each skill lives in its own directory with `SKILL.md` and any required references or scripts.

## Source and distribution

Edit skill sources here. Register each enabled skill in `~/.apm/apm.yml`, whose source is `home@default/.apm/apm.yml` in [asonas/config](https://github.com/asonas/config), for example:

```yaml
dependencies:
  apm:
    - git: asonas/skills
      path: obsidian-vault
      targets: [claude, codex]
```

Config owns the enabled set and runtime targets. Editing `~/.apm/apm.yml` deploys through the APM watcher, and mise history records the revision. Publish reviewed source changes before updating dependencies and deploying through APM. Do not edit deployed copies or create parallel local skill links. Run `mise bootstrap` only when installation is explicitly authorized; do not run it for routine source edits or tests.

## Private runtime data

Skills may contain personal workflow conventions, but must not contain conversation exports, internal project records, search results, or real benchmark questions. Keep those in the local Vault. Wiki inspection records use `.agent-state/wiki-update/`; search benchmark data uses `.agent-state/vault-rag/`.

## Tests

```sh
mise exec -- ruby test/apple_interface_guidelines_scripts_test.rb
bash test/apple_interface_guidelines_skill_test.sh
bash test/herdr_lead_muse_task_test.sh
mise exec -- ruby test/vault_state_test.rb
```

Tests use synthetic fixtures and temporary directories, not the personal Vault. Validate skill metadata and inspect references before publishing. Generalized Vault-path resolution and broader workflow redesign are separate work from repository migration.
