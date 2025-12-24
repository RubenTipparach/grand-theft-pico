--[[pod_format="raw"]]
-- input.lua - Input handling and camera control

-- Animation timer (global so it persists)
walk_timer = 0

-- Handle player input and update camera
function handle_input()
	local dx, dy = 0, 0

	if btn(0) then dx = -1 end  -- left
	if btn(1) then dx = 1 end   -- right
	if btn(2) then dy = -1 end  -- up
	if btn(3) then dy = 1 end   -- down

	-- Get speed from config
	local speed = PLAYER_CONFIG.walk_speed

	-- Move player with collision detection
	local new_x, new_y = move_with_collision(
		game.player.x, game.player.y,
		dx, dy, speed
	)
	game.player.x = new_x
	game.player.y = new_y

	-- Update facing direction based on dominant velocity
	-- When vertical > horizontal, use north/south; otherwise east/west
	if dx ~= 0 or dy ~= 0 then
		if abs(dy) > abs(dx) then
			-- Vertical movement dominates
			if dy < 0 then
				game.player.facing_dir = "north"
			else
				game.player.facing_dir = "south"
			end
		else
			-- Horizontal movement dominates (or equal)
			game.player.facing_dir = "east"  -- east/west use same sprites with flip
			game.player.facing_right = (dx < 0)
		end
	end

	-- Update walking animation
	local is_moving = (dx ~= 0 or dy ~= 0)
	if is_moving then
		walk_timer = walk_timer + 1
		local anim_speed = PLAYER_CONFIG.animation_speed
		-- 2-frame walk cycle: alternate between 1 and 2 (not 0 which is idle)
		local frame_index = flr(walk_timer / anim_speed) % 2 + 1
		game.player.walk_frame = frame_index  -- 1 or 2
	else
		walk_timer = 0
		game.player.walk_frame = 0  -- idle when not moving
	end

	-- Camera follows player
	cam_x = game.player.x
	cam_y = game.player.y
end

-- Get current player sprite based on facing direction and walk frame
function get_player_sprite()
	local frame = game.player.walk_frame
	local dir = game.player.facing_dir or "east"

	if dir == "north" then
		-- Facing away from camera (north)
		if frame == 0 then
			return SPRITES.PLAYER_NORTH_IDLE.id
		elseif frame == 1 then
			return SPRITES.PLAYER_NORTH_WALK1.id
		else
			return SPRITES.PLAYER_NORTH_WALK2.id
		end
	elseif dir == "south" then
		-- Facing toward camera (south)
		if frame == 0 then
			return SPRITES.PLAYER_SOUTH_IDLE.id
		elseif frame == 1 then
			return SPRITES.PLAYER_SOUTH_WALK1.id
		else
			return SPRITES.PLAYER_SOUTH_WALK2.id
		end
	else
		-- East/West (horizontal) - use original sprites with flip_x
		if frame == 0 then
			return SPRITES.PLAYER_IDLE.id
		elseif frame == 1 then
			return SPRITES.PLAYER_WALK1.id
		else
			return SPRITES.PLAYER_WALK2.id
		end
	end
end
