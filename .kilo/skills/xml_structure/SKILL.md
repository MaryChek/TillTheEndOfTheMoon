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

### Rule 1: Dialogue ↔ Prose transitions
| Current | Next | Action |
|---------|------|--------|
| dialogue | prose | Add `<empty-line/>` AFTER current |
| prose | dialogue | Add `<empty-line/>` AFTER current |

### Rule 2: Same type transitions
| Current | Next | Action |
|---------|------|--------|
| dialogue | dialogue | NO `<empty-line/>` |
| prose | prose | NO `<empty-line/>` |

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
    lines = xml_fragment.split('\n')
    result = []
    current_block_lines = []

    for i, line in enumerate(lines):
        current_block_lines.append(line)

        if i >= len(lines) - 1:
            # Last line - flush
            result.extend(current_block_lines)
            break

        next_line = lines[i + 1]
        current_type = classify_line(line)
        next_type = classify_line(next_line)

        # Rule 1: Dialogue ↔ Prose
        if (current_type == 'dialogue' and next_type == 'prose') or \
           (current_type == 'prose' and next_type == 'dialogue'):
            # Add line, then add empty-line after it
            result.append(line)
            result.append('<empty-line/>')
            current_block_lines = []
            continue

        # Rule 2: Same type - no spacing
        if current_type == next_type:
            continue

        # Rule 3 & 4: Subtitle and Image - needs empty-line BEFORE and AFTER
        if next_type in ('subtitle', 'image'):
            # The NEXT line is subtitle/image - we add empty-line BEFORE it
            result.extend(current_block_lines[:-1])  # Add all but the current line
            result.append('<empty-line/>')           # Add empty-line before
            result.append(line)                    # Add the current line
            current_block_lines = []
            continue

        if current_type in ('subtitle', 'image'):
            # The CURRENT line is subtitle/image - add empty-line AFTER it
            result.append(line)
            result.append('<empty-line/>')
            current_block_lines = []
            continue

        # Otherwise - flush current
        result.extend(current_block_lines)
        current_block_lines = []

    return '\n'.join(result)


def classify_line(line):
    if line.strip().startswith('<p>—'):
        return 'dialogue'
    elif line.strip().startswith('<p>'):
        return 'prose'
    elif '<subtitle>' in line:
        return 'subtitle'
    elif '<image' in line:
        return 'image'
    elif line.strip() == '' or line.strip() == '<empty-line/>':
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

## Notes
- Проход 1: Снизу вверх — определить типы переходов
- Проход 2: Сверху вниз — добавить `<empty-line/>` где нужно
- Двойные пустые строки ТОЛЬКО после заголовка главы