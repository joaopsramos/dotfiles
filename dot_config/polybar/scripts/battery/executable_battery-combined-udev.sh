#!/bin/sh

battery_print() {
    PATH_AC="/sys/class/power_supply/AC"
    PATH_BATTERY_0="/sys/class/power_supply/BAT0"
    PATH_BATTERY_1="/sys/class/power_supply/BAT1"

    ac=0
    battery_level_0=0
    battery_level_1=0
    battery_max_0=0
    battery_max_1=0

    if [ ! -f "$PATH_BATTERY_0/energy_now" ]; then
        exit
    fi

    if [ $(cat "$PATH_BATTERY_0/status") == "Charging" ]; then
        ac=1
    fi

    if [ -f "$PATH_BATTERY_0/energy_now" ]; then
        battery_level_0=$(cat "$PATH_BATTERY_0/energy_now")
    fi

    if [ -f "$PATH_BATTERY_0/energy_full" ]; then
        battery_max_0=$(cat "$PATH_BATTERY_0/energy_full")
    fi

    if [ -f "$PATH_BATTERY_1/energy_now" ]; then
        battery_level_1=$(cat "$PATH_BATTERY_1/energy_now")
    fi

    if [ -f "$PATH_BATTERY_1/energy_full" ]; then
        battery_max_1=$(cat "$PATH_BATTERY_1/energy_full")
    fi

    battery_level=$(("$battery_level_0 + $battery_level_1"))
    battery_max=$(("$battery_max_0 + $battery_max_1"))

    battery_percent=$(("$battery_level * 100"))
    battery_percent=$(("$battery_percent / $battery_max"))

    if [ "$ac" -eq 1 ]; then
        icon="%{T1}%{F#9ece6a}%{F-}%{T-}"

        # if [ "$battery_percent" -gt 97 ]; then
        #     echo "$icon"
        # else
        echo "$icon $battery_percent%"
        # fi
    else
        if [ "$battery_percent" -gt 85 ]; then
            icon="%{T5}%{T-}"
        elif [ "$battery_percent" -gt 60 ]; then
            icon="%{T5}%{T-}"
        elif [ "$battery_percent" -gt 35 ]; then
            icon="%{T5}%{T-}"
        elif [ "$battery_percent" -gt 20 ]; then
            icon="%{T5}%{F#e0af68}%{F-}%{T-}"
        else
            icon="%{T5}%{F#f7768e}%{F-}%{T-}"
        fi

        echo "$icon $battery_percent%"
    fi
}

path_pid="/tmp/polybar-battery-combined-udev.pid"

case "$1" in
    --update)
        pid=$(cat $path_pid)

        if [ "$pid" != "" ]; then
            kill -10 "$pid"
        fi
        ;;
    *)
        echo $$ > $path_pid

        trap exit INT
        trap "echo" USR1

        battery_print
        ;;
esac
