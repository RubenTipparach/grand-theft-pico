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

-- Key repeat timing (for menu navigation)
local key_repeat_time = {}           -- when key was first pressed
local key_repeat_last = {}           -- when last repeat fired
local REPEAT_DELAY = 0.35            -- delay before repeat starts (seconds)
local REPEAT_RATE = 0.08             -- time between repeats (seconds)

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

-- Check if key was pressed OR is repeating (for menu navigation)
-- Fires once on initial press, then repeats after REPEAT_DELAY at REPEAT_RATE
function input.key_pressed_repeat(k)
	local is_down = key(k)
	local now = time()

	if not is_down then
		-- Key released - clear repeat state
		key_repeat_time[k] = nil
		key_repeat_last[k] = nil
		key_state[k] = STATE_UNPRESSED
		return false
	end

	-- Key is down
	if not key_repeat_time[k] then
		-- First frame pressed - start tracking and fire immediately
		key_repeat_time[k] = now
		key_repeat_last[k] = now
		key_state[k] = STATE_PRESSED
		return true
	end

	-- Key held - check for repeat
	local held_duration = now - key_repeat_time[k]
	local since_last = now - key_repeat_last[k]

	if held_duration >= REPEAT_DELAY and since_last >= REPEAT_RATE then
		key_repeat_last[k] = now
		return true
	end

	return false
end

-- No update() needed - state is checked lazily on each call

return input
