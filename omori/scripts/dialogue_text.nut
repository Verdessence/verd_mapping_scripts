// dialogue_text.nut -- v2 dialogue driver, fully namespaced (Dlg*) so it
// can coexist with screenoverlay_text.nut / the animation framework.
// Requires dialogue_boxes.nut (generated) and an antenna quad model whose
// material IS screenspace_font_line (see note at bottom).
IncludeScript("verd/omori/dialogue_boxes.nut");   // ::DialogueBoxes

const DLG_MATERIAL = "effects/shaders/screenspace_font_line";

::DlgVars <- [ "$c0_y","$c0_z","$c0_w",           // box position/scale
               "$c1_x","$c1_y","$c1_z","$c1_w" ]; // row0, reveal, rows, pitch

::DlgCtl <- { bank = null, quad = null, typer = null, pos = null };

// Typewriter defaults. Override per box via TypeBox(id, cps, { ... }).
//   blip      : sound played per revealed glyph (null = silent)
//   blipEvery : play on every Nth glyph (1 = every glyph, OMORI-style)
//   pitch     : base pitch; pitchJitter adds +/- random cents for life
::DlgCfg <- {
	blip        = "verdessence/omori/sfx/omori_sys-text.wav",
	blipEvery   = 1,
	pitch       = 100,
	pitchJitter = 6
};

::DlgAlive <- function() {
	if (!::DlgCtl.bank) return false;
	foreach (v, mmc in ::DlgCtl.bank)
		if (!mmc || !mmc.IsValid()) return false;
	return true;
}

::DlgReset <- function() {
	::DlgStopTyping();
	if (::DlgCtl.bank)
		foreach (v, mmc in ::DlgCtl.bank)
			if (mmc && mmc.IsValid()) mmc.Kill();
	if (::DlgCtl.quad && ::DlgCtl.quad.IsValid()) ::DlgCtl.quad.Kill();
	::DlgCtl.bank = null; ::DlgCtl.quad = null;
	for (local i = 1, player; i <= MaxClients().tointeger(); i++)
		if (player = PlayerInstanceFromIndex(i))
			player.SetScriptOverlayMaterial("");
}

::DlgInit <- function(pos) {
	::DlgCtl.pos = pos;                       // remembered for auto re-init
	if (::DlgAlive()) return;
	::DlgReset();
	local bank = {};
	local quad = SpawnEntityFromTable("prop_dynamic", {
		targetname = "dlg-antenna",
		model = "models/verd/omori/text_quad.mdl",
		origin = pos, solid = 0
	});
	if (!quad) { printl("[dlg] antenna model failed to spawn -- not precached?"); return; }
	quad.SetModelScale(0.01, 0.0);
	quad.SetSize(Vector(-16000,-16000,-16000), Vector(16000,16000,16000));
	foreach (v in ::DlgVars) {
		local mmc = SpawnEntityFromTable("material_modify_control", {
			targetname = "dlgvar" + v,
			materialName = DLG_MATERIAL, materialVar = v, origin = pos
		});
		mmc.AcceptInput("SetParent", "!activator", quad, quad);
		bank[v] <- mmc;
	}
	::DlgCtl.quad = quad;
	::DlgCtl.bank = bank;                     // publish only on full success
	::DlgApplyOverlay();
	if (::DlgCfg.blip) PrecacheScriptSound(::DlgCfg.blip);   // same call soundcore uses
	// PRIME: material vars persist across rounds, so whatever was showing
	// at round end is still painted. Idle state in production = hidden.
	::DlgSetVar("$c1_x", 1);
	::DlgSetVar("$c1_z", 3);
	::DlgSetVar("$c1_y", -1);
}

::DlgApplyOverlay <- function() {
	for (local i = 1, player; i <= MaxClients().tointeger(); i++)
		if (player = PlayerInstanceFromIndex(i))
			player.SetScriptOverlayMaterial(DLG_MATERIAL);
}

// Auto-recovery: round restart kills the antenna + MMC bank (script-spawned
// entities do not survive), so any API call after a restart transparently
// rebuilds at the remembered position instead of refusing.
::DlgEnsure <- function() {
	if (::DlgAlive()) return true;
	if (!::DlgCtl.pos) { printl("[dlg] not initialized -- call ::DlgInit(Vector(...)) once"); return false; }
	::DlgInit(::DlgCtl.pos);
	return ::DlgAlive();
}

::DlgSetVar <- function(v, value) {
	if (!::DlgEnsure()) return false;
	EntFireByHandle(::DlgCtl.bank[v], "SetMaterialVar", value.tostring(), 0.0, null, null);
	return true;
}

// ------------------------------------------------------------ public API
::ShowBox <- function(id) {
	if (!(id in ::DialogueBoxes)) { printl("[dlg] unknown box: " + id); return; }
	local b = ::DialogueBoxes[id];
	if (!::DlgSetVar("$c1_x", b.row0)) return;
	::DlgSetVar("$c1_z", b.rows);
	::DlgSetVar("$c1_y", 999999);
}
::HideBox <- function() { ::DlgSetVar("$c1_y", -1); }

::DlgBlip <- function(t) {
	if (!t.blip) return;
	if (t.i % t.blipEvery != 0) return;
	local pitch = t.pitch + (t.pitchJitter > 0 ? RandomInt(-t.pitchJitter, t.pitchJitter) : 0);
	for (local i = 1, player; i <= MaxClients().tointeger(); i++)
		if (player = PlayerInstanceFromIndex(i))
			EmitSoundEx({ sound_name = t.blip, entity = player, pitch = pitch,
			              sound_level = 0, channel = 0 });   // level 0 = SNDLVL_NONE (global)
}

::TypeBox <- function(id, fl_cps = 15.0, opts = {}) {
	if (!(id in ::DialogueBoxes)) { printl("[dlg] unknown box: " + id); return; }
	::DlgStopTyping();
	local b = ::DialogueBoxes[id];
	if (!::DlgSetVar("$c1_x", b.row0)) return;
	::DlgSetVar("$c1_z", b.rows);
	::DlgSetVar("$c1_y", -1);
	local relay = SpawnEntityFromTable("logic_relay", { targetname = "dlg-typer" });
	::DlgCtl.typer = {
		relay = relay, steps = b.steps, i = 0, interval = 1.0/fl_cps,
		blip        = ("blip"        in opts) ? opts.blip        : ::DlgCfg.blip,
		blipEvery   = ("blipEvery"   in opts) ? opts.blipEvery   : ::DlgCfg.blipEvery,
		pitch       = ("pitch"       in opts) ? opts.pitch       : ::DlgCfg.pitch,
		pitchJitter = ("pitchJitter" in opts) ? opts.pitchJitter : ::DlgCfg.pitchJitter
	};
	if (::DlgCtl.typer.blip) PrecacheScriptSound(::DlgCtl.typer.blip);
	::DlgTypeTick();
}
::DlgTypeTick <- function() {
	local t = ::DlgCtl.typer;
	if (!t) return;
	if (t.i >= t.steps.len()) {
		::DlgCtl.typer = null;
		EntFireByHandle(t.relay, "Kill", "", 0.1, null, null);
		return;
	}
	::DlgSetVar("$c1_y", t.steps[t.i]);
	::DlgBlip(t);
	t.i++;
	EntFireByHandle(t.relay, "RunScriptCode", "::DlgTypeTick()", t.interval, null, null);
}
::SkipTyping <- function() {               // reveal the rest instantly
	local t = ::DlgCtl.typer;
	if (!t) return;
	::DlgStopTyping();
	::DlgSetVar("$c1_y", t.steps[t.steps.len() - 1]);
}

::DlgStopTyping <- function() {
	if (::DlgCtl.typer) {
		EntFireByHandle(::DlgCtl.typer.relay, "Kill", "", 0.0, null, null);
		::DlgCtl.typer = null;
	}
}

// ------------------------------------------------------------ lifecycle
// Round end: hide text + drop the overlay so nothing stays painted, and
// release the (about-to-die) entities. Round start: rebuild if a position
// is known. If your map has a logic_script, calling ::DlgInit from its
// OnPostSpawn is an equally valid (and simpler) alternative to the events.
::h_coreEvents <- {
	function OnGameEvent_round_end(params)   { ::HideBox(); ::DlgReset(); }
	function OnGameEvent_round_start(params) { if (::DlgCtl.pos) ::DlgInit(::DlgCtl.pos); }
	function OnGameEvent_player_spawn(params) {   // late joiners get the overlay
		if (::DlgAlive()) {
			local p = GetPlayerFromUserID(params.userid);
			if (p) p.SetScriptOverlayMaterial(DLG_MATERIAL);
		}
	}
}
__CollectGameEventCallbacks(h_coreEvents);

// Usage:
//   script ::DlgInit(Vector(x, y, z))
//   script ::ShowBox("test")
//   script ::TypeBox("test", 15)
//   script ::TypeBox("test", 15, { blip = "verdessence/omori/text_blip_mari.wav", pitch = 110 })
//   script ::TypeBox("test", 15, { blip = null })      // silent
//   script ::SkipTyping()
//
// ANTENNA MATERIAL NOTE: the proxy only fires for the material the quad
// RENDERS. text_quad.mdl currently references screenspace_font_poc (v1).
// Either edit the material name in text_quad_ref.smd to
// screenspace_font_line and recompile, or add a $texturegroup with both
// and set the quad's skin. Without this, DlgSetVar fires but nothing
// reaches the shader -- the v1 symptom you already know by heart.
