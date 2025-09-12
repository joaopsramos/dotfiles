#!/bin/bash

file=$ZED_RELATIVE_FILE
file_to_open=""

if [[ "$file" == *.ex ]]; then
    # Replace "lib/" with "test/"
    alt_file="${file/lib\//test/}"
    # Remove the file extension
    alt_file="${alt_file%.*}"
    # Append "_test.exs"
    file_to_open="${alt_file}_test.exs"
elif [[ "$file" == *_test.exs ]]; then
    # Replace "test/" with "lib/"
    alt_file="${file/test\//lib/}"
    # Replace "_test.exs" with ".ex"
    file_to_open="${alt_file%_test.exs}.ex"
fi

if [[ -n "$file_to_open" ]]; then
    zed "$file_to_open"
fi
