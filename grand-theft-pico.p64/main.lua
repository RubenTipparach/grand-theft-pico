--[[pod_format="raw"]]

-- Grand Theft Picotron
-- A top-down GTA1/2-style game for Picotron

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
include("src/flora.lua")
include("src/input.lua")
include("src/npc.lua")

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
	}
}

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

	if traffic_phase == "ns" then
		-- N-S is green, check if time for yellow
		if now >= traffic_timer + cycle_time then
			traffic_timer = now
			traffic_phase = "ns_yellow"
		end
	elseif traffic_phase == "ns_yellow" then
		-- N-S is yellow, check if time to switch to E-W green
		if now >= traffic_timer + yellow_time then
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
		-- E-W is yellow, check if time to switch to N-S green
		if now >= traffic_timer + yellow_time then
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
-- Sprite orientation is handled by flip_x/flip_y flags when drawing
function get_signal_sprite(ns_light, corner)
	local sprites
	if ns_light then
		-- N-S traffic light uses N-S sprite set
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

-- Generate street lights along roads
-- Lights are placed on both sidewalks, evenly spaced
-- street_light_offset slides lights along the sidewalk path
-- Traffic lights are placed at intersections (8 per intersection: 2 per corner)
function generate_street_lights()
	local lights = {}
	local spacing = NIGHT_CONFIG.street_light_spacing
	local offset = NIGHT_CONFIG.street_light_offset or 0
	local light_set = {}  -- track unique positions to avoid duplicates
	local sidewalk_w = ROAD_CONFIG.sidewalk_width
	local half_road = ROAD_CONFIG.road_width / 2

	-- Get all intersections first
	local intersections = get_intersections()

	-- Helper to check if position is near an intersection
	local function is_near_intersection(x, y)
		local threshold = half_road + sidewalk_w + 8  -- within intersection area
		for _, inter in ipairs(intersections) do
			if abs(x - inter.x) < threshold and abs(y - inter.y) < threshold then
				return true, inter
			end
		end
		return false, nil
	end

	local function add_light(x, y, is_traffic_light, corner, flip_x, flip_y)
		-- Skip if this position is on a road surface
		if is_on_any_road_surface(x, y) then
			return
		end
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

	-- Generate traffic lights at intersections (1 lamp per corner, 2 signals per lamp)
	-- Each corner has a lamp post with both N-S and E-W signals
	-- Signal arrangement per corner:
	--   NE: signal W (E-W), signal S (N-S)
	--   NW: signal N (N-S), signal E (E-W)
	--   SE: signal W (E-W), signal N (N-S)
	--   SW: signal N (N-S), signal E (E-W)
	for _, inter in ipairs(intersections) do
		local ix, iy = inter.x, inter.y

		-- Corner offsets from intersection center
		local corner_offset = half_road + sidewalk_w / 2

		-- NW corner: N-S signal (facing N, flip_y=true), E-W signal (facing E, flip_x=true)
		add_light(ix - corner_offset, iy - corner_offset, true, "nw", true, false)   -- N-S: flip_y for south-facing

		-- NE corner: E-W signal (facing W, no flip), N-S signal (facing S, flip_y=true)
		add_light(ix + corner_offset, iy - corner_offset, true, "ne", false, true)   -- E-W: no flip for west-facing

		-- SW corner: N-S signal (facing N, no flip), E-W signal (facing E, flip_x=true)
		add_light(ix - corner_offset, iy + corner_offset, true, "sw", true, false)   -- E-W: flip_x for east-facing

		-- SE corner: E-W signal (facing W, no flip), N-S signal (facing N, no flip)
		add_light(ix + corner_offset, iy + corner_offset, true, "se", false, false)  -- no flips needed
	end

	-- Generate regular street lights along roads (unless disabled by config)
	if not TRAFFIC_CONFIG.intersection_lights_only then
		for _, road in ipairs(ROADS) do
			local road_half = road.width / 2
			-- Offset to place lights on sidewalks (center of sidewalk)
			local sidewalk_offset = road_half + sidewalk_w / 2

			if road.direction == "horizontal" then
				-- North sidewalk (above road)
				local y_north = road.y - sidewalk_offset
				-- South sidewalk (below road)
				local y_south = road.y + sidewalk_offset

				-- Place lights along both sidewalks
				local length = road.x2 - road.x1
				local num_segments = max(1, flr(length / spacing))
				local actual_spacing = length / num_segments

				for i = 0, num_segments do
					local x = road.x1 + flr(i * actual_spacing) + offset
					-- Skip if near intersection (traffic lights already placed)
					local near, _ = is_near_intersection(x, road.y)
					if not near then
						add_light(x, y_north, false, nil, false, false)
						add_light(x, y_south, false, nil, false, false)
					end
				end

			elseif road.direction == "vertical" then
				-- West sidewalk (left of road)
				local x_west = road.x - sidewalk_offset
				-- East sidewalk (right of road)
				local x_east = road.x + sidewalk_offset

				-- Place lights along both sidewalks
				local length = road.y2 - road.y1
				local num_segments = max(1, flr(length / spacing))
				local actual_spacing = length / num_segments

				for i = 0, num_segments do
					local y = road.y1 + flr(i * actual_spacing) + offset
					-- Skip if near intersection (traffic lights already placed)
					local near, _ = is_near_intersection(road.x, y)
					if not near then
						add_light(x_west, y, false, nil, false, false)
						add_light(x_east, y, false, nil, false, false)
					end
				end
			end
		end
	end

	return lights
end

-- Street light positions (generated from roads)
STREET_LIGHTS = {}

-- Draw minimap showing player, NPCs, roads, and buildings
function draw_minimap()
	local cfg = MINIMAP_CONFIG
	if not cfg.enabled then return end

	local mx = cfg.x
	local my = cfg.y
	local mw = cfg.width
	local mh = cfg.height
	local scale = cfg.scale

	-- Calculate world center based on player position
	local px = game.player.x
	local py = game.player.y

	-- Draw background with border
	rectfill(mx - 1, my - 1, mx + mw + 1, my + mh + 1, cfg.border_color)
	rectfill(mx, my, mx + mw, my + mh, cfg.water_color)  -- water is default bg

	-- Clip to minimap area
	clip(mx, my, mw + 1, mh + 1)

	-- Helper: convert world coords to minimap coords (centered on player)
	local function world_to_map(wx, wy)
		local map_x = mx + mw / 2 + (wx - px) * scale
		local map_y = my + mh / 2 + (wy - py) * scale
		return map_x, map_y
	end

	-- Draw land area (mainland grass)
	local wcfg = WATER_CONFIG
	local lx1, ly1 = world_to_map(wcfg.land_min_x, wcfg.land_min_y)
	local lx2, ly2 = world_to_map(wcfg.land_max_x, wcfg.land_max_y)
	rectfill(lx1, ly1, lx2, ly2, cfg.bg_color)

	-- Draw islands
	if wcfg.islands then
		for _, island in ipairs(wcfg.islands) do
			local ix1, iy1 = world_to_map(island.x, island.y)
			local ix2, iy2 = world_to_map(island.x + island.w * 16, island.y + island.h * 16)
			rectfill(ix1, iy1, ix2, iy2, cfg.bg_color)
		end
	end

	-- Helper to draw a road on the minimap
	local function draw_road(road)
		local road_w = road.width * scale
		if road_w < 1 then road_w = 1 end

		if road.direction == "horizontal" then
			local x1, y1 = world_to_map(road.x1, road.y)
			local x2, y2 = world_to_map(road.x2, road.y)
			rectfill(x1, y1 - road_w / 2, x2, y1 + road_w / 2, cfg.road_color)
		else
			local x1, y1 = world_to_map(road.x, road.y1)
			local x2, y2 = world_to_map(road.x, road.y2)
			rectfill(x1 - road_w / 2, y1, x1 + road_w / 2, y2, cfg.road_color)
		end
	end

	-- Draw city roads
	for _, road in ipairs(ROADS) do
		draw_road(road)
	end

	-- Draw countryside/dirt roads
	for _, road in ipairs(COUNTRYSIDE_ROADS) do
		draw_road(road)
	end

	-- Draw buildings
	for _, b in ipairs(buildings) do
		local bx1, by1 = world_to_map(b.x, b.y)
		local bx2, by2 = world_to_map(b.x + b.w, b.y + b.h)
		rectfill(bx1, by1, bx2, by2, cfg.building_color)
	end

	-- Draw NPCs
	for _, npc in ipairs(npcs) do
		local nx, ny = world_to_map(npc.x, npc.y)
		if nx >= mx and nx <= mx + mw and ny >= my and ny <= my + mh then
			pset(nx, ny, cfg.npc_color)
		end
	end

	-- Draw player (center of minimap, always visible)
	local player_mx = mx + mw / 2
	local player_my = my + mh / 2
	circfill(player_mx, player_my, cfg.player_size, cfg.player_color)

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

	-- Create buildings from level config
	buildings = create_buildings_from_level()

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
end

-- Print text with drop shadow for legibility
function print_shadow(text, x, y, col, shadow_col)
	shadow_col = shadow_col or 0  -- default black shadow
	print(text, x + 1, y + 1, shadow_col)
	print(text, x, y, col)
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

	-- UI with drop shadows (only when debug enabled)
	profile("ui")
	if DEBUG_CONFIG.enabled then
		print_shadow("GTA PICOTRON", 4, 4, 7)
		print_shadow("arrows: move  X: toggle renderer", 4, 14, 7)
		print_shadow("pos: "..flr(game.player.x)..","..flr(game.player.y), 4, SCREEN_H - 20, 7)
		print_shadow("mode: "..render_mode, 4, SCREEN_H - 10, 7)
		print_shadow("coltab: "..shadow_coltab_mode.." (M cycle)", SCREEN_W - 150, 24, 7)

		-- CPU stats
		local cpu = stat(1)  -- CPU usage (0-1 range, where 1 = 100%)
		local fps = stat(7)  -- current FPS
		print_shadow("cpu: "..flr(cpu * 100).."%", SCREEN_W - 70, 4, 7)
		print_shadow("fps: "..flr(fps), SCREEN_W - 70, 14, 7)

		-- Draw profiler output
		profile.draw()

		-- Print profiler stats to console every 10 seconds
		profile.printh_periodic()
	end
	profile("ui")
end
