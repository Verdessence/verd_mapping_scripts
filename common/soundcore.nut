// simple play global sound
// thanks eltra
::g_t_activeSounds <- {};
::g_t_soundLengths <- {
	"verdessence/omori/omori_white-space.mp3": 14.0,
};

//
/* g_func_playSoundGlobal
* str_soundName = filename
* bool_canManip = can manipulate
* bool_isMusic 	= give it the music handler #
* i_pitch 	   	= pitch
* bool_fade	   	= add fadein
* fl_duration  	= fadein duration
* bool_isLoop 	= can loop
*/

// #region g_func_playSoundGlobal function
::g_func_playSoundGlobal <- function(str_soundName = "error.wav", t_options = {}) {
    PrecacheScriptSound(str_soundName);

	local bool_canManip 	= ("canManip"		in t_options) ? t_options.canManip 		: false;
	local bool_isMusic 	= ("isMusic" 		in t_options) ? t_options.isMusic		: false;
	local i_pitch		= ("pitch"   		in t_options) ? t_options.pitch 		: 100;
	local bool_fade		= ("fade"	 		in t_options) ? t_options.fade		  	: false;
	local fl_duration	= ("fadeDuration"	in t_options) ? t_options.fadeDuration	: 2.5;
	local bool_isLoop		= ("isLoop"			in t_options) ? t_options.isLoop		: false;

	if (str_soundName in ::g_t_activeSounds) {
		local ent_oldSound = ::g_t_activeSounds[str_soundName].ent_handle;
		if (ent_oldSound != null && ent_oldSound.IsValid()) {
			EntFireByHandle(ent_oldSound, "Kill", "", 0.0, null, null);
		}
	}

    local t_sound = {
        message = (bool_isMusic ? "#" : "") + str_soundName,
        spawnflags = 49,
        health = 10,
        pitch = i_pitch,
    };

    local ent_sound = SpawnEntityFromTable("ambient_generic", t_sound);
	if (bool_canManip || bool_fade || bool_isLoop) {
		// get the local variable out of the function so we can reuse this for soundfade
		::g_t_activeSounds[str_soundName] <- {
			ent_handle = ent_sound,
			t_config = t_sound,
		};
	}
	if (bool_fade) {
		ent_sound.AcceptInput("Volume", "0", null, null);
		ent_sound.AcceptInput("PlaySound", null, null, null);
		::g_func_soundFade(str_soundName, fl_duration, true);
	} else {
		ent_sound.AcceptInput("PlaySound", null, null, null);
		if (!bool_canManip && !bool_isLoop) {
			ent_sound.Kill();
		}
	}

	if (bool_isLoop) {
		printl("bool_isLoop true");
		local fl_loopLength = ::g_t_soundLengths[str_soundName].tofloat();
		EntFireByHandle(ent_sound, "RunScriptCode", "::g_func_procSoundLoop(`" + str_soundName + "`)", fl_loopLength, null, null);
	}
}
// #endregion``
// i felt like making the in out be false (fadeout) and true (fadein) respectively
::g_func_soundFade <- function(str_soundName = "error.wav", fl_duration = 2.5, bool_outIn = false) {

	local t_state = ::g_t_activeSounds[str_soundName];
	local ent_sound = t_state.ent_handle;

	if (ent_sound == null || !ent_sound.IsValid()) {
		delete ::g_t_activeSounds[str_soundName];
		return
	}

	local i_steps = 20;
	local fl_stepTime = fl_duration / i_steps.tofloat();
	local fl_maxVol = t_state.t_config.health.tofloat();
	local fl_startVol = bool_outIn ? 0.0 : fl_maxVol;
	local fl_endVol = bool_outIn ? fl_maxVol : 0.0;
	local fl_volStep = (fl_endVol - fl_startVol) / i_steps.tofloat();

	if (bool_outIn) {
		ent_sound.AcceptInput("Volume", fl_startVol.tostring(), null, null);
	}
	::g_func_procSoundFade(str_soundName, fl_startVol, fl_volStep, i_steps, fl_stepTime);
}
::g_func_procSoundFade <- function(str_soundName, fl_curVol, fl_volStep, i_stepRemain, fl_stepTime) {
	if (!(str_soundName in ::g_t_activeSounds)) return;

	local ent_sound = ::g_t_activeSounds[str_soundName].ent_handle;
	if (i_stepRemain <= 0) {
		if (fl_volStep < 0) {
			ent_sound.AcceptInput("StopSound", null, null, null);
			ent_sound.Kill();
		}
		return;
	}

	fl_curVol += fl_volStep;

	if (fl_curVol < 0.0) fl_curVol = 0.0;
	if (fl_curVol > 10.0) fl_curVol = 10.0;

	ent_sound.AcceptInput("Volume", fl_curVol.tostring(), null, null);
	local str_command = "::g_func_procSoundFade(`" + str_soundName + "`, " + fl_curVol + ", " + fl_volStep + ", " + (i_stepRemain - 1) + ", " + fl_stepTime + ")";
	EntFireByHandle(ent_sound, "RunScriptCode", str_command, fl_stepTime, null, null);
	// printl("current volume: " + fl_curVol + "\n volume step: " + fl_volStep + "\n steps remaining: " + i_stepRemain + "\n step time: " + fl_stepTime);
}
::g_func_procSoundLoop <- function(str_soundName) {
	local ent_sound = ::g_t_activeSounds[str_soundName].ent_handle;
	local fl_loopLength = ::g_t_soundLengths[str_soundName].tofloat();

	if (ent_sound == null || !ent_sound.IsValid()) {
		delete ::g_t_activeSounds[str_soundName];
		return;
	}

	ent_sound.AcceptInput("PlaySound", null, null, null);
	printl("looping");
	EntFireByHandle(ent_sound, "RunScriptCode", "::g_func_procSoundLoop(`" + str_soundName + "`)", fl_loopLength, null, null);
}
