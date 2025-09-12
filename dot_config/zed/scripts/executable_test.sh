#!/bin/bash

LAST_CMD_FILE="$HOME/.cache/zed_last_test_cmd"

if [[ "$1" == "--rerun" ]]; then
    if [[ -f "$LAST_CMD_FILE" ]]; then
        last_cmd=$(cat "$LAST_CMD_FILE")

        if [[ "$last_cmd" == mix\ test* ]]; then
            echo "Running: $last_cmd"
            $last_cmd
            exit $?
        fi
    fi
    exit 1
fi

file=$ZED_RELATIVE_FILE
cmd=""

if [[ "$file" == *.exs ]]; then
    cmd="mix test $ZED_RELATIVE_FILE"

    if [[ "$1" == "--line" ]]; then
        cmd+=":$ZED_ROW"
    fi

    echo $cmd > "$LAST_CMD_FILE"
    $cmd
fi
