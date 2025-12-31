--[[pod_format="raw"]]
-- input.lua - Input handling and camera control

-- Animation timer (global so it persists, now time-based)
walk_timer = 0
player_last_update_time = nil  -- for delta time calculation
player_was_walking = false     -- for footstep sound start/stop

-- Import input utilities for single-trigger key detection
local input_utils = require("src/input_utils")

-- Handle player input and update camera
function handle_input()
	-- Calculate delta time for frame-independent movement
	local now = time()
	if not player_last_update_time then
		player_last_update_time = now
	end
	local dt = now - player_last_update_time
	player_last_update_time = now
	-- Clamp dt to prevent huge jumps (e.g., after pause or lag)
	if dt > 0.1 then dt = 0.1 end
	-- Skip walking input if player is in a vehicle (vehicle handles its own input)
	-- Also skip if dialog or shop is active (player shouldn't move while in menus)
	-- Also skip during death sequence (player can't move while dead/respawning)
	if not player_vehicle and not (dialog and dialog.active) and not (shop and shop.active) and not death_sequence_active then
		local dx, dy = 0, 0

		if btn(0) then dx = -1 end  -- left
		if btn(1) then dx = 1 end   -- right
		if btn(2) then dy = -1 end  -- up
		if btn(3) then dy = 1 end   -- down

		-- Get speed from config (pixels per second, scaled by delta time)
		local speed = PLAYER_CONFIG.walk_speed * dt * 60  -- multiply by 60 to convert to per-second rate

		-- Move player with collision detection
		local new_x, new_y = move_with_collision(
			game.player.x, game.player.y,
			dx, dy, speed
		)

		-- Clamp to world bounds
		new_x = max(MAP_CONFIG.world_min_x, min(MAP_CONFIG.world_max_x, new_x))
		new_y = max(MAP_CONFIG.world_min_y, min(MAP_CONFIG.world_max_y, new_y))

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
				if dx > 0 then
					game.player.facing_dir = "east"
				else
					game.player.facing_dir = "west"
				end
				game.player.facing_right = (dx < 0)
			end
		end

		-- Update walking animation (time-based)
		local is_moving = (dx ~= 0 or dy ~= 0)
		if is_moving then
			walk_timer = walk_timer + dt
			-- animation_speed is frames at 60fps, convert to seconds (e.g., 8 frames = 8/60 seconds)
			local anim_duration = PLAYER_CONFIG.animation_speed / 60
			-- 2-frame walk cycle: alternate between 1 and 2 (not 0 which is idle)
			local frame_index = flr(walk_timer / anim_duration) % 2 + 1
			game.player.walk_frame = frame_index  -- 1 or 2
			-- Start looping footstep sound when walking begins
			if not player_was_walking then
				sfx(SFX.player_walk, 0, 0, 1)  -- channel 0, offset 0, loop
				player_was_walking = true
			end
		else
			walk_timer = 0
			game.player.walk_frame = 0  -- idle when not moving
			-- Stop footstep sound when walking stops
			if player_was_walking then
				sfx(-1, 0)  -- stop channel 0
				player_was_walking = false
			end
		end
	end

	-- Weapon controls (only when not in vehicle, dialog, shop, or death sequence)
	-- Also check dialog.close_cooldown to prevent firing right after closing dialog with Z
	local dialog_cooldown_active = dialog and dialog.close_cooldown and time() < dialog.close_cooldown
	if not player_vehicle and not (dialog and dialog.active) and not (shop and shop.active) and not death_sequence_active then
		-- Q: cycle weapon backward (single-trigger)
		if input_utils.key_pressed("q") then
			cycle_weapon_backward()
		end

		-- R: cycle weapon forward (single-trigger)
		if input_utils.key_pressed("r") then
			cycle_weapon_forward()
		end

		-- Z or Space: attack/fire (skip if dialog just closed)
		if not dialog_cooldown_active and (btn(4) or key("space")) then
			try_attack()
		end
	end

	-- Smooth follow camera with deadzone (time-based smoothing)
	-- Player can move within deadzone without camera moving
	-- When outside deadzone, camera smoothly follows to keep player at edge
	local dz_hw = CAMERA_CONFIG.deadzone_half_w
	local dz_hh = CAMERA_CONFIG.deadzone_half_h
	-- Convert frame-based smoothing to time-based using exponential decay
	-- smooth_factor = 1 - (1 - base_smooth)^(dt * 60)
	local base_smooth = CAMERA_CONFIG.follow_smoothing
	local smooth = 1 - (1 - base_smooth) ^ (dt * 60)

	-- Calculate camera lead-ahead when in vehicle
	local lead_x, lead_y = 0, 0
	if player_vehicle and player_vehicle.facing_dir then
		local lead_dist = CAMERA_CONFIG.vehicle_lead_distance
		local dir = player_vehicle.facing_dir
		if dir == "north" then
			lead_y = -lead_dist
		elseif dir == "south" then
			lead_y = lead_dist
		elseif dir == "east" then
			lead_x = lead_dist
		elseif dir == "west" then
			lead_x = -lead_dist
		end
	end

	-- Smooth the lead offset (so it doesn't snap when changing direction)
	if not camera_lead_x then camera_lead_x = 0 end
	if not camera_lead_y then camera_lead_y = 0 end
	local lead_smooth = 1 - (1 - CAMERA_CONFIG.vehicle_lead_smoothing) ^ (dt * 60)
	camera_lead_x = camera_lead_x + (lead_x - camera_lead_x) * lead_smooth
	camera_lead_y = camera_lead_y + (lead_y - camera_lead_y) * lead_smooth

	-- Calculate player offset from camera center (including lead)
	local offset_x = game.player.x + camera_lead_x - cam_x
	local offset_y = game.player.y + camera_lead_y - cam_y

	-- Target camera position (only move if player outside deadzone)
	local target_x = cam_x
	local target_y = cam_y

	if offset_x > dz_hw then
		target_x = game.player.x + camera_lead_x - dz_hw
	elseif offset_x < -dz_hw then
		target_x = game.player.x + camera_lead_x + dz_hw
	end

	if offset_y > dz_hh then
		target_y = game.player.y + camera_lead_y - dz_hh
	elseif offset_y < -dz_hh then
		target_y = game.player.y + camera_lead_y + dz_hh
	end

	-- Smooth interpolation towards target (now frame-rate independent)
	cam_x = cam_x + (target_x - cam_x) * smooth
	cam_y = cam_y + (target_y - cam_y) * smooth

	-- Round camera to integers to eliminate sub-pixel jitter
	cam_x = flr(cam_x + 0.5)
	cam_y = flr(cam_y + 0.5)
end

-- Get current player sprite based on facing direction and walk frame
function get_player_sprite()
	-- Check if player is dead - show death sprite
	if player_dead then
		return player_death_sprite  -- sprite 36
	end

	-- Check if player is hit - show hit sprite
	if player_hit_flash and time() < player_hit_flash then
		return player_hit_sprite  -- sprite 11
	end

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
