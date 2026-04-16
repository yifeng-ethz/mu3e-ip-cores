#!/usr/bin/env python3

import argparse
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(
        description="Normalize a Platform Designer components.ipx catalog."
    )
    parser.add_argument("--input", required=True, help="Input components.ipx path")
    parser.add_argument("--output", required=True, help="Output components.ipx path")
    parser.add_argument("--root", required=True, help="Repository root used for filtering")
    parser.add_argument(
        "--relative-var",
        help="Optional environment variable used to rewrite file paths portably",
    )
    return parser.parse_args()


def score_component(component):
    path = component.get("file", "")
    return (path.count("/"), len(path), path)


EXCLUDED_PARTS = {
    ".git",
    ".qsys_edit",
    "__pycache__",
    "db",
    "functional",
    "generated",
    "output_files",
    "tmp",
}
EXCLUDED_FILE_NAMES = {
    "modelsim.ini",
    "qrun.log",
    "qverilog.log",
    "transcript",
    "tr_db.log",
}


def resolve_catalog_path(path_text, root, relative_var):
    prefixes = []
    if relative_var:
        prefixes.extend((f"${relative_var}/", f"${{{relative_var}}}/"))
    for prefix in prefixes:
        if path_text.startswith(prefix):
            return (root / path_text[len(prefix) :]).resolve(strict=False)
    path = Path(path_text)
    if not path.is_absolute():
        path = root / path
    return path.resolve(strict=False)


def is_excluded_path(path, root):
    try:
        rel_path = path.relative_to(root)
    except ValueError:
        return True
    for part in rel_path.parts:
        if part in EXCLUDED_PARTS:
            return True
        if part.startswith("work_") or part.endswith(".badclone"):
            return True
    name = rel_path.name
    if name in EXCLUDED_FILE_NAMES:
        return True
    if ".qsys.stash_" in name:
        return True
    return False


def should_keep_entry(entry, root, relative_var):
    path_text = entry.get("file", "")
    if not path_text:
        return True
    path = resolve_catalog_path(path_text, root, relative_var)
    if not path.exists():
        return False
    return not is_excluded_path(path, root)


def rewrite_entry_path(entry, root, relative_var):
    if not relative_var:
        return
    path_text = entry.get("file", "")
    if not path_text:
        return
    path = resolve_catalog_path(path_text, root, relative_var)
    rel_path = path.relative_to(root).as_posix()
    entry.set("file", f"${relative_var}/{rel_path}")


def rewrite_nested_paths(entry, root, relative_var):
    if not relative_var:
        return
    root_prefix = f"{root.as_posix()}/"
    for node in entry.iter():
        for key, value in list(node.attrib.items()):
            if not value.startswith(root_prefix):
                continue
            rel_path = Path(value[len(root_prefix) :]).as_posix()
            node.set(key, f"${relative_var}/{rel_path}")


def main():
    args = parse_args()
    root_dir = Path(args.root).resolve(strict=False)
    tree = ET.parse(args.input)
    root = tree.getroot()

    plugins = [child for child in list(root) if child.tag == "plugin"]
    components = [child for child in list(root) if child.tag == "component"]
    kept_plugins = [
        plugin for plugin in plugins if should_keep_entry(plugin, root_dir, args.relative_var)
    ]
    kept_components = [
        component
        for component in components
        if should_keep_entry(component, root_dir, args.relative_var)
    ]
    best_by_key = {}
    order = []
    versions_by_name = defaultdict(set)

    for component in kept_components:
        name = component.get("name", "")
        version = component.get("version", "")
        key = (name, version)
        versions_by_name[name].add(version)
        if key not in best_by_key:
            best_by_key[key] = component
            order.append(key)
            continue
        if score_component(component) < score_component(best_by_key[key]):
            best_by_key[key] = component

    for child in list(root):
        if child.tag in {"plugin", "component"}:
            root.remove(child)

    duplicates_removed = len(kept_components) - len(order)
    filtered_removed = (len(plugins) - len(kept_plugins)) + (len(components) - len(kept_components))
    multi_version_names = {
        name for name, versions in versions_by_name.items() if len(versions) > 1
    }

    for plugin in kept_plugins:
        rewrite_entry_path(plugin, root_dir, args.relative_var)
        rewrite_nested_paths(plugin, root_dir, args.relative_var)
        root.append(plugin)

    for key in order:
        component = best_by_key[key]
        name = component.get("name", "")
        version = component.get("version", "")
        display_name = component.get("displayName", name)
        if name in multi_version_names:
            suffix = f" ({version})"
            if not display_name.endswith(suffix):
                component.set("displayName", f"{display_name}{suffix}")
        rewrite_entry_path(component, root_dir, args.relative_var)
        rewrite_nested_paths(component, root_dir, args.relative_var)
        root.append(component)

    ET.indent(tree, space=" ", level=0)
    tree.write(args.output, encoding="UTF-8", xml_declaration=True)
    print(
        f"Normalized {args.input}: kept {len(order)} unique components, "
        f"filtered {filtered_removed} excluded catalog entries, "
        f"removed {duplicates_removed} duplicate name/version entries, "
        f"version-tagged {len(multi_version_names)} multi-version component families."
    )


if __name__ == "__main__":
    main()
