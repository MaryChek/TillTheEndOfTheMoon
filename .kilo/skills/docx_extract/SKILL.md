# Skill: docx_extract

## Description
Извлекает структурированный контент из DOCX файла. Автоматически определяет Part и Resources folder по оглавлению (TOC) или по тексту.

## Triggers
- "извлечь главу {N} из docx"
- "добыть контент главы"
- "прочитать главу из документа"

## Inputs
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| docx_path | string | yes | Путь к .docx файлу, напр. "Когда луна догорит дотла.docx" |
| chapter_num | integer | yes | Номер главы для извлечения |
| next_chapter_num | integer | yes | Номер следующей главы (для определения границ) |
| resources_base | string | yes | Базовый путь к resources, напр. "resources/" |

## Outputs
| Output | Type | Description |
|--------|------|-------------|
| paragraphs | array\<Paragraph\> | Массив структурированных параграфов |
| images | array\<ImageRef\> | Массив ссылок на изображения |
| footnotes | array\<FootnoteDef\> | Массив определений сносок |
| part_info | PartInfo | Информация о Part |

## Types

### PartInfo
```yaml
part_num: integer        # 14
part_title: string        # "Бессмертные земли"
resources_folder: string  # "resources/Part_14/"
```

### Paragraph
```yaml
index: integer
text: string
type: "title" | "dialogue" | "prose" |
      "subtitle" | "empty" | "image_ref" |
      "footnote_def" | "footnote_link"
```

### ImageRef
```yaml
filename: string         # "94_nature.jpg"
paragraph_index: integer   # Позиция в тексте
```

### FootnoteDef
```yaml
marker: string           # "*" или "**"
order_in_chapter: integer # 1, 2, 3...
term: string              # "Гун Е Чжиу"
definition: string       # "– бессмертный старший собрат..."
```

## Algorithm

### Step 1: Extract DOCX contents
```python
import zipfile
import xml.etree.ElementTree as ET

with zipfile.ZipFile(docx_path, 'r') as z:
    with z.open('word/document.xml') as f:
        tree = ET.parse(f)
        root = tree.getroot()
```

### Step 2: Define namespaces
```python
ns = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
paras = root.findall('.//w:p', ns)
```

### Step 3: Find chapter boundaries
1. Search for paragraph containing `"Глава {chapter_num}."`
2. Search for paragraph containing `"Глава {next_chapter_num}."`
3. All paragraphs between these two markers belong to current chapter

### Step 4: Classify paragraph types
| Condition | Type |
|----------|------|
| text.startswith('— ') | dialogue |
| text.strip() == '\*\*\*' | subtitle |
| text.strip() == '' | empty |
| regex match `\{N\}\_[a-z_]+\.jpe?g` | image_ref |
| text.startswith('\*') | footnote_def |
| word followed by '\*' | footnote_link |
| Otherwise | prose |

### Step 5: Determine Part
1. Search for TOC or text containing `"Часть {P}. «{title}»"`
2. Map chapter numbers to Part numbers
3. resources_folder = `f"{resources_base}/Part_{P}/"`

### Step 6: Extract footnotes
- Parse paragraphs of type "footnote_def"
- Extract term (bold text before dash) and definition (text after dash)
- Assign order_in_chapter sequentially

## Output Example
```json
{
  "paragraphs": [
    {"index": 0, "text": "Глава 94. «Двойник»", "type": "title"},
    {"index": 1, "text": "", "type": "empty"},
    {"index": 2, "text": "Заручившись согласием Су Су...", "type": "prose"},
    {"index": 3, "text": "— Это гексаграмма...", "type": "dialogue"},
    {"index": 4, "text": "«Выходит, старший брат жив — подумала она — значит ли это...»", "type": "prose"},
    ...
  ],
  "images": [
    {"filename": "94_nature.jpg", "paragraph_index": 15},
    {"filename": "94_tan_tay_and_su_su.jpg", "paragraph_index": 45}
  ],
  "footnotes": [
    {"marker": "*", "order_in_chapter": 1, "term": "Гун Е Чжиу", "definition": "– бессмертный старший собрат..."}
  ],
  "part_info": {
    "part_num": 14,
    "part_title": "Бессмертные земли",
    "resources_folder": "resources/Part_14/"
  }
}
```

## Notes
- Используй xml.etree.ElementTree для парсинга
- Не изменяй оригинальный текст
- Каждый paragraph = один item в массиве
- Мысли НЕ классифицируются здесь — они определяются позже в xml_thoughts по наличию «»