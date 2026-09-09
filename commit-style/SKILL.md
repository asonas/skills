---
name: commit-style
description: Create signed Git commits and write commit or pull request text. Use when the user asks to commit changes, write a commit message, or compose a pull request title or description.
version: 0.4.0
---

# Git Commit Style

Create focused, signed commits and write commit or pull request text using these conventions. Repository-specific conventions take priority.

## Commit Workflow

When the user asks to create a commit:

1. Inspect `git status` and `git diff`. If a path was supplied, use `git -C <path>` for every Git command.
2. Group the requested changes into logical units. Stage only explicit files belonging to the current unit.
3. Keep structural and behavioral changes in separate commits when both exist, with the structural commit first.
4. Compose the message using the conventions below.
5. Commit with the dedicated AI-agent signing key:
   - Current directory: `git -c user.signingkey=735D5A50F3ED5D795B20468F06FE62FF2104E75E commit -S ...`
   - Explicit path: `git -C <path> -c user.signingkey=735D5A50F3ED5D795B20468F06FE62FF2104E75E commit -S ...`
6. If signing fails, stop and report the failure. Do not retry without signing.
7. Verify the result with `git verify-commit HEAD`, using `git -C <path>` when applicable. Report completion only after verification succeeds.

The command-scoped signing key preserves the user's global signing key for commits they create themselves.

## Subject Line

- Aim for fewer than 50 characters
- Use English
- Start imperative verbs with a capital letter
- Do not use Conventional Commits
- Do not end with a period
- Keep technical identifiers verbatim
- Embed the reason when concise: `Avoid enlarging small images`, `Avoid double-save on withdraw`

### Keeping Subjects Short

- Drop `Add` when the named artifact is already the primary deliverable: `site-sessions: SiteSession model`
- Omit secondary artifacts that are clear from the diff and explain them in the body
- Use `&` instead of `and` when it remains readable
- Drop qualifiers already conveyed by the prefix

### Contextful Verbs

Prefer specific verbs over generic ones:

- `Avoid` or `Address` over `Fix` for preventive changes
- `Extract` over `Refactor` when pulling out a concern or class
- `Introduce` over `Add` when creating a new concept or abstraction
- `Reflect` over `Update` when synchronizing external state
- `Gain` for a component receiving a capability
- `Learn` for a component receiving an option or parameter
- `No longer` for behavioral removals
- `Roll` for dependency and referenced image or tag updates
- `Trigger` for CI and build triggers

## Prefix Pattern

Use `prefix: rest of subject` when the commit targets a specific component.

Useful prefixes include:

- Class or module: `SponsorEventAssetFilesController: Fix authorization`
- Method: `SponsorEventsController#destroy: Avoid double-save`
- View or route: `broadcasts/show: Sort recipients alphabetically`
- Feature or epic: `site-sessions: Introduce SiteSession model`
- File or directory: `Dockerfile: Build minimal libvips image`
- Subsystem or infrastructure: `tf/k8s: Roll ingress image`

Omit a prefix when the subject already names the target, the change spans the whole project, or a terse message such as `Typo` is sufficient.

## Body

Use the body to explain context that is not obvious from the diff: why the change is needed, what problem it solves, or what non-obvious behavior motivated it.

- Do not repeat the diff
- Open with the background, rationale, or problem
- Use `- ` bullets when enumerating multiple details
- Wrap lines at about 72 characters
- Put issue references such as `Closes #N` at the end
- Omit the body when the subject and diff are self-explanatory

Example:

```text
SponsorEventsController#destroy: Avoid double-save

withdrawn! saves immediately, creating one editing history record,
then save! creates a second one with no meaningful diff. The job was
enqueued with the second history, missing the status change.
```

## Pull Requests

Apply the same subject conventions to pull request titles, allowing up to 70 characters.

- For a single-commit branch, use the commit subject as the title and its body as the description
- For a multi-commit branch, summarize the branch and explain its commits under headings or bullets
- Do not include test procedures, QA checklists, task lists, or TODO checkboxes in the description

Follow the active repository instructions for authorization, worktree creation, integration, and push boundaries.
