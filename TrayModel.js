.pragma library

// TrayModel.js: Pure data functions for TidyTray (omarchy bar widget & tray manager).
// Designed to run both within QML (.pragma library) and under Node.js for tests.

var SECTIONS = ["left", "center", "right"]
var DISPLAY_MODES = ["inline", "dropdown", "drawer", "flat"]
var INDICATOR_ICONS = ["chevron", "dot", "dots", "plus", "none"]
var TRIGGERS = ["click", "hover"]

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
}

function text(value) {
  return String(value || "").toLowerCase()
}

function entryId(entry) {
  if (typeof entry === "string") return entry
  if (entry && typeof entry === "object" && !Array.isArray(entry)) {
    var id = entry.id
    if (id !== undefined && id !== null && String(id) !== "") return String(id)
  }
  return ""
}

function entrySettings(entry) {
  if (!entry || typeof entry !== "object" || Array.isArray(entry)) return {}
  var copy = {}
  for (var key in entry) {
    if (key === "id") continue
    copy[key] = entry[key]
  }
  return copy
}

function asList(value) {
  if (Array.isArray(value)) return value.slice()
  if (value && typeof value === "object" && typeof value.length === "number") {
    var out = []
    for (var i = 0; i < value.length; i++) out.push(value[i])
    return out
  }
  return []
}

function normalizeIdList(value) {
  var list = asList(value)
  var out = []
  for (var i = 0; i < list.length; i++) {
    var id = entryId(list[i])
    if (id && out.indexOf(id) === -1) out.push(id)
  }
  return out
}

function normalizeDisplayMode(value) {
  var m = String(value || "").trim().toLowerCase()
  return DISPLAY_MODES.indexOf(m) !== -1 ? m : "inline"
}

function normalizeTrigger(value) {
  var t = String(value || "").trim().toLowerCase()
  return TRIGGERS.indexOf(t) !== -1 ? t : "click"
}

function normalizeIndicatorIcon(value) {
  var icon = String(value || "").trim().toLowerCase()
  return INDICATOR_ICONS.indexOf(icon) !== -1 ? icon : "chevron"
}

function chevronGlyph(icon, vertical) {
  switch (String(icon || "").toLowerCase()) {
    case "caret": return vertical ? "\uf0d7" : "\uf0d9";
    case "angle": return vertical ? "\uf107" : "\uf104";
    case "arrow": return vertical ? "\uf063" : "\uf060";
    case "double": return vertical ? "\uf103" : "\uf100";
    case "dot": return "\ueb8a";
    case "dots": return "\uf141";
    case "plus": return "\uf067";
    case "chevron":
    default:
      return vertical ? "\uf078" : "\uf053";
  }
}

function normalizeRehideSeconds(value) {
  var n = Math.round(Number(value))
  if (!isFinite(n) || n < 0) return 0
  return Math.min(600, n)
}

function normalizeDuration(value, fallback) {
  var n = Math.round(Number(value))
  if (!isFinite(n) || n < 0) return fallback !== undefined ? fallback : 200
  return Math.min(1000, n)
}

function layoutHasWidget(layout, id) {
  return layoutSectionFor(layout, id) !== ""
}

function layoutSectionFor(layout, id) {
  var key = String(id || "")
  if (!key || !layout) return ""
  for (var s = 0; s < SECTIONS.length; s++) {
    var entries = layout[SECTIONS[s]]
    if (!Array.isArray(entries)) continue
    for (var i = 0; i < entries.length; i++) {
      if (entryId(entries[i]) === key) return SECTIONS[s]
    }
  }
  return ""
}

function findLayoutEntry(layout, id) {
  var key = String(id || "")
  if (!key || !layout) return null
  for (var s = 0; s < SECTIONS.length; s++) {
    var entries = layout[SECTIONS[s]]
    if (!Array.isArray(entries)) continue
    for (var i = 0; i < entries.length; i++) {
      if (entryId(entries[i]) === key) {
        return {
          section: SECTIONS[s],
          entries: entries,
          index: i,
          entry: entries[i]
        }
      }
    }
  }
  return null
}

function itemNamed(item, query) {
  if (!item) return false
  var q = text(query)
  return text(item.id).indexOf(q) !== -1
    || text(item.title).indexOf(q) !== -1
    || text(item.tooltipTitle).indexOf(q) !== -1
}

// Smart deduplication: suppresses native SNI icons when corresponding
// Omarchy widget is loaded (e.g., omarchy.dropbox suppresses Dropbox SNI).
// Also suppresses phantom / broken tray items like localsend which picks a random ID every run.
function ownedByOmarchy(item, layout, extraHostedIds) {
  if (!item) return false
  if (itemNamed(item, "localsend")) return true
  var hosted = extraHostedIds || []
  var dropboxActive = layoutHasWidget(layout, "omarchy.dropbox")
    || hosted.indexOf("omarchy.dropbox") !== -1
  if (dropboxActive && itemNamed(item, "dropbox")) return true
  return false
}

// SystemTray item classification: 'pinned', 'drawer', or 'hidden'
function sniItemCategory(item, pinnedIds, hiddenIds) {
  if (!item) return "drawer"
  var id = String(item.id || "")
  var p = asList(pinnedIds)
  var h = asList(hiddenIds)
  if (h.indexOf(id) !== -1) return "hidden"
  if (p.indexOf(id) !== -1) return "pinned"
  return "drawer"
}

// Categorize SNI items into pinned, drawer, or hidden buckets
function filterSniItems(items, pinnedIds, hiddenIds, targetCategory, deduplicate, layout, hostedIds) {
  var list = asList(items)
  var p = asList(pinnedIds)
  var h = asList(hiddenIds)
  var result = []
  for (var i = 0; i < list.length; i++) {
    var item = list[i]
    if (!item) continue
    if (deduplicate && ownedByOmarchy(item, layout, hostedIds)) continue
    var cat = sniItemCategory(item, p, h)
    if (cat === targetCategory) {
      result.push(item)
    }
  }
  return result
}

// Normalize wrappers inside trayEntry.widgets
function normalizeWrappers(raw) {
  var out = []
  var values = asList(raw)
  for (var i = 0; i < values.length; i++) {
    var w = values[i]
    if (!w) continue
    if (typeof w === "string") {
      out.push({ entry: { id: w } })
      continue
    }
    if (w.entry && entryId(w.entry)) {
      out.push({ entry: w.entry })
      continue
    }
    if (entryId(w)) {
      out.push({ entry: w })
    }
  }
  return out
}

function wrapperId(wrapper) {
  if (!wrapper) return ""
  return wrapper.entry ? entryId(wrapper.entry) : entryId(wrapper)
}

function hostedWidgetCategory(id, pinnedIds, hiddenIds) {
  var key = String(id || "")
  var p = asList(pinnedIds)
  var h = asList(hiddenIds)
  if (h.indexOf(key) !== -1) return "hidden"
  if (p.indexOf(key) !== -1) return "pinned"
  return "drawer"
}

// Filter hosted widgets by category ('pinned', 'drawer', 'hidden')
function filterHostedWidgets(widgets, pinnedIds, hiddenIds, targetCategory) {
  var list = normalizeWrappers(widgets)
  var result = []
  for (var i = 0; i < list.length; i++) {
    var w = list[i]
    var id = wrapperId(w)
    if (!id) continue
    if (hostedWidgetCategory(id, pinnedIds, hiddenIds) === targetCategory) {
      result.push(w)
    }
  }
  return result
}

function ensurePluginListed(config, id) {
  if (!config) return false
  if (!Array.isArray(config.plugins)) config.plugins = []
  for (var i = 0; i < config.plugins.length; i++) {
    var e = config.plugins[i]
    var eid = typeof e === "string" ? e : (e ? String(e.id || "") : "")
    if (eid === id) return false
  }
  config.plugins.push({ id: id })
  return true
}

function unlistPlugin(config, id) {
  if (!config || !Array.isArray(config.plugins)) return
  config.plugins = config.plugins.filter(function(e) {
    if (!e) return false
    var eid = typeof e === "string" ? e : String(e.id || "")
    return eid !== id
  })
}

// Mutates `config` in place for mutateShellConfig:
// Absorbs a widget from the bar layout into TidyTray's widgets array
function captureIntoTray(config, trayId, sourceId, orderTokens) {
  if (!sourceId || sourceId === trayId || !config || !config.bar || !config.bar.layout) return false
  var layout = config.bar.layout
  var source = findLayoutEntry(layout, sourceId)
  if (!source) return false

  source.entries.splice(source.index, 1)

  var tray = findLayoutEntry(layout, trayId)
  if (!tray) {
    source.entries.splice(source.index, 0, source.entry)
    return false
  }

  var trayEntry = tray.entry
  if (typeof trayEntry === "string") {
    trayEntry = { id: trayEntry }
    tray.entries[tray.index] = trayEntry
  }
  if (!Array.isArray(trayEntry.widgets)) trayEntry.widgets = []

  var entryObj = typeof source.entry === "string" ? { id: source.entry } : source.entry
  var wrapper = { entry: entryObj }

  if (ensurePluginListed(config, sourceId)) wrapper.listed = true
  trayEntry.widgets.push(wrapper)

  if (Array.isArray(orderTokens) && orderTokens.length) {
    trayEntry.order = orderTokens.map(String)
  }
  return true
}

// Releases a hosted widget from TidyTray back to the main bar layout
function releaseFromTray(config, trayId, widgetId, targetSection, targetIndex) {
  if (!widgetId || !config || !config.bar || !config.bar.layout) return false
  var layout = config.bar.layout
  var tray = findLayoutEntry(layout, trayId)
  if (!tray) return false

  var trayEntry = tray.entry
  if (!trayEntry || !Array.isArray(trayEntry.widgets)) return false

  var removedWrapper = null
  for (var i = 0; i < trayEntry.widgets.length; i++) {
    if (wrapperId(trayEntry.widgets[i]) === widgetId) {
      removedWrapper = trayEntry.widgets.splice(i, 1)[0]
      break
    }
  }
  if (!removedWrapper) return false

  var secName = targetSection && SECTIONS.indexOf(targetSection) !== -1 ? targetSection : tray.section
  var secList = layout[secName]
  if (!Array.isArray(secList)) {
    secList = []
    layout[secName] = secList
  }

  var insertIdx = typeof targetIndex === "number" && targetIndex >= 0 && targetIndex <= secList.length
    ? targetIndex
    : (secName === tray.section ? tray.index + 1 : secList.length)

  secList.splice(insertIdx, 0, removedWrapper.entry)

  if (removedWrapper.listed) {
    unlistPlugin(config, widgetId)
  }
  return true
}

// Reorders hosted widgets within trayEntry.widgets
function reorderTrayWidgets(config, trayId, fromIndex, toIndex) {
  if (!config || !config.bar || !config.bar.layout) return false
  var tray = findLayoutEntry(config.bar.layout, trayId)
  if (!tray || !tray.entry || !Array.isArray(tray.entry.widgets)) return false

  var widgets = tray.entry.widgets
  if (fromIndex < 0 || fromIndex >= widgets.length) return false
  if (toIndex < 0 || toIndex >= widgets.length || fromIndex === toIndex) return false

  var item = widgets.splice(fromIndex, 1)[0]
  widgets.splice(toIndex, 0, item)
  return true
}

// Toggle membership in pinned or hidden arrays
function toggleBucketId(pinnedList, hiddenList, id, targetBucket) {
  var p = asList(pinnedList).filter(function(x) { return x !== id })
  var h = asList(hiddenList).filter(function(x) { return x !== id })
  if (targetBucket === "pinned" && asList(pinnedList).indexOf(id) === -1) {
    p.push(id)
  }
  if (targetBucket === "hidden" && asList(hiddenList).indexOf(id) === -1) {
    h.push(id)
  }
  return { pinned: p, hidden: h }
}

// State persistence across bar reloads (for seamless config mutations)
var _persistedManageState = { open: false, tab: "items" }

function setPersistedManageState(open, tab) {
  _persistedManageState = { open: !!open, tab: tab || "items" }
}

function getPersistedManageState() {
  return _persistedManageState
}

function clearPersistedManageState() {
  _persistedManageState = { open: false, tab: "items" }
}

// Catalog helpers: parse bar widgets from manifests
function catalogEntryFromManifest(sourceDir, manifest) {
  if (!manifest || typeof manifest !== "object") return null
  var kinds = manifest.kinds
  if (!Array.isArray(kinds) || kinds.indexOf("bar-widget") === -1) return null
  var ep = manifest.entryPoints && manifest.entryPoints.barWidget
  if (!ep || typeof ep !== "string" || ep.indexOf("..") !== -1) return null
  var id = String(manifest.id || "")
  if (!id) return null
  var dir = String(sourceDir || "").replace(/\/+$/, "")
  if (!dir) return null
  var meta = manifest.barWidget && typeof manifest.barWidget === "object" ? manifest.barWidget : {}
  var title = String(meta.displayName || manifest.name || id)
  return {
    id: id,
    title: title,
    url: "file://" + dir + "/" + ep.replace(/^\/+/, "")
  }
}

// Friendly display name for an unknown ID
function friendlyDisplayName(id) {
  var textStr = String(id || "")
  var seg = textStr.substring(textStr.lastIndexOf(".") + 1).replace(/[-_]+/g, " ").trim()
  if (!seg) return textStr
  return seg.charAt(0).toUpperCase() + seg.slice(1)
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    SECTIONS: SECTIONS,
    DISPLAY_MODES: DISPLAY_MODES,
    INDICATOR_ICONS: INDICATOR_ICONS,
    TRIGGERS: TRIGGERS,
    isPlainObject: isPlainObject,
    entryId: entryId,
    entrySettings: entrySettings,
    asList: asList,
    normalizeIdList: normalizeIdList,
    normalizeDisplayMode: normalizeDisplayMode,
    normalizeTrigger: normalizeTrigger,
    normalizeIndicatorIcon: normalizeIndicatorIcon,
    chevronGlyph: chevronGlyph,
    normalizeRehideSeconds: normalizeRehideSeconds,
    normalizeDuration: normalizeDuration,
    layoutHasWidget: layoutHasWidget,
    layoutSectionFor: layoutSectionFor,
    findLayoutEntry: findLayoutEntry,
    itemNamed: itemNamed,
    ownedByOmarchy: ownedByOmarchy,
    sniItemCategory: sniItemCategory,
    filterSniItems: filterSniItems,
    normalizeWrappers: normalizeWrappers,
    wrapperId: wrapperId,
    hostedWidgetCategory: hostedWidgetCategory,
    filterHostedWidgets: filterHostedWidgets,
    ensurePluginListed: ensurePluginListed,
    unlistPlugin: unlistPlugin,
    captureIntoTray: captureIntoTray,
    releaseFromTray: releaseFromTray,
    reorderTrayWidgets: reorderTrayWidgets,
    toggleBucketId: toggleBucketId,
    catalogEntryFromManifest: catalogEntryFromManifest,
    friendlyDisplayName: friendlyDisplayName,
    setPersistedManageState: setPersistedManageState,
    getPersistedManageState: getPersistedManageState,
    clearPersistedManageState: clearPersistedManageState
  }
}
