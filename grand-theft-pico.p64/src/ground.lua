--[[pod_format="raw"]]
-- ground.lua - Tile-based ground rendering with BATCHED userdata ops

-- Tile types
TILE_GRASS = 0
TILE_DIRT_LIGHT = 1
TILE_DIRT_MEDIUM = 2
TILE_DIRT_HEAVY = 3
TILE_SIDEWALK_NS = 4
TILE_SIDEWALK_EW = 5

-- Scanline buffer for batched ground rendering (11 values per scanline)
-- Format per row: spr, x0, y, x1, y, u0, v0, u1, v1, w0, w1
local ground_scanlines = userdata("f64", 11, 270)

-- Pre-allocated slope vector (reused across all ground drawing)
local ground_slope = vec(0, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0)

-- Batched sprite buffer for tilemap rendering
-- Format per row: sprite_id, x, y (no flip needed for ground tiles)
-- Max tiles visible: ~20x17 = 340 tiles, round up to 400
local MAX_VISIBLE_TILES = 400
local tile_batch = userdata("f64", 3, MAX_VISIBLE_TILES)

-- Tilemap-based rendering (alternative approach)
-- World is divided into 16x16 tiles, stored in a 2D userdata grid
local TILE_SIZE = 16
-- Expanded world bounds to include countryside
local WORLD_MIN_X = -1200
local WORLD_MIN_Y = -800
local WORLD_MAX_X = 2200
local WORLD_MAX_Y = 1900
local TILEMAP_W = 0  -- calculated at init
local TILEMAP_H = 0
local ground_tilemap = nil  -- userdata("u8", TILEMAP_W, TILEMAP_H)
local tilemap_ready = false

-- Sprite IDs for each tile type (cached at init)
local tile_sprites = {}

-- Initialize the ground tilemap (call once in _init)
function init_ground_tilemap()
	-- Calculate tilemap dimensions
	TILEMAP_W = ceil((WORLD_MAX_X - WORLD_MIN_X) / TILE_SIZE)
	TILEMAP_H = ceil((WORLD_MAX_Y - WORLD_MIN_Y) / TILE_SIZE)

	printh("Initializing ground tilemap: " .. TILEMAP_W .. "x" .. TILEMAP_H .. " tiles")

	-- Create tilemap (tile type per cell)
	ground_tilemap = userdata("u8", TILEMAP_W, TILEMAP_H)

	-- Cache sprite IDs for each tile type
	tile_sprites[TILE_GRASS] = SPRITES.GRASS.id
	tile_sprites[TILE_DIRT_LIGHT] = SPRITES.DIRT_LIGHT.id
	tile_sprites[TILE_DIRT_MEDIUM] = SPRITES.DIRT_MEDIUM.id
	tile_sprites[TILE_DIRT_HEAVY] = SPRITES.DIRT_HEAVY.id
	tile_sprites[TILE_SIDEWALK_NS] = SPRITES.SIDEWALK_NS.id
	tile_sprites[TILE_SIDEWALK_EW] = SPRITES.SIDEWALK_EW.id

	-- Fill with grass by default
	for ty = 0, TILEMAP_H - 1 do
		for tx = 0, TILEMAP_W - 1 do
			ground_tilemap:set(tx, ty, TILE_GRASS)
		end
	end

	-- Paint sidewalks first (so roads overwrite at intersections)
	for _, road in ipairs(ROADS) do
		paint_sidewalks_to_tilemap(road)
	end
	-- Then paint city roads on top
	for _, road in ipairs(ROADS) do
		paint_road_surface_to_tilemap(road)
	end
	-- Paint countryside roads (no sidewalks)
	for _, road in ipairs(COUNTRYSIDE_ROADS) do
		paint_road_surface_to_tilemap(road)
	end

	tilemap_ready = true
	printh("Ground tilemap ready!")
end

-- Paint only sidewalks for a road onto the tilemap
function paint_sidewalks_to_tilemap(road)
	local half_road = road.width / 2
	local sidewalk_w = ROAD_CONFIG.sidewalk_width

	if road.direction == "horizontal" then
		local sidewalk_tile = TILE_SIDEWALK_EW
		local road_y1 = road.y - half_road
		local road_y2 = road.y + half_road
		-- Top sidewalk
		paint_rect_to_tilemap(road.x1, road_y1 - sidewalk_w, road.x2, road_y1, sidewalk_tile)
		-- Bottom sidewalk
		paint_rect_to_tilemap(road.x1, road_y2, road.x2, road_y2 + sidewalk_w, sidewalk_tile)
	elseif road.direction == "vertical" then
		local sidewalk_tile = TILE_SIDEWALK_NS
		local road_x1 = road.x - half_road
		local road_x2 = road.x + half_road
		-- Left sidewalk
		paint_rect_to_tilemap(road_x1 - sidewalk_w, road.y1, road_x1, road.y2, sidewalk_tile)
		-- Right sidewalk
		paint_rect_to_tilemap(road_x2, road.y1, road_x2 + sidewalk_w, road.y2, sidewalk_tile)
	end
end

-- Paint only road surface onto the tilemap (called after sidewalks)
function paint_road_surface_to_tilemap(road)
	local half_road = road.width / 2
	local road_tile = road.tile_type or TILE_DIRT_MEDIUM

	if road.direction == "horizontal" then
		paint_rect_to_tilemap(road.x1, road.y - half_road, road.x2, road.y + half_road, road_tile)
	elseif road.direction == "vertical" then
		paint_rect_to_tilemap(road.x - half_road, road.y1, road.x + half_road, road.y2, road_tile)
	end
end

-- Get tile type at a world position (for flora system etc.)
function get_tile_type(wx, wy)
	if not tilemap_ready then return TILE_GRASS end

	-- Convert world coords to tile coords
	local tx = flr((wx - WORLD_MIN_X) / TILE_SIZE)
	local ty = flr((wy - WORLD_MIN_Y) / TILE_SIZE)

	-- Bounds check
	if tx < 0 or tx >= TILEMAP_W or ty < 0 or ty >= TILEMAP_H then
		return TILE_GRASS  -- default to grass outside bounds
	end

	return ground_tilemap:get(tx, ty)
end

-- Paint a rectangle of tiles onto the tilemap
function paint_rect_to_tilemap(wx1, wy1, wx2, wy2, tile_type)
	-- Convert world coords to tile coords
	local tx1 = flr((wx1 - WORLD_MIN_X) / TILE_SIZE)
	local ty1 = flr((wy1 - WORLD_MIN_Y) / TILE_SIZE)
	local tx2 = ceil((wx2 - WORLD_MIN_X) / TILE_SIZE)
	local ty2 = ceil((wy2 - WORLD_MIN_Y) / TILE_SIZE)

	-- Clamp to tilemap bounds
	tx1 = max(0, min(tx1, TILEMAP_W - 1))
	ty1 = max(0, min(ty1, TILEMAP_H - 1))
	tx2 = max(0, min(tx2, TILEMAP_W - 1))
	ty2 = max(0, min(ty2, TILEMAP_H - 1))

	for ty = ty1, ty2 do
		for tx = tx1, tx2 do
			ground_tilemap:set(tx, ty, tile_type)
		end
	end
end

-- Draw ground using tilemap (alternative to batched tline3d)
-- Uses batched spr() for better performance
function draw_ground_tilemap()
	if not tilemap_ready then return end

	-- Calculate which tiles are visible
	local cam_left = cam_x - SCREEN_CX
	local cam_top = cam_y - SCREEN_CY

	-- Tile range to draw (with 1 tile margin)
	local tx_start = flr((cam_left - WORLD_MIN_X) / TILE_SIZE) - 1
	local ty_start = flr((cam_top - WORLD_MIN_Y) / TILE_SIZE) - 1
	local tx_end = tx_start + ceil(SCREEN_W / TILE_SIZE) + 2
	local ty_end = ty_start + ceil(SCREEN_H / TILE_SIZE) + 2

	-- Clamp to tilemap bounds
	tx_start = max(0, tx_start)
	ty_start = max(0, ty_start)
	tx_end = min(TILEMAP_W - 1, tx_end)
	ty_end = min(TILEMAP_H - 1, ty_end)

	-- Pre-calculate screen offset for first tile
	local base_world_x = WORLD_MIN_X + tx_start * TILE_SIZE
	local base_world_y = WORLD_MIN_Y + ty_start * TILE_SIZE
	local base_sx = base_world_x - cam_x + SCREEN_CX
	local base_sy = base_world_y - cam_y + SCREEN_CY

	-- Build batch of visible tiles
	local tile_count = 0
	local grass_spr = tile_sprites[TILE_GRASS]

	for ty = ty_start, ty_end do
		local sy = base_sy + (ty - ty_start) * TILE_SIZE
		for tx = tx_start, tx_end do
			if tile_count >= MAX_VISIBLE_TILES then break end

			local tile_type = ground_tilemap:get(tx, ty)
			local spr_id = tile_sprites[tile_type] or grass_spr
			local sx = base_sx + (tx - tx_start) * TILE_SIZE

			-- Pack into batch: sprite_id, x, y
			tile_batch:set(0, tile_count, spr_id)
			tile_batch:set(1, tile_count, sx)
			tile_batch:set(2, tile_count, sy)
			tile_count = tile_count + 1
		end
	end

	-- Draw all tiles in one batched call
	if tile_count > 0 then
		spr(tile_batch, 0, tile_count)
	end
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

-- Get tile size for tile type (grass is 8x8, dirt is 16x16)
function get_tile_size(tile_type)
	if tile_type == TILE_GRASS then
		return 8
	end
	return 16
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

-- Draw ground using BATCHED tline3d with userdata ops
function draw_ground()
	local grass_spr = SPRITES.GRASS.id
	local grass_tex_size = SPRITES.GRASS.w

	-- Calculate world offsets for texture scrolling
	local world_x_offset = cam_x - SCREEN_CX
	local world_y_offset = cam_y - SCREEN_CY
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

	-- Draw all sidewalks first (so roads overwrite at intersections)
	for _, road in ipairs(ROADS) do
		if is_road_visible(road) then
			draw_sidewalks_batched(road, world_x_offset, world_y_offset)
		end
	end

	-- Then draw all city roads on top
	for _, road in ipairs(ROADS) do
		if is_road_visible(road) then
			draw_road_batched(road, world_x_offset, world_y_offset)
		end
	end

	-- Draw countryside roads (no sidewalks)
	for _, road in ipairs(COUNTRYSIDE_ROADS) do
		if is_road_visible(road) then
			draw_road_batched(road, world_x_offset, world_y_offset)
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

-- Legacy non-batched function (kept for reference)
function draw_road(road)
	draw_road_batched(road)
end

-- Get tile type at world position
-- Uses road definitions to determine if dirt or grass
function get_ground_tile(wx, wy)
	-- Check if position is on a road
	for _, road in ipairs(ROADS) do
		if is_on_road(wx, wy, road) then
			return road.tile_type or TILE_DIRT_MEDIUM
		end
	end

	-- Default to grass
	return TILE_GRASS
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
