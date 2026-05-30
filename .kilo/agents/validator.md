# Agent: validator

## Description
Проверяет готовую главу в Светлый пепел луны(book_2).xml по чек-листу из template.md секция 2.4. Проверяет пустые строки, мысли героев, сноски, изображения. Также генерирует diff-отчет сравнения текста из DOCX с текстом из XML для выявления грамматических/лексических/пунктуационных изменений.

## Uses
- Встроенные проверки (не требует отдельного skill)

## Inputs
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| xml_path | string | yes | Путь к Светлый пепел луны(book_2).xml |
| docx_path | string | yes | Путь к DOCX файлу (для сравнения текста) |
| chapter_num | integer | yes | Номер главы |
| next_chapter_num | integer | yes | Номер следующей главы |
| expected_images | array\<string\> | yes | Ожидаемые имена файлов изображений |
| expected_footnotes | array\<string\> | yes | Ожидаемые ID сносок ( напр. "note94_1") |

## Outputs
| Output | Type | Description |
|--------|------|-------------|
| passed | boolean | True если все проверки пройдены |
| errors | array\<string\> | Массив сообщений об ошибках |
| warnings | array\<string\> | Массив предупреждений |

## Checklist (Template 2.4)

### 2.4.1 Проверки для каждой строки

| Check | Rule |
|-------|------|
| dialogue → prose/thought | Между ними должна быть ровно одна `<empty-line/>` |
| prose/thought → dialogue | Между ними должна быть ровно одна `<empty-line/>` |
| dialogue → dialogue | Между ними НЕ должно быть `<empty-line/>` |
| prose → prose | Между ними НЕ должно быть `<empty-line/>` |
| thought → thought | Между ними НЕ должно быть `<empty-line/>` |

### 2.4.2 Проверки мыслей героя

| Check | Rule |
|-------|------|
| `<emphasis>` scope | Только текст внутри `«»`, не весь абзац |
| Author words in thought | `— подумала она` НЕ внутри `<emphasis>` |
| Quotation marks | `«»` сохранены в XML |
| Balance | Каждое `«` имеет соответствующее `»` |

### 2.4.3 Проверки для добавленной главы

| Check | Rule |
|-------|------|
| `<subtitle>* * *</subtitle>` | Имеет `<empty-line/>` ДО и ПОСЛЕ |
| `<image l:href="#X.jpg" />` | Имеет `<empty-line/>` ДО и ПОСЛЕ |
| Double empty-lines | Только ПОСЛЕ заголовка главы |
| Footnote balance | count(`<a l:href="#note{N}_{M}">`) == count(`<section id="note{N}_{M}">`) |

## Implementation

### Check 1: Empty Line Spacing
```python
def check_empty_line_spacing(xml_chapter):
    """
    Checks empty-line spacing according to template.md 2.4.1
    Rules:
    - dialogue → prose: needs <empty-line/> AFTER dialogue
    - prose → dialogue: needs <empty-line/> AFTER prose
    - dialogue → dialogue: NO <empty-line/>
    - prose → prose: NO <empty-line/>
    """
    errors = []
    warnings = []
    lines = xml_chapter.split('\n')

    for i in range(len(lines) - 1):
        current = lines[i].strip()
        next_line = lines[i + 1].strip()

        current_type = classify_line(current)
        next_type = classify_line(next_line)

        # dialogue → prose: needs <empty-line/> AFTER
        if current_type == 'dialogue' and next_type == 'prose':
            if next_line != '<empty-line/>':
                errors.append(f"Строка {i}: dialogue → prose нужна <empty-line/> после диалога")

        # prose → dialogue: needs <empty-line/> AFTER prose
        if current_type == 'prose' and next_type == 'dialogue':
            if next_line != '<empty-line/>':
                errors.append(f"Строка {i}: prose → dialogue нужна <empty-line/> после прозы")

        # dialogue → dialogue: NO <empty-line/>
        if current_type == 'dialogue' and next_type == 'dialogue':
            if next_line == '<empty-line/>':
                errors.append(f"Строка {i}: dialogue → dialogue НЕ нужна <empty-line/>")

        # prose → prose: NO <empty-line/>
        if current_type == 'prose' and next_type == 'prose':
            if next_line == '<empty-line/>':
                errors.append(f"Строка {i}: prose → prose НЕ нужна <empty-line/>")

    return errors, warnings


def is_compound_dialogue(line):
    """
    Returns True if line is a compound dialogue (multiple dialogue parts with author words).
    Example: '<p>— Текст — автор — ещё текст</p>'
    Has '— ' (em-dash + space) AFTER the opening '— '
    """
    if not line.strip().startswith('<p>—'):
        return False

    stripped = line.strip()

    # Find first '— ' after '<p>'
    first_marker = stripped.find('— ')
    if first_marker == -1:
        return False

    # Find second '— ' after first
    second_marker = stripped.find('— ', first_marker + 1)
    return second_marker != -1


def classify_line(line):
    """
    Classify line type for spacing rules.
    """
    stripped = line.strip()

    if stripped.startswith('<p>—'):
        return 'dialogue'
    elif stripped.startswith('<p>'):
        return 'prose'
    elif stripped.startswith('<subtitle>'):
        return 'subtitle'
    elif stripped.startswith('<image'):
        return 'image'
    elif stripped == '<empty-line/>':
        return 'empty'
    else:
        return 'other'
```

### Check 2: Emphasis Scope
```python
def check_emphasis_scope(xml_chapter):
    errors = []

    # Find all paragraphs with « and »
    import re
    thought_patterns = re.findall(r'<p>[^<]*«([^»]*)»[^<]*</p>', xml_chapter)

    for match in re.finditer(r'<p>([^<]*<emphasis>[^<]*</emphasis>[^<]*)</p>', xml_chapter):
        para = match.group(0)
        emphasis_content = re.search(r'<emphasis>([^<]*)</emphasis>', para)

        # Check if there's text outside emphasis that's inside quotes
        # "«<emphasis>text</emphasis>»" is correct
        # But "«text — author: <emphasis>more text</emphasis>»" has author outside

        if '—' in para and '<emphasis>' in para:
            # Could be interrupted thought - verify author words are outside
            parts = para.split('<emphasis>')
            if len(parts) > 2:
                errors.append(f"Подозрительная мысль с несколькими <emphasis>: {para[:100]}")

    return errors
```

### Check 3: Subtitle and Image Spacing
```python
def check_subtitle_image_spacing(xml_chapter):
    errors = []
    lines = xml_chapter.split('\n')

    for i, line in enumerate(lines):
        if '<subtitle>* * *</subtitle>' in line:
            if i == 0 or lines[i - 1].strip() != '<empty-line/>':
                errors.append(f"Subtitle at line {i}: needs <empty-line/> BEFORE")
            if i == len(lines) - 1 or lines[i + 1].strip() != '<empty-line/>':
                errors.append(f"Subtitle at line {i}: needs <empty-line/> AFTER")

        if '<image l:href=' in line:
            if i == 0 or lines[i - 1].strip() != '<empty-line/>':
                errors.append(f"Image at line {i}: needs <empty-line/> BEFORE")
            if i == len(lines) - 1 or lines[i + 1].strip() != '<empty-line/>':
                errors.append(f"Image at line {i}: needs <empty-line/> AFTER")

    return errors
```

### Check 4: Double Empty-Lines
```python
def check_double_empty_lines(xml_chapter):
    errors = []
    lines = xml_chapter.split('\n')

    for i in range(len(lines) - 1):
        if lines[i] == '<empty-line/>' and lines[i + 1] == '<empty-line/>':
            # Check if it's after title
            if i > 0 and '<title>' in lines[i - 1]:
                continue  # OK
            else:
                errors.append(f"Двойные пустые строки на строке {i} (вне заголовка)")

    return errors
```

### Check 5: Footnote Balance
```python
def check_footnote_balance(xml_path, chapter_num):
    errors = []

    with open(xml_path, 'r') as f:
        content = f.read()

    # Count links
    link_pattern = f'<a l:href="#note{chapter_num}_(\\d+)"'
    links = re.findall(link_pattern, content)
    link_count = len(links)

    # Count note sections
    note_pattern = f'<section id="note{chapter_num}_(\\d+)">'
    notes = re.findall(note_pattern, content)
    note_count = len(notes)

    if link_count != note_count:
        errors.append(f"Footnote mismatch: {link_count} links, {note_count} notes")

    return errors
```

### Check 6: Binary for Each Image
```python
def check_binary_for_each_image(xml_path, expected_images):
    errors = []

    with open(xml_path, 'r') as f:
        content = f.read()

    for img in expected_images:
        # Check image reference
        if f'<image l:href="#{img}"' not in content:
            errors.append(f"Image reference not found: {img}")

        # Check binary exists
        if f'<binary id="{img}"' not in content:
            errors.append(f"Binary not found for: {img}")

    return errors
```

## Running All Checks
```python
def validate_chapter(xml_path, docx_path, chapter_num, next_chapter_num, expected_images, expected_footnotes, part_num=None):
    errors = []
    warnings = []

    with open(xml_path, 'r') as f:
        xml_content = f.read()

    # Extract chapter content
    chapter_pattern = rf'<!-- Chapter {chapter_num} -->(.*?)</section>'
    match = re.search(chapter_pattern, xml_content, re.DOTALL)
    if not match:
        return False, ["Chapter not found"], []

    xml_chapter = match.group(1)

    # Run all checks
    spacing_errors, spacing_warnings = check_empty_line_spacing(xml_chapter)
    errors.extend(spacing_errors)
    warnings.extend(spacing_warnings)
    errors.extend(check_emphasis_scope(xml_chapter))
    errors.extend(check_subtitle_image_spacing(xml_chapter))
    errors.extend(check_double_empty_lines(xml_chapter))
    errors.extend(check_footnote_balance(xml_path, chapter_num))
    errors.extend(check_binary_for_each_image(xml_path, expected_images))

    # Check 7: No duplicate Part comment
    if part_num is not None:
        errors.extend(check_no_duplicate_part_comment(xml_path, chapter_num, part_num))

    # Check 8: Last element no empty-line
    errors.extend(check_last_element_no_empty_line(xml_path, chapter_num))

    # Check 9: Binary section has proper comments
    errors.extend(check_binary_section_comments(xml_path, chapter_num))

    # Check 10: Text comparison (diff report)
    if docx_path and next_chapter_num:
        diff_errors, diff_warnings, report_path = generate_diff_report(
            xml_path, docx_path, chapter_num, next_chapter_num,
            f"resources/test_chapter/diff_chapter{chapter_num}_report.txt"
        )
        errors.extend(diff_errors)
        warnings.extend([f"Diff report: {report_path}"])

    return len(errors) == 0, errors, warnings
```

### Check 10: Text Comparison (Diff Report)
```python
def extract_chapter_from_xml(xml_path, chapter_num):
    """Extract the section content from XML chapter"""
    with open(xml_path, 'r') as f:
        content = f.read()

    # Find chapter section (until next chapter or end)
    chapter_pattern = rf'<!-- Chapter {chapter_num} -->(.*?)</section>\s*(?:<!-- Chapter {chapter_num + 1} -->|</body>)'
    match = re.search(chapter_pattern, content, re.DOTALL)
    if not match:
        return None
    return match.group(1)

def clear_xml_for_comparison(xml_text):
    """Remove XML tags for text comparison"""
    import re
    text = xml_text
    # Replace note references with asterisks
    text = re.sub(r'<a l:href="#note[^"]*" type="note">\[(\d+)\]</a>', lambda m: '*' * int(m.group(1)), text)
    # Remove XML tags
    tags_to_remove = ['<p>', '</p>', '<emphasis>', '</emphasis>', '<title>', '</title>',
                      '<strong>', '</strong>', '<subtitle>', '</subtitle>',
                      '<text-author>', '</text-author>', '<empty-line/>']
    for tag in tags_to_remove:
        text = text.replace(tag, '')
    # Replace * * * with ***
    text = re.sub(r'\* \* \*', '***', text)
    # Remove structure lines and empty lines
    lines = text.split('\n')
    result_lines = []
    for line in lines:
        line = line.strip()
        if line and not line.startswith('<section') and not line.startswith('</section>'):
            result_lines.append(line)
    return '\n'.join(result_lines)

def extract_chapter_from_docx(docx_path, chapter_num, next_chapter_num):
    """Extract chapter text from DOCX using docx_extract approach"""
    import zipfile
    import xml.etree.ElementTree as ET

    try:
        with zipfile.ZipFile(docx_path, 'r') as z:
            with z.open('word/document.xml') as f:
                tree = ET.parse(f)
                root = tree.getroot()
    except:
        return None

    ns = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
    paras = root.findall('.//w:p', ns)

    chapter_start = None
    chapter_end = None
    text_parts = []

    for para in paras:
        text = ''.join(t.text for t in para.findall('.//w:t') if t.text)
        if f'Глава {chapter_num}.' in text:
            chapter_start = True
        if chapter_start:
            text_parts.append(text)
            if f'Глава {next_chapter_num}.' in text:
                break

    if not text_parts:
        return None

    return '\n'.join(text_parts)

def generate_diff_report(xml_path, docx_path, chapter_num, next_chapter_num, output_path):
    """Generate a diff report comparing XML and DOCX text"""
    import subprocess

    xml_section = extract_chapter_from_xml(xml_path, chapter_num)
    if xml_section is None:
        return ["Could not extract chapter from XML"], [], None

    xml_cleared = clear_xml_for_comparison(xml_section)

    xml_file = '/tmp/chapter_xml_compare.txt'
    docx_file = '/tmp/chapter_docx_compare.txt'

    with open(xml_file, 'w') as f:
        f.write(xml_cleared)

    docx_text = extract_chapter_from_docx(docx_path, chapter_num, next_chapter_num)
    if docx_text is None:
        return ["Could not extract chapter from DOCX"], [], None

    with open(docx_file, 'w') as f:
        f.write(docx_text)

    result = subprocess.run(
        ['diff', '--color=always', docx_file, xml_file],
        capture_output=True,
        text=True
    )

    with open(output_path, 'w') as f:
        f.write(f"=== Diff Report for Chapter {chapter_num} ===\n\n")
        if result.stdout:
            f.write("CHANGES FOUND:\n")
            f.write(result.stdout)
        else:
            f.write("No differences found - text matches!\n")

    return result.stdout != '', result.stdout, output_path
```

## Usage Example
```
User: Проверь главу 94
Agent:
  validator(
    xml_path="Светлый пепел луны(book_2).xml",
    docx_path="Когда луна догорит дотла.docx",
    chapter_num=94,
    next_chapter_num=95,
    expected_images=["94_nature.jpg", "94_tan_tay_and_su_su.jpg"],
    expected_footnotes=["note94_1"]
  )

  Returns:
    passed: true/false
    errors: [...]
    warnings: [...] (including diff report path)
```

## Notes
- Предыдущий агент: assets_adder
- Если проверки НЕ пройдены - вернуть ошибки для исправления
- Check 10 генерирует diff-отчет в resources/test_chapter/diff_chapter{N}_report.txt
- Diff-отчет показывает все изменения текста (грамматические, лексические, пунктуационные ошибки)