#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="${HOME}/Desktop/app22"
COMBINED_FILE="$(mktemp "${TMPDIR:-/tmp}/app22_code.XXXXXX")"
FILE_LIST="$(mktemp "${TMPDIR:-/tmp}/app22_files.XXXXXX")"

cleanup() {
  rm -f "$COMBINED_FILE" "$FILE_LIST"
}
trap cleanup EXIT

mkdir -p "$OUTPUT_DIR"

cd "$APP_ROOT"
rg --files lib test -g '*.dart' | LC_ALL=C sort > "$FILE_LIST"
if [[ ! -s "$FILE_LIST" ]]; then
  echo "No Dart files found under lib/ or test/." >&2
  exit 1
fi

# Preserve file boundaries while removing blank lines and trailing horizontal
# whitespace. Dart source order and all non-whitespace code remain unchanged.
while IFS= read -r source_file; do
  printf '// ===== FILE: %s =====\n' "$source_file" >> "$COMBINED_FILE"
  awk '
    {
      sub(/[[:blank:]]+$/, "")
      if ($0 !~ /^[[:blank:]]*$/) {
        print
      }
    }
  ' "$source_file" >> "$COMBINED_FILE"
done < "$FILE_LIST"

total_lines="$(wc -l < "$COMBINED_FILE" | tr -d '[:space:]')"
base_lines=$((total_lines / 3))
remainder=$((total_lines % 3))
part_1_lines=$((base_lines + (remainder > 0 ? 1 : 0)))
part_2_lines=$((base_lines + (remainder > 1 ? 1 : 0)))
part_1_end=$part_1_lines
part_2_end=$((part_1_lines + part_2_lines))

for part in 1 2 3; do
  : > "$OUTPUT_DIR/code_part_${part}.txt"
done

awk \
  -v first_end="$part_1_end" \
  -v second_end="$part_2_end" \
  -v part_1="$OUTPUT_DIR/code_part_1.txt" \
  -v part_2="$OUTPUT_DIR/code_part_2.txt" \
  -v part_3="$OUTPUT_DIR/code_part_3.txt" \
  '{
    if (NR <= first_end) {
      print > part_1
    } else if (NR <= second_end) {
      print > part_2
    } else {
      print > part_3
    }
  }' "$COMBINED_FILE"

echo "Exported $total_lines condensed lines to:"
for part in 1 2 3; do
  output_file="$OUTPUT_DIR/code_part_${part}.txt"
  echo "  $output_file ($(wc -l < "$output_file" | tr -d '[:space:]') lines)"
done

# Notes stores note bodies as HTML. Wrapping escaped source in <pre> preserves
# every visible character and line break from the generated text files.
osascript - "$OUTPUT_DIR" <<'APPLESCRIPT'
on replaceText(findText, replacementText, sourceText)
  set previousDelimiters to AppleScript's text item delimiters
  set AppleScript's text item delimiters to findText
  set sourceItems to text items of sourceText
  set AppleScript's text item delimiters to replacementText
  set replacedText to sourceItems as text
  set AppleScript's text item delimiters to previousDelimiters
  return replacedText
end replaceText

on htmlEscape(sourceText)
  set escapedText to my replaceText("&", "&amp;", sourceText)
  set escapedText to my replaceText("<", "&lt;", escapedText)
  set escapedText to my replaceText(">", "&gt;", escapedText)
  set escapedText to my replaceText("\"", "&quot;", escapedText)
  return escapedText
end htmlEscape

on run argv
  set outputDirectory to item 1 of argv

  tell application "Notes"
    activate
    set targetAccount to first account
    try
      set targetFolder to folder "App22 Code" of targetAccount
    on error
      set targetFolder to make new folder at targetAccount with properties {name:"App22 Code"}
    end try

    repeat with partNumber from 1 to 3
      set fileName to "code_part_" & partNumber & ".txt"
      set filePath to outputDirectory & "/" & fileName
      set noteText to read POSIX file filePath as «class utf8»
      set noteBody to "<pre>" & my htmlEscape(noteText) & "</pre>"
      make new note at targetFolder with properties {name:fileName, body:noteBody}
    end repeat
  end tell
end run
APPLESCRIPT

echo "Created the 'App22 Code' folder and three notes in Apple Notes."
