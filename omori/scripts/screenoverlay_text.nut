// screenoverlay_text.nut
// VScript -> screenspace_font_poc shader bridge.
//
// THE CHANNEL: screenspace_general re-reads $c0_x..$c3_w from the material
// every draw (DYNAMIC_STATE in screenspace_general.cpp), so anything that
// can write material vars at runtime has full control of the shader. The
// writer is material_modify_control (MMC): one entity drives ONE variable
// (its `materialVar` keyvalue), input SetMaterialVar sets the value. We
// spawn a bank of them, one per constant.
//
// THE EXPERIMENT (read before trusting this): the MaterialModify proxy
// resolves MMC entities *parented to the entity being rendered*. A script
// overlay's "rendering entity" is plausibly the player, so we parent the
// bank to the player. This is the one undocumented link in the chain --
// if text never changes, this is what failed, and the fallback is your
// existing SequenceAnim pattern (VMT swapping) with pre-packed variants.
//
// The VMT must contain:  Proxies { MaterialModify {} }
// (keep the Equals/$fix_fb proxy too; proxies stack)

IncludeScript("verd/omori/font_metrics.nut"); // ::FontGlyphs

const TEXT_MATERIAL = "effects/shaders/screenspace_font_poc";
const MAX_GLYPHS    = 12;
const SPACE_ADV     = 5;   // glyph px

// $c0_x = aspect, $c0_y/z = origin, $c0_w = scale, c1..c3 = packed glyphs
::TextVars <- [
	"$c1_x","$c1_y","$c1_z","$c1_w",
	"$c2_x","$c2_y","$c2_z","$c2_w",
	"$c3_x","$c3_y","$c3_z","$c3_w",
	"$c0_y","$c0_z","$c0_w"          // position + scale ride the same bank
];

// ---------------------------------------------------------------------
// Packer: string -> array of MAX_GLYPHS floats (the prefix sum lives here)
// Returns { slots = [...], pen = [xoff of each glyph], total = advance }
// ---------------------------------------------------------------------
::PackText <- function(str_text) {
	local slots = array(MAX_GLYPHS, 0);
	local pens  = [];
	local pen = 0, n = 0;
	foreach (ch in str_text) {
		local c = ch.tochar();
		if (c == " ") { pen += SPACE_ADV; continue; }
		if (!(c in ::FontGlyphs)) { printl("[text] no glyph for '" + c + "'"); continue; }
		if (n >= MAX_GLYPHS) { printl("[text] truncated at " + MAX_GLYPHS + " glyphs"); break; }
		local g = ::FontGlyphs[c];             // [cell, advance]
		slots[n] = g[1]*262144 + pen*256 + g[0];
		pens.append(pen);
		pen += g[1];
		n++;
	}
	return { slots = slots, pens = pens, total = pen };
}

// ---------------------------------------------------------------------
// MMC bank: one material_modify_control per shader constant
// ---------------------------------------------------------------------
::TextCtl <- { bank = null, typer = null };

::TextInit <- function() {
	if (::TextCtl.bank) return;
	::TextCtl.bank = {};
	local player = null;
	for (local i = 1; i <= MaxClients().tointeger(); i++)
		if (player = PlayerInstanceFromIndex(i)) break;   // POC: first player

	foreach (v in ::TextVars) {
		local mmc = SpawnEntityFromTable("material_modify_control", {
			targetname   = "textvar" + v,
			materialName = TEXT_MATERIAL,
			materialVar  = v
		});
		if (player) {
			mmc.AcceptInput("SetParent", "!activator", player, player);
		}
		::TextCtl.bank[v] <- mmc;
	}

	// activate the overlay ourselves -- SetText into an inactive overlay
	// renders nothing and proves nothing
	if (player) player.SetScriptOverlayMaterial(TEXT_MATERIAL);

	// prime EVERY owned var with the VMT defaults so an un-fired MMC can
	// never stomp position/scale to zero (scale 0 = divide-by-zero = blank)
	::SetVar("$c0_y", 100);
	::SetVar("$c0_z", 480);
	::SetVar("$c0_w", 6);
}

::SetVar <- function(v, value) {
	local mmc = ::TextCtl.bank[v];
	EntFireByHandle(mmc, "SetMaterialVar", value.tostring(), 0.0, null, null);
}

// ---------------------------------------------------------------------
// DONOR / "ANTENNA" INIT -- shared-dialogue architecture.
// Data path and display path are split: a speck-sized quad exists only
// so the proxy renders and writes the MMC values into the SHARED
// IMaterial each frame; every player displays that same material as a
// screen overlay (per-player, screen-locked, zero extra entities).
// World pass draws before overlay pass, so vars are current same-frame.
//
// The whole job is keeping the donor rendered on every client:
//  - SetModelScale makes the triangles sub-pixel (invisible in practice)
//  - SetSize inflates its cull bounds so no client ever frustum-culls it
// Verify once with scale 1.0 (visible quad + working SetVar poke), then
// shrink. If distant clients ever show stale text, the donor left their
// PVS: place it centrally, or one per dialogue area.
// ---------------------------------------------------------------------
::TextReset <- function() {
	::StopTyping();
	if (::TextCtl.bank)
		foreach (v, mmc in ::TextCtl.bank)
			if (mmc && mmc.IsValid()) mmc.Kill();
	if (("quad" in ::TextCtl) && ::TextCtl.quad && ::TextCtl.quad.IsValid())
		::TextCtl.quad.Kill();
	::TextCtl.bank = null;
}

::TextBankAlive <- function() {
	if (!::TextCtl.bank) return false;
	foreach (v, mmc in ::TextCtl.bank)
		if (!mmc || !mmc.IsValid()) return false;   // stale from round restart / aborted init
	return true;
}

::TextInitDonor <- function(pos) {
	if (::TextBankAlive()) return;
	::TextReset();                       // clear any half-dead state first
	local bank = {};                     // build locally; publish only on success

	local quad = SpawnEntityFromTable("prop_dynamic", {
		targetname = "text-antenna",
		model      = "models/verd/omori/text_quad.mdl",
		origin     = pos,
		solid      = 0
	});
	quad.SetModelScale(0.01, 0.0);
	quad.SetSize(Vector(-16000,-16000,-16000), Vector(16000,16000,16000));

	foreach (v in ::TextVars) {
		local mmc = SpawnEntityFromTable("material_modify_control", {
			targetname   = "textvar" + v,
			materialName = TEXT_MATERIAL,
			materialVar  = v,
			origin       = pos
		});
		mmc.AcceptInput("SetParent", "!activator", quad, quad);
		bank[v] <- mmc;
	}

	::TextCtl.quad <- quad;
	::TextCtl.bank = bank;               // publish: system is now officially up

	::SetVar("$c0_y", 100);
	::SetVar("$c0_z", 480);
	::SetVar("$c0_w", 6);

	// display: the overlay every player already gets
	for (local i = 1, player; i <= MaxClients().tointeger(); i++)
		if (player = PlayerInstanceFromIndex(i))
			player.SetScriptOverlayMaterial(TEXT_MATERIAL);
}

// ---------------------------------------------------------------------
// (previous) ENTITY-BASED INIT -- world-quad display, kept for reference
// ---------------------------------------------------------------------
::TextInitEntity <- function(pos) {
	if (::TextCtl.bank) return;
	::TextCtl.bank = {};

	local quad = SpawnEntityFromTable("prop_dynamic", {
		targetname = "text-quad",
		model      = "models/verd/omori/text_quad.mdl",
		origin     = pos,
		solid      = 0
	});
	::TextCtl.quad <- quad;

	foreach (v in ::TextVars) {
		local mmc = SpawnEntityFromTable("material_modify_control", {
			targetname   = "textvar" + v,
			materialName = TEXT_MATERIAL,
			materialVar  = v,
			origin       = pos
		});
		mmc.AcceptInput("SetParent", "!activator", quad, quad);
		::TextCtl.bank[v] <- mmc;
	}

	::SetVar("$c0_y", 100);
	::SetVar("$c0_z", 480);
	::SetVar("$c0_w", 6);
}

// ---------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------
::SetText <- function(str_text) {
	::TextInit();
	local p = ::PackText(str_text);
	for (local i = 0; i < MAX_GLYPHS; i++)
		::SetVar(::TextVars[i], p.slots[i]);
	return p;
}

::SetTextPos <- function(x, y, scale) {   // virtual-canvas px
	::TextInit();
	::SetVar("$c0_y", x);
	::SetVar("$c0_z", y);
	::SetVar("$c0_w", scale);
}

// Typewriter: reveal one glyph per tick by sending a progressively longer
// packed string. No shader changes, no reveal constant -- glyph slots that
// are 0 simply never render, so "typing" = repacking with one more glyph.
::TypeText <- function(str_text, fl_cps = 12.0) {
	::TextInit();
	::StopTyping();
	local full = ::PackText(str_text);
	local n = 0;
	foreach (s in full.slots) if (s != 0) n++;

	local relay = SpawnEntityFromTable("logic_relay", { targetname = "text-typer" });
	::TextCtl.typer = { relay = relay, slots = full.slots, n = n, i = 0,
	                    interval = 1.0 / fl_cps };

	// blank first
	for (local i = 0; i < MAX_GLYPHS; i++) ::SetVar(::TextVars[i], 0);
	::TypeTick();
}

::TypeTick <- function() {
	local t = ::TextCtl.typer;
	if (!t) return;
	if (t.i >= t.n) { ::TextCtl.typer = null; EntFireByHandle(t.relay, "Kill", "", 0.1, null, null); return; }
	::SetVar(::TextVars[t.i], t.slots[t.i]);   // reveal next glyph
	t.i++;
	EntFireByHandle(t.relay, "RunScriptCode", "::TypeTick()", t.interval, null, null);
}

::StopTyping <- function() {
	if (::TextCtl.typer) {
		EntFireByHandle(::TextCtl.typer.relay, "Kill", "", 0.0, null, null);
		::TextCtl.typer = null;
	}
}

// Usage:
//   script ::SetText("Hello World")
//   script ::SetTextPos(100, 480, 6)
//   script ::TypeText("WELCOME TO WHITE SPACE", 10)
