# asonas/skills

Self-authored agent skills distributed through APM. Each skill lives in its own directory with `SKILL.md` and any required references or scripts.

## Source and distribution

Edit skill sources here. Register each enabled skill in [asonas/dotfiles](https://github.com/asonas/dotfiles)'s `apm.yml`, for example:

```yaml
dependencies:
  apm:
    - git: asonas/skills
      path: obsidian-vault
      targets: [claude, codex]
```

Dotfiles owns the enabled set and runtime targets. Publish reviewed source changes before updating dependencies and deploying through APM. Do not edit deployed copies or create parallel local skill links. Run the dotfiles installer only when installation is explicitly authorized and from its canonical main worktree; do not run it for routine source edits or tests.

## Private runtime data

Skills may contain personal workflow conventions, but must not contain conversation exports, internal project records, search results, or real benchmark questions. Keep those in the local Vault. Wiki inspection records use `.agent-state/wiki-update/`; search benchmark data uses `.agent-state/vault-rag/`.

## Tests

```sh
mise exec -- ruby test/apple_interface_guidelines_scripts_test.rb
bash test/apple_interface_guidelines_skill_test.sh
mise exec -- ruby test/vault_state_test.rb
```

Tests use synthetic fixtures and temporary directories, not the personal Vault. Validate skill metadata and inspect references before publishing. Generalized Vault-path resolution and broader workflow redesign are separate work from repository migration.
