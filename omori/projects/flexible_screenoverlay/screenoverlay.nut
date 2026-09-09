// Screen Overlay to support frame reuse and variable framerate
// ...i hope

IncludeScript("verd/omori/screenoverlay_repo.nut");
::i_maxPlayers <- MaxClients().tointeger()

::CurrentAnim <- {};

::PlayAnim <- function(anim_type, anim_name, i_forceFps = null, b_isLoop = false) {
	foreach (k, v in ::CurrentAnim) {
		local idx_split = k.find(" : ");
		local old_animType = k.slice(0, idx_split);
		local old_animName = k.slice(idx_split + 3);
		::StopAnim(old_animType, old_animName);
	}
	
	if (!(anim_type in ::AnimLib) || !(anim_name in ::AnimLib[anim_type])) {
		printl(anim_type + " animation not found [" + anim_name + "]");
		return
	}
	
	local t_profile = ::AnimLib[anim_type][anim_name];
	local h_key = anim_type + " : " + anim_name;
	
	if (!("str_material" in t_profile)) {
		printl("material path may be incorrect or does not exist: " + h_key + "]");
		return;
	}
	
	/* 
	this was supposed to initialize the material_modify_control, but we're doing this
	with multiple vmts, so we can manipulate the frames and the fps
	*/
	local str_animPath = t_profile.str_material;
	local idx_prefix = str_animPath.find("materials/");
	if (idx_prefix != null && idx_prefix == 0) {
		str_animPath = str_animPath.slice(10);
	}
	local idx_suffix = str_animPath.find(".vmt");
	if (idx_suffix != null) {
		str_animPath = str_animPath.slice(0, idx_suffix);
	}
	
	// sequence duration so i can time this with entfire
	local fl_duration = 0.0;
	local b_hasMap = ("t_fps" in t_profile);
	
	for (local i = 0; i < t_profile.t_seq.len(); i++) {
		local i_frameIdx = t_profile.t_seq[i];
		local def_fps = 3.0;
		
		if (b_hasMap) {
			foreach (i_entry in t_profile.t_fps) {
				if (i_frameIdx >= i_entry.i_frame) {
					def_fps = i_entry.i_mapFps.tofloat();
				}
			}
		}
		if (i_forceFps != null) {
			local p_fps = i_forceFps.tofloat();
			if (p_fps > 0) {
				def_fps = p_fps;
			}
		}
		
		fl_duration += (1.0 / def_fps);
	}
	printl("[" + h_key + "] approx duration: " + fl_duration + "s");
	
	local t_loop = { targetname = "overlay-loop-" + anim_name };
	local ent_loop = SpawnEntityFromTable("logic_relay", t_loop);
	
	::CurrentAnim[h_key] <- {
		t_profile = t_profile,
		t_seq = t_profile.t_seq,
		i_index = 0,
		i_fps = i_forceFps,
		b_isLoop = b_isLoop,
		b_active = true,
		str_path = str_animPath,
		ent_loop = ent_loop,
	}
	
	::SequenceAnim(h_key);
}

::SequenceAnim <- function(h_key) {
	if (!(h_key in ::CurrentAnim)) return;
	
	local state = ::CurrentAnim[h_key];
	if (!state.b_active) return;
	
	if (state.i_index >= state.t_seq.len()) {
		if (state.b_isLoop) {
			state.i_index = 0;
		} else {
			local idx_split = h_key.find(" : ");
			local a_type = h_key.slice(0, idx_split);
			local a_name = h_key.slice(idx_split + 3);
			::StopAnim(a_type, a_name);
			return;
		}
	}
	
	local i_nextFrame = state.t_seq[state.i_index];
	local def_fps = 3.0;
	
	if ("t_fps" in state.t_profile) {
		foreach (i_entry in state.t_profile.t_fps) {
			if (i_nextFrame >= i_entry.i_frame) {
				def_fps = i_entry.i_mapFps.tofloat();
			}
		}
	}
	
	if (state.i_fps != null) {
		local p_fps = state.i_fps.tofloat();
		if (p_fps > 0) {
			def_fps = p_fps;
		}
	}
	local fl_fpsInterval = 1.0 / def_fps;
	local str_frameMat = state.str_path + "_" + i_nextFrame;
	
	// setup player handle
	for (local i = 1, player; i <= i_maxPlayers; i++)
		if (player = PlayerInstanceFromIndex(i))
	// thanks berke and quintuple 1
	player.SetScriptOverlayMaterial(str_frameMat);
	// printl("current frame: " + i_nextFrame + " current fps: " + def_fps);
	state.i_index = state.i_index + 1;

	EntFireByHandle(state.ent_loop, "RunScriptCode", "::SequenceAnim(\"" + h_key + "\")", fl_fpsInterval, null, null);
}
::StopAnim <- function(anim_type, anim_name) {
	local h_key = anim_type + " : " + anim_name;
	if (h_key in ::CurrentAnim) {
		::CurrentAnim[h_key].b_active = false;
		EntFireByHandle(::CurrentAnim[h_key].ent_loop, "Kill", "", 0.5, null, null);
		delete ::CurrentAnim[h_key];
	}
	for (local i = 1, player; i <= i_maxPlayers; i++)
		if (player = PlayerInstanceFromIndex(i))
	player.SetScriptOverlayMaterial("");
}