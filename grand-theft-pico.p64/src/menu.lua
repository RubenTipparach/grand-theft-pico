--[[pod_format="raw"]]
-- menu.lua - Main menu screen and save/load system

-- ============================================
-- MENU STATE
-- ============================================

game_state = "menu"  -- "menu", "playing"

menu = {
	phase = "title",          -- "title" or "options"
	selected_option = 1,
	has_save = false,
	chicken_y_offset = 0,
	thruster_frame = 0,
	thruster_timer = 0,
	thruster_scale_pulse = 0,
	-- Parallax scrolling state
	scroll_x = 0,
	-- Starfield (generated once)
	stars = nil,
}

-- ============================================
-- MENU OPTIONS
-- ============================================

function get_menu_options()
	local options = {}
	if menu.has_save then
		add(options, {id = "continue", text = "Continue Game"})
	end
	add(options, {id = "new", text = "New Game"})
	if menu.has_save then
		add(options, {id = "reset", text = "Reset Progress"})
	end
	add(options, {id = "exit", text = "Exit"})
	return options
end

-- ============================================
-- MENU RENDERING
-- ============================================

function draw_menu()
	draw_menu_background()
	draw_menu_chicken()
	draw_menu_title()
	draw_menu_prompt()
end

function draw_menu_background()
	local cfg = MENU_CONFIG

	-- Update scroll position
	menu.scroll_x = menu.scroll_x + (cfg.scroll_speed or 1.5)

	-- Night sky (dark blue/black)
	rectfill(0, 0, SCREEN_W - 1, SCREEN_H - 1, cfg.night_sky_color or 1)

	-- Generate starfield once
	if not menu.stars then
		menu.stars = {}
		for i = 1, (cfg.star_count or 100) do
			add(menu.stars, {
				x = rnd(SCREEN_W),
				y = rnd(SCREEN_H * 0.7),  -- stars only in upper 70%
				brightness = flr(rnd(3)),  -- 0, 1, or 2
				twinkle_offset = rnd(1),
			})
		end
	end

	-- Draw scrolling starfield
	local star_colors = cfg.star_colors or {33, 30, 6}  -- white, light gray, dark gray
	for _, star in ipairs(menu.stars) do
		-- Slow parallax for stars
		local sx = (star.x - menu.scroll_x * 0.05) % SCREEN_W
		-- Twinkle effect
		local twinkle = sin(time() * 2 + star.twinkle_offset)
		local color_idx = star.brightness + 1
		if twinkle > 0.7 then color_idx = max(1, color_idx - 1) end
		pset(sx, star.y, star_colors[color_idx] or 33)
	end

	-- Street takes bottom 30% of screen
	local street_y = flr(SCREEN_H * 0.7)

	-- Road/ground (dark gray asphalt)
	rectfill(0, street_y, SCREEN_W - 1, SCREEN_H - 1, cfg.road_color or 5)

	-- Road lane markings (dashed white lines, scrolling)
	local lane_y = street_y + 30
	local dash_width = cfg.dash_width or 40
	local dash_gap = cfg.dash_gap or 25
	local dash_total = dash_width + dash_gap
	local dash_offset = menu.scroll_x % dash_total
	for x = -dash_total, SCREEN_W + dash_total, dash_total do
		local dx = x - dash_offset
		rectfill(dx, lane_y, dx + dash_width, lane_y + 3, cfg.lane_color or 33)
	end

	-- Far building layer (slow parallax) - using actual building sprites
	draw_menu_textured_buildings(menu.scroll_x * 0.3, street_y, cfg.far_building_types or {
		{btype = "BRICK", w = 48, h = 60},
		{btype = "GLASS_TOWER", w = 40, h = 90},
		{btype = "CONCRETE", w = 56, h = 50},
		{btype = "TECHNO_TOWER", w = 44, h = 100},
		{btype = "LARGE_BRICK", w = 52, h = 55},
		{btype = "BULKHEAD_TOWER", w = 48, h = 85},
	}, 0.5)

	-- Near building layer (faster parallax) - using actual building sprites
	draw_menu_textured_buildings(menu.scroll_x * 0.7, street_y, cfg.near_building_types or {
		{btype = "GLASS_TOWER", w = 64, h = 120},
		{btype = "TECHNO_TOWER", w = 56, h = 140},
		{btype = "BULKHEAD_TOWER", w = 72, h = 100},
		{btype = "BRICK", w = 60, h = 80},
		{btype = "MARBLE", w = 68, h = 110},
	}, 0.8)

	-- Street lamps using actual lamp sprite
	draw_menu_street_lamps(menu.scroll_x, street_y)
end

-- Draw a parallax layer of buildings using actual wall textures
function draw_menu_textured_buildings(scroll, base_y, buildings, scale)
	local total_width = 0
	local gap = 8
	for _, b in ipairs(buildings) do
		total_width = total_width + b.w * scale + gap
	end

	local x = -(scroll % total_width)
	for i = 1, 4 do  -- repeat pattern to fill screen
		for _, b in ipairs(buildings) do
			local btype = BUILDING_TYPES[b.btype]
			if btype then
				local bw = b.w * scale
				local bh = b.h * scale
				local wall_sprite = btype.wall_sprite
				local roof_sprite = btype.roof_sprite

				-- Draw building wall (tiled texture)
				draw_menu_tiled_rect(x, base_y - bh, bw, bh, wall_sprite)

				-- Draw roof at top
				draw_menu_tiled_rect(x, base_y - bh - 8 * scale, bw, 8 * scale, roof_sprite)

				-- Add some lit windows on top
				draw_menu_building_windows(x, base_y - bh, bw, bh)
			end
			x = x + b.w * scale + gap
		end
	end
end

-- Draw a rectangle filled with tiled texture
function draw_menu_tiled_rect(rx, ry, rw, rh, sprite_id)
	local tile_size = 16
	local sprite = get_spr(sprite_id)

	for ty = ry, ry + rh - 1, tile_size do
		for tx = rx, rx + rw - 1, tile_size do
			-- Clip to building bounds
			local tw = min(tile_size, rx + rw - tx)
			local th = min(tile_size, ry + rh - ty)
			if tw > 0 and th > 0 then
				sspr(sprite, 0, 0, tw, th, tx, ty, tw, th)
			end
		end
	end
end

-- Draw lit windows on building (static, no flickering)
function draw_menu_building_windows(bx, by, bw, bh)
	local window_color = MENU_CONFIG.window_color or 22  -- yellow
	local win_size = 4
	local win_spacing = 12
	-- Use fixed seed based on building position for consistent window pattern
	local seed = flr(bx * 17 + by * 31) % 100
	for wy = by + 8, by + bh - 12, win_spacing do
		for wx = bx + 6, bx + bw - 10, win_spacing do
			-- Deterministic pattern based on position within building (not screen position)
			local rel_x = flr(wx - bx)
			local rel_y = flr(wy - by)
			if ((rel_x * 7 + rel_y * 13 + seed) % 5) < 2 then
				rectfill(flr(wx), flr(wy), flr(wx) + win_size, flr(wy) + win_size - 1, window_color)
			end
		end
	end
end

-- Draw scrolling street lamps using actual lamp sprite
function draw_menu_street_lamps(scroll, street_y)
	local cfg = MENU_CONFIG
	local lamp_spacing = cfg.lamp_spacing or 150
	local lamp_offset = scroll % lamp_spacing

	-- Street lamp sprite: ID 61, 48x48
	local lamp_sprite_id = 61
	local lamp_w = 48
	local lamp_h = 48
	local lamp_sprite = get_spr(lamp_sprite_id)

	local lamp_y = street_y - lamp_h + 12  -- position lamp above street

	for x = -lamp_spacing, SCREEN_W + lamp_spacing, lamp_spacing do
		local lx = x - lamp_offset
		-- Draw lamp sprite
		sspr(lamp_sprite, 0, 0, lamp_w, lamp_h, lx - lamp_w / 2, lamp_y, lamp_w, lamp_h)
		-- Add glow effect at lamp head
		circfill(lx, lamp_y + 8, 12, cfg.lamp_glow_color or 22)
		circfill(lx, lamp_y + 8, 7, cfg.lamp_bright_color or 33)
	end
end


function draw_menu_chicken()
	local cfg = MENU_CONFIG
	local now = time()

	-- Update bobbing
	menu.chicken_y_offset = sin(now * cfg.bob_speed) * cfg.bob_amount

	-- Update thruster animation
	if now >= menu.thruster_timer + cfg.thruster_animation_speed then
		menu.thruster_timer = now
		menu.thruster_frame = (menu.thruster_frame + 1) % 4
	end

	-- Update pulsation (oscillates between 0.8 and 1.0)
	menu.thruster_scale_pulse = sin(now * cfg.thruster_pulse_speed) * cfg.thruster_pulse_amount

	-- Calculate chicken position (centered horizontally with offset)
	local chicken_x = SCREEN_W / 2 + (cfg.chicken_offset_x or 0)
	local chicken_y = cfg.chicken_y + menu.chicken_y_offset + (cfg.chicken_offset_y or 0)

	-- Get sprites
	local thruster_sprite_id = cfg.thruster_sprites[menu.thruster_frame + 1]
	local chicken_spr = get_spr(cfg.chicken_sprite)

	-- Calculate thruster scale with pulsation (range 0.8 to 1.0)
	local chicken_scale = cfg.chicken_scale or 2.0
	local thruster_scale_x = cfg.thruster_base_scale_x * chicken_scale
	local thruster_scale_y = (cfg.thruster_base_scale_y + menu.thruster_scale_pulse) * chicken_scale

	-- RENDER ORDER: Thrusters FIRST, then chicken on top

	-- Thruster position (below scaled chicken) with local offset
	local scaled_chicken_size = cfg.chicken_size * chicken_scale
	local thruster_cx = chicken_x + (cfg.thruster_offset_x or 0)
	local thruster_cy = chicken_y + scaled_chicken_size / 2 - 4 * chicken_scale + (cfg.thruster_offset_y or 0)

	-- Draw thruster using rspr (scaled, flipped vertically)
	-- rspr(sprite, cx, cy, sx, sy, rot, flip_x, pivot_x, pivot_y)
	-- Since rspr doesn't have flip_y, we use rotation of 0.5 (180 degrees) and flip_x
	if cfg.thruster_flip_y then
		-- Flip by rotating 180 and flip_x to get vertical flip effect
		rspr(thruster_sprite_id, thruster_cx, thruster_cy, thruster_scale_x, thruster_scale_y, 0.5, true)
	else
		rspr(thruster_sprite_id, thruster_cx, thruster_cy, thruster_scale_x, thruster_scale_y, 0, false)
	end

	-- Chicken spaceship using rspr for proper quad scaling
	rspr(cfg.chicken_sprite, chicken_x, chicken_y, chicken_scale, chicken_scale, 0, false)
end

function draw_menu_title()
	local cfg = MENU_CONFIG

	-- Title text (big, centered near top)
	local title = "GRAND THEFT CHICKEN"
	local title_w = print(title, 0, -100)  -- measure width
	local title_x = (SCREEN_W - title_w) / 2
	local title_y = 30

	-- Draw black box background for legibility
	local pad = cfg.text_box_padding or 6
	rectfill(title_x - pad, title_y - pad, title_x + title_w + pad, title_y + 8 + pad, cfg.text_box_color or 1)
	rect(title_x - pad, title_y - pad, title_x + title_w + pad, title_y + 8 + pad, cfg.text_box_border or 6)

	-- Draw with shadow for visibility
	print_shadow(title, title_x, title_y, cfg.title_color)
end

function draw_menu_prompt()
	local cfg = MENU_CONFIG
	local now = time()

	if menu.phase == "title" then
		-- Blinking prompt
		if flr(now * 2) % 2 == 0 then
			local prompt = "Press E to continue"
			local prompt_w = print(prompt, 0, -100)
			local prompt_x = (SCREEN_W - prompt_w) / 2
			local prompt_y = SCREEN_H - 60

			-- Draw black box background
			local pad = cfg.text_box_padding or 6
			rectfill(prompt_x - pad, prompt_y - pad, prompt_x + prompt_w + pad, prompt_y + 8 + pad, cfg.text_box_color or 1)
			rect(prompt_x - pad, prompt_y - pad, prompt_x + prompt_w + pad, prompt_y + 8 + pad, cfg.text_box_border or 6)

			print_shadow(prompt, prompt_x, prompt_y, cfg.prompt_color)
		end
	else
		-- Menu options
		draw_menu_options()
	end
end

function draw_menu_options()
	local cfg = MENU_CONFIG
	local options = get_menu_options()

	local start_y = 180
	local line_height = 16

	-- Calculate box dimensions for all options
	local max_width = 0
	for _, opt in ipairs(options) do
		local text = "> " .. opt.text .. " <"  -- measure with indicators
		local tw = print(text, 0, -100)
		if tw > max_width then max_width = tw end
	end

	local box_x = (SCREEN_W - max_width) / 2
	local box_y = start_y
	local box_h = #options * line_height
	local pad = cfg.text_box_padding or 6

	-- Draw black box background for all options
	rectfill(box_x - pad, box_y - pad, box_x + max_width + pad, box_y + box_h + pad, cfg.text_box_color or 1)
	rect(box_x - pad, box_y - pad, box_x + max_width + pad, box_y + box_h + pad, cfg.text_box_border or 6)

	for i, opt in ipairs(options) do
		local y = start_y + (i - 1) * line_height
		local color = (i == menu.selected_option) and cfg.selected_color or cfg.unselected_color

		-- Draw selection indicator
		local text = opt.text
		if i == menu.selected_option then
			text = "> " .. text .. " <"
		end

		local text_w = print(text, 0, -100)
		local x = (SCREEN_W - text_w) / 2
		print_shadow(text, x, y, color)
	end
end

-- ============================================
-- MENU UPDATE
-- ============================================

function update_menu()
	if menu.phase == "title" then
		-- Wait for E key to proceed to options
		if input_utils.key_pressed("e") then
			menu.phase = "options"
			menu.selected_option = 1
			-- Check for save file
			menu.has_save = check_save_exists()
		end
	else
		-- Navigate options using input_utils for proper press-once behavior
		if input_utils.key_pressed("up") then
			menu.selected_option = menu.selected_option - 1
			local options = get_menu_options()
			if menu.selected_option < 1 then
				menu.selected_option = #options
			end
		elseif input_utils.key_pressed("down") then
			menu.selected_option = menu.selected_option + 1
			local options = get_menu_options()
			if menu.selected_option > #options then
				menu.selected_option = 1
			end
		end

		-- Select option with E or Z
		if input_utils.key_pressed("e") or input_utils.key_pressed("z") then
			local options = get_menu_options()
			local selected = options[menu.selected_option]
			handle_menu_selection(selected.id)
		end
	end
end

function handle_menu_selection(option_id)
	if option_id == "continue" then
		load_game()
		init_game_world()
		game_state = "playing"
	elseif option_id == "new" then
		-- Reset game state and start fresh
		reset_game_state()
		init_game_world()
		game_state = "playing"
	elseif option_id == "reset" then
		-- Delete save file and go back to title
		delete_save_file()
		menu.phase = "title"
		menu.has_save = false
	elseif option_id == "exit" then
		-- Exit Picotron cart
		stop()
	end
end

-- ============================================
-- SAVE/LOAD SYSTEM
-- ============================================

function check_save_exists()
	local data = fetch(SAVE_CONFIG.filename)
	return data ~= nil
end

function delete_save_file()
	store(SAVE_CONFIG.filename, nil)
	printh("Save file deleted")
end

function build_save_data()
	local p = game.player

	-- Collect companion (fan/lover) data
	local companions = {}
	for _, fan_data in ipairs(fans) do
		local npc = fan_data.npc
		if npc then
			add(companions, {
				x = npc.x,
				y = npc.y,
				is_lover = fan_data.is_lover,
				love = fan_data.love,
				id = fan_data.id,
				npc_type_index = get_npc_type_index(npc),
			})
		end
	end

	return {
		version = SAVE_CONFIG.version,
		timestamp = time(),

		-- Player stats
		player = {
			x = p.x,
			y = p.y,
			health = p.health,
			armor = p.armor,
			money = p.money,
			popularity = p.popularity,
		},

		-- Inventory
		inventory = {
			weapons = p.weapons,
			ammo = p.ammo,
			equipped_index = p.equipped_index,
		},

		-- Quest state
		quest = {
			current_quest = mission.current_quest,
			quest_complete = mission.quest_complete,
			npcs_encountered = mission.npcs_encountered,
			talked_to_dealer = mission.talked_to_dealer,
			fox_quest_offered = mission.fox_quest_offered,
			fox_quest_accepted = mission.fox_quest_accepted,
			foxes_killed = mission.foxes_killed,
			total_foxes = mission.total_foxes,
			cactus_killed = mission.cactus_killed,
			kathy_killed = mission.kathy_killed,
			mothership_killed = mission.mothership_killed,
			game_complete = mission.game_complete,
		},

		-- Companions
		companions = companions,

		-- Game time
		game_time_hours = game_time_hours or 8,
	}
end

function save_game()
	local data = build_save_data()

	-- Ensure directory exists
	mkdir("/appdata/grand_theft_pico")

	-- Serialize and store
	local success = store(SAVE_CONFIG.filename, data)

	if success then
		printh("Game saved successfully")
	else
		printh("ERROR: Failed to save game")
	end

	return success
end

function load_game()
	local data = fetch(SAVE_CONFIG.filename)

	if not data then
		printh("No save file found")
		return false
	end

	-- Version check
	if data.version ~= SAVE_CONFIG.version then
		printh("Warning: Save file version mismatch")
	end

	-- Restore player stats
	local p = game.player
	p.x = data.player.x
	p.y = data.player.y
	p.health = data.player.health
	p.armor = data.player.armor
	p.money = data.player.money
	p.popularity = data.player.popularity

	-- Restore inventory
	p.weapons = data.inventory.weapons or {}
	p.ammo = data.inventory.ammo or {}
	p.equipped_index = data.inventory.equipped_index or 0

	-- Restore quest state
	mission.current_quest = data.quest.current_quest
	mission.quest_complete = data.quest.quest_complete
	mission.npcs_encountered = data.quest.npcs_encountered or 0
	mission.talked_to_dealer = data.quest.talked_to_dealer or false
	mission.fox_quest_offered = data.quest.fox_quest_offered or false
	mission.fox_quest_accepted = data.quest.fox_quest_accepted or false
	mission.foxes_killed = data.quest.foxes_killed or 0
	mission.total_foxes = data.quest.total_foxes or 0
	mission.cactus_killed = data.quest.cactus_killed or false
	mission.kathy_killed = data.quest.kathy_killed or false
	mission.mothership_killed = data.quest.mothership_killed or false
	mission.game_complete = data.quest.game_complete or false

	-- Restore game time
	game_time_hours = data.game_time_hours or 8

	-- Store companions to restore after world init
	menu.saved_companions = data.companions or {}

	printh("Game loaded successfully")
	return true
end

function restore_companions()
	if not menu.saved_companions then return end

	-- Recreate companions at their saved locations
	for _, comp_data in ipairs(menu.saved_companions) do
		-- Create NPC at saved position
		local npc = create_npc(comp_data.x, comp_data.y, comp_data.npc_type_index or 1)
		add(npcs, npc)

		-- Add to fans list
		local fan_data = {
			npc = npc,
			is_lover = comp_data.is_lover,
			love = comp_data.love,
			id = comp_data.id,
		}
		add(fans, fan_data)

		-- Add to lovers list if applicable
		if comp_data.is_lover then
			add(lovers, npc)
		end
	end

	-- Update next_fan_id to avoid conflicts
	local max_id = 0
	for _, fan in ipairs(fans) do
		if fan.id and fan.id > max_id then max_id = fan.id end
	end
	next_fan_id = max_id + 1

	printh("Restored " .. #fans .. " companions (" .. #lovers .. " lovers)")

	-- Clear saved data
	menu.saved_companions = nil
end

function reset_game_state()
	local p = game.player
	p.x = 0
	p.y = 0
	p.health = PLAYER_CONFIG.max_health
	p.armor = 0
	p.money = PLAYER_CONFIG.starting_money
	p.popularity = PLAYER_CONFIG.starting_popularity
	p.weapons = {}
	p.ammo = {}
	p.equipped_index = 0

	-- Reset mission state
	mission.current_quest = nil
	mission.quest_complete = false
	mission.npcs_encountered = 0
	mission.talked_to_dealer = false
	mission.fox_quest_offered = false
	mission.fox_quest_accepted = false
	mission.foxes_killed = 0
	mission.total_foxes = 0
	mission.cactus_killed = false
	mission.kathy_killed = false
	mission.mothership_killed = false
	mission.game_complete = false

	-- Clear companions
	fans = {}
	lovers = {}
	next_fan_id = 1

	-- Reset death state
	player_dead = false
	death_sequence_active = false

	-- Reset game time
	game_time_hours = DAY_NIGHT_CYCLE_CONFIG.start_hour

	printh("Game state reset for new game")
end

-- ============================================
-- NPC TYPE INDEX HELPER
-- ============================================

function get_npc_type_index(npc)
	if not npc or not npc.npc_type then return 1 end
	for i, npc_type in ipairs(NPC_TYPES) do
		if npc.npc_type == npc_type then
			return i
		end
	end
	return 1  -- default
end
