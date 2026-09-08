// warmup
// ...what do you expect? i like to keep things consistent

// add chapter double check
if (!("warmup" in gl_t_chapterRepo)) {
	gl_t_chapterRepo["warmup"] <- {};
	
	gl_t_chapterRepo["warmup"]["warmup"] <- function() {
		// warmup exclusive stuff
		local t_warmupOverlay = {
			targetname = "warmup-overlay"
			overlayname1 = "verdessence/assets/omori/warmup",
		};
		local ent_warmupOverlay = SpawnEntityFromTable("env_screenoverlay", t_warmupOverlay);
		local ent_vscriptCore   = Entities.FindByName(null, "core-vscript");
		
		// entity i/o
		printl("warmup");
		if (ent_warmupOverlay) {
			EntFire("warmup-overlay", "StartOverlays", null, 3.0, null);
			EntFire("warmup-overlay", "StopOverlays", null, 33.0, null);
			EntFire("warmup-overlay", "Kill", null, 33.1, null);
		}
		EntFireByHandle(ent_vscriptCore, "RunScriptCode", "PlaySoundGlobal(`verdessence/omori/omori_title.mp3`, {canManip = false, isMusic = true})", 3.0, null, null);
		EntFireByHandle(ent_vscriptCore, "RunScriptCode", "MapPrintAll(`Warmup`)", 3.0, null, null);
		EntFireByHandle(ent_vscriptCore, "RunScriptCode", "MapPrintAll(`Map will begin at the end of the song`)", 5.0, null, null);
		EntFireByHandle(ent_vscriptCore, "RunScriptCode", "LevelSystem(`prologue`, `intro`)", 40.0, null, null);
	}
}

