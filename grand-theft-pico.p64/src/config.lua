--[[pod_format="raw"]]
-- config.lua - Game design configuration (sprites, buildings, tuning)

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

	-- Sidewalks (16x16)
	SIDEWALK_NS   = { id = 132, w = 16, h = 16 },  -- north-south oriented
	SIDEWALK_EW   = { id = 133, w = 16, h = 16 },  -- east-west oriented

	-- Flora (16x16)
	FLOWER_1      = { id = 139, w = 16, h = 16 },
	FLOWER_2      = { id = 140, w = 16, h = 16 },
	GRASS_BLADE   = { id = 141, w = 16, h = 16 },
	TREE_1        = { id = 142, w = 16, h = 16 },
	TREE_2        = { id = 143, w = 16, h = 16 },

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
	walk_speed = 1,
	run_speed = 2,
	animation_speed = 8,  -- frames per sprite change
	shadow_color = 25,    -- shadow color during daytime
	shadow_radius = 8,    -- shadow ellipse radius (width)
	shadow_height = 4,    -- shadow ellipse height
	shadow_x_offset = -1,  -- horizontal offset for shadow
	shadow_y_offset = 6,  -- how far below player center to draw shadow
}

-- ============================================
-- CAMERA CONFIG
-- ============================================
CAMERA_CONFIG = {
	follow_smoothing = 0.1,  -- 0 = instant, 1 = no movement
	deadzone_x = 20,
	deadzone_y = 20,
}

-- ============================================
-- NPC CONFIG
-- ============================================
NPC_CONFIG = {
	walk_speed = 0.25,           -- slower than player
	run_speed = 1,  
	run_animation_speed = 20,
	animation_speed = 10,     -- frames per sprite change
	direction_change_time = { min = 60, max = 180 },  -- frames before changing direction
	idle_time = { min = 30, max = 90 },               -- frames to stand still
	collision_radius = 4,     -- hitbox radius for building collision
	spawn_count = 120,          -- number of NPCs to spawn (larger city)
	shadow_color = 25,
	shadow_radius = 4,
	shadow_height = 2,
	shadow_x_offset = 0,
	shadow_y_offset = 6,
	-- Freaked out behavior
	scare_radius = 32,           -- distance at which NPCs get scared of player
	surprise_duration = 60,      -- frames to show surprised reaction (~1 second at 60fps)
	flee_duration = 900,         -- frames to flee (~15 seconds at 60fps)
	surprise_sprite = 135,       -- UI sprite to show above head when surprised
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
	enabled = false,  -- set to false to disable debug features
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

	-- Shadow settings
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
