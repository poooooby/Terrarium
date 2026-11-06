-- Voxel world mode: which authored town kit builds which buildings OUTSIDE.
--
-- Vermilion's six houses (lib/VermilionHouseKit.lua) and Lavender's
-- buildings have their own branches in Buildings.build; every town kit
-- since names its map (`Kit.MAP`) and the templates it takes over
-- (`Kit.TEMPLATES`), builds per placement (`Kit.model(sp, t, tx, ty)`), and
-- is listed here once -- Buildings asks for the kit, the scene for the
-- sheets whose glass burns after dark (`Kit.GLASS_UV`).

local V = ...

local HouseKits = {}

HouseKits.NAMES = { "PalletHouseKit", "ViridianHouseKit", "GatehouseKit", "PewterHouseKit",
                    "CeruleanHouseKit", "VermilionGymKit", "SouthTownKit" }

local cache = {}
local function load(name)
  if cache[name] == nil then
    local ok, Kit = pcall(V.require, name)
    cache[name] = (ok and Kit) or false
  end
  return cache[name] or nil
end

-- the kit that builds template `templateId` on map `mapId`, or nil
function HouseKits.kitFor(mapId, templateId)
  for _, name in ipairs(HouseKits.NAMES) do
    local Kit = load(name)
    local onMap = Kit and (Kit.MAP == mapId or (Kit.MAPS and Kit.MAPS[mapId]))
    if onMap and Kit.TEMPLATES and Kit.TEMPLATES[templateId] then
      return name, Kit
    end
  end
  return nil
end

-- every listed kit, for the scene's sheet effects
function HouseKits.all()
  local out = {}
  for _, name in ipairs(HouseKits.NAMES) do
    local Kit = load(name)
    if Kit then out[#out + 1] = Kit end
  end
  return out
end

return HouseKits
