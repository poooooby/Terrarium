-- Probe: the build cache's code fingerprint (lib/BuildCache.lua,
-- BuildCache.codeHash) -- what it is on this install, whether it took the
-- developer path (content hashed) or the player's (names and sizes), and
-- what it cost. Run it, change a file, run it again: the hash must move.
--
--   python tools/profiler/run.py buildcache_code_probe
return function(game)
  local src = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
  local TOOLS = (src:match("^(.*)/tests/[^/]*$") or ".") .. "/tools/profiler/"
  local Harness = dofile(TOOLS .. "Harness.lua")
  local H = assert(Harness.attach(game, { name = "buildcache_code" }))
  local BuildCache = H.V.require("BuildCache")
  local t0 = love.timer.getTime()
  local h = BuildCache.codeHash()
  local ms = (love.timer.getTime() - t0) * 1000
  H.log(("code hash %s  (%s path, %.1f ms)"):format(h, h:match("^dev:") and "developer" or "player", ms))
  local t1 = love.timer.getTime()
  BuildCache.codeHash()
  H.log(("again: %.3f ms (kept)"):format((love.timer.getTime() - t1) * 1000))
  H.log((h ~= "unlisted") and "PASS" or "FAIL: mod:list/mod:info unavailable")
  H:finish({ probe = "buildcache_code" })
  love.event.quit()
end
