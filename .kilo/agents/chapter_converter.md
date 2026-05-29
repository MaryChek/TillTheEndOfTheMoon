# Agent: chapter_converter

## Description
Конвертирует главу N из DOCX в XML с структурой, пустыми строками и комментариями (<!-- Part -->, <!-- Chapter -->). НО БЕЗ вставки в Светлый пепел луны(book_2).xml. Возвращает XML текст главы, массивы images и footnotes, и part_info для дальнейшей обработки assets_adder.

## Uses
- skill: docx_extract
- skill: xml_content
- skill: xml_structure
- skill: xml_thoughts

## Inputs
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| docx_path | string | yes | Путь к DOCX файлу |
| chapter_num | integer | yes | Номер главы |
| next_chapter_num | integer | yes | Номер следующей главы |
| resources_base | string | yes | Путь к resources, напр. "resources/" |

## Outputs
| Output | Type | Description |
|--------|------|-------------|
| xml_chapter | string | XML текст главы с комментариями, `<empty-line/>`, `<image>`, `<subtitle>`, `<title>`, `<emphasis>` |
| images | array\<ImageRef\> | Массив ссылок на изображения |
| footnotes | array\<FootnoteDef\> | Массив определений сносок |
| part_info | PartInfo | Информация о Part |
| thoughts_report | array\<ThoughtInfo\> | Отчёт о найденных мыслях |

## Workflow
```
┌────────────────────────────────────────┐
│ Step 1: docx_extract                   │
│ Input: docx_path, chapter_num,         │
│        next_chapter_num, resources_base│
│                                        │
│ Output: paragraphs[], images[],        │
│         footnotes[], part_info         │
│ (БЕЗ классификации мыслей)             │
└────────────────────┬───────────────────┘
                     │
┌────────────────────▼───────────────────┐
│ Step 2: xml_content                    │
│ Input: paragraphs[]                    │
│                                        │
│ Output: xml_fragment                   │
│ (БЕЗ empty-line, БЕЗ emphasis)         │
└────────────────────┬───────────────────┘
                     │
┌────────────────────▼───────────────────┐
│ Step 3: xml_structure                  │
│ Input: xml_fragment, paragraphs[]      │
│                                        │
│ Output: xml_with_spacing               │
│ (С empty-line, БЕЗ обработки мыслей)   │
└────────────────────┬───────────────────┘
                     │
┌────────────────────▼───────────────────┐
│ Step 4: xml_thoughts                   │
│ Input: xml_with_spacing, chapter_num   │
│                                        │
│ Output: xml_with_thoughts, report      │
│ (С <emphasis> для мыслей)              │
└────────────────────┬───────────────────┘
                     │
┌────────────────────▼───────────────────┐
│ Step 5: Add comments                   │
│ Input: xml_with_thoughts,              │
│        chapter_num, part_info          │
│                                        │
│ Output: xml_chapter_with_comments      │
│ (С комментариями Part/Chapter)        │
└────────────────────┬───────────────────┘
                     │
  returns: xml_chapter, images[], footnotes[], part_info, thoughts_report
```

## Step Details

### Step 1: docx_extract
```python
def step1_extract(docx_path, chapter_num, next_chapter_num, resources_base):
    paragraphs = extract_paragraphs(docx_path, chapter_num, next_chapter_num)
    images = find_images_in_paragraphs(paragraphs)
    footnotes = find_footnotes_in_paragraphs(paragraphs)
    part_info = determine_part(paragraphs, resources_base)
    return paragraphs, images, footnotes, part_info
```

### Step 2: xml_content
```python
def step2_convert_to_xml(paragraphs):
    xml_fragment = convert_paragraphs_to_xml(paragraphs)
    return xml_fragment
    # Note: Still WITHOUT <empty-line/>
```

### Step 3: xml_structure
```python
def step3_add_spacing(xml_fragment, paragraphs):
    xml_with_spacing = add_empty_lines(xml_fragment, paragraphs)
    return xml_with_spacing
```

### Step 4: xml_thoughts
```python
def step4_process_thoughts(xml_with_spacing, chapter_num):
    xml_with_thoughts, thoughts_report = process_thoughts(xml_with_spacing, chapter_num)
    return xml_with_thoughts, thoughts_report
```

### Step 5: Add comments
```python
def step5_add_comments(xml_with_thoughts, chapter_num, part_info):
    # Добавить комментарий Chapter (НЕ Part - это добавляет assets_adder)
    xml_chapter = f'''            <!-- Chapter {chapter_num} -->
        <section>
            {xml_with_thoughts}
        </section>'''
    return xml_chapter
```

## Usage Example
```
User: Конвертируй главу 94
Agent:
  1. docx_extract("Когда луна догорит дотла.docx", 94, 95, "resources/")
     → paragraphs[], images[2], footnotes[1],
        part_info{14, "Бессмертные земли", "resources/Part_14/"}
  2. xml_content(paragraphs)
     → xml_fragment (без empty-line, без emphasis)
  3. xml_structure(xml_fragment, paragraphs)
     → xml_with_spacing (с empty-line)
  4. xml_thoughts(xml_with_spacing, 94)
     → xml_with_thoughts, thoughts_report
  5. Add comments(xml_with_thoughts, 94, part_info)
     → xml_chapter_with_comments

  Returns: xml_chapter, images, footnotes, part_info, thoughts_report
```

## Output Example
```xml
            <!-- Chapter 94 -->
        <section>
            <title><p><strong>Глава 94. «Двойник»</strong></p></title>
            <empty-line/>
            <empty-line/>
            <p>Заручившись согласием Су Су...</p>
            ...
        </section>
```

## Notes
- Этот агент НЕ вставляет в Светлый пепел луны(book_2).xml
- Результат передаётся в assets_adder для финальной вставки
- Правило преобразования title: `Глава N. «Title»` → `<title><p><strong>Глава N. «Title»</strong></p></title>` (см. xml_content)
- Следующий агент: assets_adder
- ВАЖНО: Комментарий `<!-- Part N. «Title» -->` НЕ добавляется здесь - это делает assets_adder только если глава первая в части
- Мысли обрабатываются в xml_thoughts - отчёт выводится для проверки