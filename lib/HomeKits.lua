-- Voxel world mode: which authored home kit builds which map.
--
-- Every home kit names its maps in `Kit.MAPS` (map id -> variant). The kit
-- that builds a map is the first in NAMES whose MAPS has it; Lavender's is
-- the default, as it always was (lib/Buildings.lua's `home` branch). The
-- scene asks the same question to hold the grid and the cel step off in an
-- authored room (lib/VoxelScene.lua), so a new kit is listed here once and
-- both places know it.

local V = ...

local HomeKits = {}

HomeKits.DEFAULT = "LavenderHomeKit"
HomeKits.NAMES = { "LavenderHomeKit", "VermilionHomeKit", "RedsRoomKit",
                   "RedsHouseKit", "TownHomeKit", "OaksLabKit", "PokecenterKit",
                   "SchoolKit", "GateKit", "PewterGymKit", "CeruleanGymKit",
                   "CeruleanRoomsKit", "VermilionGymInKit", "ShipKit", "DockKit", "FacilityKit", "LobbyKit",
                   "GymHallKit", "MansionKit", "LabRoomsKit",
                   "BeachHouseKit" }

local cache = {}

local function load(name)
  if cache[name] == nil then
    local ok, Kit = pcall(V.require, name)
    cache[name] = (ok and Kit) or false
  end
  return cache[name] or nil
end

-- the kit name and module for a map, or nil when no kit names it
function HomeKits.kitFor(mapId)
  for _, name in ipairs(HomeKits.NAMES) do
    local Kit = load(name)
    if Kit and Kit.MAPS and Kit.MAPS[mapId] then return name, Kit end
  end
  return nil
end

-- the sheet a kit paints a map from: one per town where the kit has
-- several (`Kit.sheetFor`), else the kit's own
function HomeKits.sheetFor(Kit, mapId)
  return (Kit.sheetFor and Kit.sheetFor(mapId)) or Kit.SHEET
end

return HomeKits
