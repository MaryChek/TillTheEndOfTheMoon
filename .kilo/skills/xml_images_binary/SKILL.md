# Skill: xml_images_binary

## Description
Генерирует `<binary>` XML элементы из файлов изображений. Конвертирует изображения в base64 и создаёт properly formatted binary sections.

## Triggers
- "создать binary для картинок"
- "закодировать изображения"
- "добавить binary"

## Inputs
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| image_refs | array\<ImageRef\> | yes | Массив ссылок на изображения |
| part_info | PartInfo | yes | Информация о Part |
| part_binary_already_exists | boolean | yes | Есть ли уже binary для part в файле |

## Outputs
| Output | Type | Description |
|--------|------|-------------|
| binary_xml | string | `<binary>` XML для вставки в Images section |
| binary_xml_with_comments | string | То же, но с комментариями `<!-- For Part -->` и `<!-- For Chapter -->` |

## Output Format
```xml
<!-- For Part {N} -->
    <binary id="part_{N}.jpg" content-type="image/jpeg">
        {base64_content}
    </binary>
    <!-- For Chapter {M} -->
        <binary id="{M}_{name}.jpg" content-type="image/jpeg">
            {base64_content}
        </binary>
```

## Algorithm

### Step 1: Encode images to base64
```python
import base64
import subprocess

def encode_image_to_base64(image_path):
    result = subprocess.run(
        ['base64', '-i', image_path],
        capture_output=True,
        text=True
    )
    return result.stdout.strip()  # Remove newlines
```

### Step 2: Build binary XML
```python
def create_binary_xml(image_refs, part_info, part_binary_already_exists):
    binary_parts = []

    # Part binary (only if not already exists)
    if not part_binary_already_exists:
        part_image_path = f"{part_info.resources_folder}part_{part_info.part_num}.jpg"
        part_base64 = encode_image_to_base64(part_image_path)
        binary_parts.append(f'''
    <binary id="part_{part_info.part_num}.jpg" content-type="image/jpeg">
        {part_base64}
    </binary>''')

    # Chapter images
    for img in image_refs:
        img_path = f"{part_info.resources_folder}{img.filename}"
        img_base64 = encode_image_to_base64(img_path)
        binary_parts.append(f'''
        <binary id="{img.filename}" content-type="image/jpeg">
            {img_base64}
        </binary>''')

    return '\n'.join(binary_parts)
```

### Step 3: Add comments (for assets_adder)
```python
def add_comments_to_binary_xml(binary_xml, part_info, chapter_num, part_binary_already_exists):
    result = []

    # Part comment (only if part binary is being added)
    if not part_binary_already_exists:
        result.append(f'        <!-- For Part {part_info.part_num} -->')
        # binary already includes part binary

    # Chapter comment - ALWAYS added for each chapter's images
    result.append(f'            <!-- For Chapter {chapter_num} -->')
    # binary already includes chapter binaries

    return '\n'.join(result)
```

## Example

### Input
```json
{
  "image_refs": [
    {"filename": "94_nature.jpg", "paragraph_index": 15},
    {"filename": "94_tan_tay_and_su_su.jpg", "paragraph_index": 45}
  ],
  "part_info": {
    "part_num": 14,
    "part_title": "Бессмертные земли",
    "resources_folder": "resources/Part_14/"
  },
  "part_binary_already_exists": false
}
```

### Output (binary_xml_with_comments)
```xml
<!-- For Part 14 -->
    <binary id="part_14.jpg" content-type="image/jpeg">
        /9j/4AAQSkZJRgABAQAAAQABAAD...
    </binary>
    <!-- For Chapter 94 -->
        <binary id="94_nature.jpg" content-type="image/jpeg">
            /9j/4AAQSkZJRgABAQAAkACQAAD...
        </binary>
        <binary id="94_tan_tay_and_su_su.jpg" content-type="image/jpeg">
            /9j/4AAQSkZJRgABAQAASABIAAD...
        </binary>
```

## Notes
- Content-type всегда `image/jpeg` (jpeg и jpg)
- base64 получается через `base64 -i {path}` с удалением переносов строк
- Проверка `part_binary_already_exists` чтобы не дублировать part binary