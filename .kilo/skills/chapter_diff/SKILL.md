# Skill: chapter_diff

## Description
Сравнивает текст главы из DOCX с текстом из XML. Извлекает главу из обоих форматов, очищает от разметки (теги XML, пустые строки), затем показывает diff изменений.

## Inputs
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| xml_path | string | yes | Путь к FB2 XML файлу |
| docx_path | string | yes | Путь к DOCX файлу |
| chapter_num | integer | yes | Номер главы |
| next_chapter_num | integer | yes | Номер следующей главы |
| output_path | string | no | Путь для отчета (по умолчанию: `diff_chapter{N}_report.txt` в корне проекта) |

## Outputs
| Output | Type | Description |
|--------|------|-------------|
| diff_output | string | Результат сравнения diff |
| has_changes | boolean | True если есть различия |
| report_path | string | Путь к сохраненному отчету (в корне проекта) |

## Implementation

### extract_chapter_from_xml(xml_path, chapter_num)
Извлекает секцию главы из FB2 XML между комментариями `<!-- Chapter N -->` и `<!-- Chapter N+1 -->` или `</body>`.

```python
import re

def extract_chapter_from_xml(xml_path, chapter_num):
    with open(xml_path, 'r') as f:
        content = f.read()

    chapter_pattern = rf'<!-- Chapter {chapter_num} -->(.*?)</section>\s*(?:<!-- Chapter {chapter_num + 1} -->|</body>)'
    match = re.search(chapter_pattern, content, re.DOTALL)
    if not match:
        return None
    return match.group(1)
```

### extract_chapter_from_docx(docx_path, chapter_num, next_chapter_num)
Извлекает текст главы из DOCX между "Глава N." и "Глава N+1.".

```python
import zipfile
import xml.etree.ElementTree as ET

def extract_chapter_from_docx(docx_path, chapter_num, next_chapter_num):
    ns = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

    with zipfile.ZipFile(docx_path, 'r') as z:
        with z.open('word/document.xml') as f:
            tree = ET.parse(f)
            root = tree.getroot()

    paras = root.findall('.//w:p', ns)
    text_parts = []
    chapter_start = False

    for para in paras:
        text = ''.join(t.text for t in para.findall('.//w:t') if t.text)
        if f'Глава {chapter_num}.' in text:
            chapter_start = True
        if chapter_start:
            text_parts.append(text)
            if f'Глава {next_chapter_num}.' in text:
                break

    return '\n'.join(text_parts) if text_parts else None
```

### clear_docx_text(text)
Удаляет пустые строки из текста DOCX.

```python
def clear_docx_text(text):
    lines = text.split('\n')
    return '\n'.join(line for line in lines if line.strip())
```

### clear_xml_text(xml_text)
Удаляет XML разметку, заменяет ссылки на сноски звёздочками, удаляет пустые строки и структурные элементы.

```python
import re

def clear_xml_text(xml_text):
    text = xml_text
    # Replace note references with asterisks
    text = re.sub(r'<a l:href="#note[^"]*" type="note">\[(\d+)\]</a>',
                  lambda m: '*' * int(m.group(1)), text)
    # Remove XML tags
    tags = ['<p>', '</p>', '<emphasis>', '</emphasis>', '<title>', '</title>',
            '<strong>', '</strong>', '<subtitle>', '</subtitle>',
            '<text-author>', '</text-author>', '<empty-line/>']
    for tag in tags:
        text = text.replace(tag, '')
    # Replace * * * with ***
    text = re.sub(r'\* \* \*', '***', text)
    # Remove structure lines
    lines = text.split('\n')
    result = []
    skip_patterns = ['<section>', '</section>', '<epigraph>', '</epigraph>',
                     '<body', '</body>']
    for line in lines:
        stripped = line.strip()
        if stripped and not any(stripped.startswith(p) for p in skip_patterns):
            result.append(stripped)
    return '\n'.join(result)
```

### compare_chapters(xml_path, docx_path, chapter_num, next_chapter_num, output_path=None)
Основная функция сравнения. Если `output_path` не указан, сохраняет в корень проекта.

```python
def compare_chapters(xml_path, docx_path, chapter_num, next_chapter_num, output_path=None):
    if output_path is None:
        output_path = f"diff_chapter{chapter_num}_report.txt"

    xml_chapter = extract_chapter_from_xml(xml_path, chapter_num)
    if xml_chapter is None:
        return "XML chapter not found", False, None

    docx_text = extract_chapter_from_docx(docx_path, chapter_num, next_chapter_num)
    if docx_text is None:
        return "DOCX chapter not found", False, None

    cleared_xml = clear_xml_text(xml_chapter)
    cleared_docx = clear_docx_text(docx_text)

    xml_file = f'/tmp/chapter_xml_{chapter_num}.txt'
    docx_file = f'/tmp/chapter_docx_{chapter_num}.txt'

    with open(xml_file, 'w') as f:
        f.write(cleared_xml)
    with open(docx_file, 'w') as f:
        f.write(cleared_docx)

    import subprocess
    result = subprocess.run(
        ['diff', '--color=always', docx_file, xml_file],
        capture_output=True,
        text=True
    )

    has_changes = result.stdout != ''
    diff_output = result.stdout if has_changes else "No differences found"

    with open(output_path, 'w') as f:
        f.write(f"=== Diff Report for Chapter {chapter_num} ===\n\n")
        f.write(diff_output)

    return diff_output, has_changes, output_path
```

## Usage Example
```
User: Сравни главу 95
Agent:
  skill: chapter_diff(
    xml_path="Светлый пепел луны(book_2).xml",
    docx_path="Когда луна догорит дотла.docx",
    chapter_num=95,
    next_chapter_num=96
  )
  Returns:
    diff_output: "<diff result>"
    has_changes: true/false
    report_path: "diff_chapter95_report.txt"
```

## Notes
- Отчет по умолчанию сохраняется в корне проекта: `diff_chapter{N}_report.txt`
- Опирается на скрипты `clear_docx_chapter.sh` и `clear_xml_chapter.sh` в `resources/test_chapter/`
- Использует `diff --color=always` для читаемого вывода
