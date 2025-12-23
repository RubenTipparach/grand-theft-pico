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

-- Check if player would collide with any building at given position
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

	return false
end

-- Try to move player, handling collisions with sliding
-- Returns the final position after collision resolution
function move_with_collision(old_x, old_y, dx, dy, speed)
	local new_x = old_x + dx * speed
	local new_y = old_y + dy * speed

	-- Try full movement first
	if not would_collide(new_x, new_y) then
		return new_x, new_y
	end

	-- Try X movement only (slide along Y axis)
	if dx ~= 0 and not would_collide(new_x, old_y) then
		return new_x, old_y
	end

	-- Try Y movement only (slide along X axis)
	if dy ~= 0 and not would_collide(old_x, new_y) then
		return old_x, new_y
	end

	-- Can't move at all, stay in place
	return old_x, old_y
end
