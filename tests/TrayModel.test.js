const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

const modelPath = path.join(__dirname, "..", "TrayModel.js")
const source = fs.readFileSync(modelPath, "utf8").replace(/^\.pragma library\s*/m, "")

const Model = { module: { exports: {} } }
vm.createContext(Model)
vm.runInContext(source, Model, { filename: "TrayModel.js" })
const M = Model.module.exports

console.log("=== Testing TrayModel.js ===")

// 1. Normalization tests
assert.strictEqual(M.normalizeDisplayMode("INLINE"), "inline")
assert.strictEqual(M.normalizeDisplayMode("dropdown"), "dropdown")
assert.strictEqual(M.normalizeDisplayMode("invalid"), "inline")
assert.strictEqual(M.normalizeDisplayMode("flat"), "inline")

assert.strictEqual(M.normalizeTrigger("HOVER"), "hover")
assert.strictEqual(M.normalizeTrigger("click"), "click")
assert.strictEqual(M.normalizeTrigger("foo"), "click")

assert.strictEqual(M.normalizeIndicatorIcon("dots"), "dots")
assert.strictEqual(M.normalizeIndicatorIcon("none"), "chevron")
assert.strictEqual(M.normalizeIndicatorIcon("unknown"), "chevron")
assert.deepStrictEqual(Array.from(M.DISPLAY_MODES), ["inline", "dropdown", "drawer"])
assert.deepStrictEqual(Array.from(M.INDICATOR_ICONS), ["chevron", "dot", "dots", "plus"])

assert.strictEqual(M.normalizeRehideSeconds(-5), 0)
assert.strictEqual(M.normalizeRehideSeconds("15"), 15)
assert.strictEqual(M.normalizeRehideSeconds(9999), 600)

// 2. ID and Layout tests
assert.strictEqual(M.entryId("test.id"), "test.id")
assert.strictEqual(M.entryId({ id: "my.plugin" }), "my.plugin")
assert.strictEqual(M.entryId(null), "")

const sampleLayout = {
  left: ["omarchy.menu", "omarchy.workspaces"],
  center: ["omarchy.media"],
  right: ["io.github.jvlianodorneles.tidytray", { id: "omarchy.clock" }]
}

assert.strictEqual(M.layoutSectionFor(sampleLayout, "omarchy.menu"), "left")
assert.strictEqual(M.layoutSectionFor(sampleLayout, "omarchy.media"), "center")
assert.strictEqual(M.layoutSectionFor(sampleLayout, "omarchy.clock"), "right")
assert.strictEqual(M.layoutSectionFor(sampleLayout, "nonexistent"), "")
assert.strictEqual(M.layoutHasWidget(sampleLayout, "omarchy.clock"), true)
assert.strictEqual(M.layoutHasWidget(sampleLayout, "nonexistent"), false)

// 3. Deduplication tests
const localsendItem = { id: "localsend-1234", title: "LocalSend" }
const dropboxItem = { id: "dropbox-client", title: "Dropbox" }
const steamItem = { id: "steam", title: "Steam" }

assert.strictEqual(M.ownedByOmarchy(localsendItem, sampleLayout), true)
assert.strictEqual(M.ownedByOmarchy(steamItem, sampleLayout), false)
// Dropbox without omarchy.dropbox in layout
assert.strictEqual(M.ownedByOmarchy(dropboxItem, sampleLayout), false)
// Dropbox WITH omarchy.dropbox in layout
const layoutWithDropbox = {
  right: ["io.github.jvlianodorneles.tidytray", "omarchy.dropbox"]
}
assert.strictEqual(M.ownedByOmarchy(dropboxItem, layoutWithDropbox), true)

// 4. SNI filtering tests
const items = [
  { id: "steam", title: "Steam" },
  { id: "discord", title: "Discord" },
  { id: "obs", title: "OBS Studio" },
  localsendItem
]
const pinned = ["steam"]
const hidden = ["obs"]

const pinnedItems = M.filterSniItems(items, pinned, hidden, "pinned", true, sampleLayout)
assert.strictEqual(pinnedItems.length, 1)
assert.strictEqual(pinnedItems[0].id, "steam")

const drawerItems = M.filterSniItems(items, pinned, hidden, "drawer", true, sampleLayout)
assert.strictEqual(drawerItems.length, 1)
assert.strictEqual(drawerItems[0].id, "discord")

const hiddenItems = M.filterSniItems(items, pinned, hidden, "hidden", true, sampleLayout)
assert.strictEqual(hiddenItems.length, 1)
assert.strictEqual(hiddenItems[0].id, "obs")

// 5. Config mutation tests (capture, release, reorder)
const sampleConfig = {
  bar: {
    layout: {
      left: ["omarchy.menu"],
      center: [],
      right: [
        { id: "omarchy.bluetooth" },
        { id: "io.github.jvlianodorneles.tidytray", widgets: [] },
        { id: "omarchy.clock" }
      ]
    }
  },
  plugins: []
}

// Capture omarchy.bluetooth into tidytray
const captured = M.captureIntoTray(sampleConfig, "io.github.jvlianodorneles.tidytray", "omarchy.bluetooth")
assert.strictEqual(captured, true)
assert.strictEqual(sampleConfig.bar.layout.right.length, 2)
const trayEntry = sampleConfig.bar.layout.right[0]
assert.strictEqual(trayEntry.id, "io.github.jvlianodorneles.tidytray")
assert.strictEqual(trayEntry.widgets.length, 1)
assert.strictEqual(trayEntry.widgets[0].entry.id, "omarchy.bluetooth")
assert.strictEqual(sampleConfig.plugins.length, 1)
assert.strictEqual(sampleConfig.plugins[0].id, "omarchy.bluetooth")

// Reorder inside tray
trayEntry.widgets.push({ entry: { id: "omarchy.network" } })
assert.strictEqual(trayEntry.widgets.length, 2)
M.reorderTrayWidgets(sampleConfig, "io.github.jvlianodorneles.tidytray", 0, 1)
assert.strictEqual(trayEntry.widgets[0].entry.id, "omarchy.network")
assert.strictEqual(trayEntry.widgets[1].entry.id, "omarchy.bluetooth")

// Release omarchy.bluetooth from tray back to bar
const released = M.releaseFromTray(sampleConfig, "io.github.jvlianodorneles.tidytray", "omarchy.bluetooth")
assert.strictEqual(released, true)
assert.strictEqual(trayEntry.widgets.length, 1)
assert.strictEqual(sampleConfig.bar.layout.right.length, 3)
assert.strictEqual(sampleConfig.bar.layout.right[1].id, "omarchy.bluetooth")
// Plugin should be unlisted since it was listed on capture
assert.strictEqual(sampleConfig.plugins.length, 0)

// Release omarchy.network from tray before omarchy.menu in left section
const releasedBefore = M.releaseFromTray(sampleConfig, "io.github.jvlianodorneles.tidytray", "omarchy.network", "left", "omarchy.menu")
assert.strictEqual(releasedBefore, true)
assert.strictEqual(trayEntry.widgets.length, 0)
assert.strictEqual(sampleConfig.bar.layout.left[0].id, "omarchy.network")
assert.strictEqual(sampleConfig.bar.layout.left[1], "omarchy.menu")

// 6. Bucket toggling
const toggled1 = M.toggleBucketId(["steam"], [], "steam", "pinned")
assert.deepStrictEqual(JSON.parse(JSON.stringify(toggled1.pinned)), [])

const toggled2 = M.toggleBucketId([], [], "discord", "pinned")
assert.deepStrictEqual(JSON.parse(JSON.stringify(toggled2.pinned)), ["discord"])

const toggled3 = M.toggleBucketId(["discord"], [], "discord", "hidden")
assert.deepStrictEqual(JSON.parse(JSON.stringify(toggled3.pinned)), [])
// 7. State persistence tests
assert.deepStrictEqual(JSON.parse(JSON.stringify(M.getPersistedManageState())), { open: false, tab: "items" })
M.setPersistedManageState(true, "settings")
assert.deepStrictEqual(JSON.parse(JSON.stringify(M.getPersistedManageState())), { open: true, tab: "settings" })
// 8. Chevron glyph tests
assert.strictEqual(M.chevronGlyph("chevron", false, false), "\uf053")
assert.strictEqual(M.chevronGlyph("chevron", false, true), "\uf054")
assert.strictEqual(M.chevronGlyph("chevron", true, false), "\uf078")
assert.strictEqual(M.chevronGlyph("chevron", true, false, true), "\uf078")
assert.strictEqual(M.chevronGlyph("chevron", true, false, false), "\uf077")
assert.strictEqual(M.chevronGlyph("caret", false, false), "\uf0d9")
assert.strictEqual(M.chevronGlyph("caret", false, true), "\uf0da")
assert.strictEqual(M.chevronGlyph("caret", true, false, false), "\uf0d8")
assert.strictEqual(M.chevronGlyph("plus", false, true), "\uf067")

console.log("All TrayModel unit tests passed successfully!")
