-- Probe: Terrarium's rows live on ONE page, and every row on it has a plain,
-- unique name that fits. Checks, over the real menu (OptionsMenu through the
-- engine's ui.options.rows hook):
--   * the top level carries exactly one Terrarium row, OPEN TERRARIUM, and
--     neither of this mod's pipeline rows
--   * A on it opens the TERRARIUM page: VOXEL, T-SHIFT, the settings, and
--     the BUILD 3D WORLD / CLEAR 3D CACHE actions
--   * CLEAR 3D CACHE takes two presses (the cache itself is not touched:
--     BuildCache.clear is counted, not run)
--   * BUILD 3D WORLD opens the ALL / NEAREST / NONE prompt, and B closes it
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
  local top = OptionsMenu.new(game)
  game.stack:push(top)
  Scenes.wait(10)

  local prefix = H.id .. ":"
  local function isOurs(id)
    return id:sub(1, #prefix) == prefix or id:find("^pipeline:terrarium_") ~= nil
  end
  -- the top level: one row of ours, the opener
  local topOurs, opener = {}, nil
  for _, row in ipairs(top.view or top.rows or {}) do
    local id = tostring(row.id or "")
    if isOurs(id) then topOurs[#topOurs + 1] = id end
    if id == prefix .. "open" then opener = row end
  end
  log("top level, ours: " .. table.concat(topOurs, " "))
  check(#topOurs == 1 and opener ~= nil, "the top level carries only OPEN TERRARIUM")
  if not opener then H:finish(); love.event.quit(); return end
  opener.activate(game)
  Scenes.wait(5)
  local menu = game.stack:top()
  check(menu ~= top and menu.terrarium, "A on it opened the TERRARIUM page")
  Scenes.shot(OUT, "menu_0_page")

  local seen, ours = {}, {}
  local has = {}
  for _, row in ipairs(menu.rows or {}) do has[tostring(row.id)] = row end
  check(has["pipeline:terrarium_voxel"] ~= nil, "VOXEL is on the page")
  check(has["pipeline:terrarium_tiltshift"] ~= nil, "T-SHIFT is on the page")
  check(has[prefix .. "buildcache"] ~= nil, "3D CACHE is on the page")

  -- CLEAR 3D CACHE: armed by the first A, done by the second
  local BuildCache = H.V.require("BuildCache")
  local clears = 0
  local realClear = BuildCache.clear
  BuildCache.clear = function() clears = clears + 1 end
  local clear = has[prefix .. "clearcache"]
  check(clear ~= nil, "CLEAR 3D CACHE is on the page")
  if clear then
    clear.activate(game)
    check(clears == 0 and clear.value() ~= "", "one A only arms it (" .. tostring(clear.value()) .. ")")
    clear.activate(game)
    check(clears == 1 and clear.value() == "", "the second A clears")
  end
  BuildCache.clear = realClear

  -- BUILD 3D WORLD: the prompt, and B back to the page
  local BuildVeil = H.V.require("BuildVeil")
  local build = has[prefix .. "buildworld"]
  check(build ~= nil, "BUILD 3D WORLD is on the page")
  if build then
    build.activate(game)
    Scenes.wait(5)
    check(BuildVeil.active(), "it opened the ALL / NEAREST / NONE prompt")
    Scenes.shot(OUT, "menu_0_build_prompt")
    game.input.pressQueue[#game.input.pressQueue + 1] = "b"
    Scenes.wait(5)
    check(not BuildVeil.active() and game.stack:top() == menu, "B closed it, back on the page")
  end

  for _, row in ipairs(menu.rows or {}) do
    local id = tostring(row.id or "")
    if isOurs(id) then
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
  check(#ours >= 30, ("%d Terrarium rows on the page"):format(#ours))
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
