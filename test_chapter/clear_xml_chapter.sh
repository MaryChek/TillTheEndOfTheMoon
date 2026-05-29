#!/bin/bash
# clear_xml_chapter.sh
# Takes a text file and removes XML formatting tags for readability comparison

if [ $# -eq 0 ]; then
    echo "Usage: $0 <file>"
    exit 1
fi

input_file="$1"

# Create temp file for processing
temp_file=$(mktemp)

# Process the file:
# 1. Replace note references <a l:href="#note65_2" type="note">[2]</a> with asterisks
# 2. Remove basic XML tags
# 3. Remove empty-line lines and other XML structure lines
# 4. Replace * * * with ***

perl -pe 's/<a l:href="#note[^"]*" type="note">\[(\d+)\]<\/a>/"*" x $1/eg' "$input_file" | \
sed -e 's/<p>//g' \
    -e 's/<\/p>//g' \
    -e 's/<emphasis>//g' \
    -e 's/<\/emphasis>//g' \
    -e 's/<title>//g' \
    -e 's/<\/title>//g' \
    -e 's/<strong>//g' \
    -e 's/<\/strong>//g' \
    -e 's/<subtitle>//g' \
    -e 's/<\/subtitle>//g' \
    -e 's/<text-author>//g' \
    -e 's/<\/text-author>//g' \
    -e 's/\* \* \*/\*\*\*/g' | \
grep -v '<empty-line/>' | \
grep -v '<section>' | \
grep -v '</section>' | \
grep -v '<epigraph>' | \
grep -v '</epigraph>' | \
grep -v '<body' | \
grep -v '</body>' | \
grep -v '<!--.*-->' > "$temp_file"

# Replace original file with cleaned version
mv "$temp_file" "$input_file"

echo "Cleared XML tags from: $input_file"