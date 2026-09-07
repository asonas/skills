#!/bin/sh
set -eu
skill=tidy-first-conventions/SKILL.md
test -f "$skill"
grep -q '^name: tidy-first-conventions$' "$skill"
grep -q '^description: Use when ' "$skill"
grep -q '`test-driven-development` skill' "$skill"
grep -q 'Only apply commit rules when the user asks for commits.' "$skill"
if grep -Eq 'Always follow the TDD cycle|Always run all the tests' "$skill"; then
    echo 'TDD workflow leaked into tidy-first-conventions' >&2
    exit 1
fi
