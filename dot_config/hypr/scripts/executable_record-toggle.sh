#!/usr/bin/env bash
set -u
umask 077

state_dir="${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}/hypr-recording"
mkdir -p "$state_dir"
exec 9>"$state_dir/lock"
# Ignore another press while region selection or cleanup is in progress.
flock -n 9 || exit 0

is_recorder() {
    [[ "$1" =~ ^[0-9]+$ ]] \
        && [[ "$(ps -p "$1" -o comm= 2>/dev/null)" == "wf-recorder" ]] \
        && (( 10#$1 > 1 ))
}

if [[ -r "$state_dir/pid" ]]; then
    read -r stored_pid < "$state_dir/pid" || stored_pid=""
    if is_recorder "$stored_pid"; then
        kill -INT "$stored_pid"
        exit 0
    fi
    rm -f "$state_dir/pid"
fi

geometry=$(slurp) || exit 0
[[ -n "$geometry" ]] || exit 0
output_dir="$HOME/Videos/Recordings"
mkdir -p "$output_dir"
output_file="$output_dir/$(date +%Y-%m-%d_%H-%M-%S-%N).mp4"

recording_pid=""
cleanup() {
    trap - EXIT HUP INT TERM
    if is_recorder "$recording_pid"; then
        kill -INT "$recording_pid" 2>/dev/null || true
        wait "$recording_pid" 2>/dev/null || true
    fi
    flock 9
    local stored_pid=""
    if [[ -n "$recording_pid" && -r "$state_dir/pid" ]]; then
        read -r stored_pid < "$state_dir/pid" || stored_pid=""
        if [[ "$stored_pid" == "$recording_pid" ]]; then
            rm -f "$state_dir/pid"
            qs ipc call recording stopped >/dev/null 2>&1 || true
        fi
    fi
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

# Do not let the recorder inherit the toggle lock.
wf-recorder -g "$geometry" -f "$output_file" 9>&- &
recording_pid=$!
printf '%s\n' "$recording_pid" > "$state_dir/pid"
qs ipc call recording started >/dev/null 2>&1 || true
flock -u 9

status=0
wait "$recording_pid" || status=$?
cleanup
if [[ ( "$status" -eq 0 || "$status" -eq 130 ) && -s "$output_file" ]]; then
    notify-send "Recording saved" "$output_file"
else
    notify-send -u critical "Recording failed" "wf-recorder exited with status $status"
fi
