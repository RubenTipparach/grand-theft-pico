--[[pod_format="raw"]]
-- perspective.lua - GTA1/2 top-down perspective projection
--
-- GTA1/2 style: Fixed overhead camera, buildings have constant height
-- The "3D effect" comes from walls/roof offsetting OUTWARD from screen center
-- Buildings at screen edges show more wall, buildings at center show mostly roof

-- Convert world coords to screen coords
function world_to_screen(wx, wy)
	local sx = wx - cam_x + SCREEN_CX
	local sy = wy - cam_y + SCREEN_CY
	return sx, sy
end

-- Get fixed wall height for buildings
-- In GTA1/2 style, all buildings have the same wall height
function get_wall_height(sx, sy)
	return PERSPECTIVE_CONFIG.max_wall_height
end

-- Calculate wall top offset (walls lean outward from center)
-- This is the key to the GTA1/2 perspective effect:
-- - Buildings at screen center: offset is ~0, you see mostly roof
-- - Buildings at screen edges: offset pushes roof away, you see walls
function get_wall_offset(sx, sy, wall_height)
	local p_scale = PERSPECTIVE_CONFIG.perspective_scale

	-- Direction from screen center to building
	local dx = sx - SCREEN_CX
	local dy = sy - SCREEN_CY

	-- Offset increases with distance from center
	-- This makes roofs "slide" outward, revealing walls
	local ox = dx * p_scale
	local oy = dy * p_scale

	return ox, oy
end

-- Determine which walls are visible (walls face away from center)
-- In GTA1/2 top-down view, walls face TOWARD the camera (opposite of backface culling)
-- The roof offsets outward, revealing walls on the side TOWARD screen center
function get_visible_walls(sx, sy)
	local threshold = PERSPECTIVE_CONFIG.wall_visibility_threshold
	local dx = sx - SCREEN_CX
	local dy = sy - SCREEN_CY
	return {
		-- Building below center (dy > 0): roof shifts down, show NORTH wall (top edge)
		north = dy > threshold,
		-- Building above center (dy < 0): roof shifts up, show SOUTH wall (bottom edge)
		south = dy < -threshold,
		-- Building right of center (dx > 0): roof shifts right, show WEST wall (left edge)
		west  = dx > threshold,
		-- Building left of center (dx < 0): roof shifts left, show EAST wall (right edge)
		east  = dx < -threshold
	}
end
