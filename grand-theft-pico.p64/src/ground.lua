--[[pod_format="raw"]]
-- ground.lua - Tile-based ground rendering with BATCHED userdata ops

-- Tile types
TILE_GRASS = 0
TILE_DIRT_LIGHT = 1
TILE_DIRT_MEDIUM = 2
TILE_DIRT_HEAVY = 3

-- Scanline buffer for batched ground rendering (11 values per scanline)
-- Format per row: spr, x0, y, x1, y, u0, v0, u1, v1, w0, w1
local ground_scanlines = userdata("f64", 11, 270)

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

-- Draw ground using BATCHED tline3d with userdata ops
function draw_ground()
	local grass_spr = SPRITES.GRASS.id
	local grass_tex_size = SPRITES.GRASS.w  -- use sprite width from config

	-- Calculate how many times to tile grass across screen width
	local tiles_x = SCREEN_W / grass_tex_size
	local tex_u_end = tiles_x * grass_tex_size

	-- Calculate world offsets for texture scrolling
	local world_x_offset = cam_x - SCREEN_CX
	local world_y_offset = cam_y - SCREEN_CY
	local tex_u_start = world_x_offset % grass_tex_size

	-- Create start vector for first scanline (y=0)
	-- Format: spr, x0, y, x1, y, u0, v0, u1, v1, w0, w1
	local tex_v_start = world_y_offset % grass_tex_size
	local v_start = vec(grass_spr, 0, 0, SCREEN_W, 0, tex_u_start, tex_v_start, tex_u_start + tex_u_end, tex_v_start, 1, 1)

	-- Slope per scanline: only y and v change
	-- y increases by 1, v increases by 1 (will wrap via texture sampling)
	local slope = vec(0, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0)

	-- Batch fill all scanlines using userdata ops
	ground_scanlines:copy(v_start, true, 0, 0, 11)
	ground_scanlines:copy(slope, true, 0, 11, 11, 0, 11, SCREEN_H - 1)
	ground_scanlines:add(ground_scanlines, true, 0, 11, 11, 11, 11, SCREEN_H - 1)

	-- Draw all grass scanlines in one batch call
	tline3d(ground_scanlines, 0, SCREEN_H)

	-- Second pass: draw roads on top
	for _, road in ipairs(ROADS) do
		draw_road_batched(road)
	end
end

-- Draw a single road segment using BATCHED tline3d with userdata ops
function draw_road_batched(road)
	local tile_spr = get_tile_sprite(road.tile_type or TILE_DIRT_MEDIUM)
	local tex_size = 16
	local half_w = road.width / 2

	-- Calculate world offsets for texture scrolling
	local world_x_offset = cam_x - SCREEN_CX
	local world_y_offset = cam_y - SCREEN_CY

	local draw_x1, draw_x2, draw_y1, draw_y2

	if road.direction == "horizontal" then
		local sx1, sy1 = world_to_screen(road.x1, road.y - half_w)
		local sx2, _ = world_to_screen(road.x2, road.y - half_w)
		local _, sy2 = world_to_screen(road.x1, road.y + half_w)

		draw_x1 = max(0, sx1)
		draw_x2 = min(SCREEN_W, sx2)
		draw_y1 = max(0, flr(sy1))
		draw_y2 = min(SCREEN_H, flr(sy2))
	elseif road.direction == "vertical" then
		local sx1, sy1 = world_to_screen(road.x - half_w, road.y1)
		local sx2, sy2 = world_to_screen(road.x + half_w, road.y2)

		draw_x1 = max(0, sx1)
		draw_x2 = min(SCREEN_W, sx2)
		draw_y1 = max(0, flr(sy1))
		draw_y2 = min(SCREEN_H, flr(sy2))
	else
		return
	end

	if draw_x1 >= draw_x2 or draw_y1 >= draw_y2 then return end

	local count = draw_y2 - draw_y1
	if count < 1 then return end

	local road_screen_width = draw_x2 - draw_x1
	local tiles_across = max(1, road_screen_width / tex_size)
	local tex_u_start = (world_x_offset + draw_x1) % tex_size
	local tex_u_end = tex_u_start + tiles_across * tex_size

	-- Calculate starting V coordinate based on world position
	local wy_start = world_y_offset + draw_y1
	local tex_v_start = wy_start % tex_size

	-- Create start vector for first scanline
	local v_start = vec(tile_spr, draw_x1, draw_y1, draw_x2, draw_y1, tex_u_start, tex_v_start, tex_u_end, tex_v_start, 1, 1)

	-- Slope per scanline: y increases by 1, v increases by 1
	local slope = vec(0, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0)

	-- Batch fill scanlines using userdata ops
	ground_scanlines:copy(v_start, true, 0, 0, 11)
	if count > 1 then
		ground_scanlines:copy(slope, true, 0, 11, 11, 0, 11, count - 1)
		ground_scanlines:add(ground_scanlines, true, 0, 11, 11, 11, 11, count - 1)
	end

	-- Draw all road scanlines in one batch call
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
