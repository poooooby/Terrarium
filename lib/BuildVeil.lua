-- The 3D build prompt and its progress veil, on the title's CONTINUE /
-- NEW GAME page.
--
-- Why there. Building a map's diorama is the 7-10 s (and more, on a phone
-- with the JIT off) of flat 2D that players read as the mod being broken.
-- With the 3D build cache (lib/BuildCache.lua) each map only ever has to be
-- built once per install, and the title page is the cheapest moment there
-- is to do it: no game is running, nothing is on screen worth a frame, and
-- the player is about to choose where they are going anyway.
--
-- So the first time the page comes up with the 3D view on -- and again on
-- any later boot where maps that WERE built have changed (a mod update, a
-- geometry row flipped) -- it asks:
--
--   ALL      build every map now, behind a progress veil
--   NEAREST  build the map the save is in and the maps around it (its
--            connections and the places its doors lead, two steps out),
--            then go into the game with those already in 3D
--   NONE     go straight in
--
-- Whatever is not built here is built the first time the player walks
-- into it, under the "Building voxels" badge (lib/BuildBadge.lua), and
-- cached then. Every path writes to the cache, so each map is slow once.
-- B on the veil stops early and keeps what was done.
--
-- UI only: it reads the save the CONTINUE page itself reads (to know which
-- map NEAREST means), builds what the renderer would build anyway, and
-- never touches the world, the save or the game's input past its own
-- prompt.

local V = ...

local BuildCache = V.require("BuildCache")
local ChunkMesher = V.require("ChunkMesher")
local Budget = V.require("BuildBudget")
local Lang = V.require("Lang")

local BuildVeil = {}

local clock = (love and love.timer and love.timer.getTime) or os.clock

-- The build's share of a frame while the veil is up. The veil is a still
-- picture, so a low frame rate costs nothing, and the bigger the slice
-- the less of the wall clock goes to the frames around it.
BuildVeil.SLICE = 0.100

-- How far NEAREST reaches: steps through connections and doors from the
-- save's map, and a ceiling on how many maps that may come to.
BuildVeil.NEAR_STEPS = 2
BuildVeil.NEAR_MAX = 14

-- ------------------------------------------------------------- the world

local function gameData()
  local ok, Game = pcall(require, "src.core.Game")
  return ok and Game and Game.data or nil
end

local function mapFor(id)
  local data = gameData()
  local def = data and data.maps and data.maps[id]
  local ts = def and data.tilesets and data.tilesets[def.tileset]
  if not ts then return nil end
  local okM, Map = pcall(require, "src.world.Map")
  if not okM then return nil end
  local ok, map = pcall(Map.new, def, ts)
  return ok and map or nil
end

-- The full variant's masks for `id`, the way VoxelScene.prefetch builds
-- them from the engine's own neighbour walk (OverworldState:rebuildNeighbors:
-- the configured hops, reaching half the view plus a block). Computed the
-- same way so a baked `full` file carries the signature a visit will ask
-- for; a different window size simply misses on `full`, and the body
-- variant still draws while the ring builds.
function BuildVeil.masksFor(id)
  local masks = {}
  pcall(function()
    local Game = require("src.core.Game")
    local OC = require("src.world.OverworldController")
    local maps = Game.data.maps
    local hops = 2
    local okF, FD = pcall(require, "src.world.FieldDefaults")
    if okF and FD and FD.world then
      hops = FD.world(Game.data, "neighborHops") or hops
    end
    local vw, vh = Game.renderer:worldViewSize()
    for _, n in ipairs(OC.computeNeighbors(maps, id, hops,
                                           math.floor(vw / 2) + 64,
                                           math.floor(vh / 2) + 64)) do
      local d = maps[n.id]
      if d then
        masks[#masks + 1] = { n.ox, n.oy, n.ox + d.width * 32, n.oy + d.height * 32 }
      end
    end
  end)
  return masks
end

BuildVeil.mapFor = mapFor

-- Whether every part a visit to `map` needs is cached and current.
local function current(map)
  return BuildCache.has(map, "body") and BuildCache.has(map, "aux")
     and BuildCache.has(map, "full", BuildVeil.masksFor(map.id))
end

BuildVeil.current = current

-- Every map id, the outdoors first (that is where the kits are, and where
-- the slow builds are), the biggest first within each half.
function BuildVeil.allIds()
  local data = gameData()
  local out = {}
  if not (data and data.maps) then return out end
  for id, def in pairs(data.maps) do
    if def.tileset and data.tilesets[def.tileset] then out[#out + 1] = id end
  end
  local function outdoor(id)
    return next(data.maps[id].connections or {}) ~= nil
  end
  table.sort(out, function(a, b)
    local oa, ob = outdoor(a), outdoor(b)
    if oa ~= ob then return oa end
    local da, db = data.maps[a], data.maps[b]
    local sa, sb = da.width * da.height, db.width * db.height
    if sa ~= sb then return sa > sb end
    return a < b
  end)
  return out
end

-- The save's map and what is around it, nearest first.
function BuildVeil.nearestIds(rootId)
  local data = gameData()
  if not (data and data.maps and data.maps[rootId]) then return {} end
  -- Doors OUT of a building lead to LAST_MAP ("wherever you came in from"),
  -- not to a map, so walking warps forward from a house never reaches the
  -- town it stands in -- NEAREST from a save in Red's room built the two
  -- floors of the house and not Pallet. The way out is found backwards:
  -- every map with a door INTO this one.
  local into = {}
  for id, def in pairs(data.maps) do
    for _, w in ipairs(def.warps or {}) do
      local d = w.destMap
      if d and d ~= "LAST_MAP" then
        into[d] = into[d] or {}
        into[d][#into[d] + 1] = id
      end
    end
  end
  local out, seen = { rootId }, { [rootId] = true }
  local frontier = { rootId }
  for _ = 1, BuildVeil.NEAR_STEPS do
    local nextF = {}
    for _, id in ipairs(frontier) do
      local def = data.maps[id]
      local function add(dest)
        if dest and dest ~= "LAST_MAP" and data.maps[dest] and not seen[dest]
           and #out < BuildVeil.NEAR_MAX then
          seen[dest] = true
          out[#out + 1] = dest
          nextF[#nextF + 1] = dest
        end
      end
      for _, c in pairs(def.connections or {}) do
        add(type(c) == "table" and c.map)
      end
      for _, w in ipairs(def.warps or {}) do add(w.destMap) end
      for _, from in ipairs(into[id] or {}) do add(from) end
    end
    frontier = nextF
  end
  return out
end

-- Where the player will be: the CONTINUE save's map, or a new game's.
function BuildVeil.saveMap()
  local id = nil
  pcall(function()
    local SaveData = require("src.core.SaveData")
    local save = SaveData.load()
    id = save and save.player and save.player.map
  end)
  local data = gameData()
  if id and data and data.maps[id] then return id end
  return "REDS_HOUSE_2F"
end

-- Of `ids`, the maps not cached and current.
local function todo(ids)
  local out = {}
  for _, id in ipairs(ids) do
    local map = mapFor(id)
    if map and not current(map) then out[#out + 1] = id end
  end
  return out
end

-- Maps that HAD been built and no longer match: a mod update, a flipped
-- geometry row. These are what "N areas changed" counts; maps never built
-- are not changes, they are the badge's job.
function BuildVeil.staleCount()
  local n = 0
  for _, id in ipairs(BuildVeil.allIds()) do
    local map = mapFor(id)
    if map and BuildCache.known(id) and not current(map) then n = n + 1 end
  end
  return n
end

-- ---------------------------------------------------------------- state

local veil = nil        -- the pushed state while the prompt or veil is up

-- Whether the title should ask: the 3D view on and the cache usable, and
-- either nothing ever asked (first boot) or built maps have changed.
function BuildVeil.wanted()
  if not BuildCache.enabled() then return false end
  if not BuildCache.asked() then return true, 0 end
  local stale = BuildVeil.staleCount()
  return stale > 0, stale
end

local Prompt = {}
Prompt.__index = Prompt

-- `root` is the map NEAREST builds around: the save's at the title, the
-- one the player stands on when opened from the TERRARIUM page in play.
function Prompt.new(game, stale, root)
  return setmetatable({
    game = game, stale = stale or 0, root = root, phase = "ask", cursor = 1,
    choices = {
      { key = "all", label = Lang.pick("ALL", "TODOS") },
      { key = "near", label = Lang.pick("NEAREST", "PROXIMOS") },
      { key = "none", label = Lang.pick("NONE", "NENHUM") },
    },
  }, Prompt)
end

function Prompt:start(ids)
  self.queue = todo(ids)
  self.total = #self.queue
  self.done = 0
  -- the time left is weighed by map SIZE, not count: ALL builds the big
  -- outdoor maps first, so a per-map average taken early would promise
  -- the interiors at a route's price
  local data = gameData()
  self.blocks, self.blocksDone = 0, 0
  self.size = {}
  for _, id in ipairs(self.queue) do
    local d = data and data.maps[id]
    local b = d and d.width * d.height or 1
    self.size[id] = b
    self.blocks = self.blocks + b
  end
  self.t0 = clock()
  self.phase = "build"
  if self.total == 0 then self:close() end
end

function Prompt:close()
  BuildCache.markAsked()
  if self.game.stack:top() == self then self.game.stack:pop() end
  veil = nil
end

local function bakeAll(self)
  while self.done < self.total do
    local id = self.queue[self.done + 1]
    self.current = id
    local map = mapFor(id)
    if map then ChunkMesher.bake(map, BuildVeil.masksFor(id)) end
    self.done = self.done + 1
    self.blocksDone = self.blocksDone + (self.size[id] or 1)
    Budget.check()
  end
end

function Prompt:update(dt)
  local input = self.game.input
  if self.phase == "ask" then
    if input:wasPressed("up") then
      self.cursor = (self.cursor - 2) % #self.choices + 1
    elseif input:wasPressed("down") then
      self.cursor = self.cursor % #self.choices + 1
    elseif input:wasPressed("b") then
      self:close()
    elseif input:wasPressed("a") then
      local key = self.choices[self.cursor].key
      if key == "all" then
        self:start(BuildVeil.allIds())
      elseif key == "near" then
        self:start(BuildVeil.nearestIds(self.root or BuildVeil.saveMap()))
      else
        self:close()
      end
    end
    return
  end
  -- building: B stops here, keeping everything already written
  if input:wasPressed("b") then
    self:close()
    return
  end
  if not self.co then self.co = coroutine.create(bakeAll) end
  Budget.begin(self.co, BuildVeil.SLICE)
  local ok, err = coroutine.resume(self.co, self)
  Budget.finish()
  if not ok then
    print("[warn] 3D build stopped: " .. tostring(err))
    self:close()
  elseif coroutine.status(self.co) == "dead" then
    self:close()
  end
end

-- Seconds left, from what this run has done so far (the learned rate
-- until the first map is in).
function Prompt:eta()
  if self.blocksDone > 0 then
    local per = (clock() - self.t0) / self.blocksDone
    return per * (self.blocks - self.blocksDone)
  end
  return nil
end

-- ---------------------------------------------------------------- hooks

-- From main.lua's ui.title_menu.items hook: remember the list the title is
-- about to show, so the update below can tell when that menu is on top.
local titleItems = nil
local checked = false

function BuildVeil.noteTitleItems(items)
  titleItems = items
end

-- From main.lua's update: when the title's CONTINUE / NEW GAME menu is the
-- top screen and the prompt is wanted, push it -- once per boot.
function BuildVeil.update(game, voxelOn)
  if veil or checked or not titleItems then return end
  local top = game and game.stack and game.stack:top()
  if not (top and top.items == titleItems) then return end
  checked = true
  if not voxelOn then return end
  local okW, want, stale = pcall(BuildVeil.wanted)
  if not (okW and want) then return end
  veil = Prompt.new(game, stale)
  game.stack:push(veil)
end

function BuildVeil.active()
  return veil ~= nil
end

-- From the TERRARIUM page's BUILD 3D WORLD row: the same three choices,
-- any time, over whatever screen is up (B or NONE goes back to it). In
-- play, NEAREST builds around the map the player is on.
function BuildVeil.open(game)
  if veil or not (game and game.stack) then return false end
  local ow = game.overworld
  local root = ow and ow.map and ow.map.id or nil
  -- stale 0: asked for, so the panel is the plain question rather than
  -- the boot's "N areas changed"
  veil = Prompt.new(game, 0, root)
  game.stack:push(veil)
  return true
end

-- --------------------------------------------------------------- drawing

local fonts = {}
local function fontFor(px)
  px = math.max(10, math.floor(px))
  local f = fonts[px]
  if not f then
    local ok, nf = pcall(love.graphics.newFont, px)
    f = ok and nf or love.graphics.getFont()
    fonts[px] = f
  end
  return f
end

local function minutes(s)
  if not s then return "..." end
  if s < 60 then return Lang.pick("under a minute", "menos de um minuto") end
  local m = math.floor(s / 60 + 0.5)
  return Lang.pick(("about %d min"):format(m), ("cerca de %d min"):format(m))
end

-- The text of the panel, by phase, so the panel can be MEASURED before it
-- is drawn: a fixed height overflowed as soon as a hint wrapped, and a
-- phone's narrow screen wraps everything.
local function askText()
  local title = veil.stale > 0
    and Lang.pick(("%d areas changed"):format(veil.stale),
                  ("%d areas mudaram"):format(veil.stale))
    or Lang.pick("Build the 3D world?", "Construir o mundo 3D?")
  local body = veil.stale > 0
    and Lang.pick("Rebuild them now so they load instantly?",
                  "Reconstruir agora para carregarem na hora?")
    or Lang.pick("Each area is built once, then loads instantly every "
                 .. "time after. Building now saves the wait later.",
                 "Cada area e construida uma vez e depois carrega na "
                 .. "hora. Construir agora evita a espera depois.")
  local hints = {
    all = Lang.pick("Every area now", "Todas as areas agora"),
    near = Lang.pick("Where your save is, and around it",
                     "Onde o seu save esta, e ao redor"),
    none = Lang.pick("Build each area as you enter it",
                     "Construir cada area ao entrar"),
  }
  return title, body, hints
end

local function wrapH(font, text, width)
  local _, lines = font:getWrap(text, width)
  return math.max(1, #lines) * font:getHeight()
end

function BuildVeil.draw()
  if not veil then return end
  local g = love.graphics
  local w, h = g.getDimensions()
  local cv = g.getCanvas()
  if cv then w, h = cv:getDimensions() end
  -- sized off the SHORTER side: a phone held either way gets the same
  -- proportions it would on a monitor
  local px = math.min(h, w * 0.75) / 30
  local big, small = fontFor(px * 1.15), fontFor(px * 0.8)
  local pad = math.floor(px * 0.9)
  local pw = math.floor(math.min(w - px * 2, px * 22))
  local tw = pw - pad * 2
  local r = px * 0.4
  local rowGap = math.floor(px * 0.35)

  -- measure
  local ph
  local title, body, hints
  if veil.phase == "ask" then
    title, body, hints = askText()
    ph = pad + wrapH(big, title, tw) + px * 0.5 + wrapH(small, body, tw) + px * 0.8
    for _, c in ipairs(veil.choices) do
      ph = ph + big:getHeight() + wrapH(small, hints[c.key], tw - px * 1.4) + rowGap * 2
    end
    ph = ph + pad - rowGap
  else
    ph = pad + big:getHeight() * 1.5 + small:getHeight() * 1.6
         + math.max(3, px * 0.22) + px * 0.7
         + wrapH(small, Lang.pick("B: stop and play (the rest builds as you go)",
                                  "B: parar e jogar (o resto constroi ao jogar)"), tw)
         + pad
  end
  ph = math.floor(ph)
  local x, y = math.floor((w - pw) / 2), math.floor((h - ph) / 2)

  g.push("all")
  g.origin()
  g.setShader()
  -- the page dims behind the panel; the veil is opaque while building
  g.setColor(0, 0, 0, veil.phase == "build" and 0.92 or 0.55)
  g.rectangle("fill", 0, 0, w, h)
  -- the dark glass the battle HUD wears (lib/BattleHudXY.lua glassPane)
  g.setColor(0.055, 0.075, 0.10, 0.94)
  g.rectangle("fill", x, y, pw, ph, r, r)
  g.setColor(0.45, 0.82, 1.0, 0.55)
  g.setLineWidth(1)
  g.rectangle("line", x + 0.5, y + 0.5, pw - 1, ph - 1, r, r)
  local tx, ty = x + pad, y + pad
  if veil.phase == "ask" then
    g.setFont(big)
    g.setColor(0.92, 0.95, 1.0, 1)
    g.printf(title, tx, ty, tw)
    ty = ty + wrapH(big, title, tw) + px * 0.5
    g.setFont(small)
    g.setColor(0.75, 0.80, 0.88, 1)
    g.printf(body, tx, ty, tw)
    ty = ty + wrapH(small, body, tw) + px * 0.8
    for i, c in ipairs(veil.choices) do
      local sel = i == veil.cursor
      local hh = wrapH(small, hints[c.key], tw - px * 1.4)
      local rh = big:getHeight() + hh + rowGap
      if sel then
        g.setColor(0.45, 0.82, 1.0, 0.16)
        g.rectangle("fill", tx - px * 0.35, ty - rowGap * 0.5, tw + px * 0.7,
                    rh, r * 0.6, r * 0.6)
      end
      g.setFont(big)
      if sel then g.setColor(0.45, 0.82, 1.0, 1) else g.setColor(0.92, 0.95, 1.0, 1) end
      g.print(c.label, tx + px * 1.4, ty)
      if sel then g.print(">", tx + px * 0.1, ty) end
      g.setFont(small)
      g.setColor(0.62, 0.68, 0.76, 1)
      g.printf(hints[c.key], tx + px * 1.4, ty + big:getHeight(), tw - px * 1.4)
      ty = ty + rh + rowGap
    end
  else
    g.setFont(big)
    g.setColor(0.92, 0.95, 1.0, 1)
    g.printf(Lang.pick("Building the 3D world", "Construindo o mundo 3D"), tx, ty, pw - pad * 2)
    ty = ty + big:getHeight() * 1.5
    g.setFont(small)
    g.setColor(0.75, 0.80, 0.88, 1)
    g.print(Lang.pick("%d / %d areas  -  %s left", "%d / %d areas  -  %s restantes")
              :format(veil.done, veil.total, minutes(veil:eta())), tx, ty)
    ty = ty + small:getHeight() * 1.6
    local bh = math.max(3, px * 0.22)
    g.setColor(1, 1, 1, 0.15)
    g.rectangle("fill", tx, ty, tw, bh)
    g.setColor(0.45, 0.82, 1.0, 1)
    g.rectangle("fill", tx, ty, tw * (veil.total > 0 and veil.done / veil.total or 0), bh)
    ty = ty + bh + px * 0.7
    g.setColor(0.55, 0.60, 0.68, 1)
    g.printf(Lang.pick("B: stop and play (the rest builds as you go)",
                       "B: parar e jogar (o resto constroi ao jogar)"), tx, ty, tw)
  end
  g.pop()
end

-- For probes: forget this boot's "already checked", so the prompt can be
-- driven more than once in one session.
function BuildVeil.resetForProbe()
  checked = false
  veil = nil
end

return BuildVeil
