// dialogue_text.nut -- v2 dialogue driver, fully namespaced (Dlg*) so it
// can coexist with screenoverlay_text.nut / the animation framework.
// Requires dialogue_boxes.nut (generated) and an antenna quad model whose
// material IS screenspace_font_line (see note at bottom).
IncludeScript("verd/omori/dialogue_boxes.nut");   // ::DialogueBoxes

const DLG_MATERIAL = "effects/shaders/screenspace_font_line";

::DlgVars <- [ "$c0_y","$c0_z","$c0_w",           // box position/scale
               "$c1_x","$c1_y","$c1_z","$c1_w" ]; // row0, reveal, rows, pitch

::DlgCtl <- { bank = null, quad = null, typer = null };

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
}

::DlgInit <- function(pos) {
	if (::DlgAlive()) return;
	::DlgReset();
	local bank = {};
	local quad = SpawnEntityFromTable("prop_dynamic", {
		targetname = "dlg-antenna",
		model = "models/verd/omori/text_quad.mdl",
		origin = pos, solid = 0,
		angles = "0 180 180"
	});
	if (!quad) { printl("[dlg] antenna model failed to spawn -- not precached?"); return; }
	quad.SetModelScale(1.0, 0.0);
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
	for (local i = 1, player; i <= MaxClients().tointeger(); i++)
		if (player = PlayerInstanceFromIndex(i))
			player.SetScriptOverlayMaterial(DLG_MATERIAL);
}

::DlgSetVar <- function(v, value) {
	if (!::DlgAlive()) { printl("[dlg] not initialized -- call ::DlgInit(Vector(...)) first"); return false; }
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

::TypeBox <- function(id, fl_cps = 15.0) {
	if (!(id in ::DialogueBoxes)) { printl("[dlg] unknown box: " + id); return; }
	::DlgStopTyping();
	local b = ::DialogueBoxes[id];
	if (!::DlgSetVar("$c1_x", b.row0)) return;
	::DlgSetVar("$c1_z", b.rows);
	::DlgSetVar("$c1_y", -1);
	local relay = SpawnEntityFromTable("logic_relay", { targetname = "dlg-typer" });
	::DlgCtl.typer = { relay = relay, steps = b.steps, i = 0, interval = 1.0/fl_cps };
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
	t.i++;
	EntFireByHandle(t.relay, "RunScriptCode", "::DlgTypeTick()", t.interval, null, null);
}
::DlgStopTyping <- function() {
	if (::DlgCtl.typer) {
		EntFireByHandle(::DlgCtl.typer.relay, "Kill", "", 0.0, null, null);
		::DlgCtl.typer = null;
	}
}

// Usage:
//   script ::DlgInit(Vector(x, y, z))
//   script ::ShowBox("test")
//   script ::TypeBox("test", 15)
//
// ANTENNA MATERIAL NOTE: the proxy only fires for the material the quad
// RENDERS. text_quad.mdl currently references screenspace_font_poc (v1).
// Either edit the material name in text_quad_ref.smd to
// screenspace_font_line and recompile, or add a $texturegroup with both
// and set the quad's skin. Without this, DlgSetVar fires but nothing
// reaches the shader -- the v1 symptom you already know by heart.
