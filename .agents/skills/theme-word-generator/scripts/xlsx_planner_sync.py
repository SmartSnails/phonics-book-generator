#!/usr/bin/env python3
"""
xlsx_planner_sync.py
Hardened OpenXML (.xlsx) cell updater with:
  1. Automatic timestamped backup before editing
  2. Temporary directory isolation via tempfile.TemporaryDirectory()
  3. Loud failure if target worksheet or cell coordinates are missing
  4. Rich-text <strike>old</strike> formatting support
"""

import argparse
import datetime
import json
import re
import shutil
import tempfile
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

NS_MAIN = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
ET.register_namespace("", NS_MAIN)


def apply_xlsx_updates(input_xlsx: Path, output_xlsx: Path, sheet_xml_relpath: str, cell_updates: dict):
    if not input_xlsx.exists():
        raise FileNotFoundError(f"Input workbook not found: {input_xlsx}")

    # 1. Create automatic timestamped backup
    ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = input_xlsx.with_name(f"{input_xlsx.stem}_backup_{ts}{input_xlsx.suffix}")
    shutil.copy2(input_xlsx, backup_path)

    with tempfile.TemporaryDirectory(prefix="xlsx_sync_") as tmpdir:
        tmp_path = Path(tmpdir)
        with zipfile.ZipFile(input_xlsx, "r") as zf:
            zf.extractall(tmp_path)

        target_sheet = tmp_path / sheet_xml_relpath
        if not target_sheet.exists():
            raise FileNotFoundError(f"Worksheet XML '{sheet_xml_relpath}' not found inside {input_xlsx}")

        tree = ET.parse(target_sheet)
        root = tree.getroot()
        sheet_data = root.find(f"{{{NS_MAIN}}}sheetData")
        if sheet_data is None:
            raise ValueError(f"<sheetData> missing in {sheet_xml_relpath}")

        for cell_ref, raw_text in cell_updates.items():
            m = re.match(r"^([A-Z]+)(\d+)$", cell_ref.strip().upper())
            if not m:
                raise ValueError(f"Invalid A1 cell reference: {cell_ref}")
            row_num = m.group(2)

            row_el = None
            for r in sheet_data.findall(f"{{{NS_MAIN}}}row"):
                if r.attrib.get("r") == row_num:
                    row_el = r
                    break
            if row_el is None:
                raise KeyError(f"Row {row_num} (for cell {cell_ref}) not found in {sheet_xml_relpath}")

            cell_el = None
            for c in row_el.findall(f"{{{NS_MAIN}}}c"):
                if c.attrib.get("r") == cell_ref:
                    cell_el = c
                    break
            if cell_el is None:
                raise KeyError(f"Cell {cell_ref} not found in row {row_num} of {sheet_xml_relpath}")

            cell_el.attrib["t"] = "inlineStr"
            for child in list(cell_el):
                cell_el.remove(child)

            is_el = ET.SubElement(cell_el, f"{{{NS_MAIN}}}is")
            if "<strike>" in raw_text and "</strike>" in raw_text:
                pre, rest = raw_text.split("<strike>", 1)
                struck, post = rest.split("</strike>", 1)
                if pre:
                    r_pre = ET.SubElement(is_el, f"{{{NS_MAIN}}}r")
                    t_pre = ET.SubElement(r_pre, f"{{{NS_MAIN}}}t", {"xml:space": "preserve"})
                    t_pre.text = pre
                r_s = ET.SubElement(is_el, f"{{{NS_MAIN}}}r")
                rpr = ET.SubElement(r_s, f"{{{NS_MAIN}}}rPr")
                ET.SubElement(rpr, f"{{{NS_MAIN}}}strike")
                t_s = ET.SubElement(r_s, f"{{{NS_MAIN}}}t", {"xml:space": "preserve"})
                t_s.text = struck
                if post:
                    r_post = ET.SubElement(is_el, f"{{{NS_MAIN}}}r")
                    t_post = ET.SubElement(r_post, f"{{{NS_MAIN}}}t", {"xml:space": "preserve"})
                    t_post.text = post
            else:
                t_el = ET.SubElement(is_el, f"{{{NS_MAIN}}}t", {"xml:space": "preserve"})
                t_el.text = raw_text

        tree.write(target_sheet, encoding="utf-8", xml_declaration=True)

        output_xlsx.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(output_xlsx, "w", zipfile.ZIP_DEFLATED) as out_zf:
            for file_path in sorted(tmp_path.rglob("*")):
                if file_path.is_file():
                    out_zf.write(file_path, file_path.relative_to(tmp_path))

    return backup_path


def main():
    parser = argparse.ArgumentParser(description="Safe OpenXML .xlsx cell updater with backup and validation.")
    parser.add_argument("--input", required=True, help="Input .xlsx file path")
    parser.add_argument("--output", required=True, help="Output .xlsx file path")
    parser.add_argument("--sheet-xml", default="xl/worksheets/sheet8.xml", help="Worksheet XML path inside archive")
    parser.add_argument("--updates-json", required=True, help="JSON file mapping cell refs to text")
    args = parser.parse_args()

    updates = json.loads(Path(args.updates_json).read_text(encoding="utf-8"))
    backup = apply_xlsx_updates(Path(args.input), Path(args.output), args.sheet_xml, updates)
    print(f"Updated {len(updates)} cells -> {args.output} (backup saved at {backup})")


if __name__ == "__main__":
    main()
