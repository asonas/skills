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
    get) if [ -n "${FAKE_HC_STARTING:-}" ]; then echo '{"state":"live","status":null}'
         else echo '{"state":"live","status":{"state":"idle"}}'; fi ;;
    wait) echo '{"reason":"timeout"}' ;;
    read) echo "${FAKE_HC_SCREEN:-screen line}" ;;
    ls) [ -z "${FAKE_HC_LS_FAIL:-}" ] || exit 1
        empty='{"terminals":[]}'; printf '%s\n' "${FAKE_HC_LS:-$empty}" ;;
    send) [ -z "${FAKE_HC_SEND_FAIL:-}" ] || exit 1
          echo '{}' ;;
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
"$script" ls | grep -q "^$name	idle	done	" || fail "ls after result"
for status in done needs-decision blocked; do
    printf 'status: %s\n' "$status" > "$tmp/state/$name/result.md"
    [ "$("$script" ls | cut -f3)" = "$status" ] || fail "ls status: $status"
done
for contents in 'no status line' 'status: done BODY' 'status:'; do
    printf '%s\n' "$contents" > "$tmp/state/$name/result.md"
    [ "$("$script" ls | cut -f3)" = unknown ] || fail "ls invalid status: $contents"
done
command rm "$tmp/state/$name/result.md"
[ "$("$script" ls | cut -f3)" = no-result ] || fail "ls missing result"
echo "status: done" > "$tmp/state/$name/result.md"
"$script" wait "$name" | grep -q "still working" || fail "timeout not reported"
"$script" say "$name" "Use option B" | grep -q "sent to $name" || fail "say"
tail -1 "$tmp/hc.log" | tr '\0' ' ' | grep -q "send $name Use option B" || fail "say did not reach hc send"

if "$script" start nowhere "x" 2> /dev/null; then fail "unknown repo accepted"; fi
if "$script" result lead-unknown 2> /dev/null; then fail "unknown task accepted"; fi

dialog="Quick safety check: Is this a project you created or one you trust this folder"
FAKE_HC_STARTING=1 FAKE_HC_SCREEN="$dialog" "$script" wait "$name" | grep -q "^blocked:" \
    || fail "trust dialog not reported by wait"
if "$script" trust "$name" 2> /dev/null; then fail "trust answered without a dialog"; fi
FAKE_HC_SCREEN="$dialog" "$script" trust "$name" | grep -q "^trusted" || fail "trust"
tail -1 "$tmp/hc.log" | tr '\0' ' ' | grep -q "keys $name down enter" || fail "trust did not answer Yes"

"$script" close "$name" | grep -q "closed $name" || fail "close"
tr '\0' ' ' < "$tmp/hc.log" | grep -q "kill $name" || fail "close did not kill the lead"
[ -f "$tmp/state/$name/result.md" ] || fail "close removed the result"

# Coders are named <lead>-c1, which must still fit hc's 32-character limit.
mkdir -p "$tmp/repos/github.com/acme/jellyfin-viewer.example"
long="$("$script" start "$tmp/repos/github.com/acme/jellyfin-viewer.example" "x" | sed -n 's/^name: //p')"
[ "$(( ${#long} + 3 ))" -le 32 ] || fail "coder name for $long exceeds 32 characters"

before="$(ls "$tmp/state" | wc -l)"
if FAKE_HC_RUN_FAIL=1 "$script" start widget "x" 2> /dev/null; then fail "failed launch reported success"; fi
[ "$(ls "$tmp/state" | wc -l)" = "$before" ] || fail "failed launch left a task behind"

# Freeze only the name timestamp; metadata dates still use the real date.
cat > "$tmp/bin/date" <<'EOF'
#!/bin/bash
if [ "$*" = +%m%d%H%M%S ]; then
    echo 0102030405
else
    exec /bin/date "$@"
fi
EOF
chmod +x "$tmp/bin/date"
export MUSE_TASK_STATE="$tmp/frozen-state"
first="$("$script" start widget "First task" | sed -n 's/^name: //p')"
second="$("$script" start widget "Second task" | sed -n 's/^name: //p')"
[ "$first" != "$second" ] || fail "same-second starts share a name"
for task in "$first" "$second"; do
    [ "${#task}" -le 29 ] || fail "lead name exceeds 29 characters: $task"
    [ -d "$MUSE_TASK_STATE/$task" ] || fail "missing task folder: $task"
done
grep -qx 'First task' "$MUSE_TASK_STATE/$first/task.md" || fail "first task overwritten"
grep -qx 'Second task' "$MUSE_TASK_STATE/$second/task.md" || fail "second task missing"
if FAKE_HC_RUN_FAIL=1 "$script" start widget "Third task" 2> /dev/null; then
    fail "failed same-second launch reported success"
fi
[ "$(ls "$MUSE_TASK_STATE" | wc -l | tr -d ' ')" = 2 ] || fail "failed same-second launch changed task folders"
grep -qx 'First task' "$MUSE_TASK_STATE/$first/task.md" || fail "failed launch removed first task"
grep -qx 'Second task' "$MUSE_TASK_STATE/$second/task.md" || fail "failed launch removed second task"

long_first="$("$script" start "$tmp/repos/github.com/acme/jellyfin-viewer.example" "x" | sed -n 's/^name: //p')"
long_second="$("$script" start "$tmp/repos/github.com/acme/jellyfin-viewer.example" "y" | sed -n 's/^name: //p')"
[ "$long_first" != "$long_second" ] || fail "long repo collision shares a name"
[[ "$long_second" == *-2 ]] || fail "long repo collision lacks suffix"
[ "$(( ${#long_second} + 3 ))" -le 32 ] || fail "suffixed coder name exceeds 32 characters"
# Notifications disclose only a safe status token and the result path.
export MUSE_TASK_STATE="$tmp/state"
export FAKE_HC_LS='{"terminals":[{"address":"r1"}]}'
result="$tmp/state/$name/result.md"
printf 'status: needs-decision\n\nBODY-SECRET\n' > "$result"
send_count() { tr '\0' '\t' < "$tmp/hc.log" | awk -F '\t' '$1 == "send" { n++ } END { print n+0 }'; }
before="$(send_count)"
"$script" notify "$name" | grep -qx 'notified r1' || fail "notify success"
[ "$(send_count)" = "$((before + 1))" ] || fail "notify send count"
printf 'send\0r1\0[muse-task] %s finished: status=needs-decision result=%s\0\n' "$name" "$result" > "$tmp/expected"
tail -1 "$tmp/hc.log" > "$tmp/actual"
cmp -s "$tmp/expected" "$tmp/actual" || fail "notify full send argv"
if LC_ALL=C grep -a -q BODY-SECRET "$tmp/hc.log"; then fail "result body leaked"; fi
printf 'ls\0--json\0--label\0muse-task.reviewer=1\0\n' > "$tmp/expected"
tail -2 "$tmp/hc.log" | head -1 > "$tmp/actual"
cmp -s "$tmp/expected" "$tmp/actual" || fail "default reviewer label argv"
MUSE_TASK_REVIEWER_LABEL=x.y=2 "$script" notify "$name" > /dev/null
printf 'ls\0--json\0--label\0x.y=2\0\n' > "$tmp/expected"
tail -2 "$tmp/hc.log" | head -1 > "$tmp/actual"
cmp -s "$tmp/expected" "$tmp/actual" || fail "custom reviewer label argv"

command rm "$result"
"$script" notify "$name" > /dev/null
printf 'send\0r1\0[muse-task] %s finished: status=unknown result=%s\0\n' "$name" "$result" > "$tmp/expected"
tail -1 "$tmp/hc.log" > "$tmp/actual"
cmp -s "$tmp/expected" "$tmp/actual" || fail "missing result status"
for contents in 'no status line' 'status:   ' 'status: done BODY-SECRET'; do
    printf '%s\n' "$contents" > "$result"
    "$script" notify "$name" > /dev/null
    tail -1 "$tmp/hc.log" > "$tmp/actual"
    cmp -s "$tmp/expected" "$tmp/actual" || fail "unsafe or absent status"
done
printf 'status:  blocked  \nstatus: done\n' > "$result"
"$script" notify "$name" > /dev/null
tail -1 "$tmp/hc.log" | tr '\0' '\t' | grep -q 'status=blocked result=' || fail "first status trimmed"

for terminals in '{"terminals":[]}' '{"terminals":[{"address":"r1"},{"address":"r2"}]}'; do
    before="$(send_count)"
    FAKE_HC_LS="$terminals" "$script" notify "$name" > /dev/null 2> "$tmp/warning" || fail "target count failed lead"
    [ "$(send_count)" = "$before" ] || fail "ambiguous reviewer notified"
    grep -q 'muse-task: warning:' "$tmp/warning" || fail "target count warning missing"
done
before="$(send_count)"
FAKE_HC_LS_FAIL=1 "$script" notify "$name" > /dev/null 2> "$tmp/warning" || fail "ls failure failed lead"
[ "$(send_count)" = "$before" ] || fail "sent after ls failure"
grep -q 'warning: hc ls failed' "$tmp/warning" || fail "ls failure warning missing"
FAKE_HC_SEND_FAIL=1 "$script" notify "$name" > /dev/null 2> "$tmp/warning" || fail "send failure failed lead"
grep -q 'warning: hc send failed' "$tmp/warning" || fail "send failure warning missing"
before="$(send_count)"
for invalid in lead-unknown '../escape' $'lead-\ninjected'; do
    "$script" notify "$invalid" > /dev/null 2> "$tmp/warning" || fail "invalid task failed lead"
    grep -q 'muse-task: warning:' "$tmp/warning" || fail "invalid task warning missing"
done
[ "$(send_count)" = "$before" ] || fail "invalid task notified"
if "$script" notify 2> /dev/null; then fail "notify accepted no arguments"; else
    [ "$?" = 2 ] || fail "notify usage exit code"
fi
if "$script" notify "$name" extra 2> /dev/null; then fail "notify accepted extra argument"; else
    [ "$?" = 2 ] || fail "notify extra argument exit code"
fi
echo ok
