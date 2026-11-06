-- Offline (no LOVE): the battle message panel pops ONCE per message.
--
--   luajit tests/battlepanel_pop_offline.lua <mod-root>
--
-- Replays the frames a turn goes through -- a message typing, its move
-- animation (the engine clears `current` and leaves the lines up), an
-- A-to-advance line and the hold after the press, two messages with the
-- same words, the command menu's prompt -- through the panel's own identity
-- rule, and counts the times it would pop. It popped a second time over the
-- same message when the identity was the text and fell back to the two
-- visible lines while `current` was nil.
local root = arg[1] or "."
local stub = setmetatable({}, { __index = function() return function() end end })
local V = { require = function() return stub end, data = function() return {} end }
local Panels = assert(loadfile(root .. "/lib/BattlePanelsXY.lua"))(V)
local ident = Panels._msgIdentity

local pops, prev = 0, nil
local log = {}
local function frame(tag, battle, lines)
  local id = ident(battle, lines, prev)
  if id ~= prev then pops = pops + 1; log[#log + 1] = tag end
  prev = id
end

local used = { text = "PIKACHU used\nTHUNDERSHOCK!" }
local eff = { text = "It's super\neffective!" }
local fainted = { text = "Enemy PIDGEY\nfainted!" }
local again = { text = "It's super\neffective!" }    -- same words, new message

-- 1. "used THUNDERSHOCK!" opens on an empty frame, types, then the bolt
--    plays under its lines
for _ = 1, 2 do frame("used: first empty frame", { current = used }, {}) end
for _ = 1, 20 do frame("used: typing", { current = used }, { "PIKACHU used", "THUNDERSHO" }) end
for _ = 1, 40 do frame("used: animation", { animPlaying = true }, { "PIKACHU used", "THUNDERSHOCK!" }) end
-- 2. an A-to-advance line, the press, then a hold (the hit blink)
for _ = 1, 30 do frame("effective: wait for A", { current = eff, msgPrompt = true }, { "It's super", "effective!" }) end
for _ = 1, 15 do frame("effective: hold", { msgHold = true }, { "It's super", "effective!" }) end
-- the GAP after A: no message, no lines -- the pane is held, so this must
-- not replay the pop on the message that is leaving
for _ = 1, 6 do frame("gap after A", {}, {}) end
for _ = 1, 3 do frame("gap after A", { current = fainted }, { "" }) end
-- 3. the faint, then the same words again as a NEW message
for _ = 1, 20 do frame("fainted", { current = fainted }, { "Enemy PIDGEY", "fainted!" }) end
for _ = 1, 20 do frame("same words, new message", { current = again }, { "It's super", "effective!" }) end
-- 4. the menu's prompt, which has no message item
for _ = 1, 20 do frame("menu prompt", {}, { "What will", "PIKACHU do?" }) end

print("pops: " .. table.concat(log, ", "))
local want = { "used: first empty frame", "effective: wait for A", "fainted",
               "same words, new message", "menu prompt" }
local ok = #log == #want
for i = 1, #want do ok = ok and log[i] == want[i] end
print(ok and "PASS" or ("FAIL: wanted " .. table.concat(want, ", ")))
os.exit(ok and 0 or 1)
