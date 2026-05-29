# Skill: xml_content

## Description
Конвертирует paragraphs в XML теги БЕЗ пустых строк. Диалоги сохраняют маркер "— ", проза оборачивается в `<p>`. Мысли обрабатываются позже в xml_thoughts. Сноски-определения и ссылки пропускаются (идут в отдельные секции).

## Triggers
- "конвертировать в XML теги"
- "обработать текст"
- "добавить XML теги"

## Inputs
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| paragraphs | array\<Paragraph\> | yes | Массив параграфов от docx_extract |

## Outputs
| Output | Type | Description |
|--------|------|-------------|
| xml_fragment | string | XML фрагмент БЕЗ `<empty-line/>`, но с `<image>` и `<subtitle>` |

## Conversion Rules

### Title (Заголовок главы)
```
Глава 94. «Двойник» → <title><p><strong>Глава 94. «Двойник»</strong></p></title>
```

**Важно:** После title всегда добавляются ДВОЙНЫЕ пустые строки (в xml_structure).

### Dialogue (Диалог)
```
— Диалог → <p>— Диалог</p>

Диалог с автором:
— Текст — автор →
<p>— Текст — автор</p>

Несколько реплик подряд:
— Первая реплика — автор
— Вторая реплика — автор
→
<p>— Первая реплика — автор</p>
<p>— Вторая реплика — автор</p>
```

### Prose (Проза)
```
Любой текст → <p>Текст</p>
```

### Subtitle (Подзаголовок)
```
*** → <subtitle>* * *</subtitle>
```

### Image Reference (Ссылка на изображение)
```
94_nature.jpg → <image l:href="#94_nature.jpg" />
```

### Skip (Пропускаются)
| Type | Reason |
|------|--------|
| empty | Пустые строки добавляет xml_structure |
| footnote_def | Идёт в xml_footnotes для notes section |
| footnote_link | Обрабатывается xml_footnotes |

## Algorithm
```python
def convert_to_xml(paragraphs):
    xml_lines = []
    for p in paragraphs:
        if p.type == "title":
            xml_lines.append(f"<title><p><strong>{p.text}</strong></p></title>")
        elif p.type == "dialogue":
            xml_lines.append(f"<p>{p.text}</p>")
        elif p.type == "prose":
            xml_lines.append(f"<p>{p.text}</p>")
        elif p.type == "subtitle":
            xml_lines.append("<subtitle>* * *</subtitle>")
        elif p.type == "image_ref":
            xml_lines.append(f'<image l:href="#{p.text}" />')
        elif p.type == "empty":
            continue  # Skip - spacing handled by xml_structure
        elif p.type in ("footnote_def", "footnote_link"):
            continue  # Skip - handled by xml_footnotes
    return "\n".join(xml_lines)
```

## Notes
- Текст НЕ изменяется, только оборачивается в теги
- Пунктуация сохраняется verbatim
- Мысли обрабатываются позже в xml_thoughts