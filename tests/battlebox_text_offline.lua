-- Offline (no LOVE): the battle box reads the engine's rolling two-line
-- window, cut by glyphs, not current.text cut by bytes.
--
--   luajit tests/battlebox_text_offline.lua <mod-root>
--
-- A stand-in Font.split with the two things that broke the old cut: Gen 1's
-- one-glyph contractions ('s) and multi-byte letters (é). The message is the
-- one from the bug report, with its \v CONT break.
local root = arg[1] or "."
local function spans(text)
  local out, i = {}, 1
  while i <= #text do
    local to = i
    if text:sub(i, i + 1) == "'s" then to = i + 1
    elseif text:byte(i) >= 0xC0 then
      to = i + 1
      while to + 1 <= #text and text:byte(to + 1) >= 0x80 and text:byte(to + 1) < 0xC0 do to = to + 1 end
    end
    out[#out + 1] = { from = i, to = to, code = 1 }
    i = to + 1
  end
  return out
end
package.loaded["src.render.Font"] = { split = spans }
local stub = setmetatable({}, { __index = function() return function() end end })
local V
V = { require = function(n)
  if n == "BattleBoxXY" then return assert(loadfile(root .. "/lib/BattleBoxXY.lua"))(V) end
  return stub
end }
local Box = V.require("BattleBoxXY")

local fails = 0
local function eq(what, got, want)
  local g = type(got) == "table" and table.concat(got, "|") or tostring(got)
  local w = type(want) == "table" and table.concat(want, "|") or tostring(want)
  if g ~= w then fails = fails + 1; print("FAIL " .. what .. ": got [" .. g .. "] want [" .. w .. "]")
  else print("ok   " .. what .. ": " .. g) end
end

-- what the engine's startMessage builds for
-- "No! There's no\nrunning from a\vtrainer battle!"
local L = { { text = "No! There's no" }, { text = "running from a" },
            { text = "trainer battle!" } }
for _, l in ipairs(L) do l.codes = spans(l.text) end
local function typed(n) local t = {}; for i = 1, n do t[i] = 1 end; return t end
local b = { current = { text = "No! There's no\nrunning from a\vtrainer battle!" },
            lines = L }

-- mid-first line: 8 glyphs of "No! There's no" ('s is one) = "No! Ther"
b.lineIndex, b.shown = 1, { typed(8) }
eq("first line, 8 glyphs", Box._engineLines(b), { "No! Ther" })
b.shown = { typed(10) }
eq("the contraction is one glyph", Box._engineLines(b), { "No! There's" })
-- two lines up, the second complete: the CONT wait
b.lineIndex, b.shown = 2, { typed(#L[1].codes), typed(#L[2].codes) }
eq("CONT wait, two full lines", Box._engineLines(b), { "No! There's no", "running from a" })
-- after A: the window scrolls, the third line types in -- and finishes
b.lineIndex, b.shown = 3, { typed(#L[2].codes), typed(#L[3].codes) }
eq("scrolled, last line whole", Box._engineLines(b), { "running from a", "trainer battle!" })
-- no control character ever reaches the font
for _, s in ipairs(Box._engineLines(b)) do
  if s:find("[\n\v]") then fails = fails + 1; print("FAIL control char in " .. s) end
end
-- the typing flag counts glyphs against the engine's total
b.total, b.charIndex = 43, 43
eq("not typing at the end", Box.typing(b), false)
b.charIndex = 40
eq("typing before it", Box.typing(b), true)
-- a multi-byte letter is cut whole
eq("é is one glyph", Box._glyphPrefix("POKéMON", 4), "POKé")
-- no message and no animation: nothing to show
b.current = nil
eq("box empty between messages", #Box._engineLines(b), 0)
-- an engine with no window: nil, and the old cut stands in
eq("old engine", Box._engineLines({ current = { text = "x" } }), "nil")

print(fails == 0 and "PASS" or ("FAIL x" .. fails))
os.exit(fails == 0 and 0 or 1)
