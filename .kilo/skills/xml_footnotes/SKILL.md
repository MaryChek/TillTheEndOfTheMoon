# Skill: xml_footnotes

## Description
Создаёт footnote_links для вставки в текст и footnote_notes для секции `<body name="notes">`. Обрабатывает сноски вида `*термин — определение` и создаёт XML ссылки `[N]` в тексте.

## Triggers
- "создать сноски"
- "обработать примечания"
- "добавить footnote"

## Inputs
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| footnotes | array\<FootnoteDef\> | yes | Массив определений сносок |
| chapter_num | integer | yes | Номер главы |
| part_num | integer | yes | Номер Part |

## Outputs
| Output | Type | Description |
|--------|------|-------------|
| footnote_links_map | map\<string, string\> | "word*" → "word<axml>" маппинг |
| footnote_notes_xml | string | `<section id="note{N}_{M}">...</section>` для notes body |

## Footnote Format

### In Text (links)
```
Слово* → Слово<a l:href="#note78_1" type="note">[1]</a>
Слово** → Слово<a l:href="#note78_2" type="note">[2]</a>
```

### In Notes Section
```xml
<section id="note78_1">
    <p><strong>Гун Е Чжиу</strong> – бессмертный старший собрат Ли Су Су...</p>
</section>

<section id="note78_2">
    <p><strong>Юэ Фу Я</strong> – сын Цзин Лань Ань...</p>
</section>
```

## Algorithm

### Step 1: Build footnote links map
```python
def create_footnote_links(footnotes, chapter_num):
    links_map = {}
    for i, fn in enumerate(footnotes, start=1):
        note_id = f"note{chapter_num}_{i}"
        link = f'<a l:href="#{note_id}" type="note">[{i}]</a>'
        # Key is the word followed by marker
        key = f"{fn.term}{fn.marker}"  # e.g., "Гун Е Чжиу*"
        links_map[key] = f"{fn.term}{link}"
    return links_map
```

### Step 2: Create notes XML
```python
def create_notes_xml(footnotes, chapter_num, part_num):
    notes_xml = ""

    for i, fn in enumerate(footnotes, start=1):
        note_id = f"note{chapter_num}_{i}"
        notes_xml += f'''
        <section id="{note_id}">
            <p><strong>{fn.term}</strong> – {fn.definition}.</p>
        </section>
'''

    return notes_xml
```

## Example

### Input footnotes
```json
[
  {"marker": "*", "order_in_chapter": 1, "term": "Гун Е Чжиу", "definition": "– бессмертный старший собрат Ли Су Су, на которого был похож наследный принц Сяо Линь."},
  {"marker": "*", "order_in_chapter": 2, "term": "Юэ Фу Я", "definition": "– сын Цзин Лань Ань. Тот самый мальчик, которого Ли Су Су пятьсот лет назад спасла..."}
]
```

### Output footnote_links_map
```json
{
  "Гун Е Чжиу*": "Гун Е Чжиу<a l:href="#note78_1" type="note">[1]</a>",
  "Юэ Фу Я*": "Юэ Фу Я<a l:href="#note78_2" type="note">[2]</a>"
}
```

### Output footnote_notes_xml
```xml
<section id="note78_1">
    <p><strong>Гун Е Чжиу</strong> – бессмертный старший собрат Ли Су Су...</p>
</section>
<section id="note78_2">
    <p><strong>Юэ Фу Я</strong> – сын Цзин Лань Ань. Тот самый мальчик...</p>
</section>
```

## Comment Addition Logic

В assets_adder нужно добавлять комментарии:
```python
# Для Part - проверить есть ли уже хоть одна note section для этого Part
# Для Chapter - всегда добавлять
```

Пример вывода с комментариями:
```xml
<!-- For Part 11 -->
    <!-- For Chapter 78 -->
        <section id="note78_1">
            <p><strong>Гун Е Чжиу</strong> – бессмертный старший собрат...</p>
        </section>
```

## Notes
- Нумерация сносок начинается с 1 для каждой главы
- note_id формат: `note{chapter_num}_{order_in_chapter}`