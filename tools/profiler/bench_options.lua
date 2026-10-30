-- Rewrites a gen1recomp options.lua so ONLY Terrarium loads for one game
-- version -- the profiling runner's (tools/profiler/run.py) "bench profile".
-- Run with LuaJIT from the engine checkout, so the engine's own
-- SaveSerializer reads and writes the file (it round-trips options.lua
-- byte for byte; a hand-rolled writer would not):
--
--   cd <gen1recomp> && luajit <this> <options.lua> <version> <keep> <id>...
--
-- Every id given is set false in options.modsByVersion[version]; the ids in
-- <keep> (comma-separated: Terrarium, plus any --with mod) are set true.
-- Explicit falses matter: a mod with no entry
-- there falls through to the shared `mods` flag and then to the loader's
-- default, which is ENABLED (SaveData.modEnabled).
--
-- The runner backs the file up first and restores it afterwards; this
-- script never sees the backup.

package.path = "./?.lua;" .. package.path
local S = require("src.core.SaveSerializer")

local path, version, keep = arg[1], arg[2], arg[3]
assert(path and version and keep, "usage: bench_options.lua <options.lua> <version> <keepId> <id>...")

local f = assert(io.open(path, "rb"))
local body = f:read("*a")
f:close()
local opts = assert(S.decode(body))

opts.modsByVersion = opts.modsByVersion or {}
local bucket = {}
for i = 4, #arg do bucket[arg[i]] = false end
for id in keep:gmatch("[^,]+") do bucket[id] = true end
opts.modsByVersion[version] = bucket

local out = assert(io.open(path, "wb"))
out:write(S.encode(opts))
out:close()

local n = 0
for _ in pairs(bucket) do n = n + 1 end
local _, kept = keep:gsub("[^,]+", "")
print(("bench options: %s only, %d other mods off for %s"):format(keep, n - kept, version))
