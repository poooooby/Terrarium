-- Probe: every Terrarium row on the OPTIONS menu has a plain, unique name
-- that fits. Checks, over the real menu (OptionsMenu through the engine's
-- ui.options.rows hook):
--   * no two Terrarium rows share a label (there were two called MAP)
--   * every label fits the 18 glyphs the engine prints whole
--     (src/ui/OptionRows.lua, fits(16))
--   * none of the pre-rename names survive
-- and screenshots the menu with the cursor on a few rows.
--
--   python tools/profiler/run.py options_names_probe
return function(game)
  local src = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
  local TOOLS = (src:match("^(.*)/tests/[^/]*$") or ".") .. "/tools/profiler/"
  local Harness = dofile(TOOLS .. "Harness.lua")
  local Scenes = dofile(TOOLS .. "Scenes.lua")
  local OUT = os.getenv("DS_PROBE_DIR") or "."
  local H = assert(Harness.attach(game, { out = OUT, name = "options_names" }))
  local log = H.log
  local fails = 0
  local function check(ok, what)
    log((ok and "ok   " or "FAIL ") .. what)
    if not ok then fails = fails + 1 end
  end
  if not Scenes.boot(game, log) then H:finish(); love.event.quit(); return end

  local OLD = { "RES", "PFX", "UI LANG", "DIAG", "TREES", "COMBAT", "3D-BTL",
                "BACK SPRITES", "WATER", "LIGHT", "ANIME", "IMPACT", "AMBIENT",
                "SOUNDS", "CLOUD SHADE", "GROUND", "INDOOR", "HEARTH", "TOWER",
                "CRYPT", "CRYPT-FX", "SHOP", "SHOP-FX", "LEDGES", "HAUNT",
                "V-GRID", "V-CURVE", "V-HAZE", "SM64CAM", "DAYTIME", "N-DARK",
                "LAMPS", "LOAD FADE", "MAP" }
  local oldSet = {}
  for _, n in ipairs(OLD) do oldSet[n] = true end

  local OptionsMenu = require("src.ui.OptionsMenu")
  local menu = OptionsMenu.new(game)
  game.stack:push(menu)
  Scenes.wait(10)

  local prefix = H.id .. ":"
  local seen, ours = {}, {}
  for _, row in ipairs(menu.rows or {}) do
    local id = tostring(row.id or "")
    if id:sub(1, #prefix) == prefix then
      local label = tostring(row.label or "")
      local okV, value = pcall(row.value, game)
      ours[#ours + 1] = { id = id, label = label }
      log(("%-28s %-14s %s"):format(id, label, okV and tostring(value) or "?"))
      if seen[label] then
        check(false, ("label %q used by %s and %s"):format(label, seen[label], id))
      end
      seen[label] = id
      if #label > 18 then check(false, ("label %q is %d glyphs"):format(label, #label)) end
      if oldSet[label] then check(false, ("old name still on the menu: %q (%s)"):format(label, id)) end
    end
  end
  check(#ours >= 30, ("%d Terrarium rows on the menu"):format(#ours))
  check(fails == 0, "all labels unique, fitting, renamed")

  for i, key in ipairs({ ":minimap", ":worldmap", ":battledyn", ":particleFx", ":loadveil" }) do
    for _, r in ipairs(ours) do
      if r.id:sub(-#key) == key then
        pcall(menu.focusRow, menu, r.id)
        Scenes.wait(20)
        Scenes.shot(OUT, ("menu_%d%s"):format(i, key:gsub(":", "_")))
      end
    end
  end

  log(fails == 0 and "PASS" or ("FAIL x" .. fails))
  H:finish({ probe = "options_names" })
  love.event.quit()
end
