-- Two questions about the engine's screen stack, asked in one place.
--
-- `Game.stack:top() == ow` was written out by hand in about eighteen modules,
-- each meaning "the player can see the map". One named function is a single
-- line to read and a single line to change when the answer has to differ.
--
-- `Screen.onStack` is the check a lifecycle needs when it owns something a
-- screen is using. Game:returnToTitle pops every screen and emits nothing --
-- no battle.ended, no close call -- so a session that only listens for its
-- own ending event outlives the screen it belongs to. BattleExit.veil worked
-- this out first, for a fade that could be popped from under itself.

local V = ...

local Screen = {}

-- Whether the overworld `ow` is the screen on top. A plain answer: callers
-- add their own `not ow.transitioning` where a warp matters.
function Screen.onTop(game, ow)
  local stack = game and game.stack
  return (stack and stack:top() == ow) and true or false
end

-- Whether `state` is anywhere on the screen stack, under other screens
-- included (a battle stays on it while its party menu is open). A walk over
-- a handful of entries with no allocation, so a per-frame caller may use it.
function Screen.onStack(game, state)
  local stack = game and game.stack
  local states = stack and stack.states
  if not states then return false end
  for i = #states, 1, -1 do
    if states[i] == state then return true end
  end
  return false
end

return Screen
