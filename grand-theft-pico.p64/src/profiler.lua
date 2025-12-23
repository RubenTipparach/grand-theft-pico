--[[pod_format="raw"]]
-- profiler.lua - Performance profiler (based on abledbody's profiler)

local function do_nothing() end

-- Metatable makes profile() callable
local profile_meta = {__call = do_nothing}
profile = {draw = do_nothing}
setmetatable(profile, profile_meta)

local running = {}   -- Incomplete profiles
local profiles = {}  -- Complete profiles

-- Start timing a named section
local function start_profile(name)
	running[name] = {
		start = stat(1)  -- CPU usage at start
	}
end

-- Stop timing and record delta
local function stop_profile(name, active, delta)
	local prof = profiles[name]
	if prof then
		prof.time = delta + prof.time
	else
		profiles[name] = {
			time = delta,
			name = name,
		}
		add(profiles, profiles[name])
	end
end

-- Main profile function - call twice with same name to start/stop
local function _profile(_, name)
	local t = stat(1)
	local active = running[name]
	if active then
		local delta = t - active.start
		stop_profile(name, active, delta)
		running[name] = nil
	else
		start_profile(name)
	end
end

-- Draw CPU usage only
local function draw_cpu()
	print_shadow("cpu:" .. string.sub(stat(1) * 100, 1, 5) .. "%", 1, 24, 7)
end

-- Draw all profiles
local function display_profiles()
	local y = 34
	for prof in all(profiles) do
		local usage = string.sub(prof.time * 100, 1, 5) .. "%"
		local text = prof.name .. ":" .. usage
		-- Indent sub-profiles (names starting with space) in different color
		local color = prof.name:sub(1, 1) == " " and 12 or 7
		print_shadow(text, 1, y, color)
		y = y + 10
	end
	profiles = {}  -- Clear for next frame
end

-- Draw both CPU and profiles
local function display_both()
	draw_cpu()
	display_profiles()
end

-- Enable/disable profiling
-- detailed: show per-section breakdown
-- cpu: show overall CPU usage
function profile.enabled(detailed, cpu)
	profile_meta.__call = detailed and _profile or do_nothing
	profile.draw = detailed and (cpu and display_both or display_profiles)
		or (cpu and draw_cpu or do_nothing)
end
