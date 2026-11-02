-- "Terrarium looks best in ADVANCED colours" -- a one-time question in the
-- overworld when the engine's COLORS option is on anything else.
--
-- Why it is there: ADVANCED (engine id `redpp`) is the one mode that bakes a
-- fully coloured per-tile atlas (TileRenderer getGbcAtlas, see
-- lib/TerrainAtlas.lua's header), and it is the look the diorama is made
-- for. The other modes do draw in 3D -- tests/sgb_mobile_probe.lua walks all
-- seven -- but SGB recolours from four-shade zones and OG / CLASSIC are grey
-- by design, so the world comes out flatter than it should.
--
-- It first said the voxels ONLY appear in ADVANCED, after an Android report
-- that SGB stayed 2D until COLORS was switched. That did not reproduce --
-- not on desktop with the phone's rungs forced, and not on the phone itself
-- with 1.52.2-beta's DEBUG INFO -- so the wording went back to "looks best".
--
-- What it does: once the player is in free roam with the 3D view on and
-- COLORS is not ADVANCED, a panel asks SWITCH / KEEP. SWITCH sets COLORS
-- exactly as the engine's own hotkey 2 does (options.colors,
-- PaletteFX.setMode, writeOptions); KEEP remembers the mode it was asked
-- about, so it never asks again for that mode -- only if the player later
-- goes back to ADVANCED and leaves it for something else. A display option,
-- set only on the player's say-so: nothing about how the game plays.
--
-- The answer lives in mod.cache (install-scoped, like the build cache's
-- index), not in a save: it is about this install's display, not a run.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local Lang = V.require("Lang")
local PaletteFX = require("src.render.PaletteFX")

local ColorsPrompt = {}

ColorsPrompt.WANT = "redpp"     -- ADVANCED
-- free roam must hold this long before asking: arriving through a door or
-- a warp, the first second is a fade the panel would land on top of
ColorsPrompt.SETTLE = 1.0

local FILE = "colors_prompt.txt"

-- ---------------------------------------------------------------- memory

local declined = nil    -- the mode KEEP was answered for (nil = none)
local loaded = false

local function cache()
  local mod = V.mod
  return mod and mod.cache
end

local function loadDeclined()
  if loaded then return declined end
  loaded = true
  local c = cache()
  if c then
    local ok, s = pcall(c.read, c, FILE)
    if ok and type(s) == "string" and s ~= "" then declined = s:match("^%s*(%S+)") end
  end
  return declined
end

local function saveDeclined(mode)
  declined = mode
  loaded = true
  local c = cache()
  if not c then return end
  if mode then
    pcall(c.write, c, FILE, mode)
  else
    pcall(c.delete, c, FILE)
  end
end

-- ---------------------------------------------------------------- state

local prompt = nil      -- the pushed state while the panel is up
local held = 0          -- seconds the "would ask" conditions have held

-- The engine's own "busy" test before hotkey 2 reloads the map for a colour
-- change (src/core/Game.lua): a warp, a scripted cutscene, a trainer
-- engaging or an emote. The panel waits those out, so SWITCH never tears an
-- escort's NPCs out mid-move.
local function busy(ow)
  return ow.transitioning
      or (ow.runner and ow.runner.isRunning and ow.runner:isRunning())
      or (ow.scriptMoves and #ow.scriptMoves > 0)
      or ow.engaging or ow.emote
end

local function modeLabel(mode)
  local ok, s = pcall(PaletteFX.modeLabel, mode)
  return ok and s or tostring(mode)
end

local Prompt = {}
Prompt.__index = Prompt

function Prompt.new(game, mode)
  return setmetatable({
    game = game, mode = mode, cursor = 1,
    choices = {
      { key = "switch", label = Lang.pick("SWITCH TO ADVANCED", "MUDAR PARA ADVANCED") },
      { key = "keep", label = Lang.pick(("KEEP %s"):format(modeLabel(mode)),
                                        ("MANTER %s"):format(modeLabel(mode))) },
    },
  }, Prompt)
end

function Prompt:close()
  if self.game.stack:top() == self then self.game.stack:pop() end
  prompt = nil
  held = 0
end

function Prompt:update(dt)
  local input = self.game.input
  if input:wasPressed("up") or input:wasPressed("down") then
    self.cursor = self.cursor % #self.choices + 1
  elseif input:wasPressed("b") then
    saveDeclined(self.mode)
    self:close()
  elseif input:wasPressed("a") then
    local key = self.choices[self.cursor].key
    local game = self.game
    -- popped FIRST: setMode reloads the live map, which wants the overworld
    -- back on top as it would be after the hotkey
    self:close()
    if key == "switch" then
      local opts = game.save and game.save.options
      if opts then opts.colors = ColorsPrompt.WANT end
      PaletteFX.setMode(ColorsPrompt.WANT)
      if game.writeOptions then pcall(game.writeOptions, game) end
      saveDeclined(nil)
    else
      saveDeclined(self.mode)
    end
  end
end

-- From main.lua's core.update: push the panel once its conditions have held
-- for SETTLE seconds of free roam.
function ColorsPrompt.update(game, dt, voxelOn)
  if prompt then return end
  local mode = PaletteFX.mode
  if mode == ColorsPrompt.WANT then
    -- back on ADVANCED: forget an old KEEP, so leaving it again asks again
    if loadDeclined() then saveDeclined(nil) end
    held = 0
    return
  end
  local ow = game and game.overworld
  local top = game and game.stack and game.stack:top()
  if not (voxelOn and ow and ow.map and top == ow and not busy(ow))
     or loadDeclined() == mode then
    held = 0
    return
  end
  held = held + (dt or 0)
  if held < ColorsPrompt.SETTLE then return end
  prompt = Prompt.new(game, mode)
  game.stack:push(prompt)
end

function ColorsPrompt.active()
  return prompt ~= nil
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

local function wrapH(font, text, width)
  local _, lines = font:getWrap(text, width)
  return math.max(1, #lines) * font:getHeight()
end

-- The same panel as the 3D build prompt (lib/BuildVeil.lua): measured
-- before it is drawn, sized off the shorter screen side, dark glass.
function ColorsPrompt.draw()
  if not prompt then return end
  local g = love.graphics
  local w, h = g.getDimensions()
  local cv = g.getCanvas()
  if cv then w, h = cv:getDimensions() end
  local px = math.min(h, w * 0.75) / 30
  local big, small = fontFor(px * 1.15), fontFor(px * 0.8)
  local pad = math.floor(px * 0.9)
  local pw = math.floor(math.min(w - px * 2, px * 22))
  local tw = pw - pad * 2
  local r = px * 0.4
  local rowGap = math.floor(px * 0.35)

  local title = Lang.pick("Terrarium looks best in ADVANCED",
                          "O Terrarium fica melhor no ADVANCED")
  local body = Lang.pick(
    ("COLORS is set to %s. The 3D world is coloured for ADVANCED, and "
     .. "in other modes it can look grey or washed out. You can change it "
     .. "any time under OPTIONS > GRAPHICS > COLORS.")
      :format(modeLabel(prompt.mode)),
    ("COLORS esta em %s. O mundo 3D e colorido para o ADVANCED, e nos "
     .. "outros modos pode ficar cinza ou desbotado. Da para mudar a "
     .. "qualquer hora em OPTIONS > GRAPHICS > COLORS.")
      :format(modeLabel(prompt.mode)))

  local ph = pad + wrapH(big, title, tw) + px * 0.5 + wrapH(small, body, tw) + px * 0.8
  ph = ph + #prompt.choices * (big:getHeight() + rowGap * 2) + pad - rowGap
  ph = math.floor(ph)
  local x, y = math.floor((w - pw) / 2), math.floor((h - ph) / 2)

  g.push("all")
  g.origin()
  g.setShader()
  g.setColor(0, 0, 0, 0.55)
  g.rectangle("fill", 0, 0, w, h)
  g.setColor(0.055, 0.075, 0.10, 0.94)
  g.rectangle("fill", x, y, pw, ph, r, r)
  g.setColor(0.45, 0.82, 1.0, 0.55)
  g.setLineWidth(1)
  g.rectangle("line", x + 0.5, y + 0.5, pw - 1, ph - 1, r, r)
  local tx, ty = x + pad, y + pad
  g.setFont(big)
  g.setColor(0.92, 0.95, 1.0, 1)
  g.printf(title, tx, ty, tw)
  ty = ty + wrapH(big, title, tw) + px * 0.5
  g.setFont(small)
  g.setColor(0.75, 0.80, 0.88, 1)
  g.printf(body, tx, ty, tw)
  ty = ty + wrapH(small, body, tw) + px * 0.8
  g.setFont(big)
  for i, c in ipairs(prompt.choices) do
    local sel = i == prompt.cursor
    local rh = big:getHeight() + rowGap
    if sel then
      g.setColor(0.45, 0.82, 1.0, 0.16)
      g.rectangle("fill", tx - px * 0.35, ty - rowGap * 0.5, tw + px * 0.7,
                  rh, r * 0.6, r * 0.6)
      g.setColor(0.45, 0.82, 1.0, 1)
      g.print(">", tx + px * 0.1, ty)
    else
      g.setColor(0.92, 0.95, 1.0, 1)
    end
    g.print(c.label, tx + px * 1.4, ty)
    ty = ty + rh + rowGap
  end
  g.pop()
end

-- For probes: forget the remembered answer and any panel up.
function ColorsPrompt.resetForProbe()
  saveDeclined(nil)
  prompt = nil
  held = 0
end

return ColorsPrompt
