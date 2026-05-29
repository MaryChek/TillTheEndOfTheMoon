#!/bin/bash
# clear_docs_chapter.sh
# Takes a text file and removes all empty lines

if [ $# -eq 0 ]; then
    echo "Usage: $0 <file>"
    exit 1
fi

input_file="$1"

# Remove all empty lines (lines that are empty or contain only whitespace)
sed -e '/^[[:space:]]*$/d' "$input_file" > "$input_file.tmp" && mv "$input_file.tmp" "$input_file"

echo "Removed empty lines from: $input_file"