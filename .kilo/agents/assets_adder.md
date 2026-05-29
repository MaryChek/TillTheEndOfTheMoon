# Agent: assets_adder

## Description
Добавляет главу в Светлый пепел луны(book_2).xml: вставляет текст главы, notes section, и binary images. Также заменяет footnote links в тексте. Добавляет комментарии `<!-- For Part -->` и `<!-- For Chapter -->` согласно правилам.

## Uses
- skill: xml_footnotes
- skill: xml_images_binary

## Inputs
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| target_xml_path | string | yes | Путь к "Светлый пепел луны(book_2).xml" |
| xml_chapter | string | yes | XML текст главы от chapter_converter |
| chapter_num | integer | yes | Номер главы |
| images | array\<ImageRef\> | yes | Массив ссылок на изображения |
| footnotes | array\<FootnoteDef\> | yes | Массив определений сносок |
| part_info | PartInfo | yes | Информация о Part |

## Outputs
| Output | Type | Description |
|--------|------|-------------|
| success | boolean | True если успешно |
| message | string | Статус сообщение |

## Workflow
```
┌────────────────────────────────────────────┐
│ Step 1: xml_footnotes                      │
│ Input: footnotes[], chapter_num,           │
│        part_info.part_num                  │
│                                            │
│ Output: footnote_links_map,                │
│         footnote_notes_xml                 │
└────────────────────┬───────────────────────┘
                     │
┌────────────────────▼───────────────────────┐
│ Step 2: xml_images_binary                  │
│ Input: images[], part_info,                │
│        part_binary_already_exists          │
│                                            │
│ Output: binary_xml_with_comments           │
└────────────────────┬───────────────────────┘
                     │
┌────────────────────▼───────────────────────┐
│ Step 3: Insert chapter into <body>         │
│ Replace placeholder with xml_chapter       │
└────────────────────┬───────────────────────┘
                     │
┌────────────────────▼───────────────────────┐
│ Step 4: Replace footnote links in text     │
│ Using footnote_links_map                   │
└────────────────────┬───────────────────────┘
                     │
┌────────────────────▼───────────────────────┐
│ Step 5: Insert notes in <body name="notes">│
│ + Add comments <!-- For Part -->           │
│ + Add comments <!-- For Chapter -->        │
│ Only if first note for this Part           │
└────────────────────┬───────────────────────┘
                     │
┌────────────────────▼───────────────────────┐
│ Step 6: Insert binary in <!-- Images -->   │
│ + Add comments                             │
│ Only if first binary for this Part         │
└────────────────────────────────────────────┘
```

## Step Details

### Step 1: xml_footnotes
```python
footnote_links_map, footnote_notes_xml = create_footnotes(
    footnotes, chapter_num, part_info.part_num
)
```

### Step 2: xml_images_binary
```python
part_binary_already_exists = check_if_part_binary_exists(
    target_xml_path, part_info.part_num
)

binary_xml_with_comments = create_binary_xml_with_comments(
    images, part_info, chapter_num, part_binary_already_exists
)
```

### Step 3: Insert chapter
```python
# Проверить существование placeholder'ов в файле
# placeholder может быть вида:
# <!-- Chapter {chapter_num} -->
#     <section>
#         <title>...</title>
#     </section>

chapter_marker = f"<!-- Chapter {chapter_num} -->"

# Check if Part comment already exists before this chapter
part_comment_exists = part_comment_exists_before_chapter(
    target_xml_content, chapter_num, part_info.part_num
)

# Prepare the Chapter comment with proper indentation (3 tabs)
chapter_comment = f"            <!-- Chapter {chapter_num} -->"

if chapter_marker in target_xml_content:
    # Replace existing placeholder with new content
    # If Part comment doesn't exist, add it with 2 tabs before Chapter comment
    if not part_comment_exists:
        full_insert = f"        <!-- Part {part_info.part_num}. «{part_info.part_title} -->\n{chapter_comment}{xml_chapter_after_comment}"
    else:
        full_insert = f"{chapter_comment}{xml_chapter_after_comment}"
    replace_chapter_placeholder(target_xml_path, chapter_num, xml_chapter)
else:
    # Insert new chapter in correct position
    insert_chapter(target_xml_path, chapter_num, xml_chapter)
```

IMPORTANT: Part comment uses 2 tabs (8 spaces): `        <!-- Part N. «Title» -->`
Chapter comment uses 3 tabs (12 spaces): `            <!-- Chapter N -->`

### Step 4: Replace footnote links
```python
for original, replacement in footnote_links_map.items():
    xml_content = xml_content.replace(original, replacement)
```

### Step 5: Insert notes
```python
# Check if this is first note for this Part
notes_body_start = xml_content.find('<body name="notes">')

if part_notes_exist_for_part(notes_body_start, part_info.part_num):
    # Only add Chapter comment
    notes_comment = f"\n    <!-- For Chapter {chapter_num} -->\n"
else:
    # Add Part AND Chapter comments
    notes_comment = f"\n    <!-- For Part {part_info.part_num} -->\n    <!-- For Chapter {chapter_num} -->\n"

# Insert before closing </body>
insert_at = xml_content.rfind('</body>', notes_body_start)
xml_content = xml_content[:insert_at] + notes_comment + footnote_notes_xml + xml_content[insert_at:]
```

### Step 6: Insert binary images
```xml
<!-- Images -->
    <!-- Book 2. Бессмертные -->
        <!-- For Part 14 -->           (only if part_binary_already_exists is False)
            <binary id="part_14.jpg" content-type="image/jpeg">...</binary>
            <!-- For Chapter 95 -->   (always for this chapter)
                <binary id="95_tan_tay_and_su_su.jpg" content-type="image/jpeg">...</binary>
```

IMPORTANT: The `<!-- For Part N -->` comment is ONLY added if `part_binary_already_exists` is False.
The `<!-- For Chapter N -->` comment is ALWAYS added for this chapter's images.

## Checking Part Binary/Notes Existence
```python
def part_binary_already_exists(xml_path, part_num):
    """Check if any binary for this Part already exists in file"""
    with open(xml_path, 'r') as f:
        content = f.read()
    return f'<binary id="part_{part_num}.jpg"' in content

def part_notes_exist_for_part(notes_body, part_num):
    """Check if any note for this Part already exists"""
    # Search backwards from current position to find <!-- For Part -->
    # If found, Part already has notes
    # If not found, this is first note for this Part

def part_comment_exists_before_chapter(content, chapter_num, part_num):
    """Check if Part comment already exists before this chapter's Chapter comment"""
    # Find the Chapter comment position
    chapter_marker = f"<!-- Chapter {chapter_num} -->"
    chapter_pos = content.find(chapter_marker)
    if chapter_pos == -1:
        return False  # Chapter not found

    # Search in content before this chapter for Part comment
    before_content = content[:chapter_pos]
    part_comment_pattern = rf'<!-- Part {part_num}\.'
    return bool(re.search(part_comment_pattern, before_content))
```

## Usage Example
```
User: Добавь главу 94 в Светлый пепел луны(book_2).xml
Agent:
  Previous agent: chapter_converter returned:
    - xml_chapter: "..."
    - images: [94_nature.jpg, 94_tan_tay_and_su_su.jpg]
    - footnotes: [...]
    - part_info: {part_num: 14, ...}

  Step 1: xml_footnotes(footnotes, 94, 14)
    → footnote_links_map, footnote_notes_xml

  Step 2: xml_images_binary(images, part_info, 14, part_exists)
    → binary_xml_with_comments

  Step 3-6: Insert all into Светлый пепел луны(book_2).xml

  Returns: success: true
```

## Notes
- Предыдущий агент: chapter_converter
- Следующий агент: validator (для проверки)