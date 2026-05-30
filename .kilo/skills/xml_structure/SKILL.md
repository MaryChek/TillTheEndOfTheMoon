# Skill: xml_structure

## Description
Добавляет `<empty-line/>` между блоками по правилам из template.md секция 2.2. Также форматирует `<subtitle>` и `<image>` с пустыми строками до и после.

## Triggers
- "расставить пустые строки"
- "добавить empty-line"
- "добавить разделители"

## Inputs
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| xml_fragment | string | yes | XML от xml_content (без пустых строк) |
| paragraphs | array\<Paragraph\> | yes | Оригинальные параграфы для определения типов переходов |

## Outputs
| Output | Type | Description |
|--------|------|-------------|
| xml_with_structure | string | XML с `<empty-line/>`, `<image>`, `<subtitle>` |

## Spacing Rules (Template 2.2)

### Key Definitions

**Compound Dialogue (Составной диалог):** Один абзац (одна строка XML), содержащий несколько реплик через `— Автор`. Пример: `<p>— Текст — автор — ещё текст</p>`. Это ОДИН блок, внутри НЕ добавляется empty-line.

**Separate Dialogue Lines:** Разные абзацы (разные строки XML), каждый начинается с `— `. Пример: строка 1: `<p>— Первая реплика</p>`, строка 2: `<p>— Вторая реплика</p>`. Это dialogue→dialogue, НЕ нужен empty-line между ними.

### Rule 1: Dialogue ↔ Prose transitions
| Current | Next | Action |
|---------|------|--------|
| dialogue (single line) | prose | Add `<empty-line/>` AFTER current |
| prose | dialogue (single line) | Add `<empty-line/>` AFTER current |

### Rule 2: Same type transitions — NO empty-line
| Current | Next | Action |
|---------|------|--------|
| dialogue | dialogue | NO `<empty-line/>` |
| prose | prose | NO `<empty-line/>` |
| compound dialogue | any | NO `<empty-line/>` until next non-compound line |

### Rule 3: Subtitle
```
<empty-line/>
<subtitle>* * *</subtitle>
<empty-line/>
```

### Rule 4: Image
```
<empty-line/>
<image l:href="#N_name.jpg" />
<empty-line/>
```

### Rule 5: Title (Double empty-lines allowed ONLY here)
```
<title><p><strong>Глава N. «Title»</strong></p></title>
<empty-line/>
<empty-line/>
```
**Error if double empty-lines appear anywhere else!**

## Algorithm
```python
def add_spacing(xml_fragment, paragraphs):
    """
    1. First pass: identify compound dialogues (lines with multiple '— ' inside)
    2. Second pass: add empty-line based on transitions
    """
    lines = xml_fragment.split('\n')

    # First pass: mark compound dialogues
    compound_dialogue_lines = set()
    for i, line in enumerate(lines):
        if is_compound_dialogue(line):
            compound_dialogue_lines.add(i)

    # Second pass: process transitions
    result = []
    i = 0
    while i < len(lines):
        line = lines[i]
        current_type = classify_line(line, compound_dialogue_lines, i)

        if i >= len(lines) - 1:
            # Last line - add and break
            result.append(line)
            break

        next_line = lines[i + 1]
        next_type = classify_line(next_line, compound_dialogue_lines, i + 1)

        # Rule 1: Dialogue ↔ Prose
        if current_type == 'dialogue' and next_type == 'prose':
            result.append(line)
            result.append('<empty-line/>')
            i += 1
            continue

        if current_type == 'prose' and next_type == 'dialogue':
            result.append(line)
            result.append('<empty-line/>')
            i += 1
            continue

        # Rule 2: Same type - no spacing
        if current_type == next_type:
            result.append(line)
            i += 1
            continue

        # Rule 3 & 4: Subtitle and Image - empty-line BEFORE and AFTER
        if next_type in ('subtitle', 'image'):
            result.append(line)
            result.append('<empty-line/>')
            i += 1
            continue

        if current_type in ('subtitle', 'image'):
            result.append(line)
            result.append('<empty-line/>')
            i += 1
            continue

        # Default: add line
        result.append(line)
        i += 1

    return '\n'.join(result)


def is_compound_dialogue(line):
    """
    Returns True if line is a compound dialogue (multiple dialogue parts with author words).
    Example: '<p>— Текст — автор — ещё текст</p>'
    Has '— ' (em-dash + space) AFTER the opening '— '
    """
    if not line.strip().startswith('<p>—'):
        return False

    # Count occurrences of '— ' in the line
    # Simple dialogue has only one '— ' at the start
    # Compound has '— ' at start AND '— ' later (after some text)
    stripped = line.strip()

    # Remove the opening '<p>— '
    if not stripped.startswith('<p>—'):
        return False

    # Check if there's another '— ' after the opening dialogue marker
    # The pattern for compound: '<p>— Текст — автор — текст</p>'
    # We look for '— ' that appears AFTER the first '— ' (opening marker)

    # Find first '— ' after '<p>'
    first_marker = stripped.find('— ')
    if first_marker == -1:
        return False

    # Find second '— ' after first
    second_marker = stripped.find('— ', first_marker + 1)
    return second_marker != -1


def classify_line(line, compound_dialogue_lines=None, index=None):
    """
    Classify line type.
    compound_dialogue_lines: set of line indices that are compound dialogues
    index: current line index (if None, calculated from line)
    """
    if compound_dialogue_lines is None:
        compound_dialogue_lines = set()
    if index is None:
        index = -1

    stripped = line.strip()

    if stripped.startswith('<p>—'):
        # Check if this is part of a compound dialogue sequence
        if index in compound_dialogue_lines:
            return 'compound_dialogue'
        return 'dialogue'
    elif stripped.startswith('<p>'):
        return 'prose'
    elif '<subtitle>' in stripped:
        return 'subtitle'
    elif '<image' in stripped:
        return 'image'
    elif stripped == '' or stripped == '<empty-line/>':
        return 'empty'
    else:
        return 'unknown'
```

## Double Empty-Line Check
```python
def validate_double_empty_lines(xml):
    lines = xml.split('\n')
    double_found = False
    double_location = None

    for i in range(len(lines) - 1):
        if lines[i] == '<empty-line/>' and lines[i+1] == '<empty-line/>':
            # Check if this is right after title
            if i > 0 and '<title>' in lines[i-1]:
                continue  # OK - after title
            else:
                double_found = True
                double_location = i
                break

    if double_found:
        raise ValueError(f"Двойные пустые строки вне заголовка на строке {double_location}")
```

## Compound Dialogue Examples

### Compound (inside same paragraph, NO empty-line):
```
<p>— Ты слышал? — спросил он. «Они пришли» — прошептал кто-то</p>
```
This is ONE compound dialogue block, no empty-line before or after.

### NOT Compound (separate paragraphs, dialogue→dialogue, NO empty-line):
```
<p>— Ты слышал?</p>
<p>— Они пришли</p>
```
```

## Notes
- Пустые строки из оригинального DOCX должны быть сохранены
- Compound dialogue определяется по наличию нескольких `— ` в одной строке
- Двойные пустые строки ТОЛЬКО после заголовка главы
