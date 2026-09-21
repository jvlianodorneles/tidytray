#!/usr/bin/env python3
import sys
import os
import json

CONFIG_PATH = os.environ.get("OMARCHY_SHELL_JSON") or os.path.expanduser("~/.config/omarchy/shell.json")
SECTIONS = ["left", "center", "right"]

def entry_id(entry):
    if isinstance(entry, str):
        return entry
    if isinstance(entry, dict):
        return str(entry.get("id", ""))
    return ""

def load_config():
    if not os.path.exists(CONFIG_PATH):
        return None
    try:
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        sys.stderr.write(f"Error loading {CONFIG_PATH}: {e}\n")
        return None

def save_config(config):
    try:
        temp_path = CONFIG_PATH + ".tmp"
        with open(temp_path, "w", encoding="utf-8") as f:
            json.dump(config, f, indent=2, ensure_ascii=False)
            f.write("\n")
        os.replace(temp_path, CONFIG_PATH)
        return True
    except Exception as e:
        sys.stderr.write(f"Error saving {CONFIG_PATH}: {e}\n")
        return False

def find_layout_entry(layout, target_id):
    if not isinstance(layout, dict):
        return None
    for sec in SECTIONS:
        entries = layout.get(sec)
        if not isinstance(entries, list):
            continue
        for idx, entry in enumerate(entries):
            if entry_id(entry) == target_id:
                return {"section": sec, "entries": entries, "index": idx, "entry": entry}
    return None

def ensure_plugin_listed(config, plugin_id):
    if not plugin_id or "." not in plugin_id:
        return False
    if "plugins" not in config or not isinstance(config["plugins"], list):
        config["plugins"] = []
    if plugin_id not in config["plugins"]:
        config["plugins"].append(plugin_id)
        return True
    return False

def unlist_plugin(config, plugin_id):
    if not plugin_id or "plugins" not in config or not isinstance(config["plugins"], list):
        return
    if plugin_id in config["plugins"]:
        config["plugins"].remove(plugin_id)

def capture(tray_id, source_id):
    config = load_config()
    if not config or "bar" not in config or "layout" not in config["bar"]:
        return False
    layout = config["bar"]["layout"]
    source = find_layout_entry(layout, source_id)
    if not source:
        return False
    
    # Remove from current section
    removed_entry = source["entries"].pop(source["index"])
    
    tray = find_layout_entry(layout, tray_id)
    if not tray:
        # Revert
        source["entries"].insert(source["index"], removed_entry)
        return False
    
    tray_entry = tray["entry"]
    if isinstance(tray_entry, str):
        tray_entry = {"id": tray_entry}
        tray["entries"][tray["index"]] = tray_entry
    
    if "widgets" not in tray_entry or not isinstance(tray_entry["widgets"], list):
        tray_entry["widgets"] = []
    
    entry_obj = {"id": removed_entry} if isinstance(removed_entry, str) else removed_entry
    wrapper = {"entry": entry_obj}
    if ensure_plugin_listed(config, source_id):
        wrapper["listed"] = True
    tray_entry["widgets"].append(wrapper)
    return save_config(config)

def release(tray_id, widget_id, target_section=None, before_name=None):
    config = load_config()
    if not config or "bar" not in config or "layout" not in config["bar"]:
        return False
    layout = config["bar"]["layout"]
    tray = find_layout_entry(layout, tray_id)
    if not tray:
        return False
    
    tray_entry = tray["entry"]
    if not isinstance(tray_entry, dict) or "widgets" not in tray_entry or not isinstance(tray_entry["widgets"], list):
        return False
    
    removed = None
    was_listed = False
    new_widgets = []
    for w in tray_entry["widgets"]:
        w_obj = w.get("entry", w) if isinstance(w, dict) else w
        if entry_id(w_obj) == widget_id:
            removed = w_obj
            was_listed = isinstance(w, dict) and w.get("listed", False)
        else:
            new_widgets.append(w)
            
    if not removed:
        return False
        
    if was_listed:
        unlist_plugin(config, widget_id)
        
    tray_entry["widgets"] = new_widgets
    if "pinned" in tray_entry and isinstance(tray_entry["pinned"], list):
        tray_entry["pinned"] = [p for p in tray_entry["pinned"] if entry_id(p) != widget_id]
    if "hidden" in tray_entry and isinstance(tray_entry["hidden"], list):
        tray_entry["hidden"] = [h for h in tray_entry["hidden"] if entry_id(h) != widget_id]

    sec_name = target_section if (target_section and target_section in SECTIONS) else tray["section"]
    sec_list = layout.get(sec_name, [])
    
    insert_idx = len(sec_list)
    if before_name:
        for idx, item in enumerate(sec_list):
            if entry_id(item) == before_name:
                insert_idx = idx
                break
    else:
        insert_idx = (tray["index"] + 1) if (sec_name == tray["section"]) else len(sec_list)

    sec_list.insert(insert_idx, removed)
    layout[sec_name] = sec_list
    return save_config(config)

def reorder(tray_id, from_idx, to_idx):
    config = load_config()
    if not config or "bar" not in config or "layout" not in config["bar"]:
        return False
    layout = config["bar"]["layout"]
    tray = find_layout_entry(layout, tray_id)
    if not tray or not isinstance(tray["entry"], dict):
        return False
    widgets = tray["entry"].get("widgets")
    if not isinstance(widgets, list):
        return False
    
    from_idx = int(from_idx)
    to_idx = int(to_idx)
    if from_idx < 0 or from_idx >= len(widgets) or to_idx < 0 or to_idx >= len(widgets) or from_idx == to_idx:
        return False
        
    item = widgets.pop(from_idx)
    widgets.insert(to_idx, item)
    return save_config(config)

def save_settings(tray_id, settings_json):
    config = load_config()
    if not config or "bar" not in config or "layout" not in config["bar"]:
        return False
    layout = config["bar"]["layout"]
    tray = find_layout_entry(layout, tray_id)
    if not tray:
        return False
    
    try:
        new_settings = json.loads(settings_json)
    except Exception as e:
        sys.stderr.write(f"Invalid JSON settings: {e}\n")
        return False
        
    tray_entry = tray["entry"]
    if isinstance(tray_entry, str):
        tray_entry = {"id": tray_entry}
        tray["entries"][tray["index"]] = tray_entry
        
    for k, v in new_settings.items():
        tray_entry[k] = v
        
    return save_config(config)

def main():
    if len(sys.argv) < 3:
        sys.exit(1)
    action = sys.argv[1]
    tray_id = sys.argv[2]
    
    success = False
    if action == "capture" and len(sys.argv) >= 4:
        success = capture(tray_id, sys.argv[3])
    elif action == "release" and len(sys.argv) >= 4:
        target_sec = sys.argv[4] if len(sys.argv) >= 5 and sys.argv[4] else None
        before_name = sys.argv[5] if len(sys.argv) >= 6 and sys.argv[5] else None
        success = release(tray_id, sys.argv[3], target_sec, before_name)
    elif action == "reorder" and len(sys.argv) >= 5:
        success = reorder(tray_id, sys.argv[3], sys.argv[4])
    elif action == "save-settings" and len(sys.argv) >= 4:
        success = save_settings(tray_id, sys.argv[3])
        
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
