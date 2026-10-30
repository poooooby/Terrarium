-- Loads the vendored AppleCake (tools/vendor/AppleCake, MIT) into a PROBE
-- DRIVER's Lua state. Driver-side only: the mod itself never requires this.
--
-- Why a loader instead of a plain require. AppleCake expects to sit on the
-- game's require path ("lib.AppleCake") and starts its writer thread from a
-- love.filesystem PATH (newThread(dirPATH .. "thread.lua")). Neither holds
-- here: the mod lives under mods/<id>/, often behind a junction, and its
-- folder name is not fixed (TERRARIUM, TERRARIUM2, a dev checkout). So the
-- four files are read with real io from wherever THIS file sits, registered
-- in package.preload under a private prefix, and the one newThread call is
-- handed the thread's SOURCE instead of a path -- with the two modules the
-- thread requires preloaded in front of it, because a thread is a fresh Lua
-- state that shares nothing with ours.
--
-- The vendored files are not edited; everything adapts around them.
--
--   local AC = dofile(<this file>)(true)    -- active instance
--   local AC = dofile(<this file>)(false)   -- AppleCake's no-op table

local PREFIX = "terrarium_applecake."

local function here()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:gsub("\\", "/"):match("^(.*)/[^/]*$") or ".")
end

local VENDOR = here() .. "/../vendor/AppleCake/"

local function read(name)
  local f = assert(io.open(VENDOR .. name, "rb"),
                   "applecake_loader: missing " .. VENDOR .. name)
  local s = f:read("*a")
  f:close()
  return s
end

local sources = {
  AppleCake = read("AppleCake.lua"),
  threadConfig = read("threadConfig.lua"),
  outputStream = read("outputStream.lua"),
  thread = read("thread.lua"),
}

for _, name in ipairs({ "AppleCake", "threadConfig", "outputStream" }) do
  package.preload[PREFIX .. name] = function(modname)
    return assert(loadstring(sources[name], "@AppleCake/" .. name .. ".lua"))(modname)
  end
end

-- The thread's code string: preload the two modules it requires, then run
-- thread.lua with the same varargs (PATH, OWNER) AppleCake starts it with.
-- %q keeps the embedded sources intact whatever quotes they hold.
local function threadSource()
  local parts = {}
  for _, name in ipairs({ "threadConfig", "outputStream" }) do
    parts[#parts + 1] = string.format(
      "package.preload[%q] = function(n) return assert(loadstring(%q, %q))(n) end",
      PREFIX .. name, sources[name], "@AppleCake/" .. name .. ".lua")
  end
  parts[#parts + 1] = string.format(
    "return assert(loadstring(%q, %q))(...)", sources.thread, "@AppleCake/thread.lua")
  return table.concat(parts, "\n")
end

-- AppleCake looks newThread up on love.thread at call time, so swapping the
-- field for the duration of beginSession is enough.
local function patchSessions(AC)
  if not AC.beginSession or AC.__terrariumLoader then return AC end
  AC.__terrariumLoader = true
  local begin = AC.beginSession
  AC.beginSession = function(...)
    local real = love.thread.newThread
    love.thread.newThread = function(arg)
      if type(arg) == "string" and arg:match("thread%.lua$") then
        return real(threadSource())
      end
      return real(arg)
    end
    local ok, err = pcall(begin, ...)
    love.thread.newThread = real
    if not ok then error(err, 0) end
  end
  return AC
end

return function(active)
  local factory = require(PREFIX .. "AppleCake")
  return patchSessions(factory(active))
end
