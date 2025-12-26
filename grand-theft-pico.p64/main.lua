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
include("src/worldgen.lua")
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
	for _, b in ipairs(buildings) do
		local bx1 = mx + (b.x / tile_size + half_map_w - px + half_mw)
		local by1 = my + (b.y / tile_size + half_map_h - py + half_mh)
		local bx2 = mx + ((b.x + b.w) / tile_size + half_map_w - px + half_mw)
		local by2 = my + ((b.y + b.h) / tile_size + half_map_h - py + half_mh)
		rectfill(bx1, by1, bx2, by2, cfg.building_color)
	end

	-- Draw NPCs
	for _, npc in ipairs(npcs) do
		local nx = mx + (npc.x / tile_size + half_map_w - px + half_mw)
		local ny = my + (npc.y / tile_size + half_map_h - py + half_mh)
		if nx >= mx and nx <= mx + mw and ny >= my and ny <= my + mh then
			pset(nx, ny, cfg.npc_color)
		end
	end

	-- Draw player (center of minimap)
	local player_mx = mx + half_mw
	local player_my = my + half_mh
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
