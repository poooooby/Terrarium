-- The one knob for this mod's own drawn UI text: English or Portuguese.
--
-- gen1recomp's own strings are English -- src/core/Strings.lua ships as an
-- identity function until a translation mod overrides its catalog, and the
-- ROM text this build extracts (data/generated/text.lua) is the original
-- English cartridge script. Nothing in a stock checkout ever prints ITENS,
-- MAPA or OPÇÕES; those were this mod's OWN battle/menu overlays, hardcoded
-- against a Portuguese build the original author was running elsewhere.
--
-- So Portuguese is not a second language this mod has to detect -- it is a
-- choice for the player who wants this mod's OWN glass-panel menus (the
-- start menu, the bag, the battle command buttons) to read in Portuguese
-- regardless of what the underlying game prints. English is the default
-- because it is what an unmodified checkout actually shows everywhere else.
--
-- What this does NOT translate: the engine's own screens (the flat 160x144
-- menus this mod silences, dialogue, item names) -- those come from the ROM
-- and from Strings.lua, and stay whatever language the base game and its
-- own translation mods (if any) put them in. This is cosmetic to this
-- mod's overlays only.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local ModSetting = V.require("ModSetting")

local Lang = {}

Lang.setting = ModSetting.new("language", "UI LANG",
  { "en", "pt" }, { "ENGLISH", "PORTUGUÊS" })

function Lang.get()
  return Lang.setting:get()
end

function Lang.isPT()
  return Lang.get() == "pt"
end

-- Pick between an English and a Portuguese string for this mod's own drawn
-- text, by the current setting.
function Lang.pick(en, pt)
  return Lang.isPT() and pt or en
end

return Lang
