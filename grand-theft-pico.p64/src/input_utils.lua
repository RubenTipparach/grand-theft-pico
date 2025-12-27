--[[pod_format="raw"]]
-- input_utils.lua - Input handling utilities
-- State machine approach: event fires ONCE on state transition
--
-- State transitions:
--   unpressed -> pressed  = key_pressed() returns true (one frame)
--   pressed -> unpressed  = key_released() returns true (one frame)

local input = {}

-- State enum
local STATE_UNPRESSED = 0
local STATE_PRESSED = 1

-- Track current state per key
local key_state = {}

-- Check if key was just pressed (fires once on transition)
function input.key_pressed(k)
	local is_down = key(k)
	local current_state = key_state[k] or STATE_UNPRESSED

	if is_down and current_state ~= STATE_PRESSED then
		-- Transition: unpressed -> pressed
		key_state[k] = STATE_PRESSED
		return true  -- fire event
	elseif not is_down and current_state ~= STATE_UNPRESSED then
		-- Transition: pressed -> unpressed
		key_state[k] = STATE_UNPRESSED
	end

	return false
end

-- Check if key was just released (fires once on transition)
function input.key_released(k)
	local is_down = key(k)
	local current_state = key_state[k] or STATE_UNPRESSED

	if not is_down and current_state ~= STATE_UNPRESSED then
		-- Transition: pressed -> unpressed
		key_state[k] = STATE_UNPRESSED
		return true  -- fire event
	elseif is_down and current_state ~= STATE_PRESSED then
		-- Transition: unpressed -> pressed
		key_state[k] = STATE_PRESSED
	end

	return false
end

-- Check if key is currently held (not a transition, just current state)
function input.key_held(k)
	return key(k)
end

-- No update() needed - state is checked lazily on each call

return input
