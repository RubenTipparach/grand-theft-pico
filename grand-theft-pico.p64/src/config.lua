--[[pod_format="raw"]]
-- config.lua - Game design configuration (sprites, buildings, tuning)

-- ============================================
-- COLOR PALETTE REFERENCE (thispallete.hex)
-- ============================================
-- Index  Hex       Name
-- -----  ------    ----------------
--  0     #000000   black
--  1     #000000   black2 (duplicate)
--  2     #753e1e   brown
--  3     #472e3e   dark_purple
--  4     #0d2140   dark_navy
--  5     #243966   navy
--  6     #791551   magenta
--  7     #116061   teal
--  8     #434445   dark_gray
--  9     #6e4250   mauve
--  10    #495169   slate
--  11    #696570   gray
--  12    #c40c2e   red
--  13    #e9721d   orange
--  14    #f53141   bright_red
--  15    #875d58   dusty_brown
--  16    #ad6a45   rust
--  17    #9e7767   tan
--  18    #ff7070   salmon
--  19    #179c43   green
--  20    #20806c   sea_green
--  21    #faa032   gold
--  22    #fad937   yellow
--  23    #b58c7f   light_tan
--  24    #3553a6   blue
--  25    #1c75bd   sky_blue
--  26    #5cb888   mint
--  27    #76dca7   light_mint
--  28    #25acf5   bright_blue
--  29    #a69a9c   silver
--  30    #d9a798   peach
--  31    #c4bbb3   light_gray
--  32    #ffc49e   light_peach
--  33    #f2f2da   white




-- ============================================
-- SPRITE REGISTRY
-- ============================================
SPRITES = {
	-- Walls (16x16)
	BRICK_WALL       = { id = 1, w = 16, h = 16 },
	MARBLE_WALL      = { id = 2, w = 16, h = 16 },
	CRACKED_BRICK    = { id = 128, w = 16, h = 16 },
	CRACKED_CONCRETE = { id = 129, w = 16, h = 16 },
	METALLIC_PIPES   = { id = 48, w = 16, h = 16 },
	LARGE_BRICK      = { id = 49, w = 16, h = 16 },
	GREEN_BLOCK      = { id = 51, w = 16, h = 16 },
	TECHNO           = { id = 52, w = 16, h = 16 },
	ZINC             = { id = 53, w = 16, h = 16 },
	GLASS            = { id = 119, w = 16, h = 16 },
	BULKHEAD         = { id = 118, w = 16, h = 16 },

	-- Walls (16x32 tall)
	TALL_BRICK       = { id = 50, w = 16, h = 32 },

	-- Roofs/Ceilings
	ROOF             = { id = 3, w = 16, h = 16 },
	ROOF_CHIMNEY     = { id = 131, w = 16, h = 16 },
	ROOF_CIRCULAR    = { id = 40, w = 16, h = 16 },
	ROOF_POINTY      = { id = 41, w = 16, h = 16 },
	ROOF_FLAT        = { id = 42, w = 16, h = 16 },

	-- Ground textures
	DIRT_MEDIUM   = { id = 4, w = 16, h = 16 },
	DIRT_HEAVY    = { id = 5, w = 16, h = 16 },
	DIRT_LIGHT    = { id = 6, w = 16, h = 16 },
	GRASS         = { id = 7, w = 16,  h = 16  },
	GRASS_2       = { id = 134, w = 16, h = 16 },
	GRASS_3       = { id = 230, w = 16, h = 16 },
	GRASS_4       = { id = 231, w = 16, h = 16 },
	GRASS_5       = { id = 238, w = 16, h = 16 },
	GRASS_6       = { id = 239, w = 16, h = 16 },

	-- Sidewalks (16x16)
	SIDEWALK_NS   = { id = 132, w = 16, h = 16 },  -- north-south oriented
	SIDEWALK_EW   = { id = 133, w = 16, h = 16 },  -- east-west oriented

	-- Flora (16x16)
	FLOWER_1      = { id = 139, w = 16, h = 16 },
	FLOWER_2      = { id = 140, w = 16, h = 16 },
	GRASS_BLADE   = { id = 141, w = 16, h = 16 },
	TREE_1        = { id = 142, w = 16, h = 16 },
	TREE_2        = { id = 143, w = 16, h = 16 },

	-- ============================================
	-- WATER TILES (16x16, 9-sliced, 2 animation frames)
	-- ============================================
	-- Set 1: Grass border surrounding water (water is inside)
	-- Frame 1
	WATER_SET1_F1_TL = { id = 208, w = 16, h = 16 },  -- top-left corner
	WATER_SET1_F1_T  = { id = 209, w = 16, h = 16 },  -- top edge
	WATER_SET1_F1_TR = { id = 210, w = 16, h = 16 },  -- top-right corner
	WATER_SET1_F1_L  = { id = 216, w = 16, h = 16 },  -- left edge
	WATER_SET1_F1_C  = { id = 217, w = 16, h = 16 },  -- center (pure water)
	WATER_SET1_F1_R  = { id = 218, w = 16, h = 16 },  -- right edge
	WATER_SET1_F1_BL = { id = 224, w = 16, h = 16 },  -- bottom-left corner
	WATER_SET1_F1_B  = { id = 225, w = 16, h = 16 },  -- bottom edge
	WATER_SET1_F1_BR = { id = 226, w = 16, h = 16 },  -- bottom-right corner
	-- Frame 2
	WATER_SET1_F2_TL = { id = 232, w = 16, h = 16 },
	WATER_SET1_F2_T  = { id = 233, w = 16, h = 16 },
	WATER_SET1_F2_TR = { id = 234, w = 16, h = 16 },
	WATER_SET1_F2_L  = { id = 240, w = 16, h = 16 },
	WATER_SET1_F2_C  = { id = 241, w = 16, h = 16 },
	WATER_SET1_F2_R  = { id = 242, w = 16, h = 16 },
	WATER_SET1_F2_BL = { id = 248, w = 16, h = 16 },
	WATER_SET1_F2_B  = { id = 249, w = 16, h = 16 },
	WATER_SET1_F2_BR = { id = 250, w = 16, h = 16 },

	-- Set 2: Water border surrounding grass (grass island inside water)
	-- Frame 1
	WATER_SET2_F1_TL = { id = 211, w = 16, h = 16 },  -- top-left corner (inner)
	WATER_SET2_F1_T  = { id = 212, w = 16, h = 16 },  -- top edge (inner)
	WATER_SET2_F1_TR = { id = 213, w = 16, h = 16 },  -- top-right corner (inner)
	WATER_SET2_F1_L  = { id = 219, w = 16, h = 16 },  -- left edge (inner)
	-- Center is grass (use GRASS tile)
	WATER_SET2_F1_R  = { id = 221, w = 16, h = 16 },  -- right edge (inner)
	WATER_SET2_F1_BL = { id = 227, w = 16, h = 16 },  -- bottom-left corner (inner)
	WATER_SET2_F1_B  = { id = 228, w = 16, h = 16 },  -- bottom edge (inner)
	WATER_SET2_F1_BR = { id = 229, w = 16, h = 16 },  -- bottom-right corner (inner)
	-- Frame 2
	WATER_SET2_F2_TL = { id = 235, w = 16, h = 16 },
	WATER_SET2_F2_T  = { id = 236, w = 16, h = 16 },
	WATER_SET2_F2_TR = { id = 237, w = 16, h = 16 },
	WATER_SET2_F2_L  = { id = 243, w = 16, h = 16 },
	-- Center is grass
	WATER_SET2_F2_R  = { id = 245, w = 16, h = 16 },
	WATER_SET2_F2_BL = { id = 251, w = 16, h = 16 },
	WATER_SET2_F2_B  = { id = 252, w = 16, h = 16 },
	WATER_SET2_F2_BR = { id = 253, w = 16, h = 16 },

	-- Player (facing east/west - flip_x for direction)
	PLAYER_IDLE   = { id = 8,  w = 16, h = 16 },  -- idle, facing left
	PLAYER_WALK1  = { id = 9,  w = 16, h = 16 },  -- walk frame 1
	PLAYER_WALK2  = { id = 10, w = 16, h = 16 },  -- walk frame 2
	PLAYER_DAMAGED = { id = 11, w = 16, h = 16 }, -- damaged/hurt

	-- Player (facing south - toward camera)
	PLAYER_SOUTH_IDLE  = { id = 12, w = 16, h = 16 },  -- south idle
	PLAYER_SOUTH_WALK1 = { id = 14, w = 16, h = 16 },  -- south walk frame 1
	PLAYER_SOUTH_WALK2 = { id = 17, w = 16, h = 16 },  -- south walk frame 2

	-- Player (facing north - away from camera)
	PLAYER_NORTH_IDLE  = { id = 13, w = 16, h = 16 },  -- north idle
	PLAYER_NORTH_WALK1 = { id = 15, w = 16, h = 16 },  -- north walk frame 1
	PLAYER_NORTH_WALK2 = { id = 16, w = 16, h = 16 },  -- north walk frame 2

	-- NPC1 (8x16 sprites, starts at 64)
	-- Facing south (toward camera)
	NPC1_SOUTH_IDLE  = { id = 64, w = 8, h = 16 },
	NPC1_SOUTH_WALK1 = { id = 65, w = 8, h = 16 },
	NPC1_SOUTH_WALK2 = { id = 66, w = 8, h = 16 },
	NPC1_SOUTH_WALK3 = { id = 67, w = 8, h = 16 },
	-- Facing east
	NPC1_EAST_IDLE   = { id = 68, w = 8, h = 16 },
	NPC1_EAST_WALK1  = { id = 69, w = 8, h = 16 },
	NPC1_EAST_WALK2  = { id = 70, w = 8, h = 16 },
	NPC1_EAST_WALK3  = { id = 71, w = 8, h = 16 },
	-- Facing north (away from camera)
	NPC1_NORTH_IDLE  = { id = 72, w = 8, h = 16 },
	NPC1_NORTH_WALK1 = { id = 73, w = 8, h = 16 },
	NPC1_NORTH_WALK2 = { id = 74, w = 8, h = 16 },
	NPC1_NORTH_WALK3 = { id = 75, w = 8, h = 16 },
	-- Facing west
	NPC1_WEST_IDLE   = { id = 76, w = 8, h = 16 },
	NPC1_WEST_WALK1  = { id = 77, w = 8, h = 16 },
	NPC1_WEST_WALK2  = { id = 78, w = 8, h = 16 },
	NPC1_WEST_WALK3  = { id = 79, w = 8, h = 16 },
	-- Damaged
	NPC1_DAMAGED     = { id = 81, w = 8, h = 16 },

	-- NPC2 (8x16 sprites, starts at 84)
	-- Facing south (toward camera)
	NPC2_SOUTH_IDLE  = { id = 84, w = 8, h = 16 },
	NPC2_SOUTH_WALK1 = { id = 85, w = 8, h = 16 },
	NPC2_SOUTH_WALK2 = { id = 86, w = 8, h = 16 },
	NPC2_SOUTH_WALK3 = { id = 87, w = 8, h = 16 },
	-- Facing east
	NPC2_EAST_IDLE   = { id = 88, w = 8, h = 16 },
	NPC2_EAST_WALK1  = { id = 89, w = 8, h = 16 },
	NPC2_EAST_WALK2  = { id = 90, w = 8, h = 16 },
	NPC2_EAST_WALK3  = { id = 91, w = 8, h = 16 },
	-- Facing north (away from camera)
	NPC2_NORTH_IDLE  = { id = 92, w = 8, h = 16 },
	NPC2_NORTH_WALK1 = { id = 93, w = 8, h = 16 },
	NPC2_NORTH_WALK2 = { id = 94, w = 8, h = 16 },
	NPC2_NORTH_WALK3 = { id = 95, w = 8, h = 16 },
	-- Facing west
	NPC2_WEST_IDLE   = { id = 96, w = 8, h = 16 },
	NPC2_WEST_WALK1  = { id = 97, w = 8, h = 16 },
	NPC2_WEST_WALK2  = { id = 98, w = 8, h = 16 },
	NPC2_WEST_WALK3  = { id = 99, w = 8, h = 16 },
	-- Damaged
	NPC2_DAMAGED     = { id = 101, w = 8, h = 16 },
}

-- ============================================
-- BUILDING TYPES
-- ============================================
-- wall_height: multiplier for PERSPECTIVE_CONFIG.max_wall_height (1 = normal, 2 = double, etc.)
BUILDING_TYPES = {
	-- === PRIMITIVE / LOW-RISE (outer city) ===
	BRICK = {
		wall_sprite = SPRITES.BRICK_WALL.id,
		roof_sprite = SPRITES.ROOF_CHIMNEY.id,
		wall_height = 1,
	},
	CRACKED_BRICK = {
		wall_sprite = SPRITES.CRACKED_BRICK.id,
		roof_sprite = SPRITES.ROOF_FLAT.id,
		wall_height = 1,
	},
	LARGE_BRICK = {
		wall_sprite = SPRITES.LARGE_BRICK.id,
		roof_sprite = SPRITES.ROOF_POINTY.id,
		wall_height = 1,
	},
	CONCRETE = {
		wall_sprite = SPRITES.CRACKED_CONCRETE.id,
		roof_sprite = SPRITES.ROOF_FLAT.id,
		wall_height = 1,
	},
	WAREHOUSE = {
		wall_sprite = SPRITES.ZINC.id,
		roof_sprite = SPRITES.ROOF_FLAT.id,
		wall_height = 1,
	},

	-- === MID-RISE (transition zone) ===
	MARBLE = {
		wall_sprite = SPRITES.MARBLE_WALL.id,
		roof_sprite = SPRITES.ROOF_CIRCULAR.id,
		wall_height = 1,
	},
	OFFICE = {
		wall_sprite = SPRITES.MARBLE_WALL.id,
		roof_sprite = SPRITES.ROOF_POINTY.id,
		wall_height = 2,
	},
	INDUSTRIAL = {
		wall_sprite = SPRITES.METALLIC_PIPES.id,
		roof_sprite = SPRITES.ROOF_FLAT.id,
		wall_height = 1,
	},
	GREEN = {
		wall_sprite = SPRITES.GREEN_BLOCK.id,
		roof_sprite = SPRITES.ROOF_CIRCULAR.id,
		wall_height = 1,
	},

	-- === HIGH-RISE / SKYSCRAPERS (city center) ===
	TECHNO_TOWER = {
		wall_sprite = SPRITES.TECHNO.id,
		roof_sprite = SPRITES.ROOF_CIRCULAR.id,
		wall_height = 3,
	},
	GLASS_TOWER = {
		wall_sprite = SPRITES.GLASS.id,
		roof_sprite = SPRITES.ROOF_FLAT.id,
		wall_height = 3,
	},
	BULKHEAD_TOWER = {
		wall_sprite = SPRITES.BULKHEAD.id,
		roof_sprite = SPRITES.ROOF_POINTY.id,
		wall_height = 3,
	},
	CORPORATE_HQ = {
		wall_sprite = SPRITES.GLASS.id,
		roof_sprite = SPRITES.ROOF_CIRCULAR.id,
		wall_height = 4,
	},
}

-- ============================================
-- PLAYER CONFIG
-- ============================================
PLAYER_CONFIG = {
	walk_speed = 1.2,
	run_speed = 2,
	animation_speed = 8,  -- frames per sprite change
	shadow_color = 25,    -- shadow color during daytime
	shadow_radius = 8,    -- shadow ellipse radius (width)
	shadow_height = 4,    -- shadow ellipse height
	shadow_x_offset = -1,  -- horizontal offset for shadow
	shadow_y_offset = 6,  -- how far below player center to draw shadow

	-- Health system
	max_health = 100,
	health_bar_width = 60,
	health_bar_height = 6,
	health_bar_x = 8,
	health_bar_y = 12,        -- moved down to make room for label
	health_color = 12,        -- red for health
	health_bg_color = 1,      -- dark blue background
	health_border_color = 6,  -- light gray border

	-- Armor system
	max_armor = 1000,        -- can buy up to 10 times (10 x 100)
	armor_cost = 100,         -- $100 per purchase
	armor_per_purchase = 100, -- 100 armor per buy
	armor_bar_width = 60,
	armor_bar_height = 6,
	armor_bar_x = 8,
	armor_bar_y = 28,         -- below health bar (y=12+6+10 spacing)
	armor_color = 28,         -- bright blue for armor
	armor_bg_color = 1,       -- dark blue background
	armor_border_color = 6,   -- light gray border

	-- Popularity system
	max_popularity = 100,
	starting_popularity = 20,     -- initial popularity (0-100)
	popularity_bar_width = 60,
	popularity_bar_height = 6,
	popularity_bar_x = 8,
	popularity_bar_y = 44,    -- below armor bar (y=28+6+10 spacing)
	popularity_color = 14,       -- pink for popularity
	popularity_bg_color = 1,     -- dark blue background
	popularity_border_color = 6, -- light gray border
	popularity_per_fan = 2,      -- popularity gained when meeting a fan
	popularity_loss_crash = 2,   -- popularity lost per car crash
	popularity_loss_flirt_fail = 2, -- popularity lost when fan gives up (3 strikes)
	popularity_text_duration = 1.5, -- seconds to show +/- popularity text
	popularity_gain_color = 33,  -- green for gain
	popularity_loss_color = 12,   -- red for loss

	-- Fan system (chance scales with popularity)
	fan_chance_min = 0.10,       -- 10% chance at 0 popularity
	fan_chance_max = 0.50,       -- 15% chance at max popularity
	fan_detect_distance = 24,    -- pixels to detect fan
	heart_sprite = 193,          -- heart sprite ID
	heart_bob_speed = 3,         -- how fast heart bobs up/down
	heart_bob_height = 2,        -- pixels of bob
	heart_show_duration = 5,     -- seconds heart shows after player approaches
	prompt_color = 21,           -- color for interaction prompts (E: FLIRT etc)

	-- Money system
	starting_money = 20000,        -- player starts with $100
	money_color = 33,            -- green for money text
	money_display_x = 8,
	money_display_y = 60,        -- below popularity bar

	-- Dialog/Flirting
	interact_key = "e",          -- key to talk/interact
	love_meter_max = 100,        -- max love before they're yours
	love_per_good_line = 35,     -- love gained from good pickup line
	love_per_ok_line = 20,       -- love gained from ok pickup line
	love_per_bad_line = 5,       -- love gained from bad pickup line
	heal_amount = 25,            -- health restored by healing with a fan
	lover_map_color = 18,        -- color for lovers on minimap

	-- Character archetypes (assigned randomly when NPC becomes a fan)
	archetypes = { "dirty", "friendly", "clever", "funny" },

	-- Dialog options by archetype (8-10 per archetype)
	-- Each has: text, response (NPC reply), love_gain
	dialog_options = {
		dirty = { -- this is more like romantic lol, but its distinct
			{ text = "I can't stop thinking about you... day and night.", response = "That's so romantic...", love = 35 },
			{ text = "The way you look at me makes my heart race.", response = "You're making me blush!", love = 30 },
			{ text = "I want to be the reason you smile every morning.", response = "How sweet!", love = 25 },
			{ text = "Your eyes are like stars, I could get lost in them forever.", response = "So poetic!", love = 30 },
			{ text = "I've never felt this way about anyone before.", response = "Me neither...", love = 35 },
			{ text = "Every moment with you feels like magic.", response = "I feel it too!", love = 30 },
			{ text = "I want to hold your hand and never let go.", response = "Then don't...", love = 25 },
			{ text = "You make my world brighter just by being in it.", response = "You're so sweet!", love = 30 },
		},
		friendly = {
			{ text = "Hey! You seem really cool, wanna hang out?", response = "Aw, you're sweet!", love = 35 },
			{ text = "I love your vibe! What's your story?", response = "Thanks for asking!", love = 30 },
			{ text = "You look like you give great hugs!", response = "Want to find out?", love = 25 },
			{ text = "I bet you're an amazing friend.", response = "I try my best!", love = 20 },
			{ text = "Your smile just made my day better!", response = "That's so kind!", love = 30 },
			{ text = "You seem like someone worth knowing.", response = "Back at you!", love = 25 },
			{ text = "I feel like we'd get along great!", response = "I think so too!", love = 30 },
			{ text = "Want to grab coffee sometime?", response = "I'd love that!", love = 35 },
		},
		clever = {
			{ text = "Are you made of copper and tellurium? Cause you're Cu-Te!", response = "A chemistry nerd! Love it!", love = 35 },
			{ text = "You must be the square root of -1, cause you can't be real!", response = "Imaginary numbers! Nice!", love = 30 },
			{ text = "Are you a 90 degree angle? Cause you're looking right!", response = "Geometry humor!", love = 25 },
			{ text = "I wish I was your derivative so I could lie tangent to your curves.", response = "Calculus flirting? Bold!", love = 30 },
			{ text = "You're like a black hole - you just pulled me in.", response = "Astrophysics! Swoon!", love = 35 },
			{ text = "Are you a carbon sample? Cause I want to date you.", response = "Radiocarbon dating! Ha!", love = 25 },
			{ text = "If you were a Pokemon, I'd choose you.", response = "A trainer after my heart!", love = 30 },
			{ text = "Are you a keyboard? Cause you're definitely my type.", response = "Tech puns for the win!", love = 20 },
		},
		funny = {
			{ text = "What do you call a fake noodle? An impasta!", response = "Haha oh no!", love = 35 },
			{ text = "Why don't eggs tell jokes? They'd crack each other up!", response = "That's egg-cellent!", love = 30 },
			{ text = "What do you call a fish without eyes? A fsh!", response = "I sea what you did!", love = 25 },
			{ text = "Why did the scarecrow win an award? Outstanding in his field!", response = "Classic dad joke!", love = 30 },
			{ text = "What's orange and sounds like a parrot? A carrot!", response = "That's terrible! I love it!", love = 25 },
			{ text = "Why don't scientists trust atoms? They make up everything!", response = "Science dad joke combo!", love = 30 },
			{ text = "What do you call a bear with no teeth? A gummy bear!", response = "Aww that's cute and punny!", love = 35 },
			{ text = "I'm reading a book about anti-gravity. Can't put it down!", response = "That one really lifts me up!", love = 30 },
		},
	},

	-- Generic/fallback lines (used when archetype doesn't match)
	generic_lines = {
		{ text = "Hey there, nice to meet you!", response = "Nice to meet you too!", love = 15 },
		{ text = "What's a person like you doing in a place like this?", response = "Just hanging around!", love = 10 },
		{ text = "Come here often?", response = "Sometimes!", love = 5 },
		{ text = "You've got great energy!", response = "Thanks, so do you!", love = 15 },
		{ text = "I couldn't help but notice you.", response = "Oh really now?", love = 12 },
		{ text = "That's a nice outfit you've got.", response = "Why thank you!", love = 10 },
		{ text = "You seem interesting.", response = "I try to be!", love = 8 },
		{ text = "Having a good day?", response = "Better now!", love = 12 },
		{ text = "You look like fun!", response = "I like to think so!", love = 10 },
		{ text = "I like the way you walk.", response = "That's... unique!", love = 8 },
		{ text = "Something about you is different.", response = "In a good way?", love = 12 },
		{ text = "You caught my eye.", response = "Did I now?", love = 15 },
		{ text = "Mind if I walk with you?", response = "Sure, why not!", love = 10 },
	},

	-- Failure responses (when choosing wrong archetype line)
	failure_responses = {
		"Ugh, that's not my style...",
		"Really? That's the best you got?",
		"Yikes... try again.",
		"That was awful.",
		"Not impressed.",
		"You can do better than that.",
		"Cringe...",
		"That didn't land at all.",
	},

	-- 3 strikes system
	max_failures = 3,              -- failures before fan gives up
	love_gain_color = 18,          -- color for "+X love" text

	-- Dialog box settings
	dialog_width = 320,
	dialog_height = 80,
	dialog_max_chars_per_line = 50,  -- max characters per line before wrapping
	dialog_line_height = 10,         -- pixels per line of text
	dialog_bg_color = 1,
	dialog_border_color = 6,
	dialog_text_color = 33,
	dialog_option_color = 14,
	dialog_selected_color = 22,
}

-- ============================================
-- WEAPON CONFIG
-- ============================================
WEAPON_CONFIG = {
	-- Weapon order for cycling (melee first, then ranged)
	weapon_order = { "hammer", "pickaxe", "sword", "pistol", "laser_pistol", "plasma_rifle", "beam_cannon" },

	-- Melee weapons (rendered as rotating quads)
	melee = {
		hammer = {
			name = "Hammer",
			price = 50,
			damage = 15,
			swing_speed = 0.3,    -- seconds for full swing
			range = 16,           -- hit detection range
			sprite = 156,         -- weapon sprite (faces west by default)
			sprite_w = 8,         -- sprite width
			sprite_h = 16,        -- sprite height
		},
		pickaxe = {
			name = "Pick Axe",
			price = 150,
			damage = 25,
			swing_speed = 0.4,
			range = 20,
			sprite = 157,         -- weapon sprite (faces west by default)
			sprite_w = 8,
			sprite_h = 16,
		},
		sword = {
			name = "Sword",
			price = 300,
			damage = 40,
			swing_speed = 0.25,
			range = 24,
			sprite = 47,          -- weapon sprite (faces west by default)
			sprite_w = 8,
			sprite_h = 16,
		},
	},

	-- Ranged weapons (fire projectiles)
	ranged = {
		pistol = {
			name = "Pistol",
			price = 550,
			ammo_price = 10,
			ammo_count = 10,      -- ammo per purchase
			damage = 20,
			fire_rate = 0.3,      -- seconds between shots
			bullet_speed = 300,   -- pixels per second
			sprite_ew = 112,      -- bullet sprite for east/west
			sprite_ns = 113,      -- bullet sprite for north/south
			weapon_sprite = 158,  -- gun sprite when held
			weapon_w = 8,
			weapon_h = 8,
			bullet_offset_x = 8, -- bullet spawn x offset (flipped for west)
			bullet_offset_y = -1,  -- bullet spawn y offset
			bullet_offset_n_x = -2,  -- bullet spawn x offset for north
			bullet_offset_n_y = 12, -- bullet spawn y offset for north
			bullet_offset_s_x = -1,  -- bullet spawn x offset for south
			bullet_offset_s_y = 12, -- bullet spawn y offset for south
		},
		laser_pistol = {
			name = "Laser Pistol",
			price = 1200,
			ammo_price = 50,
			ammo_count = 20,
			damage = 35,
			fire_rate = 0.2,
			bullet_speed = 400,
			sprite_frames = { 114, 115 },  -- animated bullet
			animation_speed = 0.05,
			weapon_sprite = 31,   -- gun sprite when held
			weapon_w = 8,
			weapon_h = 8,
			bullet_offset_x = 12,
			bullet_offset_y = -1,
			bullet_offset_n_x = -4,  -- centered on player for north
			bullet_offset_n_y = 12,
			bullet_offset_s_x = -2,  -- centered on player for south
			bullet_offset_s_y = 12,
		},
		plasma_rifle = {
			name = "Plasma Rifle",
			price = 2500,
			ammo_price = 120,
			ammo_count = 50,
			damage = 60,
			fire_rate = 0.5,
			bullet_speed = 250,
			sprite_frames = { 54, 55, 62, 63 },  -- 4-frame animation
			animation_speed = 0.05,
			weapon_sprite = 39,   -- gun sprite when held
			weapon_w = 8,
			weapon_h = 16,
			bullet_offset_x = 10,
			bullet_offset_y = -4,
			bullet_offset_n_x = -4,
			bullet_offset_n_y = 14,
			bullet_offset_s_x = 0,
			bullet_offset_s_y = 14,
		},
		beam_cannon = {
			name = "Beam Cannon",
			price = 10000,
			ammo_price = 500,
			ammo_count = 5,
			damage = 100,         -- massive damage
			fire_rate = 1.5,      -- slow fire rate
			is_beam = true,       -- special beam weapon type
			beam_sprite = 43,     -- beam texture sprite
			beam_duration = 0.3,  -- how long beam stays visible
			beam_width = 16,      -- beam thickness
			weapon_sprite = 159,  -- gun sprite when held
			weapon_w = 8,
			weapon_h = 16,
			bullet_offset_x = 16, -- beam spawn x offset
			bullet_offset_y = 2,  -- beam spawn y offset
			bullet_offset_n_x = 1,
			bullet_offset_n_y = 16,
			bullet_offset_s_x = 3,
			bullet_offset_s_y = 16,
		},
	},

	-- Combat settings
	npc_hit_popularity_loss = 5,  -- popularity lost when hitting an NPC

	-- Melee animation settings (rotation in turns, 0-1 = 0-360 degrees)
	melee_swing_start = 0,        -- start angle in turns (0 degrees)
	melee_swing_end = 0.5,        -- end angle in turns (180 degrees)
	melee_base_rot_east = 0.875,  -- base rotation when facing east (315 degrees)
	melee_base_rot_west = 0.125,  -- base rotation when facing west (45 degrees)
	melee_offset_x = 8,           -- weapon x offset from player center
	melee_offset_y = 2,          -- weapon y offset from player center (negative = up)
	melee_swing_time = 0.08,       -- seconds for forward swing
	melee_return_time = 0.20,     -- seconds to return to rest position
	melee_pivot_x = 0,            -- rotation pivot x offset from sprite center
	melee_pivot_y = 6,            -- rotation pivot y offset from sprite center (positive = down)

	-- Ranged weapon display settings
	ranged_offset_x = 8,          -- weapon x offset from player center
	ranged_offset_y = 2,          -- weapon y offset from player center
}

-- ============================================
-- ARMS DEALER CONFIG
-- ============================================
ARMS_DEALER_CONFIG = {
	names = { "Doug", "Bill" },
	health = 1000,
	damage = 25,               -- damage per bullet to player (reduced from 25)
	fire_rate = 0.8,          -- seconds between shots
	chase_speed = 40,         -- pixels per second when hostile
	walk_speed = 15,          -- pixels per second when peaceful
	target_distance = 150,    -- stop chasing when within this distance of player
	respawn_time = 30,        -- seconds after death to respawn
	minimap_color = 16,       -- always visible on minimap
	minimap_size = 1,         -- radius of dealer marker on minimap

	-- Animation settings
	idle_animation_speed = 0.05,   -- seconds per frame when idle
	walk_animation_speed = 0.04,  -- seconds per frame when walking/chasing
	idle_frames = 11,             -- frames 0-10
	walk_frames = 12,             -- frames 16-27
	damaged_frames = 7,           -- frames 32-38

	-- Sprite IDs (1.gfx sprites start at 256)
	-- In 1.gfx: idle=0-11, walk=16-27, damaged=32-38, bullets=110-111
	sprite_base = 256,        -- offset for 1.gfx sprites
	idle_start = 0,
	walk_start = 16,
	damaged_start = 32,
	bullet_sprites = { 110, 111 },  --  ITS ON THE SPRITE BASE

	-- Interaction
	interact_distance = 24,   -- distance to show shop prompt

	-- Rendering
	sprite_scale = 0.5,       -- scale factor for dealer sprites (0.5 = 50%)
	sprite_size = 32,         -- original sprite size (32x32)
}

-- ============================================
-- FOX ENEMY CONFIG
-- ============================================
FOX_CONFIG = {
	names = { "McCloud", "Sly", "Ember", "Swiper", "Kits", "Vulpi", "Copper", "Red" },
	health = 100,
	damage = 5,              -- damage per bullet to player
	fire_rate = 2.0,          -- seconds between shots
	chase_speed = 60,         -- pixels per second when chasing (faster than dealer)
	wander_speed = 20,        -- pixels per second when wandering
	target_distance = 100,    -- stop and shoot when within this distance of player
	aggro_distance = 200,     -- distance at which fox notices player
	spawn_count = 8,          -- number of foxes to spawn
	minimap_color = 12,       -- red on minimap (color 12 = red)
	minimap_size = 1,
	bullet_speed = 150,       -- bullet speed (slightly slower than dealer)

	-- Animation settings (same offsets as dealer)
	idle_animation_speed = 0.08,
	walk_animation_speed = 0.05,
	idle_frames = 11,             -- frames 0-10
	walk_frames = 12,             -- frames 16-27
	damaged_frames = 7,           -- frames 32-38

	-- Sprite IDs (1.gfx sprites, foxes start at 64)
	sprite_base = 256 + 64,   -- offset for fox sprites in 1.gfx (256 + 64 = 320)
	idle_start = 0,
	walk_start = 16,
	damaged_start = 32, -- this plus 64 should be 96

	-- Rendering
	sprite_scale = 0.5,
	sprite_size = 32,
}

-- ============================================
-- CACTUS MONSTER CONFIG
-- ============================================
CACTUS_CONFIG = {
	name = "Cactus Monster",
	health = 500,             -- Boss-level health
	chase_speed = 40,         -- Slower than foxes
	target_distance = 80,     -- Distance to start attacking
	aggro_distance = 300,     -- Large aggro range
	minimap_color = 14,       -- Bright red on minimap (#f53141)
	minimap_size = 2,         -- Larger marker for boss
	collision_radius = 24,    -- Collision radius (half of 48x48 sprite)

	-- Melee attack (sword-like, same as player)
	melee_damage = 15,
	melee_range = 24,
	melee_cooldown = 1.0,     -- Seconds between swings
	sword_sprite = 47,        -- Same sword sprite as player (8x16)

	-- Ranged attack (10-directional bullet burst)
	ranged_damage = 10,
	ranged_cooldown = 5.0,    -- Seconds between bursts
	bullet_count = 10,        -- Bullets per burst (360/10 = 36 degree spread)
	bullet_speed = 150,
	bullet_sprite = 114,      -- Reuse laser bullet sprite

	-- Animation settings
	idle_animation_speed = 0.08,
	walk_animation_speed = 0.05,
	idle_frames = 11,         -- frames 0-10 (sprites 128-138 in sheet 2)
	walk_frames = 12,         -- frames 0-11 (sprites 144-155 in sheet 2)
	damaged_frames = 5,       -- frames 0-4 (sprites 160-164 in sheet 2)

	-- Sprite IDs (sprite sheet 2 = 2.gfx, base offset = 512)
	-- User provided: idle 128-138, run 144-155, damaged 160-164
	sprite_base = 256 + 128,  -- 2.gfx base (512) + cactus offset (128) = 640
	idle_start = 0,           -- offset 0 from base (sprites 640-650)
	walk_start = 16,          -- offset 16 from base (sprites 656-667)
	damaged_start = 32,       -- offset 32 from base (sprites 672-676)

	-- Rendering
	sprite_scale = 0.5,
	sprite_size = 48,         -- Cactus sprites are 48x48

	-- Spawn location (downtown area)
	spawn_x_min = 300,
	spawn_x_max = 700,
	spawn_y_min = 300,
	spawn_y_max = 700,
}

-- ============================================
-- CAMERA CONFIG
-- ============================================
CAMERA_CONFIG = {
	follow_smoothing = 0.08,  -- smoothing factor (lower = smoother/slower, higher = snappier)
	deadzone_half_w = 16,     -- half-width of center deadzone (player can move this far before camera follows)
	deadzone_half_h = 16,     -- half-height of center deadzone
	-- Vehicle camera lead-ahead (camera looks ahead in direction of travel)
	vehicle_lead_distance = 50,  -- how far ahead to look when driving
	vehicle_lead_smoothing = 0.04,  -- how fast the lead adjusts (lower = smoother transitions)
}

-- ============================================
-- NPC CONFIG
-- ============================================
NPC_CONFIG = {
	-- Movement speeds (pixels per second)
	walk_speed = 15,
	run_speed = 60,
	-- Animation timing (seconds per sprite change)
	run_animation_speed = 0.05,
	animation_speed = 0.1,
	-- AI behavior timing (seconds)
	direction_change_time = { min = 1.0, max = 3.0 },
	idle_time = { min = 0.5, max = 1.5 },
	-- Collision
	collision_radius = 4,
	-- Spawning
	spawn_count = 200,
	-- NPC update mode:
	-- 1 = persistent: NPCs exist everywhere, throttled updates for distant ones
	-- 2 = streaming: NPCs despawn when far, respawn nearby to maintain target count
	update_mode = 1,
	-- Shadows
	shadow_color = 25,
	shadow_radius = 4,
	shadow_height = 2,
	shadow_x_offset = 0,
	shadow_y_offset = 6,

	-- Performance tuning (mode 1: persistent)
	offscreen_update_interval = 2,  -- seconds between AI updates for offscreen NPCs
	offscreen_update_distance = 400,  -- pixels from player; NPCs beyond this are frozen

	-- Performance tuning (mode 2: streaming)
	despawn_distance = 400,    -- pixels from player; NPCs beyond this despawn (also max spawn distance)
	spawn_distance_min = 10,   -- min pixels from player for new spawns
	target_npc_count = 50,     -- target number of NPCs to maintain in streaming mode

	-- Freaked out behavior
	flee_recheck_interval = 0.75,
	scare_radius = 32,
	surprise_duration = 1.0,     -- seconds
	flee_duration = 15.0,        -- seconds
	surprise_sprite = 135,
}

-- NPC type definitions (sprite sets)
NPC_TYPES = {
	{
		name = "MALE_NPC",
		south = { idle = SPRITES.NPC1_SOUTH_IDLE.id, walk = { SPRITES.NPC1_SOUTH_WALK1.id, SPRITES.NPC1_SOUTH_WALK2.id, SPRITES.NPC1_SOUTH_WALK3.id } },
		east  = { idle = SPRITES.NPC1_EAST_IDLE.id,  walk = { SPRITES.NPC1_EAST_WALK1.id,  SPRITES.NPC1_EAST_WALK2.id,  SPRITES.NPC1_EAST_WALK3.id } },
		north = { idle = SPRITES.NPC1_NORTH_IDLE.id, walk = { SPRITES.NPC1_NORTH_WALK1.id, SPRITES.NPC1_NORTH_WALK2.id, SPRITES.NPC1_NORTH_WALK3.id } },
		west  = { idle = SPRITES.NPC1_WEST_IDLE.id,  walk = { SPRITES.NPC1_WEST_WALK1.id,  SPRITES.NPC1_WEST_WALK2.id,  SPRITES.NPC1_WEST_WALK3.id } },
		-- Expressions
		mouth_open = 80,
		surprised = 81,
		look_up = 82,
		look_down = 83,
		w = 8, h = 16,
	},
	{
		name = "FEMALE_NPC",
		south = { idle = SPRITES.NPC2_SOUTH_IDLE.id, walk = { SPRITES.NPC2_SOUTH_WALK1.id, SPRITES.NPC2_SOUTH_WALK2.id, SPRITES.NPC2_SOUTH_WALK3.id } },
		east  = { idle = SPRITES.NPC2_EAST_IDLE.id,  walk = { SPRITES.NPC2_EAST_WALK1.id,  SPRITES.NPC2_EAST_WALK2.id,  SPRITES.NPC2_EAST_WALK3.id } },
		north = { idle = SPRITES.NPC2_NORTH_IDLE.id, walk = { SPRITES.NPC2_NORTH_WALK1.id, SPRITES.NPC2_NORTH_WALK2.id, SPRITES.NPC2_NORTH_WALK3.id } },
		west  = { idle = SPRITES.NPC2_WEST_IDLE.id,  walk = { SPRITES.NPC2_WEST_WALK1.id,  SPRITES.NPC2_WEST_WALK2.id,  SPRITES.NPC2_WEST_WALK3.id } },
		-- Expressions
		mouth_open = 100,
		surprised = 101,
		look_up = 102,
		look_down = 103,
		w = 8, h = 16,
	},
}

-- ============================================
-- PERSPECTIVE CONFIG (GTA1/2 style)
-- ============================================
PERSPECTIVE_CONFIG = {
	max_wall_height = 24,           -- fixed height of all building walls
	perspective_scale = 0.12,       -- how much roofs offset from center (higher = more 3D, was 0.15)
	wall_visibility_threshold = 0,  -- pixels from center before walls show (0 = always show walls)
}

-- ============================================
-- GROUND CONFIG
-- ============================================
GROUND_CONFIG = {
	tile_size = 16,  -- base tile size for ground grid
}

-- ============================================
-- DEBUG CONFIG
-- ============================================
DEBUG_CONFIG = {
	enabled = false,         -- set to false to disable debug features (FPS, profiler, etc.)
	debug_weapons = true,    -- set to true to start with all weapons and 999 ammo
	show_all_npcs = false,    -- set to true to show all NPCs on minimap (overrides MINIMAP_CONFIG.show_npcs)
	show_all_vehicles = false, -- set to true to show all vehicles on minimap and vehicle debug info
	-- skip_to_quest = false,    -- DEPRECATED: use start_quest instead
	-- Start at a specific quest on load (nil = normal intro, or one of:)
		-- "intro",
		-- "protect_city",
		-- "make_friends",
		-- "find_love",
		-- "talk_to_companion_1",  -- leads to fix_home
		-- "fix_home",
		-- "talk_to_companion_2",  -- leads to a_prick
		-- "a_prick",
		-- "talk_to_companion_3",  -- leads to beyond_the_sea
		-- "beyond_the_sea",
		-- "talk_to_companion_4",  -- leads to mega_race
		-- "mega_race",
		-- "talk_to_companion_5",  -- leads to car_wrecker
		-- "car_wrecker",
		-- "talk_to_companion_6",  -- leads to auditor_kathy
		-- "auditor_kathy",
		-- "talk_to_companion_7",  -- leads to speed_dating
		-- "speed_dating",
		-- "talk_to_companion_8",  -- leads to bomb_delivery
		-- "bomb_delivery",
		-- "talk_to_companion_9",  -- leads to alien_invasion
		-- "alien_invasion",

		-- sketch:
		
		-- big epic rally lol, q1 street racing - one of your companions has an 
			-- they have an ex in the race, and they need you to beat them. (come up with elaborate reason)
			-- to race, drive to the starting location and drive 3 laps around the city hitting all checkpoints.
			-- draw a box in the game and the a dot on the minimap whewre the next check point is
			-- generate about 8 cars in the race! and they all try to get to thge next checkpoint, they should have a decent awareness of collision and avoid it) maybe need a cusstom racer AI
			 -- checkpoiints are as follows (using aseprite coords):
			    -- start[133, 96], [154, 96], [154,112], [174,112], [174, 127], [175,142], [115,141],  [115, 96]
				--
		-- one of your companions work for a corrupt insurance company
			-- they need you to wreck as many cars in the city as possible in 30 seconds. 
			-- if you wreck 12+ cars you win this mission, else go back to a companion to start the quest again
		
		-- the insurance comaany has sent an AUDITOR to the city to take care of the player
				-- defeat the boss which will spawn foxes to try and kill you.

		-- speed dating, you're gaining lots of fans, now a companion wants you to join a gameshow to help grow the polycule
		-- a compnanion who was a pizza delivery driver didnt get tipped enough by a customer,
				-- they want you to deliver a bomb to their house. you have a timer,
				-- dont get hit more than 3 times or your car explodes and you loose the mission
		
		-- alien invasion. Aliens are invading the city, defeat them and beat the game! 
			-- you can continue playing the game and running around the sand box after this if you want to
	-- start_quest = nil,
	start_quest = "talk_to_companion_9",
}

-- when major combat quests complete add popularity and show it on the quest complete text
-- Racing mission
-- Demolition derby (increases popularity actually lol)
-- boat stealing to deliver mail to an island hermit (get coordinates for this)
-- flower picking mission
-- maintenance - hitting some buildings with a hammer until they're fixed
-- speed dating, make 3 romantic partners in a row.


-- ============================================
-- TRAFFIC LIGHT CONFIG
-- ============================================
TRAFFIC_CONFIG = {
	cycle_time = 15,        -- seconds per green phase
	yellow_time = 2,        -- seconds for yellow before switching
	all_red_time = 2,       -- seconds for all-red safety phase between switches
	-- N-S traffic signals (controls north-south traffic flow)
	signal_sprites_ns = {
		yellow = 195,
		green = 196,
		red = 197,
	},
	-- E-W traffic signals (controls east-west traffic flow)
	signal_sprites_ew = {
		yellow = 214,
		green = 215,
		red = 222,
	},
	-- Base signal position on lamp sprite
	signal_base_x = 12,     -- from left edge of lamp (center of 24px lamp)
	signal_base_y = 21,     -- from bottom of lamp (near top)
	-- Offset for first signal (N-S) from base position
	signal_1_offset_x = -6,
	signal_1_offset_y = 0,
	-- Offset for second signal (E-W) from base position
	signal_2_offset_x = 6,
	signal_2_offset_y = 0,
	-- Only show traffic lights at intersections (disable regular street lights)
	intersection_lights_only = true,
}

-- ============================================
-- MINIMAP CONFIG
-- ============================================
MINIMAP_CONFIG = {
	enabled = true,          -- show minimap
	x = 8,                   -- screen X position (lower-left corner)
	y = 270 - 60 - 8,        -- screen Y position (lower-left corner: screen_h - height - margin)
	width = 80,              -- minimap width in pixels
	height = 60,             -- minimap height in pixels
	scale = 0.03,            -- world-to-minimap scale (smaller = more zoomed out)
	bg_color = 20,           -- background color (grass green)
	border_color = 6,        -- border color
	road_color = 5,          -- road color (gray)
	building_color = 4,      -- building color (brown)
	player_color = 22,       -- player blip color (yellow)
	npc_color = 8,           -- NPC blip color (red)
	vehicle_color = 21,      -- vehicle blip color (orange)
	boat_color = 9,          -- boat blip color (blue)
	player_size = 1,         -- player blip radius
	npc_size = 1,            -- NPC blip size
	alpha = 0.7,             -- transparency (not used directly, for reference)
	water_color = 24,        -- water color on minimap (blue)

	-- Toggle which dots are displayed
	show_player = true,      -- show player blip
	show_npcs = false,        -- show NPC blips
	show_vehicles = false,    -- show vehicle blips (cars/trucks/vans)
	show_boats = true,       -- show boat blips
	show_buildings = false,   -- show building outlines
}

-- ============================================
-- MAP GENERATION CONFIG
-- ============================================
-- Sprite 255 contains a 256x256 map that defines the world layout
-- Each pixel color represents a terrain type
MAP_CONFIG = {
	-- Map sprite ID
	sprite_id = 247,
	map_width = 256,
	map_height = 256,

	-- World scale: each map pixel = this many world units
	-- 256px * 16 = 4096 world units
	tile_size = 16,

	-- World bounds (invisible walls at map edges)
	-- Map is 256x256, center (128,128) = world (0,0)
	-- So bounds are: -128*16 = -2048 to 127*16 = 2032
	world_min_x = -2048,
	world_max_x = 2032,
	world_min_y = -2048,
	world_max_y = 2032,

	-- Color legend (map pixel colors)
	colors = {
		grass = 20,         -- grass/land
		water = 24,         -- water
		main_road = 31,     -- main paved streets (no sidewalk in map, generate sidewalks)
		dirt_road = 16,     -- dirt/country roads
		building_zone = 4,  -- brown rectangles where buildings can spawn
	},

	-- Building generation settings
	building = {
		-- Min/max building dimensions (in world units)
		min_size = 48,
		max_size = 96,
		-- Padding from roads/water (in world units)
		road_padding = 32,
		-- Target building count
		target_count = 80,
		-- Building type distribution by distance from center
		-- World (0,0) is map center, so downtown is near origin
		center_x = 0,     -- world center X (map center)
		center_y = 0,     -- world center Y (map center)
		inner_radius = 400,   -- within this = downtown
		outer_radius = 1000,  -- beyond this = countryside
	},
}

-- ============================================
-- WATER CONFIG
-- ============================================
-- Water surrounds the city with animated tiles
-- Set 1: Grass border around water (outer coastline)
-- Set 2: Water border around grass (island coastlines)
WATER_CONFIG = {
	animation_speed = 0.5,   -- seconds per frame (2 FPS animation)
	-- World bounds for land (beyond this = water)
	-- Roads span -700 to 1900 x, -400 to 1600 y
	-- Adding extra grass buffer around the city
	land_min_x = -850,       -- west edge of land (extra 100px grass beyond roads)
	land_max_x = 2050,       -- east edge of land (extra 150px grass beyond roads)
	land_min_y = -550,       -- north edge of land (extra 150px grass beyond roads)
	land_max_y = 1750,       -- south edge of land (extra 150px grass beyond roads)
	-- Water extends to world bounds (defined in ground.lua)

	-- 9-slice tile IDs for Set 1 (grass surrounding water - outer coastline)
	-- [frame][position] where position: tl, t, tr, l, c, r, bl, b, br
	set1 = {
		-- Frame 1
		{ tl = 208, t = 209, tr = 210,
		  l  = 216, c = 217, r  = 218,
		  bl = 224, b = 225, br = 226 },
		-- Frame 2
		{ tl = 232, t = 233, tr = 234,
		  l  = 240, c = 241, r  = 242,
		  bl = 248, b = 249, br = 250 },
	},

	-- 9-slice tile IDs for Set 2 (water surrounding grass - island coastlines)
	-- Center tile not used (use grass instead)
	set2 = {
		-- Frame 1
		{ tl = 211, t = 212, tr = 213,
		  l  = 219, c = nil, r  = 221,
		  bl = 227, b = 228, br = 229 },
		-- Frame 2
		{ tl = 235, t = 236, tr = 237,
		  l  = 243, c = nil, r  = 245,
		  bl = 251, b = 252, br = 253 },
	},

	-- Islands configuration (position in water, outside land bounds)
	-- x,y = world position of island top-left, w,h = size in tiles (16px each)
	islands = {
		{ x = -1000, y = -600, w = 4, h = 3 },   -- island far NW
		{ x = -1100, y = 400, w = 3, h = 2 },    -- island W
		{ x = -950, y = 1200, w = 5, h = 4 },    -- larger island SW
		{ x = 2050, y = -500, w = 4, h = 3 },    -- island far NE
		{ x = 2100, y = 600, w = 3, h = 3 },     -- island E
		{ x = 2000, y = 1400, w = 4, h = 2 },    -- island SE
		{ x = 400, y = 1750, w = 3, h = 2 },     -- island S
		{ x = 800, y = -650, w = 3, h = 2 },     -- island N
	},
}

-- ============================================
-- NIGHT MODE / LIGHTING CONFIG
-- ============================================
NIGHT_CONFIG = {
	player_light_radius = 25,    -- radius of light around player
	street_light_radius = 20,    -- radius of street lights
	street_light_spacing = 64,   -- distance between street lights (world units)
	street_light_offset = 0,     -- offset along sidewalk path (slide lights forward/back)
	darken_color = 16,           -- color index for dark areas (higher = darker)
	ambient_color = 31,          -- color index for ambient tint (even in lit areas)
	transition_speed = 16,        -- frames per transition step
	-- Transition sequences (darken_color values)
	day_to_night = { 33, 30, 20, 25, 11 },  -- day gets darker
	night_to_day = { 11, 25, 20, 30, 33 },  -- night gets lighter
	-- Lamp sprite (visual representation of street lights)
	lamp_sprite = 192,           -- sprite ID for lamp
	lamp_width = 24,             -- lamp sprite width
	lamp_height = 24,            -- lamp sprite height
	-- Entity light radii (for enemies and NPCs that glow at night)
	enemy_light_radius = 18,     -- radius of light around foxes/cactus
	dealer_light_radius = 15,    -- radius of light around arms dealers
}

-- ============================================
-- DAY-NIGHT CYCLE CONFIG
-- ============================================
DAY_NIGHT_CYCLE_CONFIG = {
	-- Cycle timing (in real seconds)
	day_duration = 12 * 60,      -- 12 minutes of daytime (720 seconds)
	night_duration = 12 * 60,    -- 12 minutes of nighttime (720 seconds)
	-- Full cycle = 24 minutes = 1440 seconds

	-- In-game time mapping
	-- 1440 real seconds = 24 in-game hours
	-- So 1 real second = 1 in-game minute
	start_hour = 15,             -- game starts at 3:00 PM

	-- Night time range (inclusive)
	night_start_hour = 18,       -- 6:00 PM - night begins
	night_end_hour = 6,          -- 6:00 AM - night ends

	-- Time skip (N key)
	time_skip_hours = 3,         -- pressing N skips 3 hours

	-- Clock HUD settings
	clock_x = 8,                 -- x position (above minimap)
	clock_y = 192,               -- y position (above minimap which is at y=202)
	clock_color = 33,            -- white text
	clock_shadow_color = 1,      -- black shadow
}

-- ============================================
-- ROAD/SIDEWALK CONFIG
-- ============================================
ROAD_CONFIG = {
	road_width = 64,       -- width of road surface (doubled from 32)
	sidewalk_width = 16,   -- width of sidewalk on each side (1 tile)
	-- Total street width = road_width + 2*sidewalk_width = 96
}

-- ============================================
-- LEVEL DATA - ROADS
-- ============================================
-- Roads are defined as line segments with width
-- tile_type: 2=medium dirt (only using medium for consistency)
-- Coordinates are doubled for larger scale
-- Each road has sidewalks on both sides (16px each)
-- Street lights placed on sidewalks (both sides)
ROADS = {
	-- === MAJOR ARTERIAL ROADS (form the main grid) ===
	-- Main horizontal roads (y positions doubled, street width 64)
	{ direction = "horizontal", y = 0,    x1 = -640, x2 = 1600, width = 64, tile_type = 2 },
	{ direction = "horizontal", y = 384,  x1 = -640, x2 = 1600, width = 64, tile_type = 2 },
	{ direction = "horizontal", y = 768,  x1 = -640, x2 = 1600, width = 64, tile_type = 2 },
	{ direction = "horizontal", y = 1152, x1 = -640, x2 = 1600, width = 64, tile_type = 2 },

	-- Main vertical roads (x positions doubled, street width 64)
	{ direction = "vertical", x = -256, y1 = -256, y2 = 1408, width = 64, tile_type = 2 },
	{ direction = "vertical", x = 256,  y1 = -256, y2 = 1408, width = 64, tile_type = 2 },
	{ direction = "vertical", x = 768,  y1 = -256, y2 = 1408, width = 64, tile_type = 2 },
	{ direction = "vertical", x = 1216, y1 = -256, y2 = 1408, width = 64, tile_type = 2 },

	-- === SECONDARY STREETS (subdivide blocks) ===
	-- Inner city horizontal streets
	{ direction = "horizontal", y = 192,  x1 = -256, x2 = 1216, width = 64, tile_type = 2 },
	{ direction = "horizontal", y = 576,  x1 = -256, x2 = 1216, width = 64, tile_type = 2 },
	{ direction = "horizontal", y = 960,  x1 = -256, x2 = 1216, width = 64, tile_type = 2 },

	-- Inner city vertical streets
	{ direction = "vertical", x = 0,    y1 = 0, y2 = 1152, width = 64, tile_type = 2 },
	{ direction = "vertical", x = 512,  y1 = 0, y2 = 1152, width = 64, tile_type = 2 },
	{ direction = "vertical", x = 960,  y1 = 0, y2 = 1152, width = 64, tile_type = 2 },
}

-- ============================================
-- COUNTRYSIDE ROADS (no sidewalks, no street lights)
-- ============================================
-- Organic road segments outside the city grid
-- tile_type: 3 = dense dirt (DIRT_HEAVY)
-- countryside = true marks these as rural roads
COUNTRYSIDE_ROADS = {
	-- === WEST COUNTRYSIDE ===
	-- Main road heading west from city
	{ direction = "horizontal", y = 576, x1 = -640, x2 = -256, width = 32, tile_type = 3, countryside = true },
	-- Branch north
	{ direction = "vertical", x = -512, y1 = 200, y2 = 576, width = 32, tile_type = 3, countryside = true },
	-- Branch south
	{ direction = "vertical", x = -480, y1 = 576, y2 = 900, width = 32, tile_type = 3, countryside = true },
	-- Curved path northwest
	{ direction = "horizontal", y = 200, x1 = -700, x2 = -512, width = 32, tile_type = 3, countryside = true },
	{ direction = "vertical", x = -700, y1 = -100, y2 = 200, width = 32, tile_type = 3, countryside = true },

	-- === EAST COUNTRYSIDE ===
	-- Main road heading east from city
	{ direction = "horizontal", y = 576, x1 = 1296, x2 = 1800, width = 32, tile_type = 3, countryside = true },
	-- Branch northeast
	{ direction = "vertical", x = 1600, y1 = 300, y2 = 576, width = 32, tile_type = 3, countryside = true },
	{ direction = "horizontal", y = 300, x1 = 1600, x2 = 1900, width = 32, tile_type = 3, countryside = true },
	-- Branch southeast
	{ direction = "vertical", x = 1700, y1 = 576, y2 = 1000, width = 32, tile_type = 3, countryside = true },

	-- === NORTH COUNTRYSIDE ===
	-- Road heading north from city
	{ direction = "vertical", x = 480, y1 = -256, y2 = -100, width = 32, tile_type = 3, countryside = true },
	{ direction = "vertical", x = 480, y1 = -400, y2 = -256, width = 32, tile_type = 3, countryside = true },
	-- Branch west
	{ direction = "horizontal", y = -300, x1 = 100, x2 = 480, width = 32, tile_type = 3, countryside = true },
	-- Branch east
	{ direction = "horizontal", y = -350, x1 = 480, x2 = 900, width = 32, tile_type = 3, countryside = true },

	-- === SOUTH COUNTRYSIDE ===
	-- Road heading south from city
	{ direction = "vertical", x = 600, y1 = 1216, y2 = 1500, width = 32, tile_type = 3, countryside = true },
	-- Branch southwest
	{ direction = "horizontal", y = 1400, x1 = 200, x2 = 600, width = 32, tile_type = 3, countryside = true },
	{ direction = "vertical", x = 200, y1 = 1400, y2 = 1600, width = 32, tile_type = 3, countryside = true },
	-- Branch southeast
	{ direction = "horizontal", y = 1350, x1 = 600, x2 = 1100, width = 32, tile_type = 3, countryside = true },
}

-- ============================================
-- FLORA CONFIG
-- ============================================
FLORA_CONFIG = {
	-- Master toggle
	enabled = false,          -- set to false to disable flora rendering

	-- Region-based procedural generation
	-- Each region_size x region_size area gets items_per_region flora items
	region_size = 160,       -- 10 tiles x 16 pixels = 160 pixel regions
	items_per_region = 8,   -- 20 flora items per 160x160 region

	-- Probability weights for flora types (relative chances)
	tree_weight = 0.15,      -- 15% chance for trees (only on eligible spots)
	flower_weight = 0.40,    -- 40% chance for flowers
	-- Remaining chance = grass blades

	-- Flora sprite IDs
	tree_sprites = { SPRITES.TREE_1.id, SPRITES.TREE_2.id },
	flower_sprites = { SPRITES.FLOWER_1.id, SPRITES.FLOWER_2.id },
	grass_sprite = SPRITES.GRASS_BLADE.id,

	-- Shadow toggle and settings
	shadows_enabled = false,  -- set to true to enable flora shadows
	shadow_color = 25,
	shadow_y_offset = 6,
	tree_shadow_radius = 5,
	tree_shadow_height = 3,
	flower_shadow_radius = 3,
	flower_shadow_height = 2,
	grass_shadow_radius = 2,
	grass_shadow_height = 1,
}

-- ============================================
-- LEVEL DATA - BUILDINGS
-- ============================================
-- Layout calculation:
-- Road corridor = 96 (64 road + 16 sidewalk each side)
-- Road spacing = 192 (between horizontal roads)
-- Block interior = 192 - 96 = 96px available
-- Building zone with 16px padding = starts at road_center + 48, height ~64px max
--
-- Horizontal roads: y=0, 192, 384, 576, 768, 960, 1152
-- Vertical roads: x=-256, 0, 256, 512, 768, 960, 1216

LEVEL_BUILDINGS = {
	-- Format: { x, y, w, h, type }

	-- =============================================
	-- OUTER RING: PRIMITIVE BUILDINGS (brick, concrete, cracked)
	-- =============================================

	-- === FAR WEST COLUMN - Left of x=-256 road ===
	{ x = -480, y = 64,  w = 80, h = 64, type = "CRACKED_BRICK" },
	{ x = -384, y = 64,  w = 64, h = 64, type = "BRICK" },
	{ x = -480, y = 256, w = 96, h = 64, type = "CRACKED_CONCRETE" },
	{ x = -368, y = 256, w = 64, h = 64, type = "LARGE_BRICK" },
	{ x = -480, y = 448, w = 80, h = 64, type = "BRICK" },
	{ x = -384, y = 448, w = 72, h = 64, type = "ZINC" },
	{ x = -480, y = 640, w = 88, h = 64, type = "CRACKED_BRICK" },
	{ x = -376, y = 640, w = 64, h = 64, type = "CONCRETE" },
	{ x = -480, y = 832, w = 160, h = 64, type = "WAREHOUSE" },
	{ x = -480, y = 1024, w = 80, h = 64, type = "LARGE_BRICK" },
	{ x = -384, y = 1024, w = 72, h = 64, type = "BRICK" },

	-- === FAR EAST COLUMN - Right of x=1216 road ===
	{ x = 1296, y = 64,  w = 80, h = 64, type = "BRICK" },
	{ x = 1392, y = 64,  w = 64, h = 64, type = "CRACKED_CONCRETE" },
	{ x = 1296, y = 256, w = 64, h = 64, type = "ZINC" },
	{ x = 1376, y = 256, w = 80, h = 64, type = "LARGE_BRICK" },
	{ x = 1296, y = 448, w = 96, h = 64, type = "CRACKED_BRICK" },
	{ x = 1408, y = 448, w = 56, h = 64, type = "CONCRETE" },
	{ x = 1296, y = 640, w = 72, h = 64, type = "BRICK" },
	{ x = 1384, y = 640, w = 72, h = 64, type = "CRACKED_CONCRETE" },
	{ x = 1296, y = 832, w = 160, h = 64, type = "WAREHOUSE" },
	{ x = 1296, y = 1024, w = 80, h = 64, type = "LARGE_BRICK" },
	{ x = 1392, y = 1024, w = 64, h = 64, type = "CRACKED_BRICK" },

	-- === TOP ROW - Above y=0 road ===
	{ x = -160, y = -112, w = 96, h = 64, type = "CRACKED_CONCRETE" },
	{ x = 80,   y = -112, w = 80, h = 64, type = "BRICK" },
	{ x = 336,  y = -112, w = 80, h = 64, type = "ZINC" },
	{ x = 592,  y = -112, w = 80, h = 64, type = "LARGE_BRICK" },
	{ x = 848,  y = -112, w = 64, h = 64, type = "CRACKED_BRICK" },
	{ x = 1040, y = -112, w = 80, h = 64, type = "CONCRETE" },

	-- === BOTTOM ROW - Below y=1152 road ===
	{ x = -160, y = 1216, w = 96, h = 64, type = "BRICK" },
	{ x = 80,   y = 1216, w = 80, h = 64, type = "CRACKED_BRICK" },
	{ x = 336,  y = 1216, w = 80, h = 64, type = "ZINC" },
	{ x = 592,  y = 1216, w = 80, h = 64, type = "LARGE_BRICK" },
	{ x = 848,  y = 1216, w = 64, h = 64, type = "CRACKED_CONCRETE" },
	{ x = 1040, y = 1216, w = 80, h = 64, type = "CONCRETE" },

	-- =============================================
	-- MIDDLE RING: MIXED DEVELOPMENT (office, marble, warehouse)
	-- =============================================

	-- === WEST COLUMN - Between x=-256 and x=0 roads ===
	{ x = -160, y = 64,  w = 96, h = 64, type = "CONCRETE" },
	{ x = -160, y = 256, w = 96, h = 64, type = "OFFICE" },
	{ x = -160, y = 448, w = 96, h = 64, type = "MARBLE" },
	{ x = -160, y = 640, w = 96, h = 64, type = "WAREHOUSE" },
	{ x = -160, y = 832, w = 96, h = 64, type = "GREEN" },
	{ x = -160, y = 1024, w = 96, h = 64, type = "OFFICE" },

	-- === EAST COLUMN - Between x=960 and x=1216 roads ===
	{ x = 1040, y = 64,  w = 96, h = 64, type = "CONCRETE" },
	{ x = 1040, y = 256, w = 96, h = 64, type = "OFFICE" },
	{ x = 1040, y = 448, w = 96, h = 64, type = "BULKHEAD_TOWER" },
	{ x = 1040, y = 640, w = 96, h = 64, type = "WAREHOUSE" },
	{ x = 1040, y = 832, w = 96, h = 64, type = "MARBLE" },
	{ x = 1040, y = 1024, w = 96, h = 64, type = "GREEN" },

	-- === ROW ABOVE CENTER - Inner blocks ===
	{ x = 80,  y = 64,  w = 96, h = 64, type = "MARBLE" },
	{ x = 336, y = 64,  w = 96, h = 64, type = "OFFICE" },
	{ x = 592, y = 64,  w = 96, h = 64, type = "BULKHEAD_TOWER" },
	{ x = 848, y = 64,  w = 64, h = 64, type = "CONCRETE" },

	-- === ROW BELOW CENTER ===
	{ x = 80,  y = 832, w = 96, h = 64, type = "OFFICE" },
	{ x = 336, y = 832, w = 96, h = 64, type = "MARBLE" },
	{ x = 592, y = 832, w = 96, h = 64, type = "GREEN" },
	{ x = 848, y = 832, w = 64, h = 64, type = "BULKHEAD_TOWER" },

	-- === BOTTOM INNER ROW ===
	{ x = 80,  y = 1024, w = 96, h = 64, type = "WAREHOUSE" },
	{ x = 336, y = 1024, w = 96, h = 64, type = "OFFICE" },
	{ x = 592, y = 1024, w = 96, h = 64, type = "MARBLE" },
	{ x = 848, y = 1024, w = 64, h = 64, type = "CONCRETE" },

	-- =============================================
	-- CITY CENTER: TALL TECHNO SKYSCRAPERS
	-- =============================================

	-- === DOWNTOWN CORE ROW 1 (between y=192 and y=384) ===
	{ x = 80,  y = 256, w = 96, h = 64, type = "METALLIC_PIPES" },
	{ x = 336, y = 256, w = 96, h = 64, type = "TECHNO_TOWER" },
	{ x = 592, y = 256, w = 96, h = 64, type = "GLASS_TOWER" },
	{ x = 848, y = 256, w = 64, h = 64, type = "BULKHEAD_TOWER" },

	-- === DOWNTOWN CORE ROW 2 (between y=384 and y=576) - THE HEART ===
	{ x = 80,  y = 448, w = 96, h = 64, type = "GLASS_SKYSCRAPER" },
	{ x = 336, y = 448, w = 96, h = 64, type = "CORPORATE_HQ" },
	{ x = 592, y = 448, w = 96, h = 64, type = "TECHNO_TOWER" },
	{ x = 848, y = 448, w = 64, h = 64, type = "METALLIC_PIPES" },

	-- === DOWNTOWN CORE ROW 3 (between y=576 and y=768) ===
	{ x = 80,  y = 640, w = 96, h = 64, type = "TECHNO" },
	{ x = 336, y = 640, w = 96, h = 64, type = "GLASS_TOWER" },
	{ x = 592, y = 640, w = 96, h = 64, type = "GLASS_SKYSCRAPER" },
	{ x = 848, y = 640, w = 64, h = 64, type = "BULKHEAD_TOWER" },
}

-- ============================================
-- VEHICLE CONFIG
-- ============================================
VEHICLE_CONFIG = {
	-- Vehicle types with their sprites
	types = {
		truck = {
			name = "truck",
			sprite_e = 201,  -- facing east
			sprite_n = 202,  -- facing north
			w = 16, h = 16,  -- sprite dimensions
			speed = 60,      -- pixels per second
			health = 100,
			ns_y_offset = 4, -- Y offset when facing N/S
		},
		van = {
			name = "van",
			sprite_e = 203,  -- facing east
			sprite_n = 204,  -- facing north
			w = 16, h = 16,  -- sprite dimensions (east-facing)
			speed = 70,
			health = 80,
			ns_y_offset = 4, -- Y offset when facing N/S
		},
		boat = {
			name = "boat",
			sprite_e = 205,  -- facing east (only water vehicle)
			sprite_n = nil,  -- boats only face E/W
			w = 16, h = 16,
			speed = 25,
			health = 60,
			water_only = true,  -- can only travel on water
			ns_y_offset = 0, -- boats don't face N/S
		},
	},

	-- Spawn limits
	max_vehicles = 100,       -- maximum cars/trucks/vans on roads
	max_boats = 50,           -- maximum boats on water

	-- Player vehicle bonuses
	player_health_multiplier = 4,  -- player's stolen vehicle has 4x health
	player_speed_multiplier = 2.0, -- player vehicle is 2x faster than AI (faster than fleeing 1.8x)

	-- Acceleration settings
	acceleration = 80,             -- pixels per second^2 (how fast to reach max speed)
	deceleration = 120,            -- pixels per second^2 (how fast to slow down when not pressing)

	-- AI flee behavior
	flee_speed_multiplier = 1.5,   -- speed multiplier when AI vehicles are fleeing (after being hit)

	-- Damage and effects
	damage_per_collision = 20,      -- damage when vehicles collide
	fire_threshold = 30,            -- health below this = on fire
	fire_sprites = { 198, 199, 206, 207 },  -- fire animation frames
	fire_animation_speed = 0.1,     -- seconds per fire frame

	-- Explosion
	explosion_sprites = { 104, 105, 106, 107 },  -- explosion animation frames
	explosion_animation_speed = 0.1,  -- seconds per explosion frame
	destroyed_sprite = 200,           -- wreckage sprite after explosion
	explosion_player_damage = 50,     -- damage to player when their vehicle explodes

	-- Interaction
	steal_prompt_distance = 24,  -- distance to show "E to steal" prompt
	steal_key = "e",             -- key to steal vehicle

	-- NPC collision
	npc_push_force = 60,         -- how fast NPCs get pushed aside

	-- Collision hitbox scale (1.0 = full sprite size, 0.7 = 70% of sprite)
	collision_scale = 0.7,       -- shrink collision box to feel tighter

	-- Respawn settings (when vehicles are destroyed)
	respawn_enabled = true,              -- set to false to disable respawning
	min_respawn_distance = 300,          -- minimum distance from player to spawn replacement
	respawn_delay = 2.0,                 -- seconds to wait after destruction before respawning

	-- Shadow settings
	shadow_color = 25,
	shadow_radius = 10,
	shadow_height = 4,
	shadow_y_offset = 6,

	-- Offscreen update throttling (performance)
	offscreen_margin = 32,              -- pixels beyond screen to consider "offscreen"
	offscreen_update_interval = 2,      -- seconds between updates for offscreen vehicles
	update_distance = 250,              -- pixels from player; vehicles beyond this are FROZEN
	flee_duration = 10,                 -- seconds to flee after being hit by player
}

-- ============================================
-- KATHY BOSS CONFIG
-- ============================================
KATHY_CONFIG = {
	name = "Auditor Kathy",
	health = 600,             -- Boss-level health (slightly more than cactus)
	chase_speed = 35,         -- Slower than foxes, keeps distance
	target_distance = 120,    -- Preferred range (further than cactus, ranged-only)
	aggro_distance = 350,     -- Large aggro range
	minimap_color = 6,        -- Magenta on minimap (#791551)
	minimap_size = 2,         -- Larger marker for boss
	collision_radius = 24,    -- Same as cactus (half of 48x48)

	-- NO MELEE (ranged only boss)

	-- Bullet Pattern 1: Spiral (sprites 45, 46)
	spiral_damage = 12,
	spiral_cooldown = 6.0,    -- 5-7 seconds (use 6 as middle)
	spiral_bullet_count = 16, -- bullets in spiral
	spiral_speed = 100,       -- slower to make spiral visible
	spiral_sprites = { 45, 46 },
	spiral_animation_speed = 0.1,
	spiral_rotation_offset = 0.1, -- rotation increment per bullet for spiral effect

	-- Bullet Pattern 2: Sweeping Line (sprites 108, 109)
	sweep_damage = 15,
	sweep_cooldown = 4.0,     -- fires more frequently than spiral
	sweep_bullet_count = 8,   -- bullets in the line
	sweep_speed = 180,        -- faster than spiral
	sweep_sprites = { 108, 109 },
	sweep_animation_speed = 0.08,
	sweep_arc = 0.25,         -- sweep 90 degrees (0.25 turns)

	-- Animation settings (same as cactus)
	idle_animation_speed = 0.08,
	walk_animation_speed = 0.05,
	idle_frames = 11,
	walk_frames = 12,
	damaged_frames = 5,

	-- Sprite IDs (1.gfx, starts at sprite 200)
	sprite_base = 256 + 192,  -- 456
	idle_start = 0,
	walk_start = 16,
	damaged_start = 32,

	-- Rendering (same as cactus)
	sprite_scale = 0.5,
	sprite_size = 48,

	-- Spawn location (downtown area, same as cactus)
	spawn_x_min = 300,
	spawn_x_max = 700,
	spawn_y_min = 300,
	spawn_y_max = 700,

	-- Fox minion count
	fox_minion_count = 3,
}

-- ============================================
-- MOTHERSHIP CONFIG (Final Boss)
-- ============================================
MOTHERSHIP_CONFIG = {
	name = "Alien Mothership",
	health = 1200,

	-- Movement (slow drift around city center)
	drift_speed = 25,
	drift_radius = 100,       -- circular drift radius
	hover_offset = -80,       -- visual height above ground (negative = higher)

	-- Spiral attack pattern
	spiral_cooldown = 5.0,          -- seconds between spiral attacks
	spiral_fire_interval = 0.033,   -- seconds between shots (~2 frames at 60fps)
	spiral_total_bullets = 30,      -- bullets per spiral
	spiral_bullet_speed = 80,       -- slower for visibility
	spiral_damage = 15,
	spiral_angle_step = 0.4,        -- rotation per bullet (in turns, 0-1)

	-- Sprites (1.gfx, base offset 256)
	sprite = 256 + 112,             -- mothership sprite (368)
	laser_sprite = 256 + 113,       -- laser bullet sprite (369)

	-- Rendering (56x32 non-square sprite)
	sprite_w = 56,                  -- mothership sprite width
	sprite_h = 32,                  -- mothership sprite height
	collision_radius = 28,          -- collision based on sprite dimensions

	-- Hit flash
	hit_flash_duration = 0.15,

	-- Spawn location (city center)
	spawn_x = 0,
	spawn_y = 0,

	-- Minion management
	max_minions = 4,
	minion_respawn_delay = 10.0,    -- seconds before spawning new minion
	initial_minion_spawn_delay = 3.0, -- delay before first minions spawn

	-- Building destruction (initial attack)
	destruction_delay = 2.0,        -- seconds after spawn before destroying buildings
	destruction_radius = 150,       -- destroy buildings within this radius of center

	-- Victory
	death_explosion_delay = 3.0,    -- seconds before final explosion
	victory_display_delay = 5.0,    -- seconds before showing options
}

-- ============================================
-- ALIEN MINION CONFIG
-- ============================================
ALIEN_MINION_CONFIG = {
	health = 150,
	chase_speed = 50,
	target_distance = 80,           -- attack range
	aggro_distance = 300,

	-- Attack pattern (N, S, E, W spread)
	attack_cooldown = 3.0,          -- seconds between attacks
	attack_pulses = 10,             -- bullets fired per attack
	pulse_interval = 0.1,           -- seconds between pulses
	bullet_speed = 120,
	bullet_damage = 10,
	bullet_sprite = 114,            -- use existing laser bullet

	-- Sprites (1.gfx, base offset 256)
	sprite_base = 256,
	idle_start = 40,                -- sprites 40-45
	idle_frames = 6,
	move_start = 48,                -- sprites 48-53
	move_frames = 6,
	attack_start = 56,              -- sprites 56-63
	attack_frames = 8,
	damaged_start = 104,            -- sprites 104-108
	damaged_frames = 5,

	-- Animation speeds
	idle_animation_speed = 0.08,
	move_animation_speed = 0.05,
	attack_animation_speed = 0.06,
	damaged_animation_speed = 0.03,

	-- Rendering
	sprite_size = 32,               -- 32x32 minion sprites
	sprite_scale = 1.0,
	collision_radius = 14,

	-- Hit flash
	hit_flash_duration = 0.25,

	-- Spawn
	spawn_radius = 80,              -- spawn distance from mothership
}

-- ============================================
-- RACE CONFIG
-- ============================================
RACE_CONFIG = {
	-- Checkpoint positions (Aseprite coordinates, will be converted to world coords)
	-- Forms a loop around the city
	checkpoints = {
		{x = 133, y = 96},   -- start/finish line
		{x = 154, y = 96},
		{x = 154, y = 112},
		{x = 174, y = 112},
		{x = 174, y = 127},
		{x = 175, y = 142},
		{x = 115, y = 141},
		{x = 115, y = 96},
	},

	-- Race settings
	total_laps = 3,
	num_racers = 8,

	-- Checkpoint detection
	checkpoint_radius = 48,        -- world units for player/racer to hit checkpoint
	start_line_radius = 64,        -- radius to detect player at start line

	-- AI racer settings
	racer_speed_multiplier = 1.7,  -- multiplier on base vehicle speed (competitive!)
	racer_health_multiplier = 4,   -- same as player vehicles (tanky)

	-- Visual settings
	checkpoint_world_radius = 20,  -- visual size of checkpoint circle in world
	checkpoint_color = 21,         -- gold for inactive checkpoints
	checkpoint_active_color = 22,  -- bright yellow for current checkpoint
	minimap_checkpoint_color = 22, -- yellow on minimap
	minimap_checkpoint_size = 2,   -- pixel radius on minimap

	-- HUD settings
	hud_x = 8,
	hud_y = 50,

	-- Time limit
	time_limit = 300,  -- 5 minutes (300 seconds)

	-- AI direction commitment (prevent twitching)
	direction_commit_distance = 48,  -- travel ~3 tiles before changing direction
}

-- ============================================
-- MENU CONFIG
-- ============================================
MENU_CONFIG = {
	-- Chicken spaceship (1.gfx, base offset 256)
	chicken_sprite = 256 + 114,     -- sprite 370
	chicken_size = 32,              -- 32x32 sprite
	chicken_scale = 3.0,            -- scale up chicken using quad

	-- Thruster flame sprites (1.gfx, base offset 256)
	thruster_sprites = {256 + 116, 256 + 117, 256 + 118, 256 + 119},  -- 372-375
	thruster_size_w = 8,            -- 8 pixels wide
	thruster_size_h = 16,           -- 16 pixels tall
	thruster_animation_speed = 0.1, -- seconds per frame
	thruster_base_scale_x = 1.0,    -- horizontal scale (no stretch)
	thruster_base_scale_y = 0.9,    -- vertical scale (min stretch)
	thruster_pulse_speed = 4.0,     -- pulsation speed (Hz)
	thruster_pulse_amount = 0.1,    -- scale variation (0.8 to 1.0 range)
	thruster_flip_y = true,         -- mirror flame vertically
	thruster_offset_x = 3,          -- local X offset for flame position
	thruster_offset_y = 8,          -- local Y offset for flame position

	-- Chicken bobbing
	bob_speed = 2.0,                -- bobbing speed (Hz)
	bob_amount = 4,                 -- pixels of vertical bob

	-- Spaceship position
	chicken_y = 120,                -- Y position (above center)
	chicken_offset_x = 120,           -- horizontal offset from center
	chicken_offset_y = 20,           -- vertical offset adjustment

	-- Night highway parallax background
	scroll_speed = 1.0,             -- parallax scroll speed
	night_sky_color = 1,            -- dark blue/black sky
	road_color = 5,                 -- dark gray asphalt
	lane_color = 33,                -- white lane markings
	dash_width = 40,                -- road dash width
	dash_gap = 25,                  -- gap between road dashes

	-- Starfield
	star_count = 100,               -- number of stars
	star_colors = {33, 30, 6},      -- white, light gray, dark gray

	-- Building textures (uses BUILDING_TYPES sprites)
	window_color = 22,              -- yellow lit windows

	-- Street lamps (uses NIGHT_CONFIG.lamp_sprite)
	lamp_spacing = 150,             -- distance between lamps
	lamp_glow_color = 22,           -- yellow glow
	lamp_bright_color = 33,         -- white center

	-- Text box (for legibility)
	text_box_color = 1,             -- black background
	text_box_border = 6,            -- gray border
	text_box_padding = 6,           -- padding around text

	-- Text colors
	title_color = 33,               -- white
	prompt_color = 22,              -- yellow
	selected_color = 22,            -- yellow for selected option
	unselected_color = 33,          -- white for unselected
}

-- ============================================
-- SAVE CONFIG
-- ============================================
SAVE_CONFIG = {
	filename = "/appdata/grand_theft_pico/save.pod",
	version = 1,  -- for future compatibility
}

-- ============================================
-- HELPER: Create building from level data
-- ============================================
function create_buildings_from_level()
	local buildings = {}
	for _, b in ipairs(LEVEL_BUILDINGS) do
		local btype = BUILDING_TYPES[b.type] or BUILDING_TYPES.BRICK
		add(buildings, {
			x = b.x,
			y = b.y,
			w = b.w,
			h = b.h,
			wall_sprite = btype.wall_sprite,
			roof_sprite = btype.roof_sprite or SPRITES.ROOF.id,
			wall_height = btype.wall_height or 1,
		})
	end
	return buildings
end
