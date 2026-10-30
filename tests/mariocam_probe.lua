-- Probe: the SM64 camera (lib/MarioCam.lua) in the real renderer.
--
--   POKEPORT_VERSION=yellow DS_PROBE_DIR=<dir> \
--   POKEPORT_DRIVER=mods/TERRARIUM/tests/mariocam_probe.lua gen1recomp
--
-- WHAT IS MEASURED, and why each of these and not "the screenshot looks
-- like Mario 64".
--
--   PARITY  VoxelScene.bounds at yaw zero must equal, to the pixel, the
--           four expressions it used before this feature existed. That box
--           is what culls terrain, and a change that quietly moved it with
--           the camera OFF would be a regression in the mode everybody is
--           already playing. Checked against the arithmetic written out
--           longhand here rather than against the function itself, so the
--           check cannot agree with a bug by sharing it.
--
--   HOLD    the orbit's whole claim is that the bearing is the PLAYER'S
--           and nobody else's. So: stand west of the map centre, stand
--           east of it, and the view yaw must not have moved. (This was
--           SWING, the opposite claim, when the mode orbited the map.)
--
--   (HOLE, CARD, INPUT, MOONWALK and the canary measured the camera
--   TURNED: culling, card angle, the D-pad remap and the sprite facing at
--   every reachable yaw. The camera no longer turns -- 2026-10-29 -- so
--   they were removed with it; PARITY and HOLD cover the fixed bearing.)
--
--   CHASE   the 0.8 / 0.3 asymmetry, in the running game rather than in a
--           unit test: after a tenth of a second of a step, the focus must
--           have closed far more of its gap than the eye has of its own.
--           That asymmetry is the port's central claim.
--
--   Screenshots for every case, because a camera is a thing you look at.

return function(game)
  local OUT = os.getenv("DS_PROBE_DIR") or "."
  local logf = io.open(OUT .. "/mariocam_probe.log", "w")
  if not logf then
    OUT = "."
    logf = assert(io.open(OUT .. "/mariocam_probe.log", "w"))
  end
  local function log(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
    logf:write(table.concat(parts, " "), "\n"); logf:flush()
  end
  log("driver start")
  local function wait(n) for _ = 1, n do coroutine.yield() end end
  local function tap(b)
    game.input.pressQueue[#game.input.pressQueue + 1] = b; coroutine.yield()
  end

  -- Booted through Game:startNewGame{intro=false}, like the profiler's
  -- drivers: mashing A from the title only works with a save to continue,
  -- and without one it sat in the intro.
  local src = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
  local TOOLS = (src:match("^(.*)/tests/[^/]*$") or ".") .. "/tools/profiler/"
  local Scenes = dofile(TOOLS .. "Scenes.lua")
  if not Scenes.boot(game, log) then logf:close() love.event.quit() return end

  local exports = game.mods and game.mods.exports
  local lib = exports and exports.TERRARIUM and exports.TERRARIUM.lib
  if not lib then
    log("FAIL: TERRARIUM not loaded"); logf:close(); love.event.quit(); return
  end
  log("version:", exports.TERRARIUM.version)

  local MarioCam = lib.require("MarioCam")
  local VoxelScene = lib.require("VoxelScene")
  local ShadowMap = lib.require("ShadowMap")
  local Voxel3D = lib.require("Voxel3D")
  local Voxel = lib.require("VoxelState")
  local DayNight = lib.require("DayNight")
  local Weather = lib.require("Weather")
  local MiniMap = lib.require("MiniMap")
  local Pipelines = require("src.render.Pipelines")

  -- 50 degrees: a real perspective with plenty of near ground in frame,
  -- which is what the VOID band needs. 75 is mostly sky and would leave
  -- the band measuring the horizon instead of the hole.
  Pipelines.setLevel("terrarium_voxel", 4)
  Pipelines.setLevel("terrarium_tiltshift", 0)
  MiniMap.setting:setIndex(3, game)          -- nothing in the corner
  Weather.setting:setIndex(2, game)          -- nothing falling through it
  -- The save opens with A-FARM armed and a bot pushing directions into the
  -- press queue would walk the player between the halves of every pair.

  local CLOCK = 300                           -- noon, pinned every frame
  local function hold(frames)
    for _ = 1, frames do DayNight.clock = CLOCK; coroutine.yield() end
    DayNight.clock = CLOCK
  end

  -- ------- LET GO OF THE STICK
  --
  -- A synthetic pressQueue inject is a press with NO SOURCE, and
  -- Input:step's rule for those is to set state[btn] = true and leave it
  -- there: nothing releases what nothing owns. So a walk burst leaves the
  -- direction held FOREVER, and the player keeps walking on every frame of
  -- every settle after it until they are jammed against a wall.
  --
  -- That cost three checks in one run -- two walks that reported "did not
  -- move (blocked)" and a chase that measured a lag of zero -- all of them
  -- describing a player who had walked into a building four sections ago
  -- and stayed there. Every burst below ends with this.
  local function releaseDirs()
    local st = game.input.state
    for _, d in ipairs({ "up", "down", "left", "right" }) do
      st[d] = false
      if game.input.sources then game.input.sources[d] = nil end
    end
    game.input.pressQueue = {}
  end

  -- One walk burst: hold `dir` for `frames`, then let go.
  local function walk(dir, frames)
    for _ = 1, frames do
      game.input.pressQueue[#game.input.pressQueue + 1] = dir
      DayNight.clock = CLOCK
      coroutine.yield()
    end
    releaseDirs()
    hold(15)
  end

  -- CELADON_CITY: 50 by 36 cells, the biggest town in Kanto, outdoors, and
  -- built around its middle -- which is the shape the radial mode's area
  -- centre assumes.
  --
  -- SIZE IS NOT A DETAIL HERE, it is what makes the culling checks mean
  -- anything. The first run of this file used PALLET_TOWN, got zero holes
  -- everywhere, and the canary at the bottom then showed why: Pallet is 20
  -- by 18 cells and the culling box is larger than the whole map, so
  -- NOTHING is ever culled at any yaw and every pass was vacuous. A test
  -- that cannot fail is not evidence, and the only reason that was caught
  -- is that the canary exists.
  local MAP = "CELADON_CITY"
  local function goTo(cx, cy, face)
    game.overworld:setMap(MAP, cx, cy, face or "down")
    hold(300)
  end

  local fails, notes = {}, {}
  local function check(ok, msg)
    if not ok then fails[#fails + 1] = msg end
    log((ok and "  ok   " or "  FAIL ") .. msg)
  end

  -- ------- the shot
  --
  -- `save` writes the png; the ImageData is kept either way so two frames
  -- can be diffed pixel for pixel.
  local function measure(name, save)
    local pending, rec = true, nil
    love.graphics.captureScreenshot(function(data)
      local W, H = data:getDimensions()
      rec = { name = name, W = W, H = H, data = data }
      if save ~= false then
        local f = io.open(OUT .. "/" .. name .. ".png", "wb")
        if f then f:write(data:encode("png"):getString()) f:close() end
      end
      pending = false
    end)
    -- WAIT FOR THE CALLBACK, not for N frames: a screenshot scheduled and
    -- then counted out in yields photographs whatever the next state is,
    -- which silently attributes one case's picture to another.
    local guard = 0
    while pending and guard < 300 do hold(1); guard = guard + 1 end
    if not rec then log("  (no shot for " .. name .. ")") end
    return rec
  end

  -- ------- the hole counter
  --
  -- A chunk is a box of world: x0..x1 by 0..ymax by z0..z1 (ChunkMesher's
  -- buckets). It is ON SCREEN if any of its eight corners projects inside
  -- the viewport with positive w, and it is KEPT if it meets the culling
  -- box -- the same test Voxel3D.drawGroup applies, restated here so the
  -- check does not agree with a bug by sharing the code that has it.
  local ChunkMesher = lib.require("ChunkMesher")

  local function onScreen(ch, W, H)
    local xs = { ch.x0, ch.x1 }
    local zs = { ch.z0, ch.z1 }
    local ys = { 0, ch.ymax or 0 }
    for _, x in ipairs(xs) do
      for _, y in ipairs(ys) do
        for _, z in ipairs(zs) do
          local px, py = Voxel3D.project(x, y, z)
          if px and px >= 0 and px <= W and py >= 0 and py <= H then
            return true
          end
        end
      end
    end
    return false
  end

  local function kept(ch, b)
    -- Voxel3D.drawGroup's own test, including the ymax reach on the north
    -- edge: a chunk whose GROUND is past the box still draws if something
    -- tall stands on it
    return ch.x1 >= b[1] and ch.x0 <= b[3]
           and ch.z1 + (ch.ymax or 0) >= b[2] and ch.z0 <= b[4]
  end

  -- ------- WHAT COUNTS AS A HOLE, and why "on screen and dropped" is not
  -- the definition
  --
  -- A chunk two thousand pixels away still PROJECTS into the viewport --
  -- it lands on the horizon row. Dropping it is not a bug, it is FAR_CAP,
  -- a trade this mod made long before this feature and made deliberately;
  -- counting those makes every camera look broken including the untouched
  -- orbit. The first version of this counter did exactly that and reported
  -- eleven holes on a working frame.
  --
  -- The invariant that actually belongs to this change is narrower and
  -- direction-free: WITHIN THE REACH THE BOX ITSELF CLAIMS, everything the
  -- camera can see must be kept, whichever way the camera is pointed. The
  -- yardstick is the ORBIT's reach -- the number the mod's far field was
  -- tuned against -- so the yawed camera is held to the same standard as
  -- the one it replaces rather than to one of its own.
  local function nearestTo(ch, x, z)
    local dx = math.max(ch.x0 - x, 0, x - ch.x1)
    local dz = math.max(ch.z0 - z, 0, z - ch.z1)
    return math.sqrt(dx * dx + dz * dz)
  end

  -- Everything that moves, stilled -- not for the counter, which does not
  -- care, but so the screenshots beside it are comparable frame to frame.
  local function holeTest(name)
    local shot = measure(name, true)
    local W = shot and shot.W or 1920
    local H = shot and shot.H or 1080
    local state = game.overworld
    local terrain = VoxelScene.prefetch and select(1, VoxelScene.prefetch(state))
    if not (terrain and terrain.chunks) then
      log("  (no terrain group for " .. name .. ")")
      return shot, 0, 0
    end
    -- THE BOX THIS FRAME, from the four numbers the renderer actually
    -- fitted it to (VoxelScene.lastView). Reconstructing them out here --
    -- guessing the view size, guessing whether the centre is the scroll or
    -- the camera focus -- would be asking about a box the frame never used.
    local lv = VoxelScene.lastView
    local b = VoxelScene.bounds(lv[1], lv[2], lv[3], lv[4], false)

    local reach = ShadowMap.groundReach(lv[4], VoxelScene.FAR_CAP)
    local seen, near, holes, total = 0, 0, 0, 0
    local worst = nil
    for _, ch in ipairs(terrain.chunks) do
      total = total + 1
      if onScreen(ch, W, H) then
        seen = seen + 1
        if nearestTo(ch, lv[1], lv[2]) <= reach then
          near = near + 1
          if not kept(ch, b) then
            holes = holes + 1
            worst = ("chunk x[%.0f..%.0f] z[%.0f..%.0f] is %.0f px away "
                     .. "(reach %.0f) but the box is [%.0f %.0f %.0f %.0f]")
                    :format(ch.x0, ch.x1, ch.z0, ch.z1,
                            nearestTo(ch, lv[1], lv[2]), reach,
                            b[1], b[2], b[3], b[4])
          end
        end
      end
    end
    log(("HOLE %-18s yaw %7.2f  %d built / %d on screen / %d within reach "
         .. "%.0f / %d CULLED")
        :format(name, math.deg(MarioCam.viewYaw()), total, seen, near,
                reach, holes))
    if worst then log("       e.g. " .. worst) end
    check(holes == 0,
          ("%s: %d chunks inside the box's own reach are on screen and culled")
          :format(name, holes))
    return shot, holes, near
  end

  -- ------- 1. PARITY: the box at yaw zero is the box we always had
  --
  -- Written out longhand from the four expressions bounds() used before
  -- this change, so the check has its own copy of the answer.
  local function oldBounds(cx, cy, vw, vh, forSun)
    local reach = ShadowMap.groundReach(vh, VoxelScene.FAR_CAP)
    local spread = reach * 0.5 + 64
    local sun = 0
    if forSun then
      sun = ShadowMap.HEIGHT
            * math.max(math.abs(ShadowMap.KX), math.abs(ShadowMap.KZ)) + 24
    end
    return { cx - vw / 2 - spread, cy - reach,
             cx + vw / 2 + spread + sun, cy + vh / 2 + 64 + sun }
  end
  local function boxEq(a, b, tol)
    for i = 1, 4 do
      if math.abs(a[i] - b[i]) > (tol or 0.001) then return false end
    end
    return true
  end
  local function boxStr(b)
    return ("[%.0f %.0f %.0f %.0f]"):format(b[1], b[2], b[3], b[4])
  end

  goTo(5, 6, "up")
  MarioCam.setting:setIndex(1, game)          -- OFF
  hold(60)
  for _, sun in ipairs({ false, true }) do
    local got = VoxelScene.bounds(400, 300, 160, 144, sun)
    local want = oldBounds(400, 300, 160, 144, sun)
    log("PARITY off sun=" .. tostring(sun), boxStr(got), "want", boxStr(want))
    check(boxEq(got, want), "bounds at yaw 0 (cam OFF, sun=" .. tostring(sun)
          .. ") matches the pre-feature box")
  end

  -- ------- AND NOT "the ON box covers the old box"
  --
  -- That check lived here while the ladder had a rung with the yaw pinned,
  -- and it made sense there: at yaw zero the two boxes describe the same
  -- camera, so the new one had better not be smaller. With the row simply
  -- ON the camera has a real yaw, and a box fitted to a camera looking
  -- EAST has no business reaching far north -- that would be covering
  -- ground nobody can see. Demanding coverage of the old box would be
  -- demanding the bug back.
  --
  -- The invariant that survives the yaw is the one the hole counter below
  -- tests: within the reach the box claims, everything on screen is kept,
  -- whichever way the camera points. The exact-parity check above still
  -- guards the case that must not move -- the row OFF.
  MarioCam.setting:setIndex(2, game)          -- ON
  hold(240)
  log("PARITY on", boxStr(VoxelScene.bounds(400, 300, 160, 144, false)),
      "old", boxStr(oldBounds(400, 300, 160, 144, false)))

  local shotOff, shotOn, shotW, shotE
  MarioCam.setting:setIndex(1, game); hold(120)
  shotOff = holeTest("cam_off")
  MarioCam.setting:setIndex(2, game); hold(240)
  shotOn = holeTest("cam_on")

  -- ------- 2. HOLD: the orbit keeps its bearing wherever the player stands
  --
  -- The radial orbit this replaced swung the yaw with the player's
  -- position about the map's centre; the player-centred orbit must not
  -- move a degree between the west edge and the east edge of the biggest
  -- town in Kanto with no camera key pressed.
  MarioCam.setting:setIndex(2, game)          -- ON
  local map = game.overworld.map
  local wCells = map and map.widthCells or 20
  local hCells = map and map.heightCells or 18
  log(("map %s cells %d x %d"):format(MAP, wCells, hCells))

  local westX = math.max(1, math.floor(wCells * 0.15))
  local eastX = math.min(wCells - 2, math.floor(wCells * 0.85))
  local midY = math.floor(hCells / 2)
  local centreX = wCells * 8

  -- WHERE THE PLAYER ACTUALLY IS, not where they were put. setMap drops
  -- them on a cell and the game may then walk them off it -- a warp tile, a
  -- script, a ledge -- so the position is reported beside every reading.
  local function spot(cx, cy, tag)
    goTo(cx, cy, "up")
    hold(240)
    local p = game.overworld.player
    local px = (p.px or 0) + 8
    log(("  %s: asked for cell (%d,%d), player is at (%.0f,%.0f) = cell "
         .. "(%d,%d), map centre x is %.0f")
        :format(tag, cx, cy, px, (p.py or 0) + 8,
                math.floor(px / 16), math.floor(((p.py or 0) + 8) / 16),
                centreX))
    return px
  end

  local pxW = spot(westX, midY, "west")
  local yawW = math.deg(MarioCam.viewYaw())
  shotW = holeTest("cam_orbit_west")
  local pxE = spot(eastX, midY, "east")
  local yawE = math.deg(MarioCam.viewYaw())
  shotE = holeTest("cam_orbit_east")
  check(pxW < centreX and pxE > centreX,
        ("the two spots really are on opposite sides of the map's centre "
         .. "(%.0f and %.0f, centre %.0f)")
        :format(pxW, pxE, centreX))
  log(("HOLD west=%.1fdeg east=%.1fdeg delta=%.1f"):format(yawW, yawE,
                                                           math.abs(yawW - yawE)))
  check(math.abs(yawW) < 2 and math.abs(yawE) < 2,
        "the orbit holds its bearing across the map (west "
        .. ("%.1f"):format(yawW) .. ", east " .. ("%.1f"):format(yawE)
        .. " deg)")

  -- ------- 4. CHASE: the focus outruns the eye, in the running game
  --
  -- Measured as the STEADY-STATE LAG of each layer behind its own target
  -- while the player walks, which is the honest in-game reading of the two
  -- constants. For an exponential chase of a target moving at v, the lag
  -- settles at v*(1-k)/k -- so the ratio between the two lags is fixed by
  -- the two coefficients alone and does not depend on how fast the player
  -- walks. At 0.8 and 0.3 corrected to 60fps that ratio is a little over
  -- six.
  --
  -- NOT measured by teleporting the player: setMap builds a new Map, which
  -- is a map change, which is a CUT -- both layers snap and the reading is
  -- of the cut rather than of the chase. The first version of this check
  -- did that and reported the eye moving nearly three times FURTHER than
  -- the focus, which is what a cut looks like when you call it a chase.
  -- ------- WALKING SIDEWAYS, AND THAT IS NOT A DODGE
  --
  -- The radial camera stands on the far side of the player from the area
  -- centre, looking inward. Camera-relative movement therefore makes UP
  -- mean "toward the middle of the map", at every position, by
  -- construction. Hold it and the player converges on the centre and then
  -- oscillates across it inside the yaw deadzone -- 150 frames of pressing
  -- up moved them sixteen pixels net, which is the sum of walking in and
  -- back out again. Correct behaviour, useless for measuring a lag that
  -- needs steady travel in one direction.
  --
  -- LEFT does not have that problem: perpendicular to the view is a walk
  -- AROUND the area centre rather than at it, so the player keeps moving
  -- and the camera keeps chasing.
  --
  -- (The convergence is true of SM64 too: in Bob-omb Battlefield, pushing
  -- away from the camera runs you at the mountain. It is liveable there
  -- because the stick is continuous, and liveable here for the same reason
  -- in reverse -- all four buttons rotate together, so down goes outward
  -- and left and right go around.)
  MarioCam.setting:setIndex(2, game)
  -- ------- A CORRIDOR LONG ENOUGH TO GET UP TO SPEED
  --
  -- The lag this measures is a STEADY-STATE lag, which needs the player
  -- moving continuously for the length of the sample. Celadon's open
  -- pocket is about two cells across in any direction: the player used it
  -- up inside forty frames, stopped against a wall, and the check reported
  -- zero moving frames out of two hundred.
  --
  -- ROUTE_17 is the Cycling Road -- twenty cells wide and a hundred and
  -- forty-four tall, the longest straight run in Kanto.
  --
  -- WHICH BUTTON walks along it is not something this file gets to assume:
  -- under camera-relative movement the physical button maps to whichever
  -- world direction currently reads as "away from the camera", and that
  -- depends on where the radial camera has swung to. So it tries all four
  -- and takes the one that actually travels, which is both robust and the
  -- honest way to write it -- hardcoding a direction here would be
  -- hardcoding an assumption about the camera the test is measuring.
  game.overworld:setMap("ROUTE_17", 9, 40, "down")
  hold(300)
  local pc = game.overworld.player
  local best, bestD = "left", -1
  for _, d in ipairs({ "up", "down", "left", "right" }) do
    local x0, z0 = pc.px, pc.py
    walk(d, 30)
    local moved = math.abs(pc.px - x0) + math.abs(pc.py - z0)
    if moved > bestD then best, bestD = d, moved end
    game.overworld:setMap("ROUTE_17", 9, 40, "down")
    hold(90)
  end
  log(("CHASE corridor: %s travels furthest (%.0f px in 30 frames)")
      :format(best, bestD))
  hold(120)

  releaseDirs()
  local p2 = game.overworld.player
  local startX = p2.px
  local startY = p2.py
  -- ONLY THE FRAMES THE PLAYER ACTUALLY MOVED ON.
  --
  -- The lag being measured is that of a chase behind a MOVING target;
  -- frames where the player stands still -- jammed on a wall, or between
  -- grid steps -- are frames where both lags decay toward zero, and
  -- averaging those in drags the answer toward noise. Averaging everything
  -- read lags of 0.05 and 0.34 pixels: the right ratio, on numbers too
  -- small to mean anything.
  local sumFoc, sumPos, samples = 0, 0, 0
  local lastX, lastZ = p2.px, p2.py
  for i = 1, 200 do
    -- one edge per frame into the press queue: step() sees a synthetic
    -- inject with no source map and holds the button for that step, which
    -- is exactly a held direction and is how the other probes here drive
    -- the game
    game.input.pressQueue[#game.input.pressQueue + 1] = best
    DayNight.clock = CLOCK
    coroutine.yield()
    local movedThisFrame = (p2.px ~= lastX or p2.py ~= lastZ)
    lastX, lastZ = p2.px, p2.py
    if i > 40 and movedThisFrame then
      local c, l = MarioCam.cam, MarioCam.lakitu
      local fx2, fz2 = c.focus[1] - l.curFocus[1], c.focus[3] - l.curFocus[3]
      local px2, pz2 = c.pos[1] - l.curPos[1], c.pos[3] - l.curPos[3]
      sumFoc = sumFoc + math.sqrt(fx2 * fx2 + fz2 * fz2)
      sumPos = sumPos + math.sqrt(px2 * px2 + pz2 * pz2)
      samples = samples + 1
    end
  end
  local walked = math.abs(game.overworld.player.px - startX)
                 + math.abs(game.overworld.player.py - startY)
  releaseDirs()
  local lagFoc = samples > 0 and sumFoc / samples or 0
  local lagPos = samples > 0 and sumPos / samples or 0
  log(("CHASE walked %.0f px over %d moving frames; mean lag: focus %.2f, "
       .. "eye %.2f, ratio %.2f")
      :format(walked, samples, lagFoc, lagPos,
              lagFoc > 0.001 and lagPos / lagFoc or -1))
  check(samples >= 20,
        ("enough moving frames to average (%d)"):format(samples))
  -- A LAG OF ZERO IS NOT A PASS, IT IS A PLAYER WHO NEVER MOVED. The first
  -- run of this check walked into a wall and reported 0.00 against 0.00,
  -- which the ratio test would have called a failure for the wrong reason
  -- and a "greater than" test would have called a pass for a worse one.
  check(walked > 16, ("the player actually walked (%.0f px)"):format(walked))
  check(lagFoc > 0.001 and lagPos / lagFoc > 2.5,
        ("the eye lags several times further than the focus (ratio %.2f)")
        :format(lagFoc > 0.001 and lagPos / lagFoc or -1))
  MarioCam.setting:setIndex(2, game)

  -- ------- 5. it survives the things that cut
  MarioCam.setting:setIndex(2, game)          -- ON
  goTo(3, 3, "down"); hold(120)
  goTo(wCells - 3, hCells - 3, "up"); hold(120)
  check(MarioCam.camera() ~= nil, "still producing a camera after two warps")
  measure("cam_free", true)

  -- and OFF hands the slot back
  MarioCam.setting:setIndex(1, game); hold(60)
  check(MarioCam.camera() == nil, "OFF yields no camera")
  check(MarioCam.viewYaw() == 0, "OFF reports yaw 0, so the box is the old box")

  log("")
  if #fails == 0 then
    log("ALL CHECKS PASSED")
  else
    log("FAILURES (" .. #fails .. "):")
    for _, f in ipairs(fails) do log("  - " .. f) end
  end
  logf:close()
  love.event.quit()
end
