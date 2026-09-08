// prologue
// ...what do you expect? i like to keep things consistent

// global stuff //
IncludeScript("verd/omori/mapcore.nut", this);
// add chapter double check
if (!("prologue" in gl_t_chapterRepo)) {
	gl_t_chapterRepo["prologue"] <- {};
}
// condition to play the intro once
if (!("SessionData" in getroottable())) {
	::SessionData <- {
		bool_bwsIsPlayed = false
	};
}


// start
gl_t_chapterRepo["prologue"]["intro"] <- function() {
	// prologue intro exclusive stuff
	// global
	::g_str_laptopUser <- null;

	// table
	local t_fadeCutscene = {
		duration = "2",
		holdtime = "6",
		rendercolor = "0 0 0",
		spawnflags = 1,
	};
	local t_fadeWhite = {
		duration = "3",
		holdtime = "2",
		rendercolor = "255 255 255",
		spawnflags = 1,
	};
	
	// some conditions
	local i_sketchbookCase = 0;

	// entity lookup
	local ent_wsInteractTissue = Entities.FindByName(null, "ws-interact-tissue");
	local ent_wsInteractMewo = Entities.FindByName(null, "ws-interact-mewo");
	local ent_wsInteractLamp = Entities.FindByName(null, "ws-interact-lamp");
	local ent_wsInteractLaptop = Entities.FindByName(null, "ws-interact-laptop");
	local ent_wsDisplayLaptop = Entities.FindByName(null, "ws-interact-laptop-display");
	local ent_wsInteractSketchbook = Entities.FindByName(null, "ws-interact-sketchbook");
	local ent_wsDisplaySketchbook = Entities.FindByName(null, "ws-interact-sketchbook-display");
	
	// entity spawn 
	local ent_vscriptCore = Entities.FindByName(null, "core-vscript");
	local str_vscriptCore = "core-vscript"; //FUCK YOU ADDOUTPUT FUCK OYU
	local ent_fadeCutscene = SpawnEntityFromTable("env_fade", t_fadeCutscene);
	local ent_fadeWhite = SpawnEntityFromTable("env_fade", t_fadeWhite);

	// pre entity injecting functions for connectoutput... BITCH 💢💢💢
	::h_interactTissue <- function() {
		MapPrintAll("A tissue box for wiping your sorrows away.");
	}
	::h_interactMewo1 <- function() {
		Dialogue("[MEWO]", "Meow? (Waiting for something to happen?)");
		PlaySoundGlobal("verdessence/omori/sfx/omori_cat-meow.mp3", {canManip = false});
	}
	::h_interactLamp1 <- function() {
		MapPrintAll("A lightbulb hangs from the ceiling, wherever it is.\n\t\tIt's pitch black inside. You can't see a thing.");
	}
	::h_interactLaptop1 <- function(caller) {
		::settingsState("!stare", true);
		::settingsState("!openjournal", true);

		local str_accID = getSteamID(caller);
		::g_str_laptopUser = str_accID;

		EntFireByHandle(ent_wsDisplayLaptop, "ShowSprite", null, 0.0, null, null);
		MapPrintAll("You booted up your laptop. What would you like to do?\n!stare\n!openjournal\n!logoff");
		
		if (str_accID != ::g_str_laptopUser) {
			MapPrintAll("The laptop is already in use by " + str_accID + ".");
		}
	}
	::h_interactSketchbook1 <- function() {
		if (i_sketchbookCase == 0) {
			MapPrintAll("Your sketchbook.\n+use to take a look.\n+attack to go back a page.");
			EntFireByHandle(ent_wsDisplaySketchbook, "ShowSprite", null, 0.0, null, null);
			PlaySoundGlobal("verdessence/omori/sfx/omori_mess-paper.mp3");
			i_sketchbookCase = 1;
		} else {
			if (::h_timer("str_wsSketchbookCd", 30.0)) {
				MapPrintAll("Your sketchbook.");
			}

			PlaySoundGlobal("verdessence/omori/sfx/omori_cursor.mp3");

			if (!(::h_timer("str_wsSketchbookClearCd", 35.0))) {
				EntFireByHandle(ent_wsDisplaySketchbook, "HideSprite", null, 0.0, null, null);
				i_sketchbookCase = 0;
			} else {
				::h_timer("str_wsSketchbookClearCd", -1);
			}
		}
	}
	
	// entity injecting
	ent_wsInteractTissue.ConnectOutput(
		"OnPressed",
		"h_interactTissue"
	);
	ent_wsInteractMewo.ConnectOutput(
		"OnPressed",
		"h_interactMewo1"
	);
	ent_wsInteractLamp.ConnectOutput(
		"OnPressed",
		"h_interactLamp1"
	);
	EntityOutputs.AddOutput(
		ent_wsInteractLaptop,
		"OnPressed",
		str_vscriptCore,
		"RunScriptCode",
		"h_interactLaptop1(activator)",
		0.0,
		-1
	);
	EntityOutputs.AddOutput(
		ent_wsInteractSketchbook,
		"OnUseLocked",
		str_vscriptCore,
		"RunScriptCode",
		"h_interactSketchbook1()",
		0.0,
		-1
	);
	EntityOutputs.AddOutput(
		ent_wsInteractSketchbook,
		"OnUseLocked",
		str_vscriptCore,
		"RunScriptCode",
		"h_procAnim(8, `ws-interact-sketchbook-display`, `forward`)", //FUCK YOU ADDOUTPUT FUCK OYU FUCK YOU
		0.0,
		-1
	);
	EntityOutputs.AddOutput(
		ent_wsInteractSketchbook,
		"OnDamaged",
		str_vscriptCore,
		"RunScriptCode",
		"h_procAnim(8, `ws-interact-sketchbook-display`, `backward`)",
		0.0,
		-1
	);
	
	// some functions for organization
	::h_wsSeq <- function() {
		EntFireByHandle(
			ent_vscriptCore,
			"RunScriptCode",
			"PlaySoundGlobal(`verdessence/omori/omori_white-space.mp3`, {canManip = true, isMusic = true, isLoop = true})",
			0.0,
			null,
			null
		);
	}
	
	// entity i/o
	printl("prologue bitch");
	SetSkyboxTexture("verdsky_omori_ws");
	/*
	EntFireByHandle(ent_fadeCutscene, "Fade", null, 0.0, null, null);
	if (!::SessionData.bool_bwsIsPlayed) {
		EntFireByHandle(ent_vscriptCore, "RunScriptCode", "PlaySoundGlobal(`verdessence/omori/omori_cutscene_beginning.mp3`, {canManip = true})", 5.0, null, null);
		EntFireByHandle(ent_vscriptCore, "RunScriptCode", "PlayAnim(`cutscene`, `before_white_space`)", 5.0, null, null);
		EntFireByHandle(ent_fadeCutscene, "Fade", null, 53.0, null, null);
		EntFireByHandle(ent_vscriptCore, "RunScriptCode", "PlayAnim(`cutscene`, `intro_1`)", 58.0, null, null);
		EntFireByHandle(ent_vscriptCore, "RunScriptCode", "PlaySoundGlobal(`verdessence/omori/sfx/omori_slide-change.mp3`)", 62.0, null, null);
		EntFireByHandle(ent_fadeCutscene, "Fade", null, 64.0, null, null);
		EntFireByHandle(ent_vscriptCore, "RunScriptCode", "PlayAnim(`cutscene`, `whitespace_intro`)", 66.0, null, null);
		EntFireByHandle(ent_fadeCutscene, "Fade", null, 68.0, null, null);
		EntFireByHandle(ent_vscriptCore, "RunScriptCode", "PlayAnim(`cutscene`, `intro_2`)", 70.0, null, null);
		EntFireByHandle(ent_vscriptCore, "RunScriptCode", "PlaySoundGlobal(`verdessence/omori/sfx/omori_slide-change.mp3`)", 71.665, null, null);
		EntFireByHandle(ent_fadeWhite, "Fade", null, 77.0, null, null);
		EntFireByHandle(ent_vscriptCore, "RunScriptCode", "PlaySoundGlobal(`verdessence/omori/omori_abstract-echo.mp3`, {canManip = true})", 82.0, null, null);
		EntFireByHandle(ent_vscriptCore, "RunScriptCode", "SoundFade(`verdessence/omori/omori_abstract-echo.mp3`, 3, false)", 84.0, null, null);
		EntFireByHandle(ent_vscriptCore, "RunScriptCode", "h_wsSeq()", 88.0, null, null);
		::SessionData.bool_bwsIsPlayed = true;
	} else {
		EntFireByHandle(ent_vscriptCore, "RunScriptCode", "PlayAnim(`cutscene`, `intro_1`)", 5.0, null, null);
		EntFireByHandle(ent_vscriptCore, "RunScriptCode", "PlaySoundGlobal(`verdessence/omori/sfx/omori_slide-change.mp3`)", 9.0, null, null);
		EntFireByHandle(ent_fadeCutscene, "Fade", null, 11.0, null, null);
		EntFireByHandle(ent_vscriptCore, "RunScriptCode", "PlayAnim(`cutscene`, `whitespace_intro`)", 13.0, null, null);
		EntFireByHandle(ent_fadeCutscene, "Fade", null, 15.0, null, null);
		EntFireByHandle(ent_vscriptCore, "RunScriptCode", "PlayAnim(`cutscene`, `intro_2`)", 17.0, null, null);
		EntFireByHandle(ent_vscriptCore, "RunScriptCode", "PlaySoundGlobal(`verdessence/omori/sfx/omori_slide-change.mp3`)", 18.665, null, null);
		EntFireByHandle(ent_fadeWhite, "Fade", null, 24.0, null, null);
		EntFireByHandle(ent_vscriptCore, "RunScriptCode", "PlaySoundGlobal(`verdessence/omori/omori_abstract-echo.mp3`, {canManip = true})", 26.0, null, null);
		EntFireByHandle(ent_vscriptCore, "RunScriptCode", "SoundFade(`verdessence/omori/omori_abstract-echo.mp3`, 3, false)", 28.0, null, null);
		EntFireByHandle(ent_vscriptCore, "RunScriptCode", "h_wsSeq()", 32.0, null, null);
	}
	*/
}