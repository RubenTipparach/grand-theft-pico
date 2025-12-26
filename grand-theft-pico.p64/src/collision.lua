--[[pod_format="raw"]]
-- collision.lua - Collision detection for player and buildings

-- Player collision box size (smaller than sprite for better feel)
-- Centered horizontally, positioned at feet vertically
-- Player sprite is 16x16, collision box is 10x6 centered at feet
PLAYER_COLLISION = {
	w = 8,  -- collision width
	h = 8,   -- collision height
	ox = 0,  -- offset from player.x to collision box left edge (centers 10px box in 16px sprite)
	oy = 0  -- offset from player.y to collision box top edge (feet area, bottom 6px of sprite)
}

-- Check if a point + size overlaps with a building's footprint
-- Accounts for perspective offset so collision matches visual appearance
function check_building_collision(px, py, pw, ph, building)
	-- Player collision box
	local p_left = px
	local p_right = px + pw
	local p_top = py
	local p_bottom = py + ph

	-- Get building center in screen coords to calculate perspective offset
	local bcx, bcy = world_to_screen(building.x + building.w / 2, building.y + building.h / 2)
	local wall_h = get_wall_height(bcx, bcy)
	local ox, oy = get_wall_offset(bcx, bcy, wall_h)

	-- Building footprint adjusted by perspective offset
	-- The roof/walls shift, so the collision should match
	local b_left = building.x + ox
	local b_right = building.x + building.w + ox
	local b_top = building.y + oy
	local b_bottom = building.y + building.h + oy

	-- AABB overlap test
	return p_left < b_right and
	       p_right > b_left and
	       p_top < b_bottom and
	       p_bottom > b_top
end

-- Check if player would collide with any building or water at given position
function would_collide(new_x, new_y)
	-- Calculate player's collision box at new position
	local col_x = new_x + PLAYER_COLLISION.ox
	local col_y = new_y + PLAYER_COLLISION.oy
	local col_w = PLAYER_COLLISION.w
	local col_h = PLAYER_COLLISION.h

	-- Check against all buildings
	for _, b in ipairs(buildings) do
		if check_building_collision(col_x, col_y, col_w, col_h, b) then
			return true
		end
	end

	-- Check for water collision (check center and corners of collision box)
	if is_water(col_x, col_y) or
	   is_water(col_x + col_w, col_y) or
	   is_water(col_x, col_y + col_h) or
	   is_water(col_x + col_w, col_y + col_h) or
	   is_water(col_x + col_w / 2, col_y + col_h / 2) then
		return true
	end

	return false
end

-- Try to push player out of a building if stuck inside
-- Returns new position if pushed out, or original position if not stuck
function push_out_of_buildings(x, y)
	if not would_collide(x, y) then
		return x, y  -- not stuck
	end

	-- Try pushing in each direction to escape
	local push_dist = 2  -- pixels to push per attempt
	local max_attempts = 20  -- max distance = push_dist * max_attempts

	for attempt = 1, max_attempts do
		local dist = push_dist * attempt
		-- Try all 8 directions
		local directions = {
			{ dx = 0, dy = -1 },   -- north
			{ dx = 0, dy = 1 },    -- south
			{ dx = -1, dy = 0 },   -- west
			{ dx = 1, dy = 0 },    -- east
			{ dx = -1, dy = -1 },  -- NW
			{ dx = 1, dy = -1 },   -- NE
			{ dx = -1, dy = 1 },   -- SW
			{ dx = 1, dy = 1 },    -- SE
		}
		for _, dir in ipairs(directions) do
			local test_x = x + dir.dx * dist
			local test_y = y + dir.dy * dist
			if not would_collide(test_x, test_y) then
				return test_x, test_y
			end
		end
	end

	-- Couldn't escape, return original position
	return x, y
end

-- Try to move player, handling collisions with sliding
-- Returns the final position after collision resolution
function move_with_collision(old_x, old_y, dx, dy, speed)
	-- First, check if we're stuck and try to push out
	local start_x, start_y = push_out_of_buildings(old_x, old_y)

	local new_x = start_x + dx * speed
	local new_y = start_y + dy * speed

	-- Try full movement first
	if not would_collide(new_x, new_y) then
		return new_x, new_y
	end

	-- Try X movement only (slide along Y axis)
	if dx ~= 0 and not would_collide(new_x, start_y) then
		return new_x, start_y
	end

	-- Try Y movement only (slide along X axis)
	if dy ~= 0 and not would_collide(start_x, new_y) then
		return start_x, new_y
	end

	-- Can't move at all, stay in place (but use pushed-out position)
	return start_x, start_y
end
