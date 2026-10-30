-- Offline: the allocation-free Mat4 paths give the SAME numbers as the
-- allocating ones they replaced -- bit for bit, not within an epsilon.
--
-- The garbage fixes (tools/profiler) rewrote the render loop's matrix
-- chains to run through scratch tables (Mat4.mulInto / set*), on the
-- promise that the arithmetic is the same operations in the same order.
-- This holds them to it: each recipe is run both ways over random inputs
-- and every entry compared with ==.
--
--   luajit tests/mat4_offline.lua <mod-root>
local root = arg[1] or "."
local chunk = assert(loadfile(root .. "/lib/Mat4.lua"))
local Mat4 = chunk()

local fails, checks = 0, 0
local function same(a, b, what)
  checks = checks + 1
  for i = 1, 16 do
    if a[i] ~= b[i] then
      fails = fails + 1
      print(("FAIL %s: entry %d %.17g ~= %.17g"):format(what, i, a[i], b[i]))
      return
    end
  end
end

-- the pre-fix Mat4.mul, verbatim: grown from {}
local function oldMul(a, b)
  local o = {}
  for r = 0, 3 do
    local a0, a1 = a[r * 4 + 1], a[r * 4 + 2]
    local a2, a3 = a[r * 4 + 3], a[r * 4 + 4]
    for c = 1, 4 do
      o[r * 4 + c] = a0 * b[c] + a1 * b[4 + c] + a2 * b[8 + c] + a3 * b[12 + c]
    end
  end
  return o
end

math.randomseed(1234)
local function rnd(k) return (math.random() * 2 - 1) * (k or 200) end
local function rmat()
  local m = {}
  for i = 1, 16 do m[i] = rnd() end
  return m
end

local A, B, K = {}, {}, {}

for n = 1, 2000 do
  -- mul / mulInto against the old loop
  local a, b = rmat(), rmat()
  same(Mat4.mul(a, b), oldMul(a, b), "mul")
  same(Mat4.mulInto({}, a, b), oldMul(a, b), "mulInto")

  -- every set* against its constructor
  local x, y, z, ang = rnd(), rnd(), rnd(), rnd(7)
  same(Mat4.setTranslate({}, x, y, z), Mat4.translate(x, y, z), "setTranslate")
  same(Mat4.setScale({}, x, y, z), Mat4.scale(x, y, z), "setScale")
  same(Mat4.setRotateX({}, ang), Mat4.rotateX(ang), "setRotateX")
  same(Mat4.setRotateY({}, ang), Mat4.rotateY(ang), "setRotateY")
  same(Mat4.setRotateZ({}, ang), Mat4.rotateZ(ang), "setRotateZ")

  -- Voxel3D.casterMatrix: old chain vs the scratch chain
  local px, py, gy = rnd(), rnd(), rnd(40)
  local mirror = n % 2 == 0
  local old = Mat4.translate(px + 8, gy, py + 8)
  if mirror then old = oldMul(old, Mat4.scale(-1, 1, 1)) end
  old = oldMul(oldMul(old, Mat4.translate(-8, 0, 0)), Mat4.scale(1, 1, 0))
  local m, spare = Mat4.setTranslate(A, px + 8, gy, py + 8), B
  if mirror then m, spare = Mat4.mulInto(spare, m, Mat4.setScale(K, -1, 1, 1)), m end
  m = Mat4.mulInto(spare, m, Mat4.setTranslate(K, -8, 0, 0))
  same(Mat4.mul(m, Mat4.setScale(K, 1, 1, 0)), old, "casterMatrix")

  -- VoxelScene billboardMatrix: every optional factor on and off
  local yaw = (n % 3 == 0) and 0 or rnd(3)
  local pitch = rnd(1.5) - math.pi / 2
  local roll = (n % 5 == 0) and rnd(0.3) or nil
  old = Mat4.translate(px + 8, gy, py + 8)
  if yaw ~= 0 then old = oldMul(old, Mat4.rotateY(yaw)) end
  old = oldMul(old, Mat4.rotateX(pitch))
  if roll and roll ~= 0 then old = oldMul(old, Mat4.rotateZ(roll)) end
  if mirror then old = oldMul(old, Mat4.scale(-1, 1, 1)) end
  old = oldMul(old, Mat4.translate(-8, 0, 0))
  m, spare = Mat4.setTranslate(A, px + 8, gy, py + 8), B
  if yaw ~= 0 then m, spare = Mat4.mulInto(spare, m, Mat4.setRotateY(K, yaw)), m end
  m, spare = Mat4.mulInto(spare, m, Mat4.setRotateX(K, pitch)), m
  if roll and roll ~= 0 then m, spare = Mat4.mulInto(spare, m, Mat4.setRotateZ(K, roll)), m end
  if mirror then m, spare = Mat4.mulInto(spare, m, Mat4.setScale(K, -1, 1, 1)), m end
  same(Mat4.mul(m, Mat4.setTranslate(K, -8, 0, 0)), old, "billboardMatrix")

  -- ShadowMap.snug: translate * model
  local model = rmat()
  same(Mat4.mul(Mat4.setTranslate(K, x, y, z), model),
       oldMul(Mat4.translate(x, y, z), model), "snug")
end

print(("mat4_offline: %d checks, %d failed"):format(checks, fails))
os.exit(fails == 0 and 0 or 1)
