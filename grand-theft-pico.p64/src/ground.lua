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

-- Stub for water animation (no-op, keeps main.lua compatible)
function update_water_animation()
	-- No water implementation
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
-- Uses road definitions to determine if dirt, sidewalk, or grass
function get_ground_tile(wx, wy)
	-- Check if position is on a road
	for _, road in ipairs(ROADS) do
		if is_on_road(wx, wy, road) then
			return road.tile_type or TILE_DIRT_MEDIUM
		end
	end

	-- Check if position is on a sidewalk
	if is_on_sidewalk(wx, wy) then
		return TILE_SIDEWALK_NS  -- return any sidewalk type (flora checks != TILE_GRASS)
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

-- Check if world position is on a sidewalk
function is_on_sidewalk(wx, wy)
	-- Check each road's sidewalk areas
	for _, road in ipairs(ROADS) do
		local half_road = road.width / 2
		local sidewalk_w = ROAD_CONFIG.sidewalk_width

		if road.direction == "horizontal" then
			-- Check top sidewalk
			if wy >= road.y - half_road - sidewalk_w and wy < road.y - half_road then
				if wx >= road.x1 and wx < road.x2 then
					return true
				end
			end
			-- Check bottom sidewalk
			if wy >= road.y + half_road and wy < road.y + half_road + sidewalk_w then
				if wx >= road.x1 and wx < road.x2 then
					return true
				end
			end
		else
			-- Check left sidewalk
			if wx >= road.x - half_road - sidewalk_w and wx < road.x - half_road then
				if wy >= road.y1 and wy < road.y2 then
					return true
				end
			end
			-- Check right sidewalk
			if wx >= road.x + half_road and wx < road.x + half_road + sidewalk_w then
				if wy >= road.y1 and wy < road.y2 then
					return true
				end
			end
		end
	end
	return false
end

-- Check if world position is on grass (not road or sidewalk)
function is_on_grass(wx, wy)
	return not is_on_any_road(wx, wy) and not is_on_sidewalk(wx, wy)
end

-- Check if world position is on a road surface (dirt tiles)
function is_on_road_surface(wx, wy)
	return is_on_any_road(wx, wy)
end

-- Check if world position is walkable for NPCs (sidewalk or grass)
function is_walkable_terrain(wx, wy)
	return is_on_sidewalk(wx, wy) or is_on_grass(wx, wy)
end

-- Check if world position is water (no water implemented - always false)
function is_water(wx, wy)
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
