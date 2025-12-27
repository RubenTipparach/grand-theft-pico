--[[pod_format="raw"]]
-- dealer.lua - Arms Dealer system (shop, combat, boss fights)

-- ============================================
-- ARMS DEALER STATE
-- ============================================

-- Global list of arms dealers
arms_dealers = {}

-- Shop state
shop = {
	active = false,
	dealer = nil,
	selected = 1,
	ammo_quantity = 1,  -- For ammo purchases
	scroll_offset = 0,
	message = nil,      -- Feedback message ("Not enough money!" etc)
	message_timer = 0,
}

-- ============================================
-- DEALER CREATION AND SPAWNING
-- ============================================

-- Create a new arms dealer
function create_arms_dealer(x, y, name)
	local cfg = ARMS_DEALER_CONFIG

	local dealer = {
		x = x,
		y = y,
		name = name,
		health = cfg.health,
		max_health = cfg.health,
		state = "idle",       -- "idle", "walking", "hostile", "dead"
		facing_right = true,  -- Only has east-facing sprites
		walk_frame = 0,
		anim_timer = 0,
		walk_timer = 0,
		walk_dir = { dx = 0, dy = 0 },
		walk_end_time = 0,
		fire_timer = 0,       -- Cooldown for shooting
		death_time = 0,       -- When died (for respawn)
		spawn_x = x,          -- Original spawn position
		spawn_y = y,
	}

	add(arms_dealers, dealer)
	return dealer
end

-- Spawn the two arms dealers on opposite sides of the city
function spawn_arms_dealers()
	local cfg = ARMS_DEALER_CONFIG
	local names = cfg.names

	-- Find valid spawn positions on sidewalks
	-- West side: x < 480
	-- East side: x >= 480

	local west_x, west_y = find_dealer_spawn_position(-200, 400, 0, 1000)
	local east_x, east_y = find_dealer_spawn_position(600, 1000, 0, 1000)

	if west_x then
		create_arms_dealer(west_x, west_y, names[1])
	end

	if east_x then
		create_arms_dealer(east_x, east_y, names[2])
	end
end

-- Find a valid spawn position on sidewalk within given bounds
function find_dealer_spawn_position(min_x, max_x, min_y, max_y)
	-- Try random positions until we find a sidewalk
	for attempt = 1, 50 do
		local x = min_x + rnd(max_x - min_x)
		local y = min_y + rnd(max_y - min_y)

		if is_on_sidewalk(x, y) then
			return x, y
		end
	end

	-- Fallback: just return center of area
	return (min_x + max_x) / 2, (min_y + max_y) / 2
end

-- ============================================
-- DEALER UPDATE
-- ============================================

-- Update all arms dealers
function update_arms_dealers()
	local now = time()
	local cfg = ARMS_DEALER_CONFIG
	local p = game.player

	for _, dealer in ipairs(arms_dealers) do
		if dealer.state == "dead" then
			-- Check for respawn
			if now >= dealer.death_time + cfg.respawn_time then
				-- Respawn at original position
				dealer.x = dealer.spawn_x
				dealer.y = dealer.spawn_y
				dealer.health = cfg.health
				dealer.state = "idle"
			end
		elseif dealer.state == "hostile" then
			-- Chase and attack player
			update_hostile_dealer(dealer, now)
		else
			-- Peaceful behavior (idle/walking)
			update_peaceful_dealer(dealer, now)
		end

		-- Update animation
		update_dealer_animation(dealer, now)

		-- Check if dealer died
		if dealer.health <= 0 and dealer.state ~= "dead" then
			dealer.state = "dead"
			dealer.death_time = now
		end
	end
end

-- Update dealer in peaceful state
function update_peaceful_dealer(dealer, now)
	local cfg = ARMS_DEALER_CONFIG

	if dealer.state == "idle" then
		-- Randomly start walking
		if now >= dealer.walk_end_time then
			if rnd(1) < 0.02 then  -- 2% chance per frame to start walking
				dealer.state = "walking"
				-- Pick random direction on sidewalk
				local dirs = {
					{ dx = 1, dy = 0 },
					{ dx = -1, dy = 0 },
					{ dx = 0, dy = 1 },
					{ dx = 0, dy = -1 },
				}
				dealer.walk_dir = dirs[flr(rnd(#dirs)) + 1]
				dealer.walk_end_time = now + 1 + rnd(2)  -- Walk for 1-3 seconds
				dealer.facing_right = dealer.walk_dir.dx >= 0
			end
		end
	elseif dealer.state == "walking" then
		-- Move in current direction
		local speed = cfg.walk_speed / 60  -- Per frame
		local new_x = dealer.x + dealer.walk_dir.dx * speed
		local new_y = dealer.y + dealer.walk_dir.dy * speed

		-- Check if still on valid terrain
		if is_on_sidewalk(new_x, new_y) or is_on_grass(new_x, new_y) then
			dealer.x = new_x
			dealer.y = new_y
		else
			-- Hit edge, stop walking
			dealer.state = "idle"
			dealer.walk_end_time = now + 1 + rnd(2)
		end

		-- Check if walk time ended
		if now >= dealer.walk_end_time then
			dealer.state = "idle"
			dealer.walk_end_time = now + 1 + rnd(2)
		end
	end
end

-- Update dealer in hostile state (chasing and attacking player)
function update_hostile_dealer(dealer, now)
	local cfg = ARMS_DEALER_CONFIG
	local p = game.player

	-- Chase player
	local dx = p.x - dealer.x
	local dy = p.y - dealer.y
	local dist = sqrt(dx * dx + dy * dy)

	if dist > 0 then
		-- Normalize and move
		local speed = cfg.chase_speed / 60
		dealer.x = dealer.x + (dx / dist) * speed
		dealer.y = dealer.y + (dy / dist) * speed

		-- Update facing direction
		dealer.facing_right = dx >= 0
	end

	-- Fire at player
	if now >= dealer.fire_timer then
		-- Check if player is in range (on screen)
		local sx, sy = world_to_screen(dealer.x, dealer.y)
		if sx > -50 and sx < SCREEN_W + 50 and sy > -50 and sy < SCREEN_H + 50 then
			-- Fire bullet
			fire_dealer_bullet(dealer)
			dealer.fire_timer = now + cfg.fire_rate
		end
	end
end

-- Fire a bullet from dealer toward player
function fire_dealer_bullet(dealer)
	local cfg = ARMS_DEALER_CONFIG
	local p = game.player

	-- Calculate direction to player
	local dx = p.x - dealer.x
	local dy = p.y - dealer.y
	local dist = sqrt(dx * dx + dy * dy)

	if dist <= 0 then return end

	-- Normalize
	dx = dx / dist
	dy = dy / dist

	-- Create projectile
	local proj = {
		x = dealer.x,
		y = dealer.y,
		dx = dx,
		dy = dy,
		speed = 200,  -- Dealer bullet speed
		damage = cfg.damage,
		owner = dealer,  -- Not "player"
		sprite = cfg.sprite_base + cfg.bullet_sprites[1],
		sprite_frames = {
			cfg.sprite_base + cfg.bullet_sprites[1],
			cfg.sprite_base + cfg.bullet_sprites[2],
		},
		frame_index = 1,
		frame_timer = 0,
		animation_speed = 0.1,
	}

	add(projectiles, proj)
end

-- Update dealer animation
function update_dealer_animation(dealer, now)
	local cfg = ARMS_DEALER_CONFIG

	-- Determine animation speed and max frames based on state
	local anim_speed, max_frames
	if dealer.state == "walking" or dealer.state == "hostile" then
		anim_speed = cfg.walk_animation_speed
		max_frames = cfg.walk_frames
	else
		anim_speed = cfg.idle_animation_speed
		max_frames = cfg.idle_frames
	end

	-- Update animation timer
	if now >= dealer.anim_timer + anim_speed then
		dealer.anim_timer = now
		dealer.walk_frame = dealer.walk_frame + 1

		if dealer.walk_frame >= max_frames then
			dealer.walk_frame = 0
		end
	end
end

-- ============================================
-- DEALER RENDERING
-- ============================================

-- Get sprite ID for dealer
function get_dealer_sprite(dealer)
	local cfg = ARMS_DEALER_CONFIG
	local base = cfg.sprite_base

	if dealer.state == "dead" then
		-- Show damaged sprite
		return base + cfg.damaged_start
	elseif dealer.state == "walking" or dealer.state == "hostile" then
		return base + cfg.walk_start + dealer.walk_frame
	else
		return base + cfg.idle_start + dealer.walk_frame
	end
end

-- Draw all arms dealers (called from building.lua depth sorting)
-- This function adds dealers to the visible list for proper Z-ordering
function add_dealers_to_visible(visible)
	for _, dealer in ipairs(arms_dealers) do
		if dealer.state ~= "dead" then
			local sx, sy = world_to_screen(dealer.x, dealer.y)
			-- Only add if on screen
			if sx > -32 and sx < SCREEN_W + 32 and sy > -32 and sy < SCREEN_H + 32 then
				local dealer_feet_y = dealer.y + 8
				add(visible, {
					type = "dealer",
					y = dealer_feet_y,
					cx = dealer.x,
					cy = dealer.y,
					sx = sx,
					sy = sy,
					data = dealer
				})
			end
		end
	end
end

-- Draw a single dealer (called during depth-sorted rendering)
function draw_dealer(dealer, sx, sy)
	local cfg = ARMS_DEALER_CONFIG
	local sprite_id = get_dealer_sprite(dealer)
	local flip_x = not dealer.facing_right

	-- Get sprite scaling
	local src_size = cfg.sprite_size
	local scale = cfg.sprite_scale
	local dst_size = src_size * scale

	-- Get sprite userdata from sprite ID
	local sprite = get_spr(sprite_id)

	-- Draw scaled sprite centered horizontally, with feet at sy
	-- sspr(sprite_userdata, src_x, src_y, src_w, src_h, dst_x, dst_y, dst_w, dst_h, flip_x)
	sspr(sprite, 0, 0, src_size, src_size,
		sx - dst_size / 2, sy - dst_size,
		dst_size, dst_size, flip_x)
end

-- Draw boss health bar for hostile dealer
function draw_boss_health_bar()
	-- Find hostile dealer
	local hostile_dealer = nil
	for _, dealer in ipairs(arms_dealers) do
		if dealer.state == "hostile" then
			hostile_dealer = dealer
			break
		end
	end

	if not hostile_dealer then return end

	local cfg = ARMS_DEALER_CONFIG

	-- Draw at top center of screen
	local bar_w = 120
	local bar_h = 8
	local bar_x = (SCREEN_W - bar_w) / 2
	local bar_y = 8

	-- Draw name
	local name = "Arms Dealer " .. hostile_dealer.name
	local name_w = #name * 4
	print_shadow(name, (SCREEN_W - name_w) / 2, bar_y - 10, 8)

	-- Health percentage
	local health_pct = hostile_dealer.health / hostile_dealer.max_health
	health_pct = max(0, min(1, health_pct))
	local fill_w = flr(bar_w * health_pct)

	-- Draw border
	rect(bar_x - 1, bar_y - 1, bar_x + bar_w, bar_y + bar_h, 6)
	-- Draw background
	rectfill(bar_x, bar_y, bar_x + bar_w - 1, bar_y + bar_h - 1, 1)
	-- Draw health fill (red for boss)
	if fill_w > 0 then
		rectfill(bar_x, bar_y, bar_x + fill_w - 1, bar_y + bar_h - 1, 8)
	end
end

-- ============================================
-- DEALER INTERACTION (SHOP)
-- ============================================

-- Check if player can interact with a dealer
function get_nearby_dealer()
	local cfg = ARMS_DEALER_CONFIG
	local p = game.player

	for _, dealer in ipairs(arms_dealers) do
		if dealer.state ~= "dead" and dealer.state ~= "hostile" then
			local dx = p.x - dealer.x
			local dy = p.y - dealer.y
			local dist = sqrt(dx * dx + dy * dy)
			if dist < cfg.interact_distance then
				return dealer
			end
		end
	end

	return nil
end

-- Draw dealer interaction prompt
function draw_dealer_prompt()
	if shop.active then return end
	if player_vehicle then return end

	local dealer = get_nearby_dealer()
	if dealer then
		local sx, sy = world_to_screen(dealer.x, dealer.y)
		local text = "E: SHOP"
		local tw = #text * 4
		print_shadow(text, sx - tw/2, sy - 24, PLAYER_CONFIG.prompt_color)
	end
end

-- Open shop with dealer
function open_shop(dealer)
	shop.active = true
	shop.dealer = dealer
	shop.selected = 1
	shop.ammo_quantity = 1
	shop.scroll_offset = 0
	shop.message = nil
end

-- Close shop
function close_shop()
	shop.active = false
	shop.dealer = nil
end

-- Get list of shop items (uses weapon_order for consistent ordering)
function get_shop_items()
	local items = {}

	-- Iterate in weapon_order (already sorted by price)
	for _, key in ipairs(WEAPON_CONFIG.weapon_order) do
		local weapon = WEAPON_CONFIG.melee[key]
		if weapon then
			add(items, {
				key = key,
				name = weapon.name,
				price = weapon.price,
				type = "melee",
				owned = owns_weapon(key),
			})
		else
			weapon = WEAPON_CONFIG.ranged[key]
			if weapon then
				add(items, {
					key = key,
					name = weapon.name,
					price = weapon.price,
					ammo_price = weapon.ammo_price,
					ammo_count = weapon.ammo_count,
					type = "ranged",
					owned = owns_weapon(key),
				})
			end
		end
	end

	return items
end

-- Update shop input
function update_shop()
	if not shop.active then return end

	local items = get_shop_items()
	local item = items[shop.selected]

	-- Navigation
	if btnp(2) then  -- Up
		shop.selected = shop.selected - 1
		if shop.selected < 1 then shop.selected = #items end
		shop.ammo_quantity = 1
	end
	if btnp(3) then  -- Down
		shop.selected = shop.selected + 1
		if shop.selected > #items then shop.selected = 1 end
		shop.ammo_quantity = 1
	end

	-- Ammo quantity (for owned ranged weapons)
	if item and item.owned and item.type == "ranged" then
		if btnp(0) then  -- Left
			shop.ammo_quantity = max(1, shop.ammo_quantity - 1)
		end
		if btnp(1) then  -- Right
			shop.ammo_quantity = shop.ammo_quantity + 1
		end
	end

	-- Purchase
	if btnp(4) then  -- O/Z button
		if item then
			try_purchase(item)
		end
	end

	-- Close shop
	if btnp(5) or keyp("e") then  -- X button or E key
		close_shop()
	end

	-- Clear message after timeout
	if shop.message and time() >= shop.message_timer then
		shop.message = nil
	end
end

-- Try to purchase an item
function try_purchase(item)
	local p = game.player

	if item.owned then
		-- Already owned, try to buy ammo (ranged only)
		if item.type == "ranged" then
			local total_cost = item.ammo_price * shop.ammo_quantity
			if p.money >= total_cost then
				p.money = p.money - total_cost
				add_ammo(item.key, item.ammo_count * shop.ammo_quantity)
				shop.message = "Bought ammo!"
				shop.message_timer = time() + 1.5
			else
				shop.message = "Not enough money!"
				shop.message_timer = time() + 1.5
			end
		else
			shop.message = "Already owned!"
			shop.message_timer = time() + 1.5
		end
	else
		-- Buy weapon
		if p.money >= item.price then
			p.money = p.money - item.price
			give_weapon(item.key)
			item.owned = true
			shop.message = "Purchased " .. item.name .. "!"
			shop.message_timer = time() + 1.5
		else
			shop.message = "Not enough money!"
			shop.message_timer = time() + 1.5
		end
	end
end

-- Draw shop UI
function draw_shop()
	if not shop.active then return end

	local items = get_shop_items()

	-- Shop box dimensions
	local box_w = 200
	local box_h = 160
	local box_x = (SCREEN_W - box_w) / 2
	local box_y = (SCREEN_H - box_h) / 2

	-- Draw background
	rectfill(box_x, box_y, box_x + box_w - 1, box_y + box_h - 1, 1)
	rect(box_x - 1, box_y - 1, box_x + box_w, box_y + box_h, 6)

	-- Draw title
	local title = "ARMS DEALER " .. shop.dealer.name
	local title_w = #title * 4
	print_shadow(title, box_x + (box_w - title_w) / 2, box_y + 4, 7)

	-- Draw money
	local money_text = "$" .. game.player.money
	print_shadow(money_text, box_x + box_w - #money_text * 4 - 8, box_y + 4, 11)

	-- Draw items
	local item_y = box_y + 20
	local visible_items = 6
	local start_idx = shop.scroll_offset + 1
	local end_idx = min(#items, start_idx + visible_items - 1)

	for i = start_idx, end_idx do
		local item = items[i]
		local is_selected = (i == shop.selected)
		local color = is_selected and 7 or 6

		-- Selection indicator
		if is_selected then
			print_shadow(">", box_x + 4, item_y, 7)
		end

		-- Item name
		local name_color = item.owned and 11 or color
		print_shadow(item.name, box_x + 14, item_y, name_color)

		-- Price or OWNED
		local price_x = box_x + 100
		if item.owned then
			print_shadow("OWNED", price_x, item_y, 11)

			-- Ammo purchase for ranged
			if item.type == "ranged" and is_selected then
				local ammo_text = "< " .. shop.ammo_quantity .. " >"
				local ammo_cost = item.ammo_price * shop.ammo_quantity
				print_shadow(ammo_text, price_x + 45, item_y, 7)
				print_shadow("$" .. ammo_cost, price_x + 85, item_y, 11)
			end
		else
			local can_afford = game.player.money >= item.price
			local price_color = can_afford and 11 or 8
			print_shadow("$" .. item.price, price_x, item_y, price_color)
		end

		item_y = item_y + 12
	end

	-- Draw scroll indicator
	if #items > visible_items then
		local scroll_x = box_x + box_w - 8
		local scroll_y = box_y + 20
		local scroll_h = visible_items * 12
		local handle_h = (visible_items / #items) * scroll_h
		local handle_y = scroll_y + (shop.scroll_offset / (#items - visible_items)) * (scroll_h - handle_h)

		-- Track
		rectfill(scroll_x, scroll_y, scroll_x + 4, scroll_y + scroll_h - 1, 5)
		-- Handle
		rectfill(scroll_x, handle_y, scroll_x + 4, handle_y + handle_h - 1, 7)
	end

	-- Draw message
	if shop.message then
		local msg_w = #shop.message * 4
		print_shadow(shop.message, box_x + (box_w - msg_w) / 2, box_y + box_h - 24, 8)
	end

	-- Draw controls
	print_shadow("Z:Buy  X:Close", box_x + 4, box_y + box_h - 12, 6)
end

-- ============================================
-- DEALER COMBAT TRIGGER
-- ============================================

-- Make dealer hostile (called when player shoots them)
function make_dealer_hostile(dealer)
	if dealer.state ~= "hostile" and dealer.state ~= "dead" then
		dealer.state = "hostile"
		dealer.fire_timer = time() + 0.5  -- Initial delay before firing
		close_shop()  -- Close shop if open
	end
end

-- Check if player is trying to interact with dealer
function check_dealer_interaction()
	if shop.active then return end
	if player_vehicle then return end
	if dialog and dialog.active then return end

	-- E key to interact (use input_utils for single-press detection)
	if input_utils.key_pressed("e") then
		local dealer = get_nearby_dealer()
		if dealer then
			open_shop(dealer)
		end
	end
end
