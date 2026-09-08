// simple play global sound
// thanks eltra
::h_activeSound <- {};
::libSoundLength <- {
	"verdessence/omori/omori_white-space.mp3": 14.0,
};

//
/* PlaySoundGlobal
* strSoundName 	= filename
* bool_canManip = can manipulate
* bool_isMusic 	= give it the music handler #
* flPitch 	   	= pitch
* bool_fade	   	= add fadein
* fl_duration  	= fadein duration
* bool_isLoop 	= can loop
*/

// #region PlaySoundGlobal function
::PlaySoundGlobal <- function(strSoundName = "error.wav", options = {}) {
    PrecacheScriptSound(strSoundName);
	
	local bool_canManip 	= ("canManip"		in options) ? options.canManip 		: false;
	local bool_isMusic 	= ("isMusic" 		in options) ? options.isMusic		: false;
	local flPitch		= ("pitch"   		in options) ? options.pitch 		: 100;
	local bool_fade		= ("fade"	 		in options) ? options.fade		  	: false;
	local fl_duration	= ("fadeDuration"	in options) ? options.fadeDuration	: 2.5;
	local bool_isLoop		= ("isLoop"			in options) ? options.isLoop		: false;
	
	if (strSoundName in ::h_activeSound) {
		local h_oldSound = ::h_activeSound[strSoundName].handle;
		if ( h_oldSound != null && h_oldSound.IsValid()) {
			EntFireByHandle(h_oldSound, "Kill", "", 0.0, null, null);
		}
	}

    local tSoundTable = {
        message = (bool_isMusic ? "#" : "") + strSoundName,
        spawnflags = 49,
        health = 10,
        pitch = flPitch,
    };

    local hSound = SpawnEntityFromTable("ambient_generic", tSoundTable);
	if (bool_canManip || bool_fade || bool_isLoop) {
		// get the local variable out of the function so we can reuse this for soundfade
		::h_activeSound[strSoundName] <- {
			handle = hSound,
			config = tSoundTable,
		};
	}
	if (bool_fade) {
		hSound.AcceptInput("Volume", "0", null, null);
		hSound.AcceptInput("PlaySound", null, null, null);
		::SoundFade(strSoundName, fl_duration, true);
	} else {
		hSound.AcceptInput("PlaySound", null, null, null);
		if (!bool_canManip && !bool_isLoop) {
			EntFireByHandle(hSound, "Kill", null, 0.1, null, null);
		}
	}

	if (bool_isLoop) {
		printl("bool_isLoop true");
		local fl_loopLength = ::libSoundLength[strSoundName].tofloat();
		EntFireByHandle(hSound, "RunScriptCode", "::ProcSoundLoop(`" + strSoundName + "`)", fl_loopLength, null, null);
	}
}
// #endregion
// i felt like making the in out be false (fadeout) and true (fadein) respectively
::SoundFade <- function(strSoundName = "error.wav", fl_duration = 2.5, bool_outIn = false) {

	local state = ::h_activeSound[strSoundName];
	local hSound = state.handle;

	if (hSound == null || !hSound.IsValid()) {
		delete ::h_activeSound[strSoundName];
		return
	}

	local i_steps = 20;
	local fl_stepTime = fl_duration / i_steps.tofloat();
	local fl_maxVol = state.config.health.tofloat();
	local fl_startVol = bool_outIn ? 0.0 : fl_maxVol;
	local fl_endVol = bool_outIn ? fl_maxVol : 0.0;
	local fl_volStep = (fl_endVol - fl_startVol) / i_steps.tofloat();

	if (bool_outIn) {
		hSound.AcceptInput("Volume", fl_startVol.tostring(), null, null);
	}
	::ProcSoundFade(strSoundName, fl_startVol, fl_volStep, i_steps, fl_stepTime);
}
::ProcSoundFade <- function(strSoundName, fl_curVol, fl_volStep, i_stepRemain, fl_stepTime) {
	if (!(strSoundName in ::h_activeSound)) return;

	local hSound = ::h_activeSound[strSoundName].handle;
	if (i_stepRemain <= 0) {
		if (fl_volStep < 0) {
			hSound.AcceptInput("StopSound", null, null, null);
			hSound.Kill();
		}
		return;
	}

	fl_curVol += fl_volStep;

	if (fl_curVol < 0.0) fl_curVol = 0.0;
	if (fl_curVol > 10.0) fl_curVol = 10.0;

	hSound.AcceptInput("Volume", fl_curVol.tostring(), null, null);
	local str_cmd = "::ProcSoundFade(`" + strSoundName + "`, " + fl_curVol + ", " + fl_volStep + ", " + (i_stepRemain - 1) + ", " + fl_stepTime + ")";
	EntFireByHandle(hSound, "RunScriptCode", str_cmd, fl_stepTime, null, null);
	// printl("current volume: " + fl_curVol + "\n volume step: " + fl_volStep + "\n steps remaining: " + i_stepRemain + "\n step time: " + fl_stepTime);
}
::ProcSoundLoop <- function(strSoundName) {
	local hSound = ::h_activeSound[strSoundName].handle;
	local fl_loopLength = ::libSoundLength[strSoundName].tofloat();

	if (hSound == null || !hSound.IsValid()) {
		delete ::h_activeSound[strSoundName];
		return;
	}

	hSound.AcceptInput("PlaySound", null, null, null);
	printl("looping");
	EntFireByHandle(hSound, "RunScriptCode", "::ProcSoundLoop(`" + strSoundName + "`)", fl_loopLength, null, null);
}