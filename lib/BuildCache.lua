-- The 3D BUILD CACHE: a map's finished diorama, kept on disk between
-- sessions so it is built once per install instead of once per session.
--
-- Why. On a phone the first visit to a map costs 7-10 s or more of flat 2D
-- (Android's LuaJIT runs with the JIT off, and the build is the kits plus a
-- per-vertex mesh walk -- PRECACHE-PLAN.md has the desktop numbers), and
-- players read that as the mod not working. The geometry is DETERMINISTIC:
-- nothing in Structures, Buildings, the kits or the mesher reads time,
-- weather, quality or randomness. It depends on the map's data, a few
-- settings rows and this mod's code -- so the finished meshes can be
-- stored, and a later visit, in this session or the next, uploads bytes
-- instead of building.
--
-- What is stored, per map, in three files (any of which can be missing):
--   <id>.body   the body-only terrain chunks (and the water riding on them)
--   <id>.full   the full variant (body + border ring), which also depends
--               on where the neighbours sit (the masks)
--   <id>.aux    grass, flowers, sprite sheets, figures, and the analysis
--               fields the rest of the mod reads after a build
--               (Structures.KEEP: lifts, lamps, chimneys, haunts, tree
--               sites, kit heights)
-- Each is lz4-compressed: a short Lua-literal header (the signature and
-- the layout) followed by the raw float32 vertex bytes (lib/MeshBytes.lua)
-- -- the very bytes a build uploads.
--
-- STALENESS is the whole design, because a stale cache would show the
-- wrong world. Every file carries a SIGNATURE: the cache format, this
-- mod's version, the game version, a hash of the tileset's pixels, a hash
-- of the map's blocks (Cut, card-key doors and regrowth change them at
-- runtime), every settings row that changes geometry, and for `full` the
-- neighbour masks. A file is used only when its signature equals the one
-- computed now; anything else is a miss and the map builds as it always
-- did. Nothing is ever patched in place.
--
-- The index (index.lua) holds every file's signature, size and last use,
-- so a lookup never touches the disk on a miss, and so the total can be
-- held under a cap (oldest out first). mod.cache has no directory
-- listing, which is why the index has to exist at all.
--
-- Aesthetics only: this stores what the renderer builds anyway and never
-- touches the world, the save or input. With the 3D CACHE row OFF nothing
-- here runs and every map builds exactly as before.

local V = ...

local ModSetting = V.require("ModSetting")
local MeshBytes = V.require("MeshBytes")
local Budget = V.require("BuildBudget")
local Lang = V.require("Lang")

local BuildCache = {}

-- Bump on ANY change to what a file holds or how it is laid out; every
-- old file then misses and is rebuilt (and its space reclaimed by the cap).
BuildCache.FORMAT = 1

BuildCache.setting = ModSetting.new("buildcache", "3D CACHE",
                                    { "on", "off" }, { "ON", "OFF" })

-- Total bytes kept on disk. A phone's storage is the tighter of the two
-- and the reason for the smaller number; either way the oldest maps go
-- first, and a map that goes is only a rebuild away.
-- Measured (tests/build_cache_probe.lua): every map in Yellow, both
-- variants and aux, is 288 MB lz4'd (923 MB raw, 40 M vertices). The caps
-- sit above that so ALL keeps the whole world; they exist for the day the
-- world grows, not for today's.
BuildCache.CAP = 1024 * 1048576
BuildCache.CAP_MOBILE = 512 * 1048576

local MAGIC = "TRVC"
local INDEX = "index.lua"

-- ---------------------------------------------------------------- access

local function store()
  local mod = V.mod
  return mod and mod.cache or nil
end

function BuildCache.enabled()
  return BuildCache.setting:get() ~= "off" and store() ~= nil
     and MeshBytes.available()
     and love.data.compress ~= nil
end

-- --------------------------------------------------------- serialization
--
-- A data-only Lua literal: numbers, strings, booleans and tables of them.
-- Anything else (a function, a userdata, a cycle) throws, and the caller
-- treats that as "do not cache this map" rather than writing half of it.
local function ser(v, out, depth)
  local t = type(v)
  if t == "number" then
    if v ~= v or v == math.huge or v == -math.huge then
      error("non-finite number")
    end
    if v == math.floor(v) and v > -1e15 and v < 1e15 then
      out[#out + 1] = string.format("%d", v)
    else
      out[#out + 1] = string.format("%.17g", v)
    end
  elseif t == "string" then
    out[#out + 1] = string.format("%q", v)
  elseif t == "boolean" then
    out[#out + 1] = v and "true" or "false"
  elseif t == "table" then
    if depth > 12 then error("table too deep") end
    out[#out + 1] = "{"
    local n = #v
    for i = 1, n do
      ser(v[i], out, depth + 1)
      out[#out + 1] = ","
    end
    for k, x in pairs(v) do
      local kt = type(k)
      if not (kt == "number" and k >= 1 and k <= n and k == math.floor(k)) then
        out[#out + 1] = "["
        ser(k, out, depth + 1)
        out[#out + 1] = "]="
        ser(x, out, depth + 1)
        out[#out + 1] = ","
      end
    end
    out[#out + 1] = "}"
  elseif t == "nil" then
    out[#out + 1] = "nil"
  else
    error("cannot serialize a " .. t)
  end
end

local function serialize(v)
  local out = {}
  ser(v, out, 0)
  return table.concat(out)
end

-- The reverse, in an empty environment: a cache file can only ever
-- produce data, whatever is in it.
local function deserialize(s)
  local chunk = loadstring and loadstring("return " .. s) or load("return " .. s)
  if not chunk then return nil end
  if setfenv then setfenv(chunk, {}) end
  local ok, v = pcall(chunk)
  if ok then return v end
  return nil
end

-- ------------------------------------------------------------ signatures

local function hex(s)
  return (s:gsub(".", function(c) return string.format("%02x", c:byte()) end))
end

local function md5(s)
  return hex(love.data.hash("md5", s))
end

-- A tileset's pixels, once per session per image: the geometry is read
-- off them (Structures classifies every tile by its art), so an asset
-- pack that repaints a tileset must miss.
local tilesetSig = {}
local function tilesetHash(tileset)
  local path = tileset and tileset.image
  if not path then return "none" end
  local h = tilesetSig[path]
  if not h then
    local ok, data = pcall(function()
      local Assets = require("src.render.Assets")
      return Assets.imageData(path)
    end)
    h = (ok and data) and md5(data:getString()) or ("path:" .. path)
    tilesetSig[path] = h
  end
  return h
end

local function blocksHash(def)
  local b = def and def.blocks
  if type(b) ~= "table" then return "none" end
  return md5(table.concat(b, ","))
end

local function try(f, ...)
  local ok, v = pcall(f, ...)
  if ok then return v end
  return nil
end

-- Every settings row whose flip calls ChunkMesher.invalidate() (the rows'
-- own remesh functions), plus the engine's void fill (main.lua voidFill).
-- A new geometry row MUST be added here or the cache will serve the old
-- shape after a flip -- the same rule as adding its remesh.
local function settingsSig()
  local parts = {}
  local function row(name)
    local v = try(function()
      return V.require(name).setting:get()
    end)
    parts[#parts + 1] = tostring(v)
  end
  row("TowerKit"); row("LedgeKit"); row("Crypt"); row("Trees3D")
  -- TOWER LIGHT: whether the crypt's walls draw their own courses is
  -- built into the mesh (CryptKit.onFxChanged remeshes)
  parts[#parts + 1] = tostring(try(function()
    return V.require("Crypt").fxSetting:get()
  end))
  parts[#parts + 1] = tostring(try(function() return V.require("Trees3D").available() end))
  parts[#parts + 1] = tostring(try(function() return V.require("Grass3D").wantsMesh() end))
  parts[#parts + 1] = tostring(try(function() return V.require("Grass3D").available() end))
  parts[#parts + 1] = tostring(try(function()
    return require("src.render.TileRenderer").voidFill
  end))
  return table.concat(parts, ",")
end

local function gameVersion()
  return tostring(try(function() return require("src.core.GameVersion").get() end))
end

local function modVersion()
  local mod = V.mod
  return tostring(mod and mod.version or "?")
end

local function masksSig(masks)
  if not masks or #masks == 0 then return "-" end
  local parts = {}
  for i, m in ipairs(masks) do
    parts[i] = table.concat(m, ":")
  end
  -- sorted: the engine's neighbour walk iterates def.connections with
  -- pairs(), so the same neighbours can arrive in a different order from
  -- one run to the next, and the order says nothing about the geometry
  table.sort(parts)
  return table.concat(parts, ";")
end

-- The signature a file for `map` / `part` must carry to be used now.
function BuildCache.signature(map, part, masks)
  local base = table.concat({
    "f" .. BuildCache.FORMAT, modVersion(), gameVersion(),
    tilesetHash(map.tileset), blocksHash(map.def), settingsSig(),
  }, "|")
  if part == "full" then base = base .. "|" .. masksSig(masks) end
  return base
end

-- ------------------------------------------------------------------ index

local index = nil          -- key -> { sig, bytes, used }
local serial = 0
-- How long THIS device takes to build a map, in ms per map block, learned
-- from every build the badge watches (BuildCache.noteBuild). It is what the
-- badge's percentage is measured against, so it has to be this device's
-- own number: a desktop builds a block in ~15 ms, a phone without the JIT
-- several times that. Kept in the index so a second session starts with it.
local DEFAULT_RATE = 40
local rate = nil
-- Whether the title's build prompt (lib/BuildVeil.lua) has been answered on
-- this install, whatever the answer: NONE must not mean "ask every boot".
local asked = false

local function loadIndex()
  if index then return index end
  index = {}
  local s = store()
  if s then
    local okR, body = pcall(s.read, s, INDEX)
    local t = okR and type(body) == "string" and deserialize(body)
    if type(t) == "table" and t.format == BuildCache.FORMAT
       and type(t.entries) == "table" then
      index = t.entries
      serial = tonumber(t.serial) or 0
      rate = tonumber(t.rate)
      asked = t.asked == true
    end
  end
  return index
end

local function saveIndex()
  local s = store()
  if not (s and index) then return end
  local ok, body = pcall(serialize, { format = BuildCache.FORMAT,
                                      serial = serial, entries = index,
                                      rate = rate, asked = asked })
  if ok then pcall(s.write, s, INDEX, body) end
end

local function keyOf(id, part)
  return id .. "." .. part
end

local function pathOf(key)
  return "maps/" .. key:gsub("[^%w%._-]", "_") .. ".bin"
end

-- Whether a usable file exists for this map/part right now (index only;
-- no disk access).
function BuildCache.has(map, part, masks)
  if not BuildCache.enabled() then return false end
  local e = loadIndex()[keyOf(map.id, part)]
  return e ~= nil and e.sig == BuildCache.signature(map, part, masks)
end

-- Whether the index exists at all -- "no index" is a first boot, which is
-- what the title's build prompt keys on.
function BuildCache.empty()
  return next(loadIndex()) == nil
end

-- Whether any part of `mapId` was ever cached (current or not): the title
-- counts a changed map only if it had been built before.
function BuildCache.known(mapId)
  local idx = loadIndex()
  return idx[keyOf(mapId, "body")] ~= nil or idx[keyOf(mapId, "aux")] ~= nil
      or idx[keyOf(mapId, "full")] ~= nil
end

function BuildCache.asked()
  loadIndex()
  return asked
end

function BuildCache.markAsked()
  loadIndex()
  if asked then return end
  asked = true
  saveIndex()
end

function BuildCache.totalBytes()
  local n = 0
  for _, e in pairs(loadIndex()) do n = n + (e.bytes or 0) end
  return n
end

local function cap()
  local okD, Device = pcall(V.require, "Device")
  local mobile = okD and Device and Device.mobile and Device.mobile()
  return mobile and BuildCache.CAP_MOBILE or BuildCache.CAP
end

-- Oldest out until the total fits.
local function enforceCap()
  local idx = loadIndex()
  local total = BuildCache.totalBytes()
  local limit = cap()
  if total <= limit then return end
  local keys = {}
  for k in pairs(idx) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return (idx[a].used or 0) < (idx[b].used or 0) end)
  local s = store()
  for _, k in ipairs(keys) do
    if total <= limit then break end
    total = total - (idx[k].bytes or 0)
    idx[k] = nil
    if s then pcall(s.delete, s, pathOf(k)) end
  end
end

-- ---------------------------------------------------------------- files
--
-- A file: MAGIC, FORMAT, header length, the header literal, then the blob
-- bytes back to back, all lz4'd. The header lists each blob's lengths, so
-- a truncated or tampered file fails the length check and is a miss.

-- Gather a mesh's record (vertex bytes and, for Grass3D, indices) into
-- `blobs`, returning its index there -- or error if the mesh was not made
-- through MeshBytes (then the map is simply not cached).
local function blobOf(mesh, blobs)
  local rec = MeshBytes.of[mesh]
  if not rec then error("mesh has no recorded bytes") end
  blobs[#blobs + 1] = rec
  return #blobs
end

local function groupLayout(g, blobs)
  if type(g) ~= "table" then return false end
  local out = { chunks = {} }
  for i, ch in ipairs(g.chunks or {}) do
    out.chunks[i] = { ch.x0, ch.z0, ch.x1, ch.z1, ch.ymax, blobOf(ch.mesh, blobs) }
  end
  if g.water then out.water = groupLayout(g.water, blobs) end
  return out
end

-- The layout of one part from a ChunkMesher cache entry `c`.
local function layoutOf(c, part, mapId, blobs)
  if part == "aux" then
    local L = {}
    if type(c.grass) == "userdata" then
      -- a textured grass mesh is Grass3D's tufts (the slab path draws off
      -- the tileset atlas and carries no texture of its own)
      local okT, tex = pcall(c.grass.getTexture, c.grass)
      L.grass = { b = blobOf(c.grass, blobs),
                  tex = (okT and tex) and "grass3d" or nil }
    end
    if type(c.flowers) == "userdata" then
      L.flowers = { b = blobOf(c.flowers, blobs) }
    end
    L.sprites = {}
    for i, g in ipairs(type(c.sprites) == "table" and c.sprites or {}) do
      if g.mesh then
        L.sprites[#L.sprites + 1] = { b = blobOf(g.mesh, blobs), path = g.path, box = g.box }
      end
    end
    L.figures = {}
    for _, f in ipairs(type(c.figures) == "table" and c.figures or {}) do
      L.figures[#L.figures + 1] = { b = blobOf(f.mesh, blobs), wx = f.wx, wz = f.wz, y = f.y }
    end
    L.keep = V.require("Structures").kept(mapId)
    return L
  end
  return groupLayout(c[part], blobs) or false
end

local function encode(sig, layout, blobs)
  local meta = { sig = sig, layout = layout, blobs = {} }
  local payload = {}
  for i, r in ipairs(blobs) do
    meta.blobs[i] = { n = r.n, vl = #r.v, il = r.i and #r.i or 0,
                      iw = r.iw, ni = r.ni }
    payload[#payload + 1] = r.v
    if r.i then payload[#payload + 1] = r.i end
  end
  local head = serialize(meta)
  local raw = MAGIC .. BuildCache.FORMAT .. "\n" .. #head .. "\n" .. head
              .. table.concat(payload)
  return love.data.compress("string", "lz4", raw)
end

local function decode(bytes, wantSig)
  local okD, raw = pcall(love.data.decompress, "string", "lz4", bytes)
  if not okD or type(raw) ~= "string" then return nil, "decompress" end
  local magic = MAGIC .. BuildCache.FORMAT .. "\n"
  if raw:sub(1, #magic) ~= magic then return nil, "magic" end
  local nl = raw:find("\n", #magic + 1, true)
  local hl = nl and tonumber(raw:sub(#magic + 1, nl - 1))
  if not hl then return nil, "header" end
  local meta = deserialize(raw:sub(nl + 1, nl + hl))
  if type(meta) ~= "table" or meta.sig ~= wantSig
     or type(meta.blobs) ~= "table" then
    return nil, "signature"
  end
  local pos = nl + hl + 1
  local blobs = {}
  for i, b in ipairs(meta.blobs) do
    local vl, il = tonumber(b.vl) or -1, tonumber(b.il) or 0
    if vl < 0 or pos + vl + il - 1 > #raw then return nil, "truncated" end
    local r = { n = b.n, v = raw:sub(pos, pos + vl - 1) }
    pos = pos + vl
    if il > 0 then
      r.i, r.iw, r.ni = raw:sub(pos, pos + il - 1), b.iw, b.ni
      pos = pos + il
    end
    if #r.v ~= r.n * MeshBytes.PER * 4 then return nil, "length" end
    blobs[i] = r
  end
  if pos ~= #raw + 1 then return nil, "trailing" end
  return meta.layout, blobs
end

-- Write one part of a freshly built map. `c` is the ChunkMesher cache
-- entry holding its meshes. Any failure means the part is not cached --
-- never a broken file: the index is only updated after the file is down.
function BuildCache.store(map, part, masks, c)
  if not BuildCache.enabled() then return false end
  local s = store()
  local blobs = {}
  local okL, layout = pcall(layoutOf, c, part, map.id, blobs)
  if not okL then return false end
  local sig = BuildCache.signature(map, part, masks)
  local okE, bytes = pcall(encode, sig, layout, blobs)
  if not okE or type(bytes) ~= "string" then return false end
  local key = keyOf(map.id, part)
  local okW, res = pcall(s.write, s, pathOf(key), bytes)
  if not okW or not res then return false end
  serial = serial + 1
  loadIndex()[key] = { sig = sig, bytes = #bytes, used = serial }
  enforceCap()
  saveIndex()
  return true
end

-- Read and check one part: its layout and blob records, or nil (a miss).
-- A file that fails any check is dropped from the index, so it is built
-- (and rewritten) instead of failing again next time.
function BuildCache.load(map, part, masks)
  if not BuildCache.has(map, part, masks) then return nil end
  local s = store()
  local key = keyOf(map.id, part)
  local okR, bytes = pcall(s.read, s, pathOf(key))
  local layout, blobs
  if okR and type(bytes) == "string" then
    layout, blobs = decode(bytes, BuildCache.signature(map, part, masks))
  end
  if layout == nil then
    loadIndex()[key] = nil
    pcall(s.delete, s, pathOf(key))
    saveIndex()
    return nil
  end
  serial = serial + 1
  loadIndex()[key].used = serial
  BuildCache.dirty = true
  return layout, blobs
end

-- --------------------------------------------------------------- restore
--
-- Upload a decoded part. Runs inside a mesher job's coroutine, so the
-- uploads slice exactly like a build's (MeshBytes.upload checks the
-- budget between 65k-vertex pieces).

local function uploadGroup(L, blobs, Group)
  if type(L) ~= "table" then return nil end
  local g = setmetatable({ chunks = {} }, Group)
  for _, ch in ipairs(L.chunks or {}) do
    local mesh = MeshBytes.upload(blobs[ch[6]], false)
    if not mesh then
      g:release()
      error("chunk upload failed")
    end
    g.chunks[#g.chunks + 1] = { mesh = mesh, x0 = ch[1], z0 = ch[2],
                                x1 = ch[3], z1 = ch[4], ymax = ch[5] }
    Budget.check()
  end
  if L.water then g.water = uploadGroup(L.water, blobs, Group) end
  return g
end

function BuildCache.restoreGroup(layout, blobs, Group)
  return uploadGroup(layout, blobs, Group)
end

-- Aux: returns grass, flowers, sprites, figures (ChunkMesher's slot
-- shapes) and the KEEP table for Structures.seed.
function BuildCache.restoreAux(layout, blobs)
  local grass, flowers = false, false
  if layout.grass then
    grass = MeshBytes.upload(blobs[layout.grass.b], false) or false
    if grass and layout.grass.tex == "grass3d" then
      local okG, G = pcall(V.require, "Grass3D")
      local tex = okG and G and G.texture and G.texture()
      if tex then pcall(grass.setTexture, grass, tex) end
    end
  end
  if layout.flowers then
    flowers = MeshBytes.upload(blobs[layout.flowers.b], false) or false
  end
  local okB, Buildings = pcall(V.require, "Buildings")
  local sprites = {}
  for _, s in ipairs(layout.sprites or {}) do
    local tex = nil
    if s.path and okB and Buildings and Buildings.spriteImage then
      tex = Buildings.spriteImage(s.path)
    end
    sprites[#sprites + 1] = { mesh = MeshBytes.upload(blobs[s.b], false), tex = tex,
                              path = s.path, box = s.box }
    Budget.check()
  end
  local figures = {}
  for _, f in ipairs(layout.figures or {}) do
    local mesh = MeshBytes.upload(blobs[f.b], false)
    if mesh then
      figures[#figures + 1] = { mesh = mesh, wx = f.wx, wz = f.wz, y = f.y }
    end
  end
  return grass, flowers, sprites, figures, layout.keep
end

-- ------------------------------------------------------------ estimates

local function blocksOf(map)
  local def = map and map.def
  return math.max(1, (def and def.width or 10) * (def and def.height or 9))
end

-- Seconds a cold build of `map` should take on this device.
function BuildCache.estimate(map)
  loadIndex()
  return math.max(1.0, blocksOf(map) * (rate or DEFAULT_RATE) / 1000)
end

-- A build of `map` took `seconds` (arrival to first 3D frame): fold it in.
function BuildCache.noteBuild(map, seconds)
  if not (seconds and seconds > 0.2) then return end
  loadIndex()
  local r = seconds * 1000 / blocksOf(map)
  rate = rate and (rate * 0.7 + r * 0.3) or r
  saveIndex()
end

-- ------------------------------------------------------------- managing

-- Drop every file (the CLEAR 3D CACHE action, or a format change).
function BuildCache.clear()
  local s = store()
  for k in pairs(loadIndex()) do
    if s then pcall(s.delete, s, pathOf(k)) end
  end
  index = {}
  serial = 0
  asked = false
  if s then pcall(s.delete, s, INDEX) end
end

-- Forget the session memo of tileset pixels (an asset reload repaints
-- them; the signature has to see the new art).
function BuildCache.forgetTilesets()
  tilesetSig = {}
end

pcall(function()
  require("src.render.Assets").register(function() BuildCache.forgetTilesets() end)
end)

-- How many of `ids` hold a usable file for every part a visit needs
-- (body + aux, and full with the masks given by `masksFor(id)`).
function BuildCache.missing(maps, masksFor)
  local n = 0
  for _, map in ipairs(maps) do
    if not (BuildCache.has(map, "body") and BuildCache.has(map, "aux")
            and BuildCache.has(map, "full", masksFor and masksFor(map.id))) then
      n = n + 1
    end
  end
  return n
end

function BuildCache.row() return BuildCache.setting:row() end

function BuildCache.help()
  return Lang.pick(
    "Keeps the built 3D world on disk, so a map you have seen loads in "
    .. "about a second next time instead of building again. OFF builds "
    .. "every map each session, as before.",
    "Guarda o mundo 3D construido no disco, para que um mapa ja visto "
    .. "carregue em cerca de um segundo da proxima vez. OFF constroi cada "
    .. "mapa a cada sessao, como antes.")
end

return BuildCache
