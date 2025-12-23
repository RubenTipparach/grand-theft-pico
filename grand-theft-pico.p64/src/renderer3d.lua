--[[pod_format="raw"]]
-- renderer3d.lua - Proper 3D projection for GTA-style top-down view

-- 3D Camera for top-down view (looking down at an angle)
Camera3D = {
	x = 0,           -- world X position (follows player)
	y = 0,           -- world Y position (follows player)
	z = 0,           -- world Z (height) - not used for player
	pitch = 0.15,    -- camera pitch (tilt angle, ~54 degrees from vertical)
	yaw = 0,         -- camera yaw (rotation) - 0 = looking down -Z
	distance = 8,    -- distance from focal point
	fov = 70,        -- field of view in degrees
}

-- Projection constants
local SCREEN_W = 480
local SCREEN_H = 270
local HALF_W = 240
local HALF_H = 135

-- Precomputed values (updated when camera changes)
local cos_pitch, sin_pitch = 1, 0
local cos_yaw, sin_yaw = 1, 0
local proj_scale = 270 / 0.7  -- ~385

-- Update camera precomputed values
function update_camera()
	cos_pitch = cos(Camera3D.pitch)
	sin_pitch = sin(Camera3D.pitch)
	cos_yaw = cos(Camera3D.yaw)
	sin_yaw = sin(Camera3D.yaw)

	-- Projection scale based on FOV
	local tan_half_fov = sin(Camera3D.fov / 360) / cos(Camera3D.fov / 360)
	proj_scale = SCREEN_H / tan_half_fov
end

-- Project a 3D world point to 2D screen coordinates
-- world_x, world_y = horizontal position (like map coordinates)
-- world_z = height (vertical in 3D space)
-- Returns screen_x, screen_y, depth (or nil if behind camera)
function project_point(world_x, world_y, world_z)
	-- Translate relative to camera
	local dx = world_x - Camera3D.x
	local dy = world_y - Camera3D.y
	local dz = world_z  -- height relative to ground

	-- Rotate around Y axis (yaw) - in world XY plane
	local rx = dx * cos_yaw - dy * sin_yaw
	local ry = dx * sin_yaw + dy * cos_yaw

	-- Rotate around X axis (pitch) - tilt camera
	local rz = dz * cos_pitch - ry * sin_pitch
	local ry2 = dz * sin_pitch + ry * cos_pitch

	-- Apply camera distance (camera is above and behind)
	local view_z = ry2 + Camera3D.distance

	-- Near plane clipping
	if view_z < 0.1 then return nil, nil, nil end

	-- Perspective projection
	local inv_z = 1 / view_z
	local screen_x = HALF_W + rx * proj_scale * inv_z
	local screen_y = HALF_H - rz * proj_scale * inv_z

	return screen_x, screen_y, view_z
end

-- Draw a textured quad (4 vertices) using tline3d scanlines
-- Vertices are in world coordinates: {x, y, z}
-- UVs are texture coordinates for each vertex
function draw_quad_3d(sprite_idx, v1, v2, v3, v4)
	-- Project all 4 vertices
	local sx1, sy1, d1 = project_point(v1.x, v1.y, v1.z)
	local sx2, sy2, d2 = project_point(v2.x, v2.y, v2.z)
	local sx3, sy3, d3 = project_point(v3.x, v3.y, v3.z)
	local sx4, sy4, d4 = project_point(v4.x, v4.y, v4.z)

	-- Skip if any vertex is behind camera
	if not sx1 or not sx2 or not sx3 or not sx4 then return end

	-- Draw as two triangles using scanlines
	-- Triangle 1: v1, v2, v3
	draw_tri_3d(sprite_idx,
		sx1, sy1, d1, 0, 0,
		sx2, sy2, d2, 16, 0,
		sx3, sy3, d3, 16, 16)

	-- Triangle 2: v1, v3, v4
	draw_tri_3d(sprite_idx,
		sx1, sy1, d1, 0, 0,
		sx3, sy3, d3, 16, 16,
		sx4, sy4, d4, 0, 16)
end

-- Draw a textured triangle using horizontal scanlines
function draw_tri_3d(sprite_idx, x1, y1, d1, u1, v1, x2, y2, d2, u2, v2, x3, y3, d3, u3, v3)
	-- Sort vertices by Y coordinate (top to bottom)
	if y1 > y2 then
		x1, y1, d1, u1, v1, x2, y2, d2, u2, v2 = x2, y2, d2, u2, v2, x1, y1, d1, u1, v1
	end
	if y2 > y3 then
		x2, y2, d2, u2, v2, x3, y3, d3, u3, v3 = x3, y3, d3, u3, v3, x2, y2, d2, u2, v2
	end
	if y1 > y2 then
		x1, y1, d1, u1, v1, x2, y2, d2, u2, v2 = x2, y2, d2, u2, v2, x1, y1, d1, u1, v1
	end

	-- Calculate perspective-correct weights (1/z)
	local w1 = 1 / d1
	local w2 = 1 / d2
	local w3 = 1 / d3

	-- Top to middle section
	local dy12 = y2 - y1
	local dy13 = y3 - y1

	if dy13 > 0 then
		-- Slopes for long edge (v1 to v3)
		local dx13 = (x3 - x1) / dy13
		local dw13 = (w3 - w1) / dy13

		-- Top half
		if dy12 > 0 then
			local dx12 = (x2 - x1) / dy12
			local dw12 = (w2 - w1) / dy12

			local start_y = max(0, flr(y1))
			local end_y = min(SCREEN_H - 1, flr(y2))

			for y = start_y, end_y do
				local t = y - y1
				local xa = x1 + dx12 * t
				local xb = x1 + dx13 * t
				local wa = w1 + dw12 * t
				local wb = w1 + dw13 * t

				if xa > xb then
					xa, xb, wa, wb = xb, xa, wb, wa
				end

				-- Draw scanline with tline3d
				local tex_v = (y - start_y) % 16
				tline3d(sprite_idx, xa, y, xb, y,
						0, tex_v, 16, tex_v,
						wa, wb, 0x200)
			end
		end

		-- Bottom half
		local dy23 = y3 - y2
		if dy23 > 0 then
			local dx23 = (x3 - x2) / dy23
			local dw23 = (w3 - w2) / dy23

			local start_y = max(0, flr(y2))
			local end_y = min(SCREEN_H - 1, flr(y3))

			for y = start_y, end_y do
				local t12 = y - y1
				local t23 = y - y2
				local xa = x2 + dx23 * t23
				local xb = x1 + dx13 * t12
				local wa = w2 + dw23 * t23
				local wb = w1 + dw13 * t12

				if xa > xb then
					xa, xb, wa, wb = xb, xa, wb, wa
				end

				local tex_v = (y - start_y) % 16
				tline3d(sprite_idx, xa, y, xb, y,
						0, tex_v, 16, tex_v,
						wa, wb, 0x200)
			end
		end
	end
end

-- Draw a 3D box (building) with textured walls and roof
-- x, y = world position, w, h = footprint size, height = building height
function draw_building_3d(x, y, w, h, height, wall_sprite, roof_sprite)
	-- Define 8 vertices of the box
	-- Bottom face (on ground, z=0)
	local b1 = {x = x,     y = y,     z = 0}
	local b2 = {x = x + w, y = y,     z = 0}
	local b3 = {x = x + w, y = y + h, z = 0}
	local b4 = {x = x,     y = y + h, z = 0}

	-- Top face (roof, z=height)
	local t1 = {x = x,     y = y,     z = height}
	local t2 = {x = x + w, y = y,     z = height}
	local t3 = {x = x + w, y = y + h, z = height}
	local t4 = {x = x,     y = y + h, z = height}

	-- Get projected center for depth sorting / culling
	local cx, cy, cd = project_point(x + w/2, y + h/2, height/2)
	if not cx then return end  -- Building behind camera

	-- Determine which faces are visible based on camera position
	local dx = (x + w/2) - Camera3D.x
	local dy = (y + h/2) - Camera3D.y

	-- Draw back faces first (painter's algorithm)
	-- North wall (back, y=y) - visible when building is in front of camera
	if dy > 0 then
		draw_quad_3d(wall_sprite, b1, b2, t2, t1)
	end

	-- West wall (left, x=x) - visible when building is to the right
	if dx > 0 then
		draw_quad_3d(wall_sprite, b1, t1, t4, b4)
	end

	-- East wall (right, x=x+w) - visible when building is to the left
	if dx < 0 then
		draw_quad_3d(wall_sprite, b2, b3, t3, t2)
	end

	-- South wall (front, y=y+h) - visible when building is behind camera view
	if dy < 0 then
		draw_quad_3d(wall_sprite, b3, b4, t4, t3)
	end

	-- Roof (always visible from above)
	draw_quad_3d(roof_sprite, t1, t2, t3, t4)
end

-- Initialize camera
update_camera()
