-- Probe: what a persistent 3D BUILD CACHE would hold, and what it would
-- save -- the Phase 0 numbers the build-cache design is decided from.
--
-- For EVERY map in the game data, built off-screen from a throwaway
-- Map.new (the same path the title-screen build-all would take):
--   build ms     Structures.forMap + body + full + aux, synchronously
--   vertices     every mesh the mesher caches for the map (terrain chunks,
--                water, grass, flowers, sprite sheets, figures)
--   raw bytes    vertices x 24 (FORMAT: 6 float32) -- what a cache file
--                would carry before compression; indices are not stored
--                (a quad fan regenerates them) except for Grass3D tufts
-- Then, on a sample of the heaviest maps, the real encode/decode path:
-- read the vertices back, love.data.pack them, lz4 them, and time the
-- restore (decompress -> ByteData -> newMesh + setVertices), so the ratio
-- and the per-vertex costs are measured rather than guessed.
--
--   <DS_PROBE_DIR>/build_cache.log
--
-- DS_BC_MAPS=ID,ID,...  only those maps
-- DS_BC_JITOFF=1        jit.off() for the whole run (a phone proxy: Android
--                       LuaJIT runs without the JIT)
--
--   python tools/profiler/run.py build_cache_probe [--env DS_BC_JITOFF=1]
return function(game)
  local src = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
  local TOOLS = (src:match("^(.*)/tests/[^/]*$") or ".") .. "/tools/profiler/"
  local Harness = dofile(TOOLS .. "Harness.lua")
  local Scenes = dofile(TOOLS .. "Scenes.lua")

  local OUT = os.getenv("DS_PROBE_DIR") or "."
  local H = assert(Harness.attach(game, { out = OUT, name = "build_cache" }))
  local log, V = H.log, H.V

  if not Scenes.boot(game, log) then H:finish(); love.event.quit(); return end
  Scenes.pin(V, log)
  Scenes.wait(120)

  local jitoff = os.getenv("DS_BC_JITOFF") == "1"
  if jitoff and jit then jit.off(); jit.flush() end
  log("jit:", jit and (jit.status() and "on" or "off") or "none")

  local ChunkMesher = V.require("ChunkMesher")
  local Structures = V.require("Structures")
  local Map = require("src.world.Map")
  local data = (Game and Game.data) or game.data
  local clock = love.timer.getTime

  local ids = {}
  local only = os.getenv("DS_BC_MAPS")
  if only and only ~= "" then
    for id in only:gmatch("[^,%s]+") do ids[#ids + 1] = id end
  else
    for id in pairs(data.maps) do ids[#ids + 1] = id end
    table.sort(ids)
  end
  log("maps:", #ids)

  -- every mesh the mesher holds for a map, as { mesh, label }
  local function meshesOf(map)
    local out = {}
    local function group(g, label)
      if type(g) ~= "table" then return end
      for _, ch in ipairs(g.chunks or {}) do out[#out + 1] = { ch.mesh, label } end
      if g.water then group(g.water, label .. ".water") end
    end
    group(ChunkMesher.peek(map, true), "body")
    group(ChunkMesher.peek(map, false), "full")
    local gr = ChunkMesher.grass(map)
    if gr then out[#out + 1] = { gr, "grass" } end
    local fl = ChunkMesher.flowers(map)
    if fl then out[#out + 1] = { fl, "flowers" } end
    for _, g in ipairs(ChunkMesher.spriteGroups(map) or {}) do
      if g.mesh then out[#out + 1] = { g.mesh, "sprites" } end
    end
    for _, f in ipairs(ChunkMesher.figures(map) or {}) do
      out[#out + 1] = { f.mesh, "figures" }
    end
    return out
  end

  -- ------------------------------------------------------- the codec pass
  -- Read a sample of vertices back out of real meshes, pack them the way
  -- the cache would, compress, and time the restore.
  local PER = 6
  local fmtK = 64
  local fmt = "<" .. string.rep("f", PER * fmtK)
  local packT, packV, rawB, lzB, decT, upT, upV = 0, 0, 0, 0, 0, 0, 0
  local sampled = 0
  local function codec(map)
    sampled = sampled + 1
    for _, m in ipairs(meshesOf(map)) do
      local mesh = m[1]
      local nv = math.min(mesh:getVertexCount(), 40000)
      nv = nv - nv % fmtK
      if nv > 0 then
        -- read back (not timed: the real cache never reads a mesh back)
        local flat = {}
        for v = 1, nv do
          local a, b, c, d, e, f = mesh:getVertex(v)
          local k = (v - 1) * PER
          flat[k + 1], flat[k + 2], flat[k + 3] = a, b, c
          flat[k + 4], flat[k + 5], flat[k + 6] = d, e, f
        end
        local t0 = clock()
        local parts = {}
        for v = 0, nv - fmtK, fmtK do
          local k = v * PER
          parts[#parts + 1] = love.data.pack("string", fmt,
                                             unpack(flat, k + 1, k + PER * fmtK))
        end
        local s = table.concat(parts)
        packT = packT + (clock() - t0); packV = packV + nv
        rawB = rawB + #s
        local lz = love.data.compress("string", "lz4", s)
        lzB = lzB + #lz
        local t1 = clock()
        local back = love.data.decompress("string", "lz4", lz)
        local bd = love.data.newByteData(back)
        decT = decT + (clock() - t1)
        local t2 = clock()
        local nm = love.graphics.newMesh(V.require("Voxel3D").FORMAT, nv,
                                         "triangles", "static")
        nm:setVertices(bd, 1)
        upT = upT + (clock() - t2); upV = upV + nv
        nm:release(); bd:release()
      end
    end
  end
  local rows, totalV, totalMs, failed = {}, 0, 0, 0
  for n, id in ipairs(ids) do
    local def = data.maps[id]
    local ts = def and data.tilesets[def.tileset]
    if ts then
      local ok, map = pcall(Map.new, def, ts)
      if ok then
        collectgarbage("collect")
        local t0 = clock()
        local okS = pcall(Structures.forMap, map)
        local t1 = clock()
        local okB = pcall(ChunkMesher.get, map, true)
        local okF = pcall(ChunkMesher.get, map, false)
        local t2 = clock()
        local verts, parts = 0, 0
        for _, m in ipairs(meshesOf(map)) do
          verts = verts + m[1]:getVertexCount(); parts = parts + 1
        end
        local ms = (t2 - t0) * 1000
        rows[#rows + 1] = { id = id, ms = ms, sms = (t1 - t0) * 1000,
                            verts = verts, parts = parts,
                            ok = okS and okB and okF }
        if not (okS and okB and okF) then failed = failed + 1 end
        totalV, totalMs = totalV + verts, totalMs + ms
        -- the codec sample: the first few heavy maps, then released like
        -- every other map so GPU memory stays at one map's worth
        if verts > 150000 and sampled < 6 then codec(map) end
        pcall(ChunkMesher.invalidate, id)
        if n % 20 == 0 then
          log(("  %d/%d  %.0f s so far"):format(n, #ids, totalMs / 1000))
        end
        coroutine.yield()
      end
    end
  end

  table.sort(rows, function(a, b) return a.verts > b.verts end)
  log("")
  log("heaviest maps (vertices, raw MB at 24 B/vertex, build ms, of which Structures):")
  for i = 1, math.min(40, #rows) do
    local r = rows[i]
    log(("  %-28s %8d v  %6.1f MB  %7.0f ms  (%6.0f)  %d meshes%s"):format(
      r.id, r.verts, r.verts * 24 / 1048576, r.ms, r.sms, r.parts,
      r.ok and "" or "  FAILED"))
  end
  local empty = 0
  for _, r in ipairs(rows) do if r.verts == 0 then empty = empty + 1 end end
  log("")
  log(("TOTAL %d maps (%d with no 3D, %d failed): %d vertices, %.0f MB raw, build %.0f s")
      :format(#rows, empty, failed, totalV, totalV * 24 / 1048576, totalMs / 1000))

  log("")
  if packV > 0 then
    log(("codec sample: %d vertices from %d heavy maps"):format(packV, sampled))
    log(("  pack  %.2f us/vertex  (%.0f ms per million)"):format(packT / packV * 1e6, packT / packV * 1e9))
    log(("  lz4   %.1f%% of raw"):format(lzB / rawB * 100))
    log(("  restore: decompress+ByteData %.2f us/vertex, upload %.2f us/vertex"):format(
      decT / packV * 1e6, upT / upV * 1e6))
    local ratio = lzB / rawB
    log(("PROJECTED all-maps cache: %.0f MB lz4 (%.0f MB raw)"):format(
      totalV * 24 * ratio / 1048576, totalV * 24 / 1048576))
    log(("PROJECTED all-maps encode %.1f s, restore %.1f s"):format(
      totalV * packT / packV, totalV * (decT / packV + upT / upV)))
  end

  H:finish()
  love.event.quit()
end
