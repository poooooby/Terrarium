-- KB of Lua garbage per frame, per scene, recorded by
-- tests/gc_budget_probe.lua (DS_GC_RECORD=1). Keyed by JIT mode: a
-- jit-on run also counts trace objects (tools/profiler/GcMeter.lua).
-- Machine-specific like every perf number here; re-record on a new box.
return {
  jit = {
    ["CELADON_CITY:stand"] = 151.28,
    ["CELADON_CITY:walk"] = 151.51,
    ["LAVENDER_TOWN:stand"] = 192.43,
    ["LAVENDER_TOWN:walk"] = 201.25,
    ["PALLET_TOWN:stand"] = 124.30,
    ["PALLET_TOWN:walk"] = 128.89,
    ["ROUTE_12:stand"] = 190.53,
    ["VERMILION_CITY:stand"] = 160.02,
    ["VERMILION_CITY:walk"] = 148.98,
  },
}
