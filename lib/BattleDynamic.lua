-- One row for the whole dynamic battle costume.
--
-- Every piece of the package already keeps its own gate -- the attack
-- camera's `enabled`, the fan's, the panels', the weather's, the
-- ribbon's, the capsules' WORLD flag -- and every draw path behind those
-- gates already degrades to the classic presentation it replaced (flat
-- rows, corner capsules, the plain rig). This module is one hand on all
-- of them, across five levels:
--
--   DYNAMIC          the costume as built: the camera moves, the panels
--                     float, the capsules hang beside their own mon.
--   DYNAMIC MINIMAL  everything DYNAMIC has -- the moving camera, the
--                     floating world-hung capsules, the fan, the ribbon,
--                     the floating message panel -- except the command
--                     menu and the move-selection screen, which this
--                     level leaves for another mod to draw (see MINIMAL
--                     below for why).
--   CLASSIC          exactly the original mod's still fight -- the
--                     camera holds the rig, the menu and the box lie
--                     flat on the glass, the capsules pin to the window
--                     corners with Unova's bars (name, HP, EXP) -- minus
--                     the frosted panel that used to sit behind them,
--                     which this level never draws.
--   MINIMAL          the same corner-pinned name/HP/EXP reading and the
--                     message text ("Wild X appeared!" and the like),
--                     but no command menu and no move-selection screen
--                     -- that is left for another mod to draw, or for a
--                     battle to sit in until one does.
--   OFF              nothing this mod draws at all: no box, no HUD, no
--                     menu, no frost. Just the 3D scene, the models, and
--                     whatever hit FX are independently on -- the way a
--                     fresh install would look.
--
-- The flip is safe mid-battle by construction: every gate is consulted
-- per frame, and each level's paths are the fallbacks the level above it
-- was built over. Applied at every battle's door too, so a persisted
-- choice holds from the first frame.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local ModSetting = V.require("ModSetting")

local BattleDynamic = {}

BattleDynamic.setting = ModSetting.new("battledyn", "COMBAT",
  { "dynamic", "dynamic_minimal", "classic", "minimal", "off" },
  { "DYNAMIC", "DYNAMIC MINIMAL", "CLASSIC", "MINIMAL", "OFF" })

function BattleDynamic.mode()
  return BattleDynamic.setting:get()
end

-- DYNAMIC and DYNAMIC MINIMAL both move: camera, floating panels, the
-- capsules hung in the world beside their own mon. The two differ only
-- in whether the command menu shows (see wantsMinimal below).
function BattleDynamic.wantsDynamic()
  local mode = BattleDynamic.mode()
  return mode == "dynamic" or mode == "dynamic_minimal"
end

-- CLASSIC and MINIMAL still wear the corner-pinned box and HUD; DYNAMIC
-- and DYNAMIC MINIMAL wear the floating one instead (see wantsDynamic);
-- only OFF takes the costume off entirely and draws nothing in its
-- place.
function BattleDynamic.wantsCostume()
  return BattleDynamic.mode() ~= "off"
end

-- MINIMAL and DYNAMIC MINIMAL both hide the command menu and the
-- move-selection screen -- the only axis those two differ from CLASSIC
-- and DYNAMIC on, respectively.
function BattleDynamic.wantsMinimal()
  local mode = BattleDynamic.mode()
  return mode == "minimal" or mode == "dynamic_minimal"
end

function BattleDynamic.wantsOff()
  return BattleDynamic.mode() == "off"
end

-- the gates, by module and field -- each module stays its own master;
-- this row only writes what a probe (or a hand on the module) could.
-- Tied to wantsDynamic() specifically: these are the moving parts
-- CLASSIC and MINIMAL hold still, not the costume itself (see
-- COSTUME_GATES below). BattleHitFX is deliberately NOT here -- hit FX
-- are an independent polish layer, not part of this row's own
-- presentation, and stay on (their own default) at every level
-- including OFF.
local GATES = {
  { "BattleShot", "enabled" },
  { "BattleFanXY", "ENABLED" },
  { "BattlePanelsXY", "ENABLED" },
  { "BattleGlassFX", "ENABLED" },
  { "BattleRibbon", "ENABLED" },
}

-- the costume itself -- the box and HUD reskin -- on for every level but
-- OFF
local COSTUME_GATES = {
  { "BattleBoxXY", "ENABLED" },
  { "BattleHudXY", "ENABLED" },
}

function BattleDynamic.apply()
  local on = BattleDynamic.wantsDynamic()
  for _, gate in ipairs(GATES) do
    local ok, M = pcall(V.require, gate[1])
    if ok and M then M[gate[2]] = on end
  end
  local costume = BattleDynamic.wantsCostume()
  for _, gate in ipairs(COSTUME_GATES) do
    local ok, M = pcall(V.require, gate[1])
    if ok and M then M[gate[2]] = costume end
  end
  local minimal = BattleDynamic.wantsMinimal()
  local off = BattleDynamic.wantsOff()
  -- MINIMAL and DYNAMIC MINIMAL: the box still speaks for the
  -- "messages" phase (floating or flat, following wantsDynamic), but
  -- gets out of the way for "menu"/"moveSelect" -- neither drawing its
  -- own command UI there nor forcing the engine's, so another mod's own
  -- hook (or the engine's, absent one) is what the player sees.
  local okB, Box = pcall(V.require, "BattleBoxXY")
  if okB and Box then
    Box.HIDE_COMMANDS = minimal
    -- OFF: suppressed outright, never falling back to the engine's own
    -- box the way a plain `available()==false` would (see BattleBoxXY
    -- .install) -- OFF means nothing this mod touches shows at all.
    Box.SUPPRESS = off
  end
  local okH, Hud = pcall(V.require, "BattleHudXY")
  if okH and Hud then Hud.SUPPRESS = off end
  -- the capsules keep Unova's bars at every level but OFF; only DYNAMIC
  -- and DYNAMIC MINIMAL hang them beside their own mon (CLASSIC and
  -- MINIMAL pin them to the window corners instead), and clears the
  -- world debug so a probe can tell which placement is live rather than
  -- reading a stale one
  local okC, Cap = pcall(V.require, "BattleCapsule")
  if okC and Cap then
    Cap.WORLD = on
    if not on then Cap._world = nil end
  end
  return on
end

-- OPTIONS row: cycle then apply. The manager page writes through
-- mod.options_changed (main.lua), which calls onOptionsChanged here.
function BattleDynamic.setting:row()
  local self_ = self
  return {
    id = ((V.mod and V.mod.id) or "TERRARIUM") .. ":" .. self.key,
    label = self.label,
    value = function() return self_.labels[self_:read()] end,
    step = function(game, dir)
      self_:cycle(game, dir)
      BattleDynamic.apply()
      return true
    end,
  }
end

function BattleDynamic.onOptionsChanged(value)
  BattleDynamic.setting:sync(value)
  BattleDynamic.apply()
end

return BattleDynamic
