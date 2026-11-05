-- Voxel world mode: characters as flat forward-facing sprite billboards.
--
-- Every character -- the player, NPCs, the ghosts standing on a neighbour
-- map -- is its CURRENT 2D sprite frame on a single flat quad. The sheets
-- carry real alpha and the shader discards it, so the quad cuts the
-- sprite's exact silhouette out of itself; no geometry is built from the
-- pixels and nothing about a sprite is voxelized.
--
-- That is deliberate. A sprite is a DRAWING, not an object seen from one
-- side: Gen 1's overworld figures are 16x16 icons with a fixed front-on
-- reading, and turning one into a solid -- whether a contoured slab or a
-- carved visual hull -- reconstructs a body the artist never drew and the
-- game never implied. It also had the mod ship a description of the ROM
-- art. One quad wearing the real frame is both more faithful and cheaper:
-- it needs no pixel access at all, only the sheet's dimensions.
--
-- The card always faces SOUTH -- the direction the 2D game implies -- and
-- only LEANS BACK, pivoting at its feet, by exactly the camera's pitch
-- (VoxelScene's billboardMatrix), so at every tilt level it reads face-on
-- like the flat game. Right-facing and the alternating walk step are
-- matrix mirrors, not extra meshes. UVs point into the live sheet image,
-- so RED++ OBP bakes, SGB palette bakes and sprite-replacing mods all
-- texture it with no rebuild.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local Assets = require("src.render.Assets")
local Voxel3D = V.require("Voxel3D")

local SpriteBillboards = {}

local meshes = {}

-- A sprite def's `image` is usually a path, but the engine also takes the
-- picture itself -- "a mod may hand over an ImageData instead of a path"
-- (src/render/SpriteRenderer.lua's constructor) -- and Untamed Tohjo does,
-- for its follower's reskin (npc:setSpriteDef with the unbaked def). Every
-- cache here and in VoxelScene keyed on def.image .. "#" .. something,
-- which throws on userdata, and the engine retires a pipeline that throws:
-- one reskin and the diorama was off for the session. The key for such a
-- picture is its own tostring (unique per object), worked out once.
local userKeys = setmetatable({}, { __mode = "k" })
function SpriteBillboards.imageKey(image)
  if type(image) == "string" then return image end
  if image == nil then return "" end
  local k = userKeys[image]
  if not k then
    k = tostring(image)
    userKeys[image] = k
  end
  return k
end
local imageKey = SpriteBillboards.imageKey

-- The sheet's dimensions: a path through Assets like the engine; a picture
-- handed over as one (ImageData or Image) answers for itself.
local function sheetOf(def)
  local src = def.image
  if type(src) == "string" then return Assets.image(src) end
  if type(src) == "userdata" and src.getDimensions then return src end
  return nil
end

-- One flat 16x16 quad UV-mapped to a whole frame. A hair of inset keeps
-- the sampler inside this frame rather than picking up the neighbouring
-- one along the shared edge.
--
-- `cut` is how many pixels of the FEET are hidden (0 = full card). A water
-- mon uses this so only the top of the body sticks out of the pond: the
-- quad's local y=0 is the waterline (mid-sprite UV) and local y runs up to
-- the head. Placed with its origin on Water.surfaceAt, the cut edge is the
-- waterline and the mon reads as semi-submerged rather than standing on
-- the surface like a paper cutout.
-- A sheet whose frames are not the vanilla 16x16 column: imported art laid
-- out on a grid, or a taller effect (Untamed Tohjo's shiny sparkle is
-- 16x24). SpriteRenderer takes frameWidth/frameHeight/frameColumns/
-- frameOffset/anchorX/anchorY off the def (src/render/SpriteRenderer.lua's
-- constructor); before this the card cut 16x16 rows at frame*16 out of
-- every sheet, so a 24-tall frame came out as the wrong slice of the art.
--
-- Placed the way the 2D path places it. There the frame's top-left is
-- (px + 8 - anchorX, py + 12 - anchorY) and a vanilla frame's bottom edge
-- is py + 12; the card's feet stand where a vanilla card's do, so it spans
-- x in [8 - anchorX, 8 - anchorX + fw] (in the card's 0..16 space) and y in
-- [-(fh - anchorY), anchorY], less the waterline cut off the bottom.
--
-- Only for such sheets: a vanilla def takes the old arithmetic below
-- untouched, so every figure the game ships keeps its exact vertices.
local function isVanilla(def)
  return (def.frameWidth or 16) == 16 and (def.frameHeight or 16) == 16
     and (def.frameColumns or 1) == 1 and (def.frameOffset or 0) == 0
     and (def.anchorX or 8) == 8 and (def.anchorY or 16) == 16
end
SpriteBillboards.isVanilla = isVanilla

local function buildGridCard(def, img, frame, cut)
  local iw, ih = img:getDimensions()
  local fw = math.max(1, math.floor(tonumber(def.frameWidth) or 16))
  local fh = math.max(1, math.floor(tonumber(def.frameHeight) or 16))
  local cols = math.max(1, math.floor(tonumber(def.frameColumns) or 1))
  local index = frame + math.max(0, math.floor(tonumber(def.frameOffset) or 0))
  local ax = tonumber(def.anchorX) or fw / 2
  local ay = tonumber(def.anchorY) or fh
  local fx, fy = (index % cols) * fw, math.floor(index / cols) * fh
  if fx + fw > iw or fy + fh > ih then fx, fy = 0, 0 end
  local u0, u1 = (fx + 0.02) / iw, (fx + fw - 0.02) / iw
  local v0, v1 = (fy + 0.05) / ih, (fy + fh - 0.05) / ih
  cut = math.floor(tonumber(cut) or 0)
  if cut < 0 then cut = 0 elseif cut > fh - 4 then cut = math.max(0, fh - 4) end
  local vCut = v1 + (v0 - v1) * (cut / fh)
  local x0, x1 = 8 - ax, 8 - ax + fw
  local y0, y1 = -(fh - ay), ay - cut
  local verts = {
    { x0, y0, 0, u0, vCut, 1 }, { x1, y0, 0, u1, vCut, 1 },
    { x1, y1, 0, u1, v0, 1 }, { x0, y1, 0, u0, v0, 1 },
  }
  local indices = {}
  Voxel3D.pushQuad(indices, 0)
  return Voxel3D.newMesh(verts, indices)
end

local function buildCard(def, frame, cut)
  local ok, img = pcall(sheetOf, def)
  if not (ok and img) then return nil end
  if not isVanilla(def) then return buildGridCard(def, img, frame, cut) end
  local iw, ih = img:getDimensions()
  local fy = frame * 16
  if fy + 16 > ih then fy = 0 end
  local u0, u1 = 0.02 / iw, (16 - 0.02) / iw
  local v0, v1 = (fy + 0.05) / ih, (fy + 15.95) / ih
  cut = math.floor(tonumber(cut) or 0)
  if cut < 0 then cut = 0 elseif cut > 12 then cut = 12 end
  local vis = 16 - cut
  -- UV at the waterline: cut/16 of the way from feet (v1) toward head (v0)
  local vCut = v1 + (v0 - v1) * (cut / 16)
  local verts = {
    { 0, 0, 0, u0, vCut, 1 }, { 16, 0, 0, u1, vCut, 1 },
    { 16, vis, 0, u1, v0, 1 }, { 0, vis, 0, u0, v0, 1 },
  }
  local indices = {}
  Voxel3D.pushQuad(indices, 0)
  return Voxel3D.newMesh(verts, indices)
end

-- The card for one (sprite def, frame index [, waterline cut]), or nil
-- (headless / no image), cached like every other derived GPU object.
--
-- The solid draw, the sun pass and the player's occlusion silhouette all
-- take THIS mesh. That the three agree is load-bearing, not tidiness: the
-- silhouette is drawn with the depth test INVERTED, so any self-overlap in
-- the mesh would read as "behind something" and repaint the figure on open
-- ground whether or not anything hides it; and the sun must see the same
-- outline the camera does, or a shadow stops matching what casts it.
function SpriteBillboards.mesh(def, frame, cut)
  cut = math.floor(tonumber(cut) or 0)
  if cut < 0 then cut = 0 end
  local key = imageKey(def.image) .. "#" .. frame .. (cut > 0 and ("#w" .. cut) or "")
  -- a grid sheet's cards are keyed on its layout too: two defs may share
  -- one image and cut it differently (a vanilla def keeps the key it had)
  if not isVanilla(def) then
    key = key .. "#g" .. tostring(def.frameWidth) .. "x" .. tostring(def.frameHeight)
          .. ":" .. tostring(def.frameColumns) .. ":" .. tostring(def.frameOffset)
          .. ":" .. tostring(def.anchorX) .. "," .. tostring(def.anchorY)
  end
  if meshes[key] == nil then
    local ok, m = pcall(buildCard, def, frame, cut)
    meshes[key] = (ok and m) or false
  end
  return meshes[key] or nil
end

-- Kept as its own name because the shadow and ghost passes read as their
-- own thing at the call sites; it once carried a different mesh from the
-- solid draw, and now deliberately does not.
SpriteBillboards.shadowQuad = SpriteBillboards.mesh

function SpriteBillboards.invalidate()
  meshes = {}
end

Assets.register(SpriteBillboards.invalidate)

return SpriteBillboards
