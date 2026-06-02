# asonas/skills

Self-authored skills for Claude Code / cursor-agent. Each skill is one directory containing a `SKILL.md` (plus optional supporting files such as `DESIGN.md`).

## Used together with asonas/dotfiles

This repository is not used on its own. It is meant to be used together with [asonas/dotfiles](https://github.com/asonas/dotfiles). The `apm.yml` in dotfiles references each skill here as a dependency, and they are deployed to the real environment via APM (Agent Package Manager).

In the dotfiles `apm.yml` they are registered like this:

```yaml
dependencies:
  apm:
    - asonas/skills/commit
    - asonas/skills/cross-review
    - asonas/skills/entire
    - asonas/skills/git-worktree-workflow
    - asonas/skills/legacy-code-improvement
    - asonas/skills/pr-review
    - asonas/skills/usb-debug
```

## How it is deployed

Run `./install.sh` from the root of asonas/dotfiles. APM places everything in the right location.

```bash
cd /path/to/asonas/dotfiles
./install.sh
```

Internally `install.sh` does the following:

- Symlinks `~/.apm/apm.yml` to the dotfiles `apm.yml`
- Runs `apm compile` to compile APM primitives into `CLAUDE.md` / `AGENTS.md`
- Runs `apm install -g --target claude,cursor`, deploying the dependencies — including the skills in this repository — to `~/.claude` and `~/.cursor`

So do not `git clone` this repository and use it directly. Deployment is always driven from the dotfiles `install.sh`.

## Adding a new skill

1. Create `<skill-name>/SKILL.md` in this repository
2. Add `asonas/skills/<skill-name>` to `dependencies.apm` in the asonas/dotfiles `apm.yml`
3. Re-run `./install.sh` in asonas/dotfiles to deploy it

Adding a directory to this repository alone does not make the skill available to Claude Code / cursor-agent. You must also register the dependency in dotfiles and re-run the install before it takes effect. Creating symlinks by hand is not necessary — running the dotfiles `install.sh` is the correct path.
