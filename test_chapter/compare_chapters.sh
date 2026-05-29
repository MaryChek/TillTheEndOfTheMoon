#!/bin/bash
# compare_chapters.sh
# Compares two chapter files after clearing formatting

./resources/test_chapter/clear_docx_chapter.sh resources/test_chapter/docx_chapter.txt
./resources/test_chapter/clear_xml_chapter.sh resources/test_chapter/xml_chapter.txt
diff --color=always resources/test_chapter/docx_chapter.txt resources/test_chapter/xml_chapter.txt