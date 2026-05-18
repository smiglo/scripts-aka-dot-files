#!/bin/bash

LOCK_FILE="/tmp/lid_suspend.pid"
LOG_FILE="/var/log/acpi-lid.log"
IDLE_TIMEOUT=300

USER_NAME="tom"
USER_ID=$(id -u "$USER_NAME")
export HYPRLAND_INSTANCE_SIGNATURE=$(ls -t /run/user/$USER_ID/hypr/ | head -n 1)
export XDG_RUNTIME_DIR="/run/user/$USER_ID"

log() {
    echo "$(date +"%b %d %T") $@" >>$LOG_FILE
}

kill-waiter()
{
    if [[ -f "$LOCK_FILE" ]]; then
        log "killing waiter"
        kill "$(< "$LOCK_FILE")" 2>/dev/null
        rm "$LOCK_FILE"
    fi
}

log "state: '$1'"

case "$1" in
    *1|*close)
        log "lid closed"
        sudo -u "$USER_NAME" -E hyprctl dispatch dpms off
        kill-waiter
        log "starting waiter"
        (
            sleep $IDLE_TIMEOUT
            if grep -q "closed" /proc/acpi/button/lid/LID/state; then
                log "suspending"
                systemctl suspend
            fi
            rm "$LOCK_FILE"
        ) &
        echo $! > "$LOCK_FILE"
        ;;

    *0|*open)
        log "lid opened"
        kill-waiter
        sudo -u "$USER_NAME" -E hyprctl dispatch dpms on
        ;;
esac
