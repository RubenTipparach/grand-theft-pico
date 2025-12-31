--[[pod_format="raw"]]
-- music.lua - Music manager for Grand Theft Chicken

-- ============================================
-- MUSIC STATE
-- ============================================

music_manager = {
	current_track = nil,      -- currently playing track name ("menu", "intro", "playing")
	loaded_file = nil,        -- currently loaded sfx file path
	is_playing = false,
}

-- ============================================
-- MUSIC FUNCTIONS
-- ============================================

-- Load and play a music track by name
-- track_name: "menu", "intro", or "playing"
function play_music(track_name)
	local cfg = MUSIC_CONFIG
	local track = cfg[track_name]

	if not track then
		printh("Music: Unknown track name: " .. tostring(track_name))
		return
	end

	-- Don't reload if already playing this track
	if music_manager.current_track == track_name and music_manager.is_playing then
		return
	end

	-- Stop current music first
	if music_manager.is_playing then
		stop_music(false)  -- no fade for quick switch
	end

	-- Load the SFX file into memory
	local sfx_data = fetch(track.sfx_file)
	if sfx_data then
		sfx_data:poke(cfg.memory_address)
		music_manager.loaded_file = track.sfx_file

		-- Set music volume
		poke(0x5539, cfg.volume)

		-- Play the music with fade-in
		music(track.pattern, cfg.fade_in_ms, nil, cfg.memory_address)

		music_manager.current_track = track_name
		music_manager.is_playing = true

		printh("Music: Playing " .. track_name .. " from " .. track.sfx_file)
	else
		printh("Music: Failed to load " .. track.sfx_file)
	end
end

-- Stop music playback
function stop_music(fade)
	if not music_manager.is_playing then
		return
	end

	local cfg = MUSIC_CONFIG
	local fade_ms = fade and cfg.fade_out_ms or 0

	-- Stop music (pattern -1 stops playback)
	music(-1, fade_ms)

	music_manager.is_playing = false
	-- Don't clear current_track so we know what was playing

	printh("Music: Stopped" .. (fade and " with fade" or ""))
end

-- Update music based on current game state
-- Call this when game_state changes
function update_music_for_state(new_state)
	if new_state == "menu" then
		play_music("menu")
	elseif new_state == "intro" then
		play_music("intro")
	elseif new_state == "playing" then
		play_music("playing")
	else
		-- Unknown state, stop music
		stop_music(true)
	end
end

-- Set music volume (0.0 to 1.0)
function set_music_volume(volume)
	-- Convert 0-1 to 0x00-0x40
	local vol = flr(volume * 0x40)
	vol = max(0, min(0x40, vol))
	poke(0x5539, vol)
end

-- Get current music volume (0.0 to 1.0)
function get_music_volume()
	return peek(0x5539) / 0x40
end
