-- Probe: the town map rebuilt from the classic picture.
--
-- Counted:
--   it BUILDS on this build (report().built, the three shaders, the count of
--   places -- 47, the classic map's own list), and how long it took;
--   the OBJECTIVE resolves and its route is walked along the picture's own
--   roads (path length > 2 means the search found the roads, 2 means it
--   fell back to a straight line);
--   every string a player can read is US English -- no Portuguese words
--   left in the module's table or in the quest chain;
--   FLY and AREA screens are honoured (the screen's own fields survive);
--   CLASSIC hands the screen back: the engine's own 160x144 picture is on
--   the window, measured by its palette's light blue.
-- And the pictures: the region, the zoom, the top-down view, fly, area,
-- classic, and the region at night.
--
--   POKEPORT_VERSION=yellow DS_PROBE_DIR=<dir> \
--   POKEPORT_DRIVER=mods/TERRARIUM/tests/worldmap_new_probe.lua gen1recomp
return function(game)
  local OUT = os.getenv("DS_PROBE_DIR") or "."
  local logf = assert(io.open(OUT .. "/worldmap_new_probe.log", "w"))
  local function log(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
    logf:write(table.concat(parts, " "), "\n"); logf:flush()
  end
  local function wait(n) for _ = 1, n do coroutine.yield() end end
  local function tap(b)
    game.input.pressQueue[#game.input.pressQueue + 1] = b; coroutine.yield()
  end
  local function shot(name)
    local done, keep = false, nil
    love.graphics.captureScreenshot(function(data)
      local f = io.open(OUT .. "/" .. name, "wb")
      if f then f:write(data:encode("png"):getString()) f:close() end
      keep = data; done = true
    end)
    local guard = 0
    while not done and guard < 240 do coroutine.yield(); guard = guard + 1 end
    return keep
  end

  local n = 0
  while not (game.overworld and game.stack and game.stack:top()) do
    wait(1); n = n + 1
    if n > 900 then log("FAIL: no overworld") logf:close() love.event.quit() return end
  end
  n = 0
  while game.stack:top() ~= game.overworld do
    tap("a"); wait(10); n = n + 11
    if n > 1500 then log("FAIL: never reached free roam") break end
  end
  game.input:reset()

  local exports = game.mods and game.mods.exports
  local lib = exports and exports.TERRARIUM and exports.TERRARIUM.lib
  if not lib then log("FAIL: TERRARIUM not loaded"); logf:close(); love.event.quit(); return end
  log("version:", exports.TERRARIUM.version)

  local WorldMap3D = lib.require("WorldMap3D")
  local WorldMapQuest = lib.require("WorldMapQuest")
  local DayNight = lib.require("DayNight")
  local Weather = lib.require("Weather")
  local Lang = lib.require("Lang")
  local TownMap = require("src.ui.TownMap")

  DayNight.setting:sync("day")
  Weather.setting:sync("none")
  WorldMap3D.setting:sync("3d")
  game.overworld:setMap("ROUTE_12", 10, 20, "down")
  wait(120)

  -- ------- 1. the strings, before a pixel
  --
  -- LANG=en carries no Portuguese anywhere -- STRINGS (via its EN/PT
  -- split, see WorldMap3D.lua) and the quest chain's own _en fields.
  -- LANG=pt is checked the other way: the handful of labels this mod's
  -- own original Portuguese actually had (STRINGS_PT's keys, and every
  -- quest step's _pt fields) must still say so -- restoring them was
  -- the point, not something a future edit should silently regress.
  local pt = { "ç", "ã", "õ", "INSÍGNIA", "Derrote", "Recupere", "Ginásio", "OBJETIVO", "VOCÊ", "SAIR", "GIRAR" }
  local function hasPT(s)
    for _, w in ipairs(pt) do if s:find(w, 1, true) then return w end end
    return nil
  end
  local okS = true

  Lang.setting:sync("en")
  for k, v in pairs(WorldMap3D.strings()) do
    if type(v) == "string" then
      local hit = hasPT(v)
      if hit then log(("  FAIL: strings.%s still carries %q"):format(k, hit)) okS = false end
    elseif type(v) == "table" then
      for k2, v2 in pairs(v) do
        local hit = hasPT(v2)
        if hit then log(("  FAIL: strings.%s.%s still carries %q"):format(k, k2, hit)) okS = false end
      end
    end
  end
  for _, st in ipairs(WorldMapQuest.CHAIN) do
    local hit = hasPT(st.title_en .. " " .. (st.detail_en or ""))
    if hit then log(("  FAIL: quest %s (en) still carries %q"):format(st.id, hit)) okS = false end
  end
  log("english strings:", okS and "PASS" or "FAIL")

  -- Exact matches, not a Portuguese-looking-word heuristic: some of the
  -- restored originals ("OBJETIVO", "A SEGUIR") carry no accent at all,
  -- so a heuristic scan would false-negative on them. These are the
  -- literal values lib/WorldMap3D.lua's STRINGS_PT and
  -- lib/WorldMapQuest.lua's CHAIN _pt fields were set to.
  Lang.setting:sync("pt")
  local ptStrings = { objective = "OBJETIVO", next = "A SEGUIR",
                      badges = "INSÍGNIAS", you = "VOCÊ" }
  for k, want in pairs(ptStrings) do
    local got = WorldMap3D.strings()[k]
    if got ~= want then
      log(("  FAIL: strings.%s under LANG=pt: wanted %q, got %q")
          :format(k, want, tostring(got)))
      okS = false
    end
  end
  for _, st in ipairs(WorldMapQuest.CHAIN) do
    if st.title ~= nil then
      log(("  FAIL: quest %s has a bare .title field; only _en/_pt should exist")
          :format(st.id))
      okS = false
    end
    if type(st.title_pt) ~= "string" or st.title_pt == "" then
      log(("  FAIL: quest %s has no title_pt"):format(st.id))
      okS = false
    end
  end
  local qpt = WorldMapQuest.current(game.save)
  if qpt then
    local src = nil
    for _, st in ipairs(WorldMapQuest.CHAIN) do
      if st.id == qpt.step.id then src = st break end
    end
    if not (src and qpt.step.title == src.title_pt and qpt.step.detail == src.detail_pt) then
      log(("  FAIL: WorldMapQuest.current() under LANG=pt did not resolve to %s's title_pt/detail_pt")
          :format(tostring(qpt.step.id)))
      okS = false
    end
  end
  log("portuguese carried over under LANG=pt:", okS and "PASS" or "FAIL")
  Lang.setting:sync("en")

  -- ------- 2. the build, through the real screen
  local function openMap(opts)
    local screen = TownMap.new(game, opts)
    game.stack:push(screen)
    local guard = 0
    while guard < 1200 do
      wait(1); guard = guard + 1
      local rep = WorldMap3D.report()
      if rep.built or rep.failed then break end
    end
    return screen
  end
  local screen = openMap()
  wait(90)
  local rep = WorldMap3D.report()
  log(("built=%s failed=%s places=%d landVerts=%d propVerts=%d waterVerts=%d peaks=%d shaders=%s ms=%.0f")
      :format(tostring(rep.built), tostring(rep.failed), rep.places, rep.landVerts, rep.propVerts,
              rep.waterVerts, rep.peaks, tostring(rep.shaders), rep.ms))
  if not rep.built then log("  FAIL: the map did not build") end
  local plainCount = #TownMap.new(game).locs
  if rep.places ~= plainCount then
    log(("  FAIL: %d places against the screen's own %d"):format(rep.places, plainCount))
  end
  if not rep.shaders then log("  FAIL: a shader did not compile") end
  log(("screen: mode=%s sel=%s player=%s  quest=%s target=%s path=%d")
      :format(tostring(screen.mode), tostring(screen.sel),
              tostring(screen.playerLoc and screen.playerLoc.name),
              tostring(rep.quest), tostring(rep.target), rep.path))
  if rep.quest and rep.path <= 2 then log("  note: the objective route fell back to a straight line") end
  -- where every pin landed
  local places = WorldMap3D.debugPlaces()
  local off = 0
  local w, h = love.graphics.getDimensions()
  for _, p in ipairs(places) do
    if p.sx < 0 or p.sx > w or p.sy < 0 or p.sy > h then off = off + 1 end
  end
  log(("pins on screen: %d of %d"):format(#places - off, #places))
  if off > 0 then log("  FAIL: pins off screen in the wide view") end
  shot("wm_region.png")

  -- the cursor: a few d-pad taps, the banner follows
  tap("right"); wait(30); tap("up"); wait(30)
  log("after right, up: sel=" .. tostring(screen.sel) .. " " .. tostring(screen.locs[screen.sel] and screen.locs[screen.sel].name))
  shot("wm_moved.png")
  WorldMap3D.toggleZoom(); wait(80)
  shot("wm_zoom.png")
  WorldMap3D.toggleTopDown(); wait(80)
  shot("wm_zoom_top.png")
  WorldMap3D.toggleZoom(); wait(80)
  shot("wm_top.png")
  WorldMap3D.toggleTopDown(); wait(40)
  -- night
  DayNight.setting:sync("night"); wait(60)
  shot("wm_night.png")
  DayNight.setting:sync("day"); wait(20)
  tap("b"); wait(20)

  -- ------- 3. fly
  local flew = nil
  local fly = openMap({ fly = true, onFly = function(id) flew = id end })
  wait(60)
  log(("fly screen: fly=%s locs=%d sel=%s"):format(tostring(fly.fly), #fly.locs, tostring(fly.sel)))
  shot("wm_fly.png")
  tap("down"); wait(30)
  log("fly after down: " .. tostring(fly.locs[fly.sel] and fly.locs[fly.sel].name))
  tap("a"); wait(30)
  log("A on the fly screen flew to: " .. tostring(flew) .. "  top is overworld: " .. tostring(game.stack:top() == game.overworld))
  if not flew then log("  FAIL: A did not fly") end
  wait(200)

  -- ------- 4. the Pokedex area
  local nest = openMap({ nestSpecies = "PIDGEY" })
  wait(60)
  log(("area screen: nests=%d"):format(nest.nests and #nest.nests or -1))
  shot("wm_area.png")
  tap("a"); wait(30)

  -- ------- 5. classic
  WorldMap3D.setting:sync("classic")
  local cls = openMap()
  wait(60)
  local img = shot("wm_classic.png")
  if img then
    local hit, seen = 0, 0
    for y = 0, img:getHeight() - 1, 4 do
      for x = 0, img:getWidth() - 1, 4 do
        local r, g, b = img:getPixel(x, y)
        seen = seen + 1
        -- the engine's TOWNMAP palette on this build: sky blue {0,173,255}
        -- and grass green {82,230,0}, measured off its own screen
        if (r < 0.1 and math.abs(g - 0.678) < 0.08 and b > 0.9)
           or (math.abs(r - 0.322) < 0.08 and g > 0.85 and b < 0.1) then hit = hit + 1 end
      end
    end
    log(("classic: palette pixels %d of %d sampled (%.1f%%)"):format(hit, seen, 100 * hit / seen))
    if hit < seen * 0.10 then log("  FAIL: the classic picture is not on the window") end
  end
  log("classic report: built=" .. tostring(WorldMap3D.report().built) .. " classic=" .. tostring(WorldMap3D.report().classic))
  tap("b"); wait(20)
  WorldMap3D.setting:sync("3d")

  log("done")
  logf:close()
  love.event.quit()
end
