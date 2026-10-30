-- Probe: Lua garbage per frame, per scene, against a recorded budget.
--
-- For each map in Scenes.MAPS: one GcMeter window standing still and one
-- pacing (tools/profiler/GcMeter.lua -- collector stopped, count deltas,
-- attribution through Perf.wrap). Prints the top allocators per window and
-- compares KB/frame with tests/gc_budget.lua:
--
--   FAIL <scene>  -- over budget by more than MARGIN (a regression)
--   NOTE <scene>  -- under budget by more than MARGIN (re-record it, so the
--                    win is locked in and cannot quietly erode)
--
--   DS_GC_RECORD=1  rewrite tests/gc_budget.lua from this run instead
--   DS_GC_JITOFF=1  measure with the JIT off (see GcMeter's note); a budget
--                   is only comparable with a run in the same mode
--
--   POKEPORT_VERSION=yellow DS_PROBE_DIR=<dir> \
--   POKEPORT_DRIVER=mods/<id>/tests/gc_budget_probe.lua love .
return function(game)
  local src = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
  local ROOT = src:match("^(.*)/tests/[^/]*$") or "."
  local TOOLS = ROOT .. "/tools/profiler/"
  local Harness = dofile(TOOLS .. "Harness.lua")
  local Scenes = dofile(TOOLS .. "Scenes.lua")
  local GcMeter = dofile(TOOLS .. "GcMeter.lua")

  local OUT = os.getenv("DS_PROBE_DIR") or "."
  local RECORD = (os.getenv("DS_GC_RECORD") or "") == "1"
  local MARGIN = 0.20      -- 20%: window-to-window noise measured ~8-12%
  local FLOOR = 2.0        -- KB/frame; below this a percentage is noise

  local H = assert(Harness.attach(game, { out = OUT, name = "gc_budget" }))
  local log = H.log
  if not Scenes.boot(game, log) then H:finish(); love.event.quit(); return end
  Scenes.pin(H.V, log)
  local gc = GcMeter.new(H)
  -- DS_GC_DEEP=1: also split VoxelScene.render by the module calls it
  -- makes (Harness.DEEP_WRAPS) -- for finding WHERE, not for the budget,
  -- since the wraps themselves cost a little
  local DEEP = (os.getenv("DS_GC_DEEP") or "") == "1"
  if DEEP then
    local took = {}
    for mod, fns in pairs(Harness.DEEP_WRAPS) do
      local ok, M = pcall(H.V.require, mod)
      for _, fn in ipairs(fns) do
        local label = mod .. "." .. fn
        if ok and type(M) == "table" and type(M[fn]) == "function"
            and not Harness.wrapped[label] and H.Perf.wrap(M, fn, label) then
          Harness.wrapped[label] = true
          took[#took + 1] = label
        end
      end
    end
    log("deep wraps:", #took)
    RECORD = false   -- a deep run is never a budget
  end

  local budgetPath = ROOT .. "/tests/gc_budget.lua"
  local budget = {}
  do
    local f = io.open(budgetPath, "r")
    if f then
      local chunk = loadstring(f:read("*a")); f:close()
      local ok, t = pcall(chunk)
      if ok and type(t) == "table" then budget = t end
    end
  end
  local mode = gc.jitOff and "jitoff" or "jit"
  budget[mode] = budget[mode] or {}

  local measured = {}
  for _, c in ipairs(Scenes.MAPS) do
    if Scenes.visit(game, H.V, c, log) then
      local r1 = gc:window(c.id .. ":stand", 120)
      measured[r1.name] = r1.kbPerFrame
      if c.walk ~= false then
        local r2 = gc:window(c.id .. ":walk", 192, Scenes.pacer(game))
        measured[r2.name] = r2.kbPerFrame
      end
    end
  end

  log("")
  local fails = 0
  local names = {}
  for k in pairs(measured) do names[#names + 1] = k end
  table.sort(names)
  for _, name in ipairs(names) do
    local kb, want = measured[name], budget[mode][name]
    if not want then
      log(("NEW  %-28s %7.2f KB/frame (no budget yet)"):format(name, kb))
    elseif kb > want * (1 + MARGIN) and kb - want > FLOOR then
      fails = fails + 1
      log(("FAIL %-28s %7.2f KB/frame, budget %.2f"):format(name, kb, want))
    elseif kb < want * (1 - MARGIN) and want - kb > FLOOR then
      log(("NOTE %-28s %7.2f KB/frame, budget %.2f -- re-record"):format(name, kb, want))
    else
      log(("ok   %-28s %7.2f KB/frame, budget %.2f"):format(name, kb, want))
    end
  end

  if RECORD then
    for name, kb in pairs(measured) do
      budget[mode][name] = math.floor(kb * 100 + 0.5) / 100
    end
    local lines = {
      "-- KB of Lua garbage per frame, per scene, recorded by",
      "-- tests/gc_budget_probe.lua (DS_GC_RECORD=1). Keyed by JIT mode: a",
      "-- jit-on run also counts trace objects (tools/profiler/GcMeter.lua).",
      "-- Machine-specific like every perf number here; re-record on a new box.",
      "return {",
    }
    local modes = {}
    for m in pairs(budget) do modes[#modes + 1] = m end
    table.sort(modes)
    for _, m in ipairs(modes) do
      lines[#lines + 1] = ("  %s = {"):format(m)
      local ks = {}
      for k in pairs(budget[m]) do ks[#ks + 1] = k end
      table.sort(ks)
      for _, k in ipairs(ks) do
        lines[#lines + 1] = ("    [%q] = %.2f,"):format(k, budget[m][k])
      end
      lines[#lines + 1] = "  },"
    end
    lines[#lines + 1] = "}"
    local f = io.open(budgetPath, "w")
    if f then
      f:write(table.concat(lines, "\n"), "\n"); f:close()
      log("recorded budget ->", budgetPath)
    end
  end

  gc:write(OUT .. "/gc_budget.json", { probe = "gc_budget", mode = mode })
  log(fails == 0 and "PASS" or ("FAIL x" .. fails))
  Scenes.unpin()
  H:finish({ probe = "gc_budget", mode = mode })
  love.event.quit()
end
