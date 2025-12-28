--[[pod_format="raw"]]
-- ground.lua - Tile-based ground rendering with BATCHED userdata ops

-- Tile types
TILE_GRASS = 0
TILE_DIRT_LIGHT = 1
TILE_DIRT_MEDIUM = 2
TILE_DIRT_HEAVY = 3
TILE_SIDEWALK_NS = 4
TILE_SIDEWALK_EW = 5
TILE_WATER = 6

-- Grass tile variants (populated after SPRITES is loaded)
local grass_variants = nil

-- Initialize grass variants (called after config loads)
function init_grass_variants()
	grass_variants = {
		SPRITES.GRASS.id,
		--SPRITES.GRASS_2.id,
		--SPRITES.GRASS_3.id,
		--SPRITES.GRASS_4.id,
		--SPRITES.GRASS_5.id,
		SPRITES.GRASS_6.id,
	}
end

-- Deterministic hash function for tile coordinates
-- Returns a consistent pseudo-random value 0-1 for any (x, y)
local function tile_hash(x, y)
	-- Simple but effective hash combining coordinates
	-- Uses prime multipliers for good distribution
	local h = x * 374761393 + y * 668265263
	h = h ~ (h >> 13)
	h = h * 1274126177
	h = h ~ (h >> 16)
	-- Normalize to 0-1 range
	return (h % 1000) / 1000
end

-- Get grass sprite for a specific tile coordinate (deterministic)
local function get_grass_sprite(mx, my)
	if not grass_variants then
		init_grass_variants()
	end
	local hash = tile_hash(mx, my)
	local index = flr(hash * #grass_variants) + 1
	return grass_variants[index]
end

-- Scanline buffer for batched ground rendering (11 values per scanline)
-- Format per row: spr, x0, y, x1, y, u0, v0, u1, v1, w0, w1
local ground_scanlines = userdata("f64", 11, 270)

-- Pre-allocated slope vector (reused across all ground drawing)
local ground_slope = vec(0, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0)

-- Water animation frame (0 or 1)
local water_frame = 0
local water_timer = 0

-- ============================================
-- GROUND BUFFER SYSTEM (blit-based caching)
-- ============================================
-- Buffer extends beyond screen to allow camera movement without redraw
local GROUND_BUFFER_PADDING = 128  -- pixels of padding on each side
local ground_buffer = nil  -- userdata for pre-rendered ground tiles
local ground_cache_cam_x = nil  -- camera position when buffer was rendered
local ground_cache_cam_y = nil
local ground_buffer_dirty = true  -- force redraw on first frame

-- Initialize ground buffer (call once at startup)
function init_ground_buffer()
	local buf_w = SCREEN_W + GROUND_BUFFER_PADDING * 2
	local buf_h = SCREEN_H + GROUND_BUFFER_PADDING * 2
	ground_buffer = userdata("u8", buf_w, buf_h)
	ground_buffer_dirty = true
	ground_cache_cam_x = nil
	ground_cache_cam_y = nil
end

-- Mark ground buffer as needing redraw (call when tiles change)
function invalidate_ground_buffer()
	ground_buffer_dirty = true
end

-- Update water animation timer
function update_water_animation()
	water_timer = water_timer + 1 / 60  -- assume 60fps
	if water_timer >= WATER_CONFIG.animation_speed then
		water_timer = 0
		water_frame = 1 - water_frame  -- toggle 0/1
		-- Water is drawn separately on top of ground buffer, no need to invalidate
	end
end

-- Get current water center tile sprite (animated)
function get_water_sprite()
	if water_frame == 0 then
		return WATER_CONFIG.set1[1].c  -- frame 1 center
	else
		return WATER_CONFIG.set1[2].c  -- frame 2 center
	end
end

-- Check if a road is visible on screen (frustum cull)
-- countryside roads have no sidewalks, so don't add sidewalk_width
function is_road_visible(road)
	local sidewalk_extra = road.countryside and 0 or ROAD_CONFIG.sidewalk_width
	local half_w = road.width / 2 + sidewalk_extra
	local sx1, sy1, sx2, sy2

	if road.direction == "horizontal" then
		sx1, sy1 = world_to_screen(road.x1, road.y - half_w)
		sx2, sy2 = world_to_screen(road.x2, road.y + half_w)
	else
		sx1, sy1 = world_to_screen(road.x - half_w, road.y1)
		sx2, sy2 = world_to_screen(road.x + half_w, road.y2)
	end

	-- Check if road rect overlaps screen
	return sx2 > 0 and sx1 < SCREEN_W and sy2 > 0 and sy1 < SCREEN_H
end

-- Draw ground using blit-based caching
-- Only redraws the buffer when camera moves beyond padding threshold
function draw_ground()
	-- Initialize buffer on first call
	if not ground_buffer then
		init_ground_buffer()
	end

	-- Check if we need to redraw the buffer
	local need_redraw = ground_buffer_dirty
	if not need_redraw and ground_cache_cam_x then
		-- Check if camera moved beyond padding threshold
		local dx = abs(cam_x - ground_cache_cam_x)
		local dy = abs(cam_y - ground_cache_cam_y)
		if dx > GROUND_BUFFER_PADDING or dy > GROUND_BUFFER_PADDING then
			need_redraw = true
		end
	else
		need_redraw = true
	end

	if need_redraw then
		-- Redraw the entire ground buffer
		render_ground_to_buffer()
		ground_cache_cam_x = cam_x
		ground_cache_cam_y = cam_y
		ground_buffer_dirty = false
	end

	-- Draw buffer as sprite at offset position
	-- Buffer was rendered with its top-left at world position (cache_cam - SCREEN_C - PADDING)
	-- That world position should appear at screen position:
	--   sx = world_x + SCREEN_CX - cam_x
	-- So buffer top-left goes to screen:
	--   (cache_cam_x - SCREEN_CX - PADDING) + SCREEN_CX - cam_x = cache_cam_x - PADDING - cam_x
	-- Which simplifies to: -(cam_x - cache_cam_x) - PADDING
	local draw_x = -(cam_x - ground_cache_cam_x) - GROUND_BUFFER_PADDING
	local draw_y = -(cam_y - ground_cache_cam_y) - GROUND_BUFFER_PADDING

	-- Draw the buffer sprite (simpler than blit, just position the whole image)
	spr(ground_buffer, draw_x, draw_y)

	-- Draw water separately on top (animates without invalidating buffer)
	draw_water_from_map()
end

-- Render all ground tiles to the offscreen buffer
function render_ground_to_buffer()
	-- Save current draw target
	set_draw_target(ground_buffer)

	-- Clear buffer (use grass color as background)
	cls(3)  -- dark green background

	-- Buffer covers cam position +/- padding
	-- We render tiles for this extended area
	local buf_cam_x = cam_x
	local buf_cam_y = cam_y

	-- Calculate world offsets for texture scrolling
	local world_x_offset = buf_cam_x - SCREEN_CX - GROUND_BUFFER_PADDING
	local world_y_offset = buf_cam_y - SCREEN_CY - GROUND_BUFFER_PADDING

	-- Draw all tile types to buffer (except water - drawn separately for animation)
	render_grass_to_buffer(buf_cam_x, buf_cam_y)
	render_roads_to_buffer(buf_cam_x, buf_cam_y)

	-- Restore draw target to screen
	set_draw_target()
end

-- Render grass tiles to the ground buffer
function render_grass_to_buffer(buf_cam_x, buf_cam_y)
	if not WORLD_DATA or not WORLD_DATA.tiles then return end

	local tiles = WORLD_DATA.tiles
	local tile_size = MAP_CONFIG.tile_size
	local map_w = MAP_CONFIG.map_width
	local map_h = MAP_CONFIG.map_height
	local half_w = map_w / 2
	local half_h = map_h / 2

	local buf_w = SCREEN_W + GROUND_BUFFER_PADDING * 2
	local buf_h = SCREEN_H + GROUND_BUFFER_PADDING * 2

	-- Calculate visible world bounds (extended by buffer padding)
	local left_wx = buf_cam_x - SCREEN_CX - GROUND_BUFFER_PADDING - tile_size
	local top_wy = buf_cam_y - SCREEN_CY - GROUND_BUFFER_PADDING - tile_size
	local right_wx = buf_cam_x + SCREEN_CX + GROUND_BUFFER_PADDING + tile_size
	local bottom_wy = buf_cam_y + SCREEN_CY + GROUND_BUFFER_PADDING + tile_size

	-- Convert to map coordinates
	local mx1 = max(0, flr(left_wx / tile_size) + half_w)
	local my1 = max(0, flr(top_wy / tile_size) + half_h)
	local mx2 = min(map_w - 1, flr(right_wx / tile_size) + half_w)
	local my2 = min(map_h - 1, flr(bottom_wy / tile_size) + half_h)

	-- Screen offset for buffer (buffer center = camera position)
	local screen_ox = SCREEN_CX + GROUND_BUFFER_PADDING - buf_cam_x
	local screen_oy = SCREEN_CY + GROUND_BUFFER_PADDING - buf_cam_y

	-- Draw grass tiles with deterministic variation
	for my = my1, my2 do
		local wy = (my - half_h) * tile_size
		local sy = wy + screen_oy
		for mx = mx1, mx2 do
			local tile = tiles:get(mx, my)
			if tile == MAP_TILE_GRASS or tile == MAP_TILE_BUILDING_ZONE then
				local wx = (mx - half_w) * tile_size
				local sx = wx + screen_ox
				local grass_spr = get_grass_sprite(mx, my)
				spr(grass_spr, sx, sy)
			end
		end
	end
end

-- Render water tiles to the ground buffer
function render_water_to_buffer(buf_cam_x, buf_cam_y)
	if not WORLD_DATA or not WORLD_DATA.tiles then return end

	local tiles = WORLD_DATA.tiles
	local tile_size = MAP_CONFIG.tile_size
	local map_w = MAP_CONFIG.map_width
	local map_h = MAP_CONFIG.map_height
	local half_w = map_w / 2
	local half_h = map_h / 2

	-- Calculate visible world bounds (extended by buffer padding)
	local left_wx = buf_cam_x - SCREEN_CX - GROUND_BUFFER_PADDING - tile_size
	local top_wy = buf_cam_y - SCREEN_CY - GROUND_BUFFER_PADDING - tile_size
	local right_wx = buf_cam_x + SCREEN_CX + GROUND_BUFFER_PADDING + tile_size
	local bottom_wy = buf_cam_y + SCREEN_CY + GROUND_BUFFER_PADDING + tile_size

	-- Convert to map coordinates
	local mx1 = max(0, flr(left_wx / tile_size) + half_w)
	local my1 = max(0, flr(top_wy / tile_size) + half_h)
	local mx2 = min(map_w - 1, flr(right_wx / tile_size) + half_w)
	local my2 = min(map_h - 1, flr(bottom_wy / tile_size) + half_h)

	-- Screen offset for buffer
	local screen_ox = SCREEN_CX + GROUND_BUFFER_PADDING - buf_cam_x
	local screen_oy = SCREEN_CY + GROUND_BUFFER_PADDING - buf_cam_y

	-- Draw water tiles with 9-slice borders
	for my = my1, my2 do
		local wy = (my - half_h) * tile_size
		local sy = wy + screen_oy
		for mx = mx1, mx2 do
			if tiles:get(mx, my) == MAP_TILE_WATER then
				local wx = (mx - half_w) * tile_size
				local sx = wx + screen_ox
				local water_spr = get_water_tile_sprite(mx, my, tiles, map_w, map_h)
				spr(water_spr, sx, sy)
			end
		end
	end
end

-- Render road tiles to the ground buffer
function render_roads_to_buffer(buf_cam_x, buf_cam_y)
	if not WORLD_DATA or not WORLD_DATA.tiles then return end

	local tiles = WORLD_DATA.tiles
	local tile_size = MAP_CONFIG.tile_size
	local map_w = MAP_CONFIG.map_width
	local map_h = MAP_CONFIG.map_height
	local half_w = map_w / 2
	local half_h = map_h / 2

	-- Get sprites
	local main_road_spr = SPRITES.DIRT_MEDIUM.id
	local dirt_road_spr = SPRITES.DIRT_HEAVY.id
	local sidewalk_ns_spr = SPRITES.SIDEWALK_NS.id
	local sidewalk_ew_spr = SPRITES.SIDEWALK_EW.id

	-- Calculate visible world bounds (extended by buffer padding)
	local left_wx = buf_cam_x - SCREEN_CX - GROUND_BUFFER_PADDING - tile_size
	local top_wy = buf_cam_y - SCREEN_CY - GROUND_BUFFER_PADDING - tile_size
	local right_wx = buf_cam_x + SCREEN_CX + GROUND_BUFFER_PADDING + tile_size
	local bottom_wy = buf_cam_y + SCREEN_CY + GROUND_BUFFER_PADDING + tile_size

	-- Convert to map coordinates
	local mx1 = max(0, flr(left_wx / tile_size) + half_w)
	local my1 = max(0, flr(top_wy / tile_size) + half_h)
	local mx2 = min(map_w - 1, flr(right_wx / tile_size) + half_w)
	local my2 = min(map_h - 1, flr(bottom_wy / tile_size) + half_h)

	-- Screen offset for buffer
	local screen_ox = SCREEN_CX + GROUND_BUFFER_PADDING - buf_cam_x
	local screen_oy = SCREEN_CY + GROUND_BUFFER_PADDING - buf_cam_y

	-- Draw tiles
	for my = my1, my2 do
		local wy = (my - half_h) * tile_size
		local sy = wy + screen_oy
		for mx = mx1, mx2 do
			local tile = tiles:get(mx, my)
			local wx = (mx - half_w) * tile_size
			local sx = wx + screen_ox

			if tile == MAP_TILE_MAIN_ROAD then
				spr(main_road_spr, sx, sy)
			elseif tile == MAP_TILE_DIRT_ROAD then
				spr(dirt_road_spr, sx, sy)
			elseif tile == MAP_TILE_SIDEWALK_NS then
				spr(sidewalk_ns_spr, sx, sy)
			elseif tile == MAP_TILE_SIDEWALK_EW then
				spr(sidewalk_ew_spr, sx, sy)
			end
		end
	end
end

-- Draw grass tiles from parsed map data (optimized - only visible grass tiles)
-- This replaces the old full-screen grass fill approach
function draw_grass_from_map(world_x_offset, world_y_offset)
	-- Skip if world data not initialized
	if not WORLD_DATA or not WORLD_DATA.tiles then
		-- Fallback to full-screen grass fill if no tilemap
		draw_grass_fullscreen(world_x_offset, world_y_offset)
		return
	end

	local tiles = WORLD_DATA.tiles
	local tile_size = MAP_CONFIG.tile_size
	local map_w = MAP_CONFIG.map_width
	local map_h = MAP_CONFIG.map_height
	local half_w = map_w / 2
	local half_h = map_h / 2

	-- Calculate visible world bounds
	local left_wx = cam_x - SCREEN_CX - tile_size
	local top_wy = cam_y - SCREEN_CY - tile_size
	local right_wx = cam_x + SCREEN_CX + tile_size
	local bottom_wy = cam_y + SCREEN_CY + tile_size

	-- Convert to map coordinates (world 0,0 = map 128,128)
	local mx1 = max(0, flr(left_wx / tile_size) + half_w)
	local my1 = max(0, flr(top_wy / tile_size) + half_h)
	local mx2 = min(map_w - 1, flr(right_wx / tile_size) + half_w)
	local my2 = min(map_h - 1, flr(bottom_wy / tile_size) + half_h)

	-- Screen offset for converting world coords to screen coords
	local screen_ox = SCREEN_CX - cam_x
	local screen_oy = SCREEN_CY - cam_y

	-- Draw grass tiles in visible range with deterministic variation
	for my = my1, my2 do
		local wy = (my - half_h) * tile_size
		local sy = wy + screen_oy
		for mx = mx1, mx2 do
			local tile = tiles:get(mx, my)
			-- Draw grass for grass tiles and building zones (buildings will be drawn on top)
			if tile == MAP_TILE_GRASS or tile == MAP_TILE_BUILDING_ZONE then
				local wx = (mx - half_w) * tile_size
				local sx = wx + screen_ox
				local grass_spr = get_grass_sprite(mx, my)
				spr(grass_spr, sx, sy)
			end
		end
	end
end

-- Fallback: full-screen grass fill (used when no tilemap data)
function draw_grass_fullscreen(world_x_offset, world_y_offset)
	local grass_spr = SPRITES.GRASS.id
	local grass_tex_size = SPRITES.GRASS.w

	local tex_u_start = world_x_offset % grass_tex_size
	local tex_v_start = world_y_offset % grass_tex_size
	local tex_u_end = tex_u_start + (SCREEN_W / grass_tex_size) * grass_tex_size

	-- Create start vector for first scanline (y=0)
	local v_start = vec(grass_spr, 0, 0, SCREEN_W, 0, tex_u_start, tex_v_start, tex_u_end, tex_v_start, 1, 1)

	-- Batch fill all scanlines using userdata ops
	ground_scanlines:copy(v_start, true, 0, 0, 11)
	ground_scanlines:copy(ground_slope, true, 0, 11, 11, 0, 11, SCREEN_H - 1)
	ground_scanlines:add(ground_scanlines, true, 0, 11, 11, 11, 11, SCREEN_H - 1)

	-- Draw all grass scanlines in one batch call
	tline3d(ground_scanlines, 0, SCREEN_H)
end

-- Draw road and sidewalk tiles directly from the parsed tilemap
-- This is simpler and more accurate than generating ROADS segments
function draw_roads_from_map(world_x_offset, world_y_offset)
	-- Skip if world data not initialized
	if not WORLD_DATA or not WORLD_DATA.tiles then return end

	local tiles = WORLD_DATA.tiles
	local tile_size = MAP_CONFIG.tile_size
	local map_w = MAP_CONFIG.map_width
	local map_h = MAP_CONFIG.map_height
	local half_w = map_w / 2
	local half_h = map_h / 2

	-- Get sprites
	local main_road_spr = SPRITES.DIRT_MEDIUM.id
	local dirt_road_spr = SPRITES.DIRT_HEAVY.id
	local sidewalk_ns_spr = SPRITES.SIDEWALK_NS.id
	local sidewalk_ew_spr = SPRITES.SIDEWALK_EW.id

	-- Calculate visible world bounds
	local left_wx = cam_x - SCREEN_CX - tile_size
	local top_wy = cam_y - SCREEN_CY - tile_size
	local right_wx = cam_x + SCREEN_CX + tile_size
	local bottom_wy = cam_y + SCREEN_CY + tile_size

	-- Convert to map coordinates (world 0,0 = map 128,128)
	local mx1 = max(0, flr(left_wx / tile_size) + half_w)
	local my1 = max(0, flr(top_wy / tile_size) + half_h)
	local mx2 = min(map_w - 1, flr(right_wx / tile_size) + half_w)
	local my2 = min(map_h - 1, flr(bottom_wy / tile_size) + half_h)

	-- Screen offset for converting world coords to screen coords
	local screen_ox = SCREEN_CX - cam_x
	local screen_oy = SCREEN_CY - cam_y

	-- Draw tiles in visible range
	for my = my1, my2 do
		local wy = (my - half_h) * tile_size
		local sy = wy + screen_oy
		for mx = mx1, mx2 do
			local tile = tiles:get(mx, my)
			local wx = (mx - half_w) * tile_size
			local sx = wx + screen_ox

			if tile == MAP_TILE_MAIN_ROAD then
				spr(main_road_spr, sx, sy)
			elseif tile == MAP_TILE_DIRT_ROAD then
				spr(dirt_road_spr, sx, sy)
			elseif tile == MAP_TILE_SIDEWALK_NS then
				spr(sidewalk_ns_spr, sx, sy)
			elseif tile == MAP_TILE_SIDEWALK_EW then
				spr(sidewalk_ew_spr, sx, sy)
			end
		end
	end
end

-- Get water sprite for a tile based on neighboring tiles (9-slice)
-- Uses Set 1 for outer corners/edges (grass surrounding water)
-- Uses Set 2 for inner corners (water surrounding grass - diagonal notches)
-- Helper to check if a tile is water (inlined for performance)
local function is_water_at(tiles, x, y, map_w, map_h)
	if x < 0 or x >= map_w or y < 0 or y >= map_h then
		return true  -- outside map = water
	end
	return tiles:get(x, y) == MAP_TILE_WATER
end

function get_water_tile_sprite(mx, my, tiles, map_w, map_h)
	local frame = water_frame + 1  -- 1 or 2 for table index
	local set1 = WATER_CONFIG.set1[frame]
	local set2 = WATER_CONFIG.set2[frame]

	-- Cardinal neighbors (using hoisted helper function)
	local n = is_water_at(tiles, mx, my - 1, map_w, map_h)  -- north
	local s = is_water_at(tiles, mx, my + 1, map_w, map_h)  -- south
	local w = is_water_at(tiles, mx - 1, my, map_w, map_h)  -- west
	local e = is_water_at(tiles, mx + 1, my, map_w, map_h)  -- east

	-- Diagonal neighbors (for inner corner detection)
	local nw = is_water_at(tiles, mx - 1, my - 1, map_w, map_h)  -- northwest
	local ne = is_water_at(tiles, mx + 1, my - 1, map_w, map_h)  -- northeast
	local sw = is_water_at(tiles, mx - 1, my + 1, map_w, map_h)  -- southwest
	local se = is_water_at(tiles, mx + 1, my + 1, map_w, map_h)  -- southeast

	-- Set 1: Outer corners/edges (grass border around water)
	-- Corner cases (2 cardinal sides have grass)
	if not n and not w and s and e then return set1.tl end  -- grass on top and left
	if not n and not e and s and w then return set1.tr end  -- grass on top and right
	if not s and not w and n and e then return set1.bl end  -- grass on bottom and left
	if not s and not e and n and w then return set1.br end  -- grass on bottom and right

	-- Edge cases (1 cardinal side has grass)
	if not n and s and w and e then return set1.t end   -- grass on top
	if not s and n and w and e then return set1.b end   -- grass on bottom
	if not w and n and s and e then return set1.l end   -- grass on left
	if not e and n and s and w then return set1.r end   -- grass on right

	-- Set 2: Inner corners (all 4 cardinal neighbors are water, but diagonal has grass)
	-- These create the "notch" effect for rounded coastlines
	-- The corner sprite fills the opposite corner from where the grass is
	if n and s and w and e then
		-- All cardinal neighbors are water - check diagonals for inner corners
		if not nw then return set2.br end  -- grass at NW diagonal = fill BR corner
		if not ne then return set2.bl end  -- grass at NE diagonal = fill BL corner
		if not sw then return set2.tr end  -- grass at SW diagonal = fill TR corner
		if not se then return set2.tl end  -- grass at SE diagonal = fill TL corner
	end

	-- Center (all sides and diagonals are water)
	return set1.c
end

-- Draw water tiles based on parsed map data with 9-slice borders
-- Optimized: only draws water in visible area, uses direct userdata access
-- Coordinate system: world (0,0) = map center (128,128)
function draw_water_from_map(world_x_offset, world_y_offset)
	-- Skip if world data not initialized
	if not WORLD_DATA or not WORLD_DATA.tiles then return end

	local tiles = WORLD_DATA.tiles
	local tile_size = MAP_CONFIG.tile_size
	local map_w = MAP_CONFIG.map_width
	local map_h = MAP_CONFIG.map_height
	local half_w = map_w / 2
	local half_h = map_h / 2

	-- Calculate visible world bounds
	local left_wx = cam_x - SCREEN_CX - tile_size
	local top_wy = cam_y - SCREEN_CY - tile_size
	local right_wx = cam_x + SCREEN_CX + tile_size
	local bottom_wy = cam_y + SCREEN_CY + tile_size

	-- Convert to map coordinates (world 0,0 = map 128,128)
	local mx1 = max(0, flr(left_wx / tile_size) + half_w)
	local my1 = max(0, flr(top_wy / tile_size) + half_h)
	local mx2 = min(map_w - 1, flr(right_wx / tile_size) + half_w)
	local my2 = min(map_h - 1, flr(bottom_wy / tile_size) + half_h)

	-- Screen offset for converting world coords to screen coords
	local screen_ox = SCREEN_CX - cam_x
	local screen_oy = SCREEN_CY - cam_y

	-- Draw water tiles with proper 9-slice borders
	for my = my1, my2 do
		-- Convert map Y to world Y
		local wy = (my - half_h) * tile_size
		local sy = wy + screen_oy
		for mx = mx1, mx2 do
			if tiles:get(mx, my) == MAP_TILE_WATER then
				-- Convert map X to world X
				local wx = (mx - half_w) * tile_size
				local sx = wx + screen_ox
				-- Get appropriate 9-slice sprite based on neighbors
				local water_spr = get_water_tile_sprite(mx, my, tiles, map_w, map_h)
				spr(water_spr, sx, sy)
			end
		end
	end
end

-- Draw sidewalks on both sides of a road (offsets passed from caller)
function draw_sidewalks_batched(road, world_x_offset, world_y_offset)
	local sidewalk_w = ROAD_CONFIG.sidewalk_width
	local half_road = road.width / 2

	if road.direction == "horizontal" then
		local sidewalk_spr = SPRITES.SIDEWALK_EW.id
		local top_y = road.y - half_road - sidewalk_w
		local bot_y = road.y + half_road
		draw_sidewalk_strip(sidewalk_spr, road.x1, top_y, road.x2, top_y + sidewalk_w, world_x_offset, world_y_offset)
		draw_sidewalk_strip(sidewalk_spr, road.x1, bot_y, road.x2, bot_y + sidewalk_w, world_x_offset, world_y_offset)
	else
		local sidewalk_spr = SPRITES.SIDEWALK_NS.id
		local left_x = road.x - half_road - sidewalk_w
		local right_x = road.x + half_road
		draw_sidewalk_strip(sidewalk_spr, left_x, road.y1, left_x + sidewalk_w, road.y2, world_x_offset, world_y_offset)
		draw_sidewalk_strip(sidewalk_spr, right_x, road.y1, right_x + sidewalk_w, road.y2, world_x_offset, world_y_offset)
	end
end

-- Draw a single sidewalk strip
function draw_sidewalk_strip(sidewalk_spr, wx1, wy1, wx2, wy2, world_x_offset, world_y_offset)
	-- Convert world coords to screen
	local sx1, sy1 = world_to_screen(wx1, wy1)
	local sx2, sy2 = world_to_screen(wx2, wy2)

	-- Clip to screen
	local draw_x1 = max(0, flr(sx1))
	local draw_x2 = min(SCREEN_W, ceil(sx2))
	local draw_y1 = max(0, flr(sy1))
	local draw_y2 = min(SCREEN_H, ceil(sy2))

	if draw_x1 >= draw_x2 or draw_y1 >= draw_y2 then return end

	local count = draw_y2 - draw_y1
	if count < 1 then return end

	local strip_w = draw_x2 - draw_x1
	local tex_u_start = (world_x_offset + draw_x1) % 16
	local tex_u_end = tex_u_start + max(1, strip_w / 16) * 16
	local tex_v_start = (world_y_offset + draw_y1) % 16

	-- Create start vector and batch fill
	local v_start = vec(sidewalk_spr, draw_x1, draw_y1, draw_x2, draw_y1, tex_u_start, tex_v_start, tex_u_end, tex_v_start, 1, 1)
	ground_scanlines:copy(v_start, true, 0, 0, 11)
	if count > 1 then
		ground_scanlines:copy(ground_slope, true, 0, 11, 11, 0, 11, count - 1)
		ground_scanlines:add(ground_scanlines, true, 0, 11, 11, 11, 11, count - 1)
	end
	tline3d(ground_scanlines, 0, count)
end

-- Draw a single road segment using BATCHED tline3d with userdata ops
function draw_road_batched(road, world_x_offset, world_y_offset)
	local tile_spr = get_tile_sprite(road.tile_type or TILE_DIRT_MEDIUM)
	local half_w = road.width / 2
	local draw_x1, draw_x2, draw_y1, draw_y2

	if road.direction == "horizontal" then
		local sx1, sy1 = world_to_screen(road.x1, road.y - half_w)
		local sx2, sy2 = world_to_screen(road.x2, road.y + half_w)
		draw_x1 = max(0, sx1)
		draw_x2 = min(SCREEN_W, sx2)
		draw_y1 = max(0, flr(sy1))
		draw_y2 = min(SCREEN_H, flr(sy2))
	else
		local sx1, sy1 = world_to_screen(road.x - half_w, road.y1)
		local sx2, sy2 = world_to_screen(road.x + half_w, road.y2)
		draw_x1 = max(0, sx1)
		draw_x2 = min(SCREEN_W, sx2)
		draw_y1 = max(0, flr(sy1))
		draw_y2 = min(SCREEN_H, flr(sy2))
	end

	if draw_x1 >= draw_x2 or draw_y1 >= draw_y2 then return end

	local count = draw_y2 - draw_y1
	if count < 1 then return end

	local road_w = draw_x2 - draw_x1
	local tex_u_start = (world_x_offset + draw_x1) % 16
	local tex_u_end = tex_u_start + max(1, road_w / 16) * 16
	local tex_v_start = (world_y_offset + draw_y1) % 16

	-- Create start vector and batch fill
	local v_start = vec(tile_spr, draw_x1, draw_y1, draw_x2, draw_y1, tex_u_start, tex_v_start, tex_u_end, tex_v_start, 1, 1)
	ground_scanlines:copy(v_start, true, 0, 0, 11)
	if count > 1 then
		ground_scanlines:copy(ground_slope, true, 0, 11, 11, 0, 11, count - 1)
		ground_scanlines:add(ground_scanlines, true, 0, 11, 11, 11, 11, count - 1)
	end
	tline3d(ground_scanlines, 0, count)
end

-- Get sprite for tile type
function get_tile_sprite(tile_type)
	if tile_type == TILE_GRASS then
		return SPRITES.GRASS.id
	elseif tile_type == TILE_DIRT_LIGHT then
		return SPRITES.DIRT_LIGHT.id
	elseif tile_type == TILE_DIRT_MEDIUM then
		return SPRITES.DIRT_MEDIUM.id
	elseif tile_type == TILE_DIRT_HEAVY then
		return SPRITES.DIRT_HEAVY.id
	end
	return SPRITES.GRASS.id  -- default
end

-- Legacy non-batched function (kept for reference)
function draw_road(road)
	draw_road_batched(road)
end

-- Get tile type at world position
-- Uses tilemap data to determine terrain type
function get_ground_tile(wx, wy)
	-- Use tilemap if available
	if WORLD_DATA and WORLD_DATA.tiles then
		local tile = get_map_tile_at_world(wx, wy)
		-- Convert MAP_TILE_* to TILE_* for legacy compatibility
		if tile == MAP_TILE_GRASS then
			return TILE_GRASS
		elseif tile == MAP_TILE_WATER then
			return TILE_WATER  -- flora should NOT spawn here
		elseif tile == MAP_TILE_MAIN_ROAD then
			return TILE_DIRT_MEDIUM
		elseif tile == MAP_TILE_DIRT_ROAD then
			return TILE_DIRT_HEAVY  -- flora should NOT spawn here
		elseif tile == MAP_TILE_SIDEWALK_NS or tile == MAP_TILE_SIDEWALK_EW then
			return TILE_SIDEWALK_NS
		elseif tile == MAP_TILE_BUILDING_ZONE then
			return TILE_GRASS  -- building zones count as grass for flora
		end
	end

	-- Fallback: check old road definitions
	for _, road in ipairs(ROADS) do
		if is_on_road(wx, wy, road) then
			return road.tile_type or TILE_DIRT_MEDIUM
		end
	end

	-- Default to grass
	return TILE_GRASS
end

-- Alias for flora.lua compatibility
function get_tile_type(wx, wy)
	return get_ground_tile(wx, wy)
end

-- Check if world position is on a road segment
function is_on_road(wx, wy, road)
	local half_w = road.width / 2

	if road.direction == "horizontal" then
		-- Horizontal road: check Y range and X range
		if wy >= road.y - half_w and wy < road.y + half_w then
			if wx >= road.x1 and wx < road.x2 then
				return true
			end
		end
	elseif road.direction == "vertical" then
		-- Vertical road: check X range and Y range
		if wx >= road.x - half_w and wx < road.x + half_w then
			if wy >= road.y1 and wy < road.y2 then
				return true
			end
		end
	end

	return false
end

-- Check if world position is on any road
function is_on_any_road(wx, wy)
	for _, road in ipairs(ROADS) do
		if is_on_road(wx, wy, road) then
			return true
		end
	end
	return false
end

-- ============================================
-- TERRAIN QUERY HELPERS (for NPC pathfinding)
-- ============================================

-- Check if world position is on a sidewalk (tilemap-based)
function is_on_sidewalk(wx, wy)
	if not WORLD_DATA or not WORLD_DATA.tiles then return false end
	local tile = get_map_tile_at_world(wx, wy)
	return tile == MAP_TILE_SIDEWALK_NS or tile == MAP_TILE_SIDEWALK_EW
end

-- Check if world position is on grass (tilemap-based)
function is_on_grass(wx, wy)
	if not WORLD_DATA or not WORLD_DATA.tiles then return true end
	local tile = get_map_tile_at_world(wx, wy)
	return tile == MAP_TILE_GRASS
end

-- Check if world position is on a road surface (tilemap-based)
-- Includes both main roads and dirt roads
function is_on_road_surface(wx, wy)
	if not WORLD_DATA or not WORLD_DATA.tiles then return false end
	local tile = get_map_tile_at_world(wx, wy)
	return tile == MAP_TILE_MAIN_ROAD or tile == MAP_TILE_DIRT_ROAD
end

-- Check if world position is on a MAIN road only (for vehicles - no dirt roads)
function is_on_main_road(wx, wy)
	if not WORLD_DATA or not WORLD_DATA.tiles then return false end
	local tile = get_map_tile_at_world(wx, wy)
	return tile == MAP_TILE_MAIN_ROAD
end

-- Check if world position is walkable for NPCs (sidewalk or grass)
function is_walkable_terrain(wx, wy)
	return is_on_sidewalk(wx, wy) or is_on_grass(wx, wy)
end

-- Check if world position is water (from parsed map data)
function is_water(wx, wy)
	-- Use map data if available
	if WORLD_DATA and WORLD_DATA.tiles then
		return is_water_from_map(wx, wy)
	end
	return false
end

-- Get the nearest sidewalk position from a given point
-- Returns x, y of nearest sidewalk tile center, or nil if none found
function get_nearest_sidewalk(wx, wy)
	local search_radius = 200  -- max search distance
	local best_dist = search_radius * search_radius
	local best_x, best_y = nil, nil

	-- Search in expanding squares
	for dist = 16, search_radius, 16 do
		-- Check points at this distance in 8 directions
		local offsets = {
			{ dx = 0, dy = -dist },   -- north
			{ dx = 0, dy = dist },    -- south
			{ dx = -dist, dy = 0 },   -- west
			{ dx = dist, dy = 0 },    -- east
			{ dx = -dist, dy = -dist }, -- NW
			{ dx = dist, dy = -dist },  -- NE
			{ dx = -dist, dy = dist },  -- SW
			{ dx = dist, dy = dist },   -- SE
		}

		for _, off in ipairs(offsets) do
			local tx = wx + off.dx
			local ty = wy + off.dy
			if is_on_sidewalk(tx, ty) then
				local d = off.dx * off.dx + off.dy * off.dy
				if d < best_dist then
					best_dist = d
					best_x = tx
					best_y = ty
				end
			end
		end

		-- If we found something at this distance, return it
		if best_x then
			return best_x, best_y
		end
	end

	return nil, nil
end

-- Get direction towards a target position
function get_direction_towards(from_x, from_y, to_x, to_y)
	local dx = to_x - from_x
	local dy = to_y - from_y

	-- Prefer the axis with larger difference
	if abs(dx) > abs(dy) then
		if dx > 0 then return "east" else return "west" end
	else
		if dy > 0 then return "south" else return "north" end
	end
end
