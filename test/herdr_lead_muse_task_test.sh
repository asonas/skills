#!/bin/bash
# muse-task against fake hc and ghq: checks how tasks are launched,
# listed and read, without starting real agents.
set -eu

root="$(cd "$(dirname "$0")/.." && pwd)"
script="$root/herdr-lead/scripts/muse-task"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin" "$tmp/repos/github.com/acme/widget"
cat > "$tmp/bin/hc" <<'EOF'
#!/bin/bash
printf '%s\0' "$@" >> "$FAKE_HC_LOG"; printf '\n' >> "$FAKE_HC_LOG"
case "$1" in
    run) [ -z "${FAKE_HC_RUN_FAIL:-}" ] || { echo '{"error":{}}'; exit 1; }
         echo '{"address":"t9","name":"x"}' ;;
    get) echo '{"state":"live","status":{"state":"idle"}}' ;;
    wait) echo '{"reason":"timeout"}' ;;
    read) echo "screen line" ;;
    send) echo '{}' ;;
esac
EOF
cat > "$tmp/bin/ghq" <<EOF
#!/bin/bash
[ "\$4" = widget ] || [ "\$4" = acme/widget ] && echo "$tmp/repos/github.com/acme/widget"
exit 0
EOF
chmod +x "$tmp/bin/hc" "$tmp/bin/ghq"

export PATH="$tmp/bin:$PATH" MUSE_TASK_STATE="$tmp/state" FAKE_HC_LOG="$tmp/hc.log"
fail() { echo "FAIL: $*" >&2; exit 1; }

out="$("$script" start widget "Fix the typo in README")"
name="$(printf '%s\n' "$out" | sed -n 's/^name: //p')"
[[ "$name" =~ ^lead-widget-[0-9]{10}$ ]] || fail "unexpected name: $name"
[ "${#name}" -le 32 ] || fail "name longer than hc allows"
printf '%s\n' "$out" | grep -q '^terminal: t9$' || fail "terminal not reported"

launch="$(tr "\0" " " < "$tmp/hc.log")"
for want in "run --bg" "--outlive-parent" "--name $name" "--cwd $tmp/repos/github.com/acme/widget" \
    "--label muse-task=1" "claude --permission-mode auto" "$root/herdr-lead/SKILL.md" \
    "Result file: $tmp/state/$name/result.md" "Fix the typo in README"; do
    [[ "$launch" == *"$want"* ]] || fail "launch lacks: $want"
done

"$script" ls | grep -q "^$name	idle	no-result	" || fail "ls before result"
"$script" result "$name" | grep -q "screen line" || fail "result should fall back to the screen"
echo "status: done" > "$tmp/state/$name/result.md"
"$script" result "$name" | grep -qx "status: done" || fail "result file not printed"
"$script" ls | grep -q "^$name	idle	result	" || fail "ls after result"
"$script" wait "$name" | grep -q "still working" || fail "timeout not reported"
"$script" say "$name" "Use option B" | grep -q "sent to $name" || fail "say"
tail -1 "$tmp/hc.log" | tr '\0' ' ' | grep -q "send $name Use option B" || fail "say did not reach hc send"

if "$script" start nowhere "x" 2> /dev/null; then fail "unknown repo accepted"; fi
if "$script" result lead-unknown 2> /dev/null; then fail "unknown task accepted"; fi

before="$(ls "$tmp/state" | wc -l)"
if FAKE_HC_RUN_FAIL=1 "$script" start widget "x" 2> /dev/null; then fail "failed launch reported success"; fi
[ "$(ls "$tmp/state" | wc -l)" = "$before" ] || fail "failed launch left a task behind"
echo ok
