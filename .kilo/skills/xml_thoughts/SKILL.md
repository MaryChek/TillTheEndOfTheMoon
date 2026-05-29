# Skill: xml_thoughts

## Description
Обрабатывает XML после xml_content и xml_structure. Находит мысли (текст в кавычках «») в диалогах и прозе, оборачивает их в `<emphasis>`. Генерирует отчёт со всеми найденными мыслями.

## Triggers
- "обработать мысли"
- "найти мысли в главе"
- "добавить emphasis к мыслям"

## Inputs
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| xml_fragment | string | yes | XML с диалогами и прозой (после xml_structure) |
| chapter_num | integer | yes | Номер главы (для отчёта) |

## Outputs
| Output | Type | Description |
|--------|------|-------------|
| xml_with_thoughts | string | XML с `<emphasis>` для мыслей |
| thoughts_report | array\<ThoughtInfo\> | Список всех найденных мыслей |

## Types

### ThoughtInfo
```yaml
line_number: integer    # Номер строки в XML
original_text: string   # Оригинальный текст строки
thoughts_found: array  # Массив найденных мыслей в строке
```

### Thought
```yaml
quoted_text: string     # Текст внутри кавычек
is_full_paragraph: boolean  # True если весь абзац — мысль
has_author_words: boolean   # True если есть слова автора (— подумала она)
```

## Algorithm

### Step 1: Find all lines with quotes
```python
import re

def find_thought_lines(xml):
    lines = xml.split('\n')
    thought_lines = []
    for i, line in enumerate(lines):
        if '«' in line and '»' in line:
            thought_lines.append({
                'line_number': i,
                'text': line,
                'thoughts': extract_thoughts(line)
            })
    return thought_lines
```

### Step 2: Extract thoughts from line
```python
def extract_thoughts(line):
    thoughts = []
    # Remove XML tags for analysis
    text = re.sub(r'<[^>]+>', '', line)

    if not ('«' in text and '»' in text):
        return thoughts

    # Check if entire paragraph is a thought
    text_stripped = text.strip()
    if text_stripped.startswith('«') and text_stripped.endswith('»'):
        # Check if there's author words inside
        inner = text_stripped[1:-1]  # Remove outer quotes
        if '— ' not in inner and ' —' not in inner:
            # No author words - full paragraph is a thought
            thoughts.append({
                'quoted_text': inner,
                'is_full_paragraph': True,
                'has_author_words': False
            })
        else:
            # Has author words - need to split
            parts = split_by_author_words(inner)
            for part in parts:
                if part.startswith('«') and part.endswith('»'):
                    thoughts.append({
                        'quoted_text': part[1:-1],
                        'is_full_paragraph': False,
                        'has_author_words': True
                    })
    else:
        # Embedded quotes - extract each «text» block
        thoughts.extend(extract_embedded_thoughts(text))

    return thoughts
```

### Step 3: Split by author words
```python
AUTHOR_WORDS_PATTERNS = [
    r'—\s*\w+\s+\w+\s*—',  # — подумала она, — решил он
    r'—\s*\w+\s*—',        # — воскликнул —
]

def split_by_author_words(text):
    """Split text by author words markers, keeping markers in result"""
    pattern = '|'.join(AUTHOR_WORDS_PATTERNS)
    parts = re.split(f'({pattern})', text)
    return [p for p in parts if p.strip()]
```

### Step 4: Extract embedded thoughts
```python
def extract_embedded_thoughts(text):
    """Extract «text» blocks that are embedded in prose/dialogue"""
    thoughts = []
    # Match quoted sections
    pattern = r'«([^»]+)»'
    matches = re.finditer(pattern, text)
    for match in matches:
        quoted = match.group(1)
        # Check if this is author words (usually short, contains —)
        if '—' in quoted:
            continue  # Skip author words
        thoughts.append({
            'quoted_text': quoted,
            'is_full_paragraph': False,
            'has_author_words': False
        })
    return thoughts
```

### Step 5: Wrap thoughts in emphasis
```python
def wrap_thoughts_in_emphasis(line, thoughts):
    """Wrap found thoughts in <emphasis> tags"""
    result = line
    for thought in thoughts:
        quoted = thought['quoted_text']
        # Escape for regex
        quoted_escaped = re.escape(quoted)
        # Replace in XML line (not the plain text)
        # Need to be careful to only replace the quoted part in proper context
        result = replace_quoted_with_emphasis(result, quoted)
    return result
```

### Step 6: Full processing
```python
def process_thoughts(xml, chapter_num):
    lines = xml.split('\n')
    thought_report = []

    for i, line in enumerate(lines):
        if '«' in line and '»' in line:
            thoughts = extract_thoughts(line)
            if thoughts:
                thought_report.append({
                    'line_number': i + 1,
                    'original_text': line.strip(),
                    'thoughts_found': thoughts
                })
                # Wrap thoughts in emphasis
                lines[i] = wrap_thoughts_in_emphasis(line, thoughts)

    return '\n'.join(lines), thought_report
```

## Thought Detection Examples

### Example 1: Full paragraph thought
```
Input:  <p>«Выходит, старший брат жив»</p>
Output: <p>«<emphasis>Выходит, старший брат жив</emphasis>»</p>
```

### Example 2: Thought with author words
```
Input:  <p>«Выходит, старший брат жив — подумала она — значит ли это...»</p>
Output: <p>«<emphasis>Выходит, старший брат жив</emphasis> — подумала она — <emphasis>значит ли это...</emphasis>»</p>
```

### Example 3: Embedded thought in prose
```
Input:  <p>Она посмотрела на него и подумала: «Неужели это он»</p>
Output: <p>Она посмотрела на него и подумала: «<emphasis>Неужели это он</emphasis>»</p>
```

### Example 4: Embedded thought in dialogue
```
Input:  <p>— Ты слышал? — спросил он. «Они пришли» — прошептал кто-то</p>
Output: <p>— Ты слышал? — спросил он. «<emphasis>Они пришли</emphasis>» — прошептал кто-то</p>
```

## Report Format

```json
{
  "chapter": 95,
  "total_thoughts": 12,
  "thoughts": [
    {
      "line_number": 2541,
      "original_text": "<p>«Выходит, старший брат жив»</p>",
      "thoughts_found": [
        {
          "quoted_text": "Выходит, старший брат жив",
          "is_full_paragraph": true,
          "has_author_words": false
        }
      ]
    },
    ...
  ]
}
```

## Notes
- Мысли определяются по наличию « и » в тексте
- Author words (— подумала она, — решил он) НЕ оборачиваются в emphasis
- Обрабатывает диалоги и прозу после xml_structure
- Генерирует отчёт для проверки корректности
