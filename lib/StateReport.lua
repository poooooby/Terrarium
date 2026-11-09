-- What state is each lifecycle in, by name, on demand.
--
-- A lot of this mod is ordered lifecycles encoded in plain fields: a battle
-- session is `session` + `armed` + `shot` + `snapped` + `broken`, a mesh slot
-- is nil, a job, a mesh or `false`. Those fields are fine to run on, and
-- rewriting them around a state-machine library would put every working
-- lifecycle at risk on hot paths for nothing a player could see. What they
-- could not do was say what they were: "unarmed" and "shotless" and "broken"
-- looked the same from outside, so every probe guessed at them and a bug
-- report had nothing to quote.
--
-- So each lifecycle worth naming DECLARES itself here, beside the fields it
-- reads: a name, the states it can be in, and a function that DERIVES the
-- current one from those fields. Nothing is stored, nothing is driven from
-- here, and no behaviour can depend on it.
--
-- Costs nothing per frame: only the DEBUG INFO panel, probes and other mods
-- (mod.exports.states) ever call all(), and define() is a table write at load.
--
-- assets/docs/state-machines.md is the catalogue of every lifecycle, including
-- the ones deliberately not reported and why; tools/check_states.py fails if
-- it and the define() calls disagree.

local V = ...

local StateReport = {}

local order, byName = {}, {}

-- name    "area.thing", e.g. "battle.session"
-- states  every value fn may answer, as a list
-- fn      () -> state, detail   (detail: optional short string)
--
-- Defining a name again replaces it in place, so a reloaded module neither
-- doubles its row nor moves it.
function StateReport.define(name, states, fn)
  local allowed = {}
  for _, s in ipairs(states) do allowed[s] = true end
  local rec = byName[name]
  if rec then
    rec.states, rec.allowed, rec.fn = states, allowed, fn
    return
  end
  rec = { name = name, states = states, allowed = allowed, fn = fn }
  byName[name] = rec
  order[#order + 1] = rec
end

local function read(rec)
  local ok, state, detail = pcall(rec.fn)
  if not ok then return "error", tostring(state) end
  -- an answer the declaration does not list is itself the finding: the
  -- derivation and the lifecycle have drifted apart, so say so loudly rather
  -- than report a name nothing else knows
  if state == nil or not rec.allowed[state] then
    return "?" .. tostring(state), detail
  end
  return state, detail
end

-- One lifecycle's current state, and its detail. nil for an unknown name.
function StateReport.state(name)
  local rec = byName[name]
  if not rec then return nil end
  return read(rec)
end

-- Every lifecycle, in the order they were defined:
-- { { name=, state=, detail=, states= }, ... }
function StateReport.all()
  local out = {}
  for i, rec in ipairs(order) do
    local state, detail = read(rec)
    out[i] = { name = rec.name, state = state, detail = detail,
               states = rec.states }
  end
  return out
end

-- Every name that has been defined, sorted (tools and probes).
function StateReport.names()
  local out = {}
  for i, rec in ipairs(order) do out[i] = rec.name end
  table.sort(out)
  return out
end

-- Whether `state` is one `name` declares. Lets a probe assert a state it
-- expects actually exists, so a typo cannot pass by never matching.
function StateReport.declares(name, state)
  local rec = byName[name]
  return (rec and rec.allowed[state]) and true or false
end

return StateReport
