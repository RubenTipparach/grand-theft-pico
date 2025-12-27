--[[pod_format="raw"]]

-- Grand Theft Picotron
-- A top-down GTA1/2-style game for Picotron

-- ============================================
-- REQUIRE FUNCTION (for modules that return values)
-- ============================================
function require(name)
	if _modules == nil then
		_modules = {}
	end

	local already_imported = _modules[name]
	if already_imported ~= nil then
		return already_imported
	end

	local filename = fullpath(name .. '.lua')
	local src = fetch(filename)

	if type(src) ~= "string" then
		notify("could not include " .. filename)
		stop()
		return
	end

	local func, err = load(src, "@" .. filename, "t", _ENV)
	if not func then
		send_message(3, { event = "report_error", content = "*syntax error" })
		send_message(3, { event = "report_error", content = tostr(err) })
		stop()
		return
	end

	local module = func()
	_modules[name] = module

	return module
end

-- ============================================
-- INCLUDES (load modules)
-- ============================================
include("src/constants.lua")
include("src/config.lua")
include("src/utils.lua")
include("src/profiler.lua")
include("src/perspective.lua")
include("src/culling.lua")
include("src/wall_renderer.lua")
include("src/building.lua")
include("src/collision.lua")
include("src/ground.lua")
include("src/worldgen.lua")
include("src/flora.lua")
include("src/input.lua")
include("src/npc.lua")
include("src/vehicle.lua")
include("src/weapon.lua")
include("src/dealer.lua")

-- Load input utilities module (for single-press detection)
input_utils = require("src/input_utils")

-- ============================================
-- PALETTE SETUP
-- ============================================
palette_loaded = false

function setup_palette()
	if not palette_loaded then
		-- Try loading palette from project folder
		local palette_data = fetch("toybox_palette.pal")

		if not palette_data then
			-- Try alternate path
			palette_data = fetch("/ram/cart/toybox_palette.pal")
			printh("Trying /ram/cart/toybox_palette.pal...")
		end

		if palette_data then
			printh("Palette loaded! Type: " .. type(palette_data))

			local color_count = 0
			-- Load all 64 colors from palette
			for i = 0, 63 do
				local color = palette_data[i]
				if color then
					color_count = color_count + 1
					-- Apply using pal() with p=2 to set RGB display palette
					pal(i, color, 2)
				end
			end

			-- Set color 0 as transparent for sprites
			palt(0, true)
			palette_loaded = true
			printh("SUCCESS: " .. color_count .. " colors loaded and applied!")
		else
			printh("WARNING: Could not load toybox_palette.pal from any path")
		end
	end
end

-- ============================================
-- GAME STATE (globals used by modules)
-- ============================================
cam_x, cam_y = 480, 480  -- camera world position (start centered on player)

game = {
	player = {
		x = 480,
		y = 480,
		facing_right = true,
		facing_dir = "east",  -- "north", "south", "east" (east/west use flip_x)
		walk_frame = 0,
		-- Combat/popularity system
		health = PLAYER_CONFIG.max_health,
		popularity = PLAYER_CONFIG.starting_popularity,
		-- Money system
		money = PLAYER_CONFIG.starting_money,
		-- Weapon inventory
		weapons = {},         -- List of owned weapon keys (e.g., {"hammer", "pistol"})
		ammo = {},            -- Ammo counts by weapon key (e.g., {pistol = 30})
		equipped_index = 0,   -- 0 = no weapon, 1+ = index into weapons
		is_attacking = false,
		attack_timer = 0,
		attack_angle = 0,     -- For melee swing rotation
		fire_cooldown = 0,    -- Cooldown timer for ranged weapons
	}
}

-- List of NPCs that are fans/lovers (by NPC reference)
-- Fans: NPCs who recognized the player, won't flee, show heart
-- Lovers: Fans who filled love meter, always show heart, can heal
fans = {}  -- { npc = npc_ref, is_lover = false, love = 0 }
lovers = {}  -- separate list for quick lookup on minimap

-- Dialog system state
dialog = {
	active = false,
	npc = nil,           -- NPC we're talking to
	fan_data = nil,      -- fan data for the NPC
	options = {},        -- current dialog options
	selected = 1,        -- currently selected option
	phase = "choose",    -- "choose" = picking line, "result" = showing result
	result_text = "",    -- text to show after choosing
	result_timer = 0,    -- time until dialog closes
}

-- Popularity change display (shows +/- text near bar)
popularity_change = {
	amount = 0,         -- amount to display (+5 or -2 etc)
	end_time = 0,       -- when to stop showing
}

-- Helper function to change popularity and show feedback
function change_popularity(amount)
	game.player.popularity = max(0, min(PLAYER_CONFIG.max_popularity, game.player.popularity + amount))
	popularity_change.amount = amount
	popularity_change.end_time = time() + PLAYER_CONFIG.popularity_text_duration
end

-- Player death state
player_dead = false
death_timer = 0
death_fade = 0  -- 0-1 for fade effect

-- Handle player death
function handle_player_death()
	if player_dead then return end

	player_dead = true
	death_timer = time()
	death_fade = 0

	-- Lose half money
	game.player.money = flr(game.player.money / 2)

	-- Lose 20 popularity
	change_popularity(-20)

	-- Clear all lovers (romantic partners lost)
	lovers = {}
	for _, fan in ipairs(fans) do
		fan.is_lover = false
		fan.love = 0
	end

	-- Reset hostile dealers
	if arms_dealers then
		for _, dealer in ipairs(arms_dealers) do
			if dealer.state == "hostile" then
				dealer.state = "idle"
			end
		end
	end

	-- Close any open dialogs/shop
	if dialog then dialog.active = false end
	if shop then shop.active = false end

	-- Exit vehicle if in one
	if player_vehicle then
		player_vehicle.is_player_vehicle = false
		player_vehicle = nil
	end
end

-- Update death sequence
function update_death()
	if not player_dead then
		-- Check if player should die
		if game.player.health <= 0 then
			handle_player_death()
		end
		return
	end

	local elapsed = time() - death_timer

	-- Fade to black over 1 second
	if elapsed < 1 then
		death_fade = elapsed
	-- Show "WASTED" for 1 second
	elseif elapsed < 2 then
		death_fade = 1
	-- Fade back in over 1 second
	elseif elapsed < 3 then
		death_fade = 1 - (elapsed - 2)
		-- Respawn player at start position (once, at start of fade-in)
		if elapsed < 2.1 then
			game.player.x = 0
			game.player.y = 0
			game.player.health = PLAYER_CONFIG.max_health
			cam_x = 0
			cam_y = 0
		end
	else
		-- Death sequence complete
		player_dead = false
		death_fade = 0
	end
end

-- Draw death overlay
function draw_death_overlay()
	if not player_dead and death_fade <= 0 then return end

	-- Draw black overlay with fade
	local alpha = flr(death_fade * 255)
	if alpha > 0 then
		-- Use dark color for fade effect
		for y = 0, SCREEN_H - 1, 4 do
			for x = 0, SCREEN_W - 1, 4 do
				if rnd(255) < alpha then
					rectfill(x, y, x + 3, y + 3, 0)
				end
			end
		end
	end

	-- Show "WASTED" text
	local elapsed = time() - death_timer
	if elapsed > 1 and elapsed < 2.5 then
		local text = "WASTED"
		local tw = #text * 8  -- Larger font assumption
		print_shadow(text, (SCREEN_W - tw) / 2, SCREEN_H / 2 - 8, 8)

		-- Show what was lost
		local loss_text = "Lost money and popularity"
		local ltw = #loss_text * 4
		print_shadow(loss_text, (SCREEN_W - ltw) / 2, SCREEN_H / 2 + 8, 6)
	end
end

-- Player shadow
SHADOW_RADIUS = 37
shadow_coltab_mode = 56  -- current color table sprite (cycles 56, 57, 58)

-- Night mode / Day-night cycle
night_mode = false
night_mask = nil  -- userdata for night overlay mask
street_lights_on = false  -- street lights only on at full night

-- Day-night cycle state
day_night_state = "day"  -- "day", "to_night", "night", "to_day"
day_night_transition_index = 0  -- current index in transition sequence
day_night_transition_timer = 0  -- frames until next step

-- Buildings created from level data in config
buildings = {}

-- Nearby entity caches (computed once per frame for optimization)
-- Avoids iterating through full NPC/vehicle lists multiple times
nearby_fans = {}      -- { npc, fan_data, dist } for fans within interaction range
nearby_fan = nil      -- closest fan NPC reference (for quick access)
nearby_fan_data = nil -- closest fan's data

-- ============================================
-- MAIN CALLBACKS
-- ============================================

-- Rendering mode: "tline3d" (batched scanlines, fastest) or "tri" (batched textri)
render_mode = "tline3d"

-- Ground rendering mode: "scanline" (batched tline3d)
ground_mode = "scanline"

-- Draw with color table applied - pass a function to draw inside
function draw_with_colortable(color_table_sprite, draw_fn)
	local sprite = get_spr(color_table_sprite)
	memmap(0x8000, sprite)
	poke(0x550b, 0x3f)  -- enable color table for shapes
	draw_fn()  -- call the drawing function
	unmap(sprite)
	poke(0x550b, 0x00)  -- disable color table
end

-- Apply just one row of a color table
function apply_colortable_row(color_table_sprite, color_row)
	local sprite = get_spr(color_table_sprite)
	local address = 0x8000 + color_row * 64
	for x = 0, 63 do
		local c = sprite:get(x, color_row)
		poke(address + x, c)
	end
	poke(0x550b, 0x3f)  -- enable color table for shapes
end

-- Reset color table (disable it)
function reset_colortable()
	poke(0x550b, 0x00)
end

-- Update day-night cycle transitions
function update_day_night_cycle()
	if day_night_state == "to_night" then
		-- Transitioning to night
		day_night_transition_timer = day_night_transition_timer - 1
		if day_night_transition_timer <= 0 then
			day_night_transition_index = day_night_transition_index + 1
			if day_night_transition_index > #NIGHT_CONFIG.day_to_night then
				-- Transition complete - now it's night
				day_night_state = "night"
				street_lights_on = true  -- turn on street lights
				printh("Night time! Street lights ON")
			else
				-- Apply next color in sequence
				NIGHT_CONFIG.darken_color = NIGHT_CONFIG.day_to_night[day_night_transition_index]
				day_night_transition_timer = NIGHT_CONFIG.transition_speed
				printh("Transition to night: " .. NIGHT_CONFIG.darken_color)
			end
		end
	elseif day_night_state == "to_day" then
		-- Transitioning to day
		day_night_transition_timer = day_night_transition_timer - 1
		if day_night_transition_timer <= 0 then
			day_night_transition_index = day_night_transition_index + 1
			if day_night_transition_index > #NIGHT_CONFIG.night_to_day then
				-- Transition complete - now it's day
				day_night_state = "day"
				night_mode = false  -- disable overlay completely
				printh("Day time!")
			else
				-- Apply next color in sequence
				NIGHT_CONFIG.darken_color = NIGHT_CONFIG.night_to_day[day_night_transition_index]
				day_night_transition_timer = NIGHT_CONFIG.transition_speed
				printh("Transition to day: " .. NIGHT_CONFIG.darken_color)
			end
		end
	end
end

-- Start transitioning to night or day
function toggle_day_night()
	if day_night_state == "day" then
		-- Start transition to night
		day_night_state = "to_night"
		day_night_transition_index = 1
		day_night_transition_timer = NIGHT_CONFIG.transition_speed
		night_mode = true  -- enable overlay
		street_lights_on = false  -- lights off during transition
		NIGHT_CONFIG.darken_color = NIGHT_CONFIG.day_to_night[1]
		printh("Starting transition to night: " .. NIGHT_CONFIG.darken_color)
	elseif day_night_state == "night" then
		-- Start transition to day
		day_night_state = "to_day"
		day_night_transition_index = 1
		day_night_transition_timer = NIGHT_CONFIG.transition_speed
		street_lights_on = false  -- turn off street lights immediately
		NIGHT_CONFIG.darken_color = NIGHT_CONFIG.night_to_day[1]
		printh("Starting transition to day (lights OFF): " .. NIGHT_CONFIG.darken_color)
	end
	-- If already transitioning, ignore the press
end

-- Night mode settings (initialized from config in _init)

-- Check if a position is on any road surface (not sidewalk)
function is_on_any_road_surface(x, y)
	for _, road in ipairs(ROADS) do
		local half_road = road.width / 2
		if road.direction == "horizontal" then
			if y >= road.y - half_road and y <= road.y + half_road and
			   x >= road.x1 and x <= road.x2 then
				return true
			end
		elseif road.direction == "vertical" then
			if x >= road.x - half_road and x <= road.x + half_road and
			   y >= road.y1 and y <= road.y2 then
				return true
			end
		end
	end
	return false
end

-- ============================================
-- TRAFFIC LIGHT SYSTEM
-- ============================================
-- Global traffic state (all intersections sync)
-- Phases: "ns" = N-S green, "ns_yellow" = N-S yellow, "ew" = E-W green, "ew_yellow" = E-W yellow
traffic_phase = "ns"  -- current phase
traffic_timer = 0     -- time of last phase change

-- Check if a position is at an intersection (where two roads cross)
function is_at_intersection(x, y)
	local half_road = ROAD_CONFIG.road_width / 2
	local on_horizontal = false
	local on_vertical = false

	for _, road in ipairs(ROADS) do
		if road.direction == "horizontal" then
			if y >= road.y - half_road and y <= road.y + half_road and
			   x >= road.x1 and x <= road.x2 then
				on_horizontal = true
			end
		elseif road.direction == "vertical" then
			if x >= road.x - half_road and x <= road.x + half_road and
			   y >= road.y1 and y <= road.y2 then
				on_vertical = true
			end
		end
	end

	return on_horizontal and on_vertical
end

-- Get all intersection center points (where roads cross)
function get_intersections()
	local intersections = {}
	local half_road = ROAD_CONFIG.road_width / 2

	-- Find all horizontal roads
	local h_roads = {}
	local v_roads = {}
	for _, road in ipairs(ROADS) do
		if road.direction == "horizontal" then
			add(h_roads, road)
		elseif road.direction == "vertical" then
			add(v_roads, road)
		end
	end

	-- Check each horizontal/vertical pair for intersection
	for _, h_road in ipairs(h_roads) do
		for _, v_road in ipairs(v_roads) do
			-- Check if they actually cross
			local h_y = h_road.y
			local v_x = v_road.x

			-- Horizontal road spans x1 to x2, check if v_x is in range
			-- Vertical road spans y1 to y2, check if h_y is in range
			if v_x >= h_road.x1 and v_x <= h_road.x2 and
			   h_y >= v_road.y1 and h_y <= v_road.y2 then
				add(intersections, { x = v_x, y = h_y })
			end
		end
	end

	return intersections
end

-- Update traffic light phase
-- Cycle: ns (green) -> ns_yellow -> ew (green) -> ew_yellow -> ns ...
function update_traffic_lights()
	local now = time()
	local cycle_time = TRAFFIC_CONFIG.cycle_time
	local yellow_time = TRAFFIC_CONFIG.yellow_time

	local all_red_time = TRAFFIC_CONFIG.all_red_time

	if traffic_phase == "ns" then
		-- N-S is green, check if time for yellow
		if now >= traffic_timer + cycle_time then
			traffic_timer = now
			traffic_phase = "ns_yellow"
		end
	elseif traffic_phase == "ns_yellow" then
		-- N-S is yellow, check if time for all-red
		if now >= traffic_timer + yellow_time then
			traffic_timer = now
			traffic_phase = "all_red_ns_to_ew"
		end
	elseif traffic_phase == "all_red_ns_to_ew" then
		-- All red (after N-S), check if time to switch to E-W green
		if now >= traffic_timer + all_red_time then
			traffic_timer = now
			traffic_phase = "ew"
		end
	elseif traffic_phase == "ew" then
		-- E-W is green, check if time for yellow
		if now >= traffic_timer + cycle_time then
			traffic_timer = now
			traffic_phase = "ew_yellow"
		end
	elseif traffic_phase == "ew_yellow" then
		-- E-W is yellow, check if time for all-red
		if now >= traffic_timer + yellow_time then
			traffic_timer = now
			traffic_phase = "all_red_ew_to_ns"
		end
	elseif traffic_phase == "all_red_ew_to_ns" then
		-- All red (after E-W), check if time to switch to N-S green
		if now >= traffic_timer + all_red_time then
			traffic_timer = now
			traffic_phase = "ns"
		end
	end
end

-- Check if NPC can cross in given direction based on current traffic phase
function can_cross_in_direction(direction)
	-- "ns" phase = north/south traffic moves (vertical crossing allowed)
	-- "ew" phase = east/west traffic moves (horizontal crossing allowed)
	-- Yellow phases: don't start crossing (treat as red for new crossings)
	if traffic_phase == "ns" then
		return direction == "north" or direction == "south"
	elseif traffic_phase == "ew" then
		return direction == "east" or direction == "west"
	else
		-- Yellow phase - don't start new crossings
		return false
	end
end

-- Get the signal sprite for a light based on which direction it controls
-- ns_light = true means this light controls north-south traffic
-- N-S lights show GREEN when N-S phase (N-S traffic can go)
-- E-W lights show GREEN when E-W phase (E-W traffic can go)
-- All-red phases show RED for both directions (safety buffer between switches)
-- Sprite orientation is handled by flip_x/flip_y flags when drawing
function get_signal_sprite(ns_light, corner)
	local sprites

	-- All-red phases: both directions show red
	if traffic_phase == "all_red_ns_to_ew" or traffic_phase == "all_red_ew_to_ns" then
		if ns_light then
			return TRAFFIC_CONFIG.signal_sprites_ns.red
		else
			return TRAFFIC_CONFIG.signal_sprites_ew.red
		end
	end

	if ns_light then
		-- N-S traffic light uses N-S sprite set
		-- Shows GREEN when N-S phase (N-S traffic can go)
		-- Shows RED when E-W phase (E-W traffic has right of way)
		sprites = TRAFFIC_CONFIG.signal_sprites_ns
		if traffic_phase == "ns" then
			return sprites.green
		elseif traffic_phase == "ns_yellow" then
			return sprites.yellow
		else
			return sprites.red
		end
	else
		-- E-W traffic light uses E-W sprite set
		-- Shows GREEN when E-W phase (E-W traffic can go)
		-- Shows RED when N-S phase (N-S traffic has right of way)
		sprites = TRAFFIC_CONFIG.signal_sprites_ew
		if traffic_phase == "ew" then
			return sprites.green
		elseif traffic_phase == "ew_yellow" then
			return sprites.yellow
		else
			return sprites.red
		end
	end
end

-- Generate street lights at sidewalk corners
-- A sidewalk corner is where a sidewalk tile has exactly 2 adjacent sidewalk tiles
-- that form an L-shape (corner pattern)
-- Traffic lights are placed at these corners
function generate_street_lights()
	local lights = {}
	local light_set = {}  -- track unique positions to avoid duplicates
	local tile_size = MAP_CONFIG.tile_size
	local map_w = MAP_CONFIG.map_width
	local map_h = MAP_CONFIG.map_height
	local tiles = WORLD_DATA.tiles

	local function add_light(x, y, is_traffic_light, corner, flip_x, flip_y)
		local key = flr(x) .. "," .. flr(y)
		if not light_set[key] then
			light_set[key] = true
			add(lights, {
				x = x,
				y = y,
				is_traffic_light = is_traffic_light or false,
				corner = corner,  -- "nw", "ne", "sw", "se" for traffic lights
				flip_x = flip_x or false,
				flip_y = flip_y or false,
			})
		end
	end

	-- Helper to check if a tile is sidewalk
	local function is_sidewalk(mx, my)
		if mx < 0 or mx >= map_w or my < 0 or my >= map_h then
			return false
		end
		local tile = tiles:get(mx, my)
		return tile == MAP_TILE_SIDEWALK_NS or tile == MAP_TILE_SIDEWALK_EW
	end

	-- Scan all tiles for sidewalk corners
	for my = 0, map_h - 1 do
		for mx = 0, map_w - 1 do
			if is_sidewalk(mx, my) then
				-- Check adjacent tiles (N, S, E, W)
				local has_north = is_sidewalk(mx, my - 1)
				local has_south = is_sidewalk(mx, my + 1)
				local has_west = is_sidewalk(mx - 1, my)
				local has_east = is_sidewalk(mx + 1, my)

				-- Detect corner patterns (exactly 2 adjacent sidewalks forming an L)
				local corner = nil

				-- NW corner: has sidewalk to south AND east (L opens to SE)
				if has_south and has_east and not has_north and not has_west then
					corner = "nw"
				-- NE corner: has sidewalk to south AND west (L opens to SW)
				elseif has_south and has_west and not has_north and not has_east then
					corner = "ne"
				-- SW corner: has sidewalk to north AND east (L opens to NE)
				elseif has_north and has_east and not has_south and not has_west then
					corner = "sw"
				-- SE corner: has sidewalk to north AND west (L opens to NW)
				elseif has_north and has_west and not has_south and not has_east then
					corner = "se"
				end

				if corner then
					-- Convert map coords to world coords (center of tile)
					local wx, wy = map_to_world(mx, my)
					wx = wx + tile_size / 2
					wy = wy + tile_size / 2

					-- All sidewalk corners get traffic lights
					add_light(wx, wy, true, corner, false, false)
				end
			end
		end
	end

	printh("Generated " .. #lights .. " traffic lights at sidewalk corners")
	return lights
end

-- Street light positions (generated from roads)
STREET_LIGHTS = {}

-- Draw minimap using sprite 255 map directly
-- Coordinate system: world (0,0) = map center (128,128)
function draw_minimap()
	local cfg = MINIMAP_CONFIG
	if not cfg.enabled then return end

	local mx = cfg.x
	local my = cfg.y
	local mw = cfg.width
	local mh = cfg.height

	-- Get map sprite
	local map_spr = get_spr(MAP_CONFIG.sprite_id)
	local map_w = MAP_CONFIG.map_width
	local map_h = MAP_CONFIG.map_height
	local tile_size = MAP_CONFIG.tile_size
	local half_map_w = map_w / 2
	local half_map_h = map_h / 2

	-- Calculate player position in map coordinates (world 0,0 = map 128,128)
	local px = game.player.x / tile_size + half_map_w
	local py = game.player.y / tile_size + half_map_h

	-- Calculate visible region of map (centered on player)
	local half_mw = mw / 2
	local half_mh = mh / 2

	-- Draw border
	rectfill(mx - 1, my - 1, mx + mw + 1, my + mh + 1, cfg.border_color)

	-- Calculate source rectangle (clamp to map bounds)
	local src_x = flr(px - half_mw)
	local src_y = flr(py - half_mh)
	local src_w = mw
	local src_h = mh

	-- Calculate destination offset for clamping
	local dst_x = mx
	local dst_y = my

	-- Clamp left edge
	if src_x < 0 then
		dst_x = mx - src_x
		src_w = src_w + src_x
		src_x = 0
	end

	-- Clamp top edge
	if src_y < 0 then
		dst_y = my - src_y
		src_h = src_h + src_y
		src_y = 0
	end

	-- Clamp right edge
	if src_x + src_w > map_w then
		src_w = map_w - src_x
	end

	-- Clamp bottom edge
	if src_y + src_h > map_h then
		src_h = map_h - src_y
	end

	-- Clip to minimap area
	clip(mx, my, mw + 1, mh + 1)

	-- Fill background with water color (for areas outside map)
	rectfill(mx, my, mx + mw, my + mh, cfg.water_color)

	-- Draw the map sprite section (only if valid size)
	if src_w > 0 and src_h > 0 then
		sspr(map_spr, src_x, src_y, src_w, src_h, dst_x, dst_y)
	end

	-- Draw buildings on top (convert world coords to minimap coords)
	if cfg.show_buildings then
		for _, b in ipairs(buildings) do
			local bx1 = mx + (b.x / tile_size + half_map_w - px + half_mw)
			local by1 = my + (b.y / tile_size + half_map_h - py + half_mh)
			local bx2 = mx + ((b.x + b.w) / tile_size + half_map_w - px + half_mw)
			local by2 = my + ((b.y + b.h) / tile_size + half_map_h - py + half_mh)
			rectfill(bx1, by1, bx2, by2, cfg.building_color)
		end
	end

	-- Draw NPCs (and lovers in special color)
	if cfg.show_npcs then
		for _, npc in ipairs(npcs) do
			local nx = mx + (npc.x / tile_size + half_map_w - px + half_mw)
			local ny = my + (npc.y / tile_size + half_map_h - py + half_mh)
			if nx >= mx and nx <= mx + mw and ny >= my and ny <= my + mh then
				-- Check if this NPC is a lover (use special color)
				local color = cfg.npc_color
				if is_npc_lover(npc) then
					color = PLAYER_CONFIG.lover_map_color
				end
				pset(nx, ny, color)
			end
		end
	end

	-- Always draw lovers on minimap (even if NPCs are disabled)
	for _, lover_npc in ipairs(lovers) do
		local lx = mx + (lover_npc.x / tile_size + half_map_w - px + half_mw)
		local ly = my + (lover_npc.y / tile_size + half_map_h - py + half_mh)
		if lx >= mx and lx <= mx + mw and ly >= my and ly <= my + mh then
			pset(lx, ly, PLAYER_CONFIG.lover_map_color)
		end
	end

	-- Draw vehicles
	for _, vehicle in ipairs(vehicles) do
		if vehicle.state ~= "destroyed" then
			local is_boat = vehicle.vtype.water_only
			-- Check if this type should be shown
			if (is_boat and cfg.show_boats) or (not is_boat and cfg.show_vehicles) then
				local vx = mx + (vehicle.x / tile_size + half_map_w - px + half_mw)
				local vy = my + (vehicle.y / tile_size + half_map_h - py + half_mh)
				if vx >= mx and vx <= mx + mw and vy >= my and vy <= my + mh then
					local color = is_boat and cfg.boat_color or cfg.vehicle_color
					pset(vx, vy, color)
				end
			end
		end
	end

	-- Draw arms dealers (always visible on minimap)
	if arms_dealers then
		for _, dealer in ipairs(arms_dealers) do
			if dealer.state ~= "dead" then
				local dx = mx + (dealer.x / tile_size + half_map_w - px + half_mw)
				local dy = my + (dealer.y / tile_size + half_map_h - py + half_mh)
				-- Always draw dealers, even if off edge of minimap (clipped anyway)
				circfill(dx, dy, ARMS_DEALER_CONFIG.minimap_size, ARMS_DEALER_CONFIG.minimap_color)
			end
		end
	end

	-- Draw player (center of minimap)
	if cfg.show_player then
		local player_mx = mx + half_mw
		local player_my = my + half_mh
		circfill(player_mx, player_my, cfg.player_size, cfg.player_color)
	end

	-- Reset clip
	clip()
end

-- Pre-allocated userdata for batched circfill (x, y, r, color) x max lights on screen
-- Increased for double-sided sidewalk lights
local MAX_VISIBLE_LIGHTS = 64
local light_batch = userdata("f64", 4, MAX_VISIBLE_LIGHTS)

-- Draw night mode overlay - efficient method
-- Draw to night_mask userdata, then render as sprite with color table
function draw_night_mode(player_sx, player_sy)
	if not night_mode then return end

	-- Get config values
	local player_radius = NIGHT_CONFIG.player_light_radius
	local street_radius = NIGHT_CONFIG.street_light_radius
	local darken_color = NIGHT_CONFIG.darken_color
	local ambient_color = NIGHT_CONFIG.ambient_color

	-- First pass: draw ambient tint over everything (no holes)
	local coltab_sprite = get_spr(shadow_coltab_mode)
	memmap(0x8000, coltab_sprite)
	poke(0x550b, 0x3f)  -- enable color table
	rectfill(0, 0, SCREEN_W, SCREEN_H, ambient_color)
	unmap(coltab_sprite)
	poke(0x550b, 0x00)

	-- Second pass: draw darker areas with light holes
	-- Set draw target to night mask
	set_draw_target(night_mask)

	-- Fill with darken color
	cls(darken_color)

	-- Punch out light circles with transparent color (0)
	-- Player light follows player position
	circfill(player_sx, player_sy, player_radius, 0)

	-- Street lights (only when fully night) - batched circfill
	if street_lights_on then
		local light_count = 0
		local margin = street_radius

		-- Build batch of visible lights
		for _, light in ipairs(STREET_LIGHTS) do
			local sx, sy = world_to_screen(light.x, light.y)
			-- Only include if on screen (with margin for the radius)
			if sx > -margin and sx < SCREEN_W + margin and sy > -margin and sy < SCREEN_H + margin then
				if light_count < MAX_VISIBLE_LIGHTS then
					-- Pack into userdata: x, y, radius, color (row = light_count)
					local row = light_count * 4
					light_batch[row] = sx
					light_batch[row + 1] = sy
					light_batch[row + 2] = street_radius
					light_batch[row + 3] = 0  -- transparent color to punch holes
					light_count = light_count + 1
				end
			end
		end

		-- Draw all lights in one batched call
		if light_count > 0 then
			circfill(light_batch, 0, light_count)
		end
	end

	-- Reset draw target to screen
	set_draw_target()

	-- Apply color table and draw the mask
	coltab_sprite = get_spr(shadow_coltab_mode)
	memmap(0x8000, coltab_sprite)
	poke(0x550b, 0x3f)  -- enable color table

	-- Ensure color 0 is transparent when drawing sprite
	palt(0, true)

	-- Draw mask as sprite (color 0 is transparent, darken color gets darkened)
	spr(night_mask, 0, 0)

	-- Reset color table and transparency
	palt(0, true)  -- keep 0 transparent (default)
	unmap(coltab_sprite)
	poke(0x550b, 0x00)
end

function _init()
	setup_palette()

	-- Create night mask sprite (screen-sized)
	night_mask = userdata("u8", SCREEN_W, SCREEN_H)

	-- Initialize world from map sprite 255
	-- This parses the map, generates ROADS, COUNTRYSIDE_ROADS, and LEVEL_BUILDINGS
	init_world_from_map()

	-- Create buildings from generated level data
	buildings = create_buildings_from_level()

	-- Set player position at world center (0,0) which is map center (128,128)
	game.player.x = 0
	game.player.y = 0
	cam_x = 0
	cam_y = 0
	printh("Player starting at: 0, 0 (map center)")

	-- Generate street lights along roads
	STREET_LIGHTS = generate_street_lights()
	printh("Generated " .. #STREET_LIGHTS .. " street lights")

	-- Generate countryside flora
	generate_flora()

	-- Spawn NPCs on roads
	-- Mode 1 uses spawn_count at random roads, mode 2 spawns target_npc_count near player
	if NPC_CONFIG.update_mode == 2 then
		spawn_npcs(NPC_CONFIG.target_npc_count, game.player.x, game.player.y)
	else
		spawn_npcs(NPC_CONFIG.spawn_count)
	end

	-- Spawn vehicles on roads and boats on water
	spawn_vehicles()

	-- Spawn arms dealers
	spawn_arms_dealers()

	-- Enable profiler (detailed=true, cpu=true)
	profile.enabled(true, true)

	printh("Grand Theft Picotron initialized!")
	printh("Use arrow keys to move")
	printh("Loaded " .. #buildings .. " buildings")
	printh("Press X to toggle render mode (tline3d/tri)")
end

function _update()
	profile("input")
	handle_input()
	profile("input")

	-- Update water animation
	update_water_animation()

	-- Update traffic lights
	update_traffic_lights()

	-- Update NPCs (pass player position for scare behavior)
	profile("npcs_update")
	update_npcs(game.player.x, game.player.y)
	profile("npcs_update")

	-- Update vehicles
	profile("vehicles_update")
	update_vehicles()
	profile("vehicles_update")

	-- Update weapons and projectiles
	update_projectiles()
	update_melee_attack()

	-- Update arms dealers
	update_arms_dealers()
	update_shop()
	check_dealer_interaction()

	-- If player is in a vehicle, sync player position to vehicle
	if player_vehicle then
		game.player.x = player_vehicle.x
		game.player.y = player_vehicle.y
	end

	-- Toggle render mode with X button
	if btnp(5) then
		if render_mode == "tline3d" then
			render_mode = "tri"
		else
			render_mode = "tline3d"
		end
		printh("Render mode: " .. render_mode)
	end

	-- Debug: cycle shadow color table with M key
	if DEBUG_CONFIG.enabled and keyp("m") then
		shadow_coltab_mode = shadow_coltab_mode + 1
		if shadow_coltab_mode > 59 then
			shadow_coltab_mode = 56
		end
		printh("Shadow color table: " .. shadow_coltab_mode)
	end

	-- Toggle day/night cycle with N key
	if keyp("n") then
		toggle_day_night()
	end

	-- Update day-night cycle transitions
	update_day_night_cycle()

	-- Update nearby entity cache (once per frame)
	update_nearby_cache()

	-- Check for fan interaction and update dialog
	check_fan_interaction()
	update_dialog()

	-- Update death sequence (checks for player death, handles respawn)
	update_death()
end

-- Update nearby entity cache (called once per frame)
-- This avoids iterating through full lists multiple times for interaction checks
-- Also refreshes heart show timer for nearby fans
function update_nearby_cache()
	local px, py = game.player.x, game.player.y
	local interact_range = PLAYER_CONFIG.fan_detect_distance * 2
	local now = time()
	local heart_duration = PLAYER_CONFIG.heart_show_duration

	-- Clear caches
	nearby_fans = {}
	nearby_fan = nil
	nearby_fan_data = nil

	-- Skip if in vehicle (can't interact with fans)
	if player_vehicle then return end

	-- Find all nearby fans and track the closest one
	local best_dist = interact_range
	for _, fan_data in ipairs(fans) do
		local npc = fan_data.npc
		local dx = npc.x - px
		local dy = npc.y - py
		local dist = sqrt(dx * dx + dy * dy)
		if dist < interact_range then
			add(nearby_fans, { npc = npc, fan_data = fan_data, dist = dist })
			-- Refresh heart show timer when player is nearby
			fan_data.heart_show_until = now + heart_duration
			if dist < best_dist then
				best_dist = dist
				nearby_fan = npc
				nearby_fan_data = fan_data
			end
		end
	end
end

-- Print text with drop shadow for legibility
function print_shadow(text, x, y, col, shadow_col)
	shadow_col = shadow_col or 0  -- default black shadow
	print(text, x + 1, y + 1, shadow_col)
	print(text, x, y, col)
end

-- Draw player health bar
function draw_health_bar()
	local cfg = PLAYER_CONFIG
	local x = cfg.health_bar_x
	local y = cfg.health_bar_y
	local w = cfg.health_bar_width
	local h = cfg.health_bar_height

	-- Calculate health percentage
	local health_pct = game.player.health / cfg.max_health
	health_pct = max(0, min(1, health_pct))  -- clamp 0-1
	local fill_w = flr(w * health_pct)

	-- Draw label
	print_shadow("HP", x, y - 8, cfg.health_color)

	-- Draw border
	rect(x - 1, y - 1, x + w, y + h, cfg.health_border_color)
	-- Draw background
	rectfill(x, y, x + w - 1, y + h - 1, cfg.health_bg_color)
	-- Draw health fill
	if fill_w > 0 then
		rectfill(x, y, x + fill_w - 1, y + h - 1, cfg.health_color)
	end
end

-- Draw player popularity bar
function draw_popularity_bar()
	local cfg = PLAYER_CONFIG
	local x = cfg.popularity_bar_x
	local y = cfg.popularity_bar_y
	local w = cfg.popularity_bar_width
	local h = cfg.popularity_bar_height

	-- Calculate popularity percentage
	local pop_pct = game.player.popularity / cfg.max_popularity
	pop_pct = max(0, min(1, pop_pct))  -- clamp 0-1
	local fill_w = flr(w * pop_pct)

	-- Draw label
	print_shadow("POP", x, y - 8, cfg.popularity_color)

	-- Draw border
	rect(x - 1, y - 1, x + w, y + h, cfg.popularity_border_color)
	-- Draw background
	rectfill(x, y, x + w - 1, y + h - 1, cfg.popularity_bg_color)
	-- Draw popularity fill
	if fill_w > 0 then
		rectfill(x, y, x + fill_w - 1, y + h - 1, cfg.popularity_color)
	end

	-- Draw popularity change text (if active)
	if time() < popularity_change.end_time then
		local amount = popularity_change.amount
		local text = (amount >= 0) and ("+" .. amount) or tostr(amount)
		local col = (amount >= 0) and cfg.popularity_gain_color or cfg.popularity_loss_color
		print_shadow(text, x + w + 4, y - 2, col)
	end
end

-- Draw lover count under popularity bar
function draw_lover_count()
	local cfg = PLAYER_CONFIG
	local x = cfg.popularity_bar_x
	local y = cfg.popularity_bar_y + cfg.popularity_bar_height + 4  -- below popularity bar

	-- Draw heart icon and count
	local count = #lovers
	local heart_sprite = cfg.heart_sprite
	-- Draw small heart sprite (scaled down or just use spr)
	spr(heart_sprite, x, y - 2)
	-- Draw count next to heart
	print_shadow("x" .. count, x + 10, y, cfg.popularity_color)
end

-- Draw player money display
function draw_money()
	local cfg = PLAYER_CONFIG
	local x = cfg.money_display_x
	local y = cfg.money_display_y
	-- Draw money as "$XXX" text in green
	print_shadow("$" .. game.player.money, x, y, cfg.money_color)
end

-- Find the nearest fan/lover NPC within interaction range
-- Uses cached values computed in update_nearby_cache()
function find_nearby_fan()
	return nearby_fan, nearby_fan_data
end

-- Helper: shuffle an array in place
function shuffle_array(arr)
	for i = #arr, 2, -1 do
		local j = flr(rnd(i)) + 1
		arr[i], arr[j] = arr[j], arr[i]
	end
	return arr
end

-- Helper: pick random items from array (without replacement)
function pick_random_items(arr, count)
	local copy = {}
	for _, v in ipairs(arr) do add(copy, v) end
	shuffle_array(copy)
	local result = {}
	for i = 1, min(count, #copy) do
		add(result, copy[i])
	end
	return result
end

-- Start dialog with a fan
function start_dialog(npc, fan_data)
	dialog.active = true
	dialog.npc = npc
	dialog.fan_data = fan_data
	dialog.selected = 1
	dialog.phase = "choose"
	dialog.love_gained = 0  -- track love gained this dialog for display

	-- Stop the NPC from moving during dialog
	npc.in_dialog = true

	-- Initialize failure count if not set
	if not fan_data.failures then
		fan_data.failures = 0
	end

	-- Build options based on fan/lover status
	dialog.options = {}

	if fan_data.is_lover then
		-- Lovers always have heal option
		add(dialog.options, { text = "Heal me!", action = "heal" })
		add(dialog.options, { text = "Nevermind", action = "cancel" })
	else
		-- Non-lovers get flirting options based on archetype
		local archetype = fan_data.archetype or "friendly"
		local all_options = PLAYER_CONFIG.dialog_options

		-- Get the archetype-matching options
		local matching_options = all_options[archetype] or all_options.friendly

		-- Get one random option from the matching archetype (guaranteed)
		local archetype_pick = matching_options[flr(rnd(#matching_options)) + 1]
		-- Mark it as matching the archetype
		archetype_pick = {
			text = archetype_pick.text,
			response = archetype_pick.response,
			love = archetype_pick.love,
			is_correct = true  -- this is the right choice
		}

		-- Build pool of options from OTHER archetypes
		local other_pool = {}
		for arch, opts in pairs(all_options) do
			if arch ~= archetype then
				for _, opt in ipairs(opts) do
					add(other_pool, {
						text = opt.text,
						response = opt.response,
						love = opt.love,
						is_correct = false  -- wrong archetype
					})
				end
			end
		end

		-- Pick 2 random options from other archetypes
		local other_picks = pick_random_items(other_pool, 2)

		-- Combine: archetype pick + other picks, then shuffle
		local final_options = { archetype_pick }
		for _, opt in ipairs(other_picks) do
			add(final_options, opt)
		end
		shuffle_array(final_options)

		-- Convert to dialog format
		for _, opt in ipairs(final_options) do
			add(dialog.options, {
				text = opt.text,
				action = "flirt",
				love = opt.love,
				response = opt.response,
				is_correct = opt.is_correct
			})
		end
	end
end

-- Handle dialog option selection
function select_dialog_option()
	local opt = dialog.options[dialog.selected]
	if not opt then return end

	if opt.action == "cancel" then
		-- Clear dialog flag on NPC
		if dialog.npc then dialog.npc.in_dialog = false end
		dialog.active = false
		return
	end

	if opt.action == "heal" then
		-- Heal the player
		game.player.health = min(PLAYER_CONFIG.max_health, game.player.health + PLAYER_CONFIG.heal_amount)
		dialog.phase = "result"
		dialog.result_text = "You feel better! +" .. PLAYER_CONFIG.heal_amount .. " HP"
		dialog.result_timer = time() + 1.5
		return
	end

	-- Flirting action
	if opt.action == "flirt" then
		local fan_data = dialog.fan_data

		-- Check if this is the correct archetype choice
		if opt.is_correct then
			-- Success! Add love
			fan_data.love = fan_data.love + opt.love
			dialog.love_gained = opt.love

			-- Check if love meter is full (becomes a lover)
			if fan_data.love >= PLAYER_CONFIG.love_meter_max then
				fan_data.is_lover = true
				fan_data.love = PLAYER_CONFIG.love_meter_max
				-- Add to lovers list for minimap
				add(lovers, fan_data.npc)
				dialog.phase = "result"
				dialog.result_text = "They're smitten! New lover!"
			else
				-- Show NPC's response with love gain
				dialog.phase = "result"
				dialog.result_text = opt.response or "..."
			end
		else
			-- Wrong choice! Increment failure count
			fan_data.failures = (fan_data.failures or 0) + 1
			dialog.love_gained = 0

			-- Check if they've had enough (3 strikes)
			if fan_data.failures >= PLAYER_CONFIG.max_failures then
				dialog.phase = "result"
				dialog.result_text = "I'm done with you!"
				dialog.result_timer = time() + 1.5
				-- Mark for removal after dialog closes
				dialog.fan_gave_up = true
				return
			else
				-- Show a random failure response
				local responses = PLAYER_CONFIG.failure_responses
				local fail_response = responses[flr(rnd(#responses)) + 1]
				dialog.phase = "result"
				dialog.result_text = fail_response
			end
		end
		dialog.result_timer = time() + 1.5
		return
	end
end

-- Update dialog system
function update_dialog()
	if not dialog.active then return end

	if dialog.phase == "result" then
		-- Wait for result timer
		if time() >= dialog.result_timer then
			-- Clear dialog flag on NPC so they can move again
			if dialog.npc then dialog.npc.in_dialog = false end

			-- Check if fan gave up (3 strikes)
			if dialog.fan_gave_up then
				dialog.fan_gave_up = false
				-- Remove from fans list
				for i, fan_data in ipairs(fans) do
					if fan_data.npc == dialog.npc then
						deli(fans, i)
						break
					end
				end
				-- Make NPC flee and reset their fan_checked so they can become a fan again later
				dialog.npc.state = "fleeing"
				dialog.npc.state_end_time = time() + NPC_CONFIG.flee_duration
				dialog.npc.flee_dir = get_flee_direction(dialog.npc, game.player.x, game.player.y)
				dialog.npc.facing_dir = dialog.npc.flee_dir or dialog.npc.facing_dir
				dialog.npc.fan_checked = false  -- can become a fan again based on popularity
				-- Lose popularity for failing at flirting
				change_popularity(-PLAYER_CONFIG.popularity_loss_flirt_fail)
			end

			dialog.active = false
		end
		return
	end

	-- Navigate options with up/down
	if btnp(2) then  -- up
		dialog.selected = dialog.selected - 1
		if dialog.selected < 1 then dialog.selected = #dialog.options end
	elseif btnp(3) then  -- down
		dialog.selected = dialog.selected + 1
		if dialog.selected > #dialog.options then dialog.selected = 1 end
	end

	-- Select with X or E key (use input_utils for E to share state with check_fan_interaction)
	if btnp(5) or input_utils.key_pressed("e") then
		select_dialog_option()
	end

	-- Cancel with O key
	if btnp(4) then
		dialog.active = false
	end
end

-- Wrap text to fit within max characters per line
-- Returns a table of lines
function wrap_text(text, max_chars)
	local lines = {}
	local current_line = ""

	-- Split text into words manually (avoid string.gmatch)
	local words = split(text, " ", false)
	for _, word in ipairs(words) do
		if #word > 0 then
			if #current_line == 0 then
				current_line = word
			elseif #current_line + 1 + #word <= max_chars then
				current_line = current_line .. " " .. word
			else
				add(lines, current_line)
				current_line = word
			end
		end
	end

	-- Add remaining line
	if #current_line > 0 then
		add(lines, current_line)
	end

	return lines
end

-- Draw dialog box
function draw_dialog()
	if not dialog.active then return end

	local cfg = PLAYER_CONFIG
	local w = cfg.dialog_width
	local max_chars = cfg.dialog_max_chars_per_line
	local line_h = cfg.dialog_line_height
	local x = (SCREEN_W - w) / 2

	-- Calculate height based on content
	local content_height = 0
	local wrapped_options = {}  -- cache wrapped text for options

	if dialog.phase == "result" then
		-- Result phase: wrap result text
		local result_lines = wrap_text(dialog.result_text, max_chars)
		content_height = #result_lines * line_h + 20  -- padding
		if dialog.love_gained and dialog.love_gained > 0 then
			content_height = content_height + 14  -- extra line for love gain
		end
	else
		-- Choose phase: calculate height for all options with wrapping
		for i, opt in ipairs(dialog.options) do
			local prefix = (i == dialog.selected) and "> " or "  "
			local text = prefix .. opt.text
			local lines = wrap_text(text, max_chars)
			wrapped_options[i] = lines
			content_height = content_height + #lines * line_h + 4  -- 4px gap between options
		end
		content_height = content_height + 22  -- padding for love bar area
	end

	-- Add space for love bar if showing
	if dialog.fan_data and not dialog.fan_data.is_lover then
		content_height = content_height + 16
	end

	local h = max(cfg.dialog_height, content_height)
	local y = SCREEN_H - h - 20  -- above bottom of screen

	-- Draw box
	rectfill(x, y, x + w, y + h, cfg.dialog_bg_color)
	rect(x, y, x + w, y + h, cfg.dialog_border_color)

	-- Always show love meter at the top if flirting (not a lover yet)
	local content_start_y = y + 8
	if dialog.fan_data and not dialog.fan_data.is_lover then
		local love_pct = dialog.fan_data.love / cfg.love_meter_max
		local bar_w = w - 16
		local bar_x = x + 8
		local bar_y = y + 4
		-- Background
		rectfill(bar_x, bar_y, bar_x + bar_w, bar_y + 6, 1)
		-- Fill
		if love_pct > 0 then
			rectfill(bar_x, bar_y, bar_x + bar_w * love_pct, bar_y + 6, 14)
		end
		-- Border
		rect(bar_x - 1, bar_y - 1, bar_x + bar_w + 1, bar_y + 7, 6)
		-- Label
		print_shadow("LOVE", bar_x, bar_y - 8, 14)

		-- Show failure count if any
		if dialog.fan_data.failures and dialog.fan_data.failures > 0 then
			local strikes = dialog.fan_data.failures .. "/" .. cfg.max_failures
			print_shadow(strikes, bar_x + bar_w - 16, bar_y - 8, 8)  -- red color for strikes
		end
		content_start_y = bar_y + 14
	end

	if dialog.phase == "result" then
		-- Show result text with wrapping, centered
		local result_lines = wrap_text(dialog.result_text, max_chars)
		local total_text_height = #result_lines * line_h
		local result_y = y + (h - total_text_height) / 2

		for _, line in ipairs(result_lines) do
			local tw = #line * 4
			print(line, x + (w - tw) / 2, result_y, cfg.dialog_text_color)
			result_y = result_y + line_h
		end

		-- Show love gain text below result (if gained love)
		if dialog.love_gained and dialog.love_gained > 0 then
			local love_text = "+" .. dialog.love_gained .. " love"
			local ltw = #love_text * 4
			print(love_text, x + (w - ltw) / 2, result_y + 4, cfg.love_gain_color)
		end
	else
		-- Show options with text wrapping
		local oy = content_start_y
		for i, opt in ipairs(dialog.options) do
			local col = (i == dialog.selected) and cfg.dialog_selected_color or cfg.dialog_option_color
			local prefix = (i == dialog.selected) and "> " or "  "
			local text = prefix .. opt.text
			local lines = wrap_text(text, max_chars)

			for j, line in ipairs(lines) do
				-- Only show prefix on first line
				if j > 1 then
					line = "  " .. line  -- indent continuation lines
				end
				print(line, x + 8, oy, col)
				oy = oy + line_h
			end
			oy = oy + 2  -- small gap between options
		end
	end
end

-- Check for fan interaction (E key near fan)
function check_fan_interaction()
	if dialog.active then return end
	if player_vehicle then return end  -- can't talk while in vehicle

	-- Use input_utils.key_pressed to prevent E key from also selecting dialog option
	if input_utils.key_pressed("e") then
		local npc, fan_data = find_nearby_fan()
		if npc and fan_data then
			start_dialog(npc, fan_data)
		end
	end
end

-- Draw prompt when near a fan
function draw_fan_prompt()
	if dialog.active then return end
	if player_vehicle then return end

	local npc, fan_data = find_nearby_fan()
	if npc and fan_data then
		local sx, sy = world_to_screen(npc.x, npc.y)
		-- Different text for fans vs lovers (lovers can heal you)
		local text = fan_data.is_lover and "E: HEAL" or "E: FLIRT"
		local tw = #text * 4
		-- Draw above the heart sprite (moved up from -20 to -28)
		local prompt_y = sy - 28
		print_shadow(text, sx - tw/2, prompt_y, PLAYER_CONFIG.prompt_color)
	end
end

function _draw()
	cls(1)  -- dark background

	-- Draw ground tiles (grass and dirt roads)
	profile("ground")
	draw_ground()
	profile("ground")

	-- Draw countryside flora (behind buildings/sprites)
	profile("flora")
	draw_flora()
	profile("flora")

	-- Get player sprite info
	local player_spr = get_player_sprite()
	local flip_x = not game.player.facing_right

	-- Draw buildings, player, NPCs, and lamps with proper depth sorting
	profile("buildings")
	draw_buildings_and_player(buildings, game.player, player_spr, flip_x)
	profile("buildings")

	-- Draw collision effects (explosion feedback)
	draw_collision_effects()

	-- Draw projectiles and melee weapon
	draw_projectiles()
	draw_melee_weapon()

	-- Draw player shadow overlay using color table (only when not in night mode)
	-- if not night_mode then
	-- 	apply_color_table(shadow_coltab_mode)
	-- end

	-- Draw night mode overlay (darkness with street light cutouts)
	-- Calculate player screen position for spotlight
	profile("night")
	local player_sx, player_sy = world_to_screen(game.player.x, game.player.y)
	draw_night_mode(player_sx, player_sy)
	profile("night")

	-- Draw traffic signals AFTER night overlay so they stay bright/visible
	draw_traffic_signals()

	-- Draw minimap
	draw_minimap()

	-- Draw vehicle health bar (if in vehicle)
	draw_vehicle_health_bar()

	-- Draw steal prompt (if near a vehicle)
	draw_steal_prompt()

	-- Draw fan prompt (if near a fan)
	draw_fan_prompt()

	-- Draw player health, popularity, and money
	draw_health_bar()
	draw_popularity_bar()
	draw_lover_count()
	draw_money()

	-- Draw weapon HUD (equipped weapon and ammo)
	draw_weapon_hud()

	-- Draw dealer prompt and boss health bar
	draw_dealer_prompt()
	draw_boss_health_bar()

	-- Draw dialog box (if talking to fan)
	draw_dialog()

	-- Draw shop UI (overlays everything)
	draw_shop()

	-- Draw death overlay (WASTED screen - overlays everything)
	draw_death_overlay()

	-- UI with drop shadows (only when debug enabled)
	profile("ui")
	if DEBUG_CONFIG.enabled then
		-- print_shadow("GTA PICOTRON", 4, 4, 6)
		print_shadow("arrows: move  X: toggle renderer", 4, 14, 6)
		print_shadow("pos: "..flr(game.player.x)..","..flr(game.player.y), 4, SCREEN_H - 20, 6)
		print_shadow("mode: "..render_mode, 4, SCREEN_H - 10, 6)
		print_shadow("coltab: "..shadow_coltab_mode.." (M cycle)", SCREEN_W - 150, 24, 6)

		-- CPU stats
		local cpu = stat(1)  -- CPU usage (0-1 range, where 1 = 100%)
		local fps = stat(7)  -- current FPS
		print_shadow("cpu: "..flr(cpu * 100).."%", SCREEN_W - 70, 4, 6)
		print_shadow("fps: "..flr(fps), SCREEN_W - 70, 14, 6)

		-- Draw profiler output
		profile.draw()

		-- Print profiler stats to console every 10 seconds
		profile.printh_periodic()
	end
	profile("ui")
end
