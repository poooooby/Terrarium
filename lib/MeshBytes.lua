-- Meshes as BYTES: build a voxel mesh from a packed float32 string, and
-- remember that string so lib/BuildCache.lua can write it to disk.
--
-- Why this exists. The engine's sandbox denies `ffi`, so on every real
-- install ChunkMesher took its table path: one six-number Lua table PER
-- VERTEX (0.4-0.8 million on a route), handed to love.graphics.newMesh,
-- which walks them one by one. On a phone, where LuaJIT runs with the JIT
-- off, that is a large share of the 7-10 s players stare at flat 2D for.
--
-- `love.data` is NOT blocked (gen1recomp src/mods/Sandbox.lua), and LOVE 11
-- takes a Mesh's vertices and its vertex map straight from a Data object
-- (Mesh:setVertices(data, start), Mesh:setVertexMap(data, "uint16"|"uint32")).
-- So a sink can keep a FLAT number array -- no per-vertex table -- and pack
-- it into one string with love.data.pack, a C call per 64 vertices. That
-- string is exactly what a cache file needs, so building and caching share
-- one path: the bytes a build uploads are the bytes the cache stores, and a
-- restore is that same upload without the build in front of it.
--
-- Indices are not stored for quad meshes. Every quad the meshers emit is
-- the same fan (0,1,2)(0,2,3) off its own four corners (Voxel3D.pushQuad),
-- so a map's index buffer is a pure function of its quad count and comes
-- from one shared string, grown on demand. Grass3D's tufts are the one
-- non-quad mesh; they carry their own packed indices.

local V = ...

local Budget = V.require("BuildBudget")
local Voxel3D = V.require("Voxel3D")

local MeshBytes = {}

-- Floats per vertex: VertexPosition 3, VertexTexCoord 2, VertexShade 1
-- (Voxel3D.FORMAT). A change to FORMAT is a change to every cache file,
-- which is why BuildCache folds this into its signature.
MeshBytes.PER = 6
local PER = MeshBytes.PER

-- Vertices packed per love.data.pack call. 64 x 6 = 384 arguments through
-- unpack(), comfortably under LuaJIT's limit, and few enough calls that the
-- per-call overhead disappears into the copying.
local BLOCK = 64

-- When true, every mesh made here keeps its bytes in `MeshBytes.of` until
-- BuildCache has written them (BuildCache turns it on with the 3D CACHE
-- row). Off, the strings are garbage the moment the upload is done.
MeshBytes.recording = false

-- mesh -> { v = vertex bytes, n = vertex count [, i = index bytes,
-- iw = "uint16"|"uint32", ni = index count] }. Weak keys: a released,
-- forgotten mesh takes its record with it.
MeshBytes.of = setmetatable({}, { __mode = "k" })

local fmtCache = {}
local function fmtFor(floats)
  local f = fmtCache[floats]
  if not f then
    f = "<" .. string.rep("f", floats)
    fmtCache[floats] = f
  end
  return f
end

local pack = love and love.data and love.data.pack
local unpack = unpack or table.unpack

-- Whether this build of LOVE can do any of it. Headless (the offline
-- suite) it cannot, and the callers keep their table paths.
function MeshBytes.available()
  return pack ~= nil and love.data.newByteData ~= nil
     and love.graphics ~= nil and love.graphics.newMesh ~= nil
end

-- A flat float array (PER per vertex) -> one little-endian float32 string.
function MeshBytes.packFlat(flat, nVerts)
  local parts = {}
  local total = nVerts * PER
  local step = BLOCK * PER
  local i = 1
  while i <= total do
    local last = i + step - 1
    if last > total then last = total end
    parts[#parts + 1] = pack("string", fmtFor(last - i + 1), unpack(flat, i, last))
    i = last + 1
    Budget.tick()
  end
  return table.concat(parts)
end

-- The historical table-of-tables vertex list ({x,y,z,u,v,shade} each) ->
-- the same string, through a reused flat block.
function MeshBytes.packTables(verts)
  local parts, block = {}, {}
  local n = #verts
  local v = 1
  while v <= n do
    local last = v + BLOCK - 1
    if last > n then last = n end
    local k = 0
    for j = v, last do
      local t = verts[j]
      block[k + 1], block[k + 2], block[k + 3] = t[1], t[2], t[3]
      block[k + 4], block[k + 5], block[k + 6] = t[4], t[5], t[6]
      k = k + PER
    end
    parts[#parts + 1] = pack("string", fmtFor(k), unpack(block, 1, k))
    v = last + 1
    Budget.tick()
  end
  return table.concat(parts)
end

-- LOVE's own rule for which width a vertex map gets
-- (vertex::getIndexDataTypeFromMax): uint16 while every index fits.
local function widthFor(nVerts)
  return nVerts <= 65535 and "uint16" or "uint32"
end

-- The shared quad-fan index strings, one per width, grown by doubling and
-- sliced with sub(). Built once per session at most a few times.
local fan = { uint16 = { s = "", q = 0 }, uint32 = { s = "", q = 0 } }

local function fanIndex(nQuads, width)
  local f = fan[width]
  if f.q < nQuads then
    local want = math.max(nQuads, f.q * 2, 1024)
    -- a uint16 fan stops at the last quad whose corners still fit in 16
    -- bits (16383 quads = 65532 vertices; widthFor sends anything bigger
    -- to uint32). Doubling past it packed 65536 into an "H" and threw.
    if width == "uint16" then want = math.min(want, 16383) end
    local code = width == "uint16" and "H" or "I4"
    local fmt = "<" .. string.rep(code, 6 * 64)
    local parts = { f.s }
    local q = f.q
    local block = {}
    while q < want do
      local count = math.min(64, want - q)
      local k = 0
      for j = q, q + count - 1 do
        local b = j * 4
        block[k + 1], block[k + 2], block[k + 3] = b, b + 1, b + 2
        block[k + 4], block[k + 5], block[k + 6] = b, b + 2, b + 3
        k = k + 6
      end
      local fm = count == 64 and fmt or ("<" .. string.rep(code, k))
      parts[#parts + 1] = pack("string", fm, unpack(block, 1, k))
      q = q + count
    end
    f.s, f.q = table.concat(parts), want
  end
  local bytes = nQuads * 6 * (width == "uint16" and 2 or 4)
  return f.s:sub(1, bytes)
end

-- A 1-based Lua index list -> 0-based packed indices of the right width.
function MeshBytes.packIndices(indices, nVerts)
  local width = widthFor(nVerts)
  local code = width == "uint16" and "H" or "I4"
  local parts, block = {}, {}
  local n = #indices
  local i = 1
  while i <= n do
    local last = math.min(i + 383, n)
    local k = 0
    for j = i, last do
      k = k + 1
      block[k] = indices[j] - 1
    end
    parts[#parts + 1] = pack("string", "<" .. string.rep(code, k), unpack(block, 1, k))
    i = last + 1
    Budget.tick()
  end
  return table.concat(parts), width, n
end

-- Vertices per upload slice: a route's chunk can be megabytes, and one
-- atomic setVertices was the frame spike the FFI sink already sliced away.
local SLICE = 65536

-- The upload. `rec` is a record in the shape MeshBytes.of holds; a quad
-- mesh (no `i`) gets the shared fan. Returns the Mesh or nil. `keep`
-- false skips the recording even while it is on: a mesh restored FROM
-- the cache has nothing to write back.
function MeshBytes.upload(rec, keep)
  local n = rec.n
  if not n or n == 0 then return nil end
  local ok, mesh = pcall(function()
    local m = love.graphics.newMesh(Voxel3D.FORMAT, n, "triangles", "static")
    local stride = PER * 4
    local i = 0
    while i < n do
      local count = math.min(SLICE, n - i)
      local data = love.data.newByteData(rec.v:sub(i * stride + 1, (i + count) * stride))
      m:setVertices(data, i + 1)
      data:release()
      i = i + count
      Budget.check()
    end
    local istr, width, ni = rec.i, rec.iw, rec.ni
    if not istr then
      width = widthFor(n)
      local quads = n / 4
      istr, ni = fanIndex(quads, width), quads * 6
    end
    local data = love.data.newByteData(istr)
    m:setVertexMap(data, width, ni)
    data:release()
    return m
  end)
  if not ok then
    print("[warn] MeshBytes upload failed: " .. tostring(mesh))
    return nil
  end
  if MeshBytes.recording and keep ~= false then MeshBytes.of[mesh] = rec end
  return mesh
end

-- A quad mesh from a flat float array (4 vertices per quad, fan order).
function MeshBytes.fromFlat(flat, nQuads)
  if nQuads == 0 then return nil end
  local n = nQuads * 4
  return MeshBytes.upload({ v = MeshBytes.packFlat(flat, n), n = n })
end

-- A mesh from the historical table lists: `indices` nil for a quad mesh,
-- else a 1-based triangle list (Grass3D's tufts).
function MeshBytes.fromTables(verts, indices)
  local n = #verts
  if n == 0 then return nil end
  local rec = { v = MeshBytes.packTables(verts), n = n }
  if indices then
    rec.i, rec.iw, rec.ni = MeshBytes.packIndices(indices, n)
  end
  return MeshBytes.upload(rec)
end

-- Drop a mesh's record once its bytes are on disk (or will never be).
function MeshBytes.forget(mesh)
  if mesh then MeshBytes.of[mesh] = nil end
end

return MeshBytes
