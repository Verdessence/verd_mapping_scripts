// set level manager, where warmup is init
// actual stage content is separated in files, check /stages for more info
// ////////////// //
// important vars //
// ////////////// //
if (!("g_str_currentChapter" in getroottable())) {
	::g_str_currentChapter <- "warmup";
}
if (!("g_str_currentStage" in getroottable())) {
	::g_str_currentStage <- "warmup";
}
if (!("g_t_chapterRepo" in getroottable())) {
	::g_t_chapterRepo <- {};
}
IncludeScript("verd/omori/mapcore.nut");

/*
FUTURE REFERENCE
	CHAPTERS
		WARMUP, PROLOGUE, THREE DAYS LEFT, TWO DAYS LEFT, ONE DAY LEFT, ???, MOVING DAY
	STAGES
		TBD
		IF I HAD TO GUESS, IT WOULD BE

		PROLOGUE, SUNNY
			WHITE SPACE, SUNNY'S HOUSE, SOMETHING HEIGHTS, OTHERWORLD, CATTAIL FIELD
		THREE DAYS LEFT
			SUNNY'S HOUSE, SUNNY'S STREET, HOBBEEZ, FARAWAY PARK, OTHERMART, CHURCH, BASIL'S HOUSE, SUNNY'S HOUSE, SOMETHING SPIDERS, PYREFLY FOREST, SWEETHEART'S CASTLE, LOST LIBRARY
		TWO DAYS LEFT
			SUNNY'S HOUSE, GINO'S, OTHERMART, KEL'S HOUSE, FARAWAY PARK, SECRET HANGOUT, SOMETHING WATER, BASIL'S HOUSE, KEL'S HOUSE, SUNNY'S HOUSE, NORTH LAKE, DEEP WELL, LAST RESORT, UNDERWATER HIGHWAY, DEEPER WELL, HUMPHREY, BLACK SPACE, CHURCH OF SOMETHING, RED SPACE, SUNNY'S HOUSE
		ONE DAY LEFT
			SUNNY'S HOUSE, SUNNY'S STREET, BASIL'S HOUSE, SUNNY'S HOUSE, TREEHOUSE, BASIL'S HOUSE, SOMETHING HANGING BODY, BASIL'S MEDOW, TRUTH, BASIL'S HOUSE
		MOVING DAY / ???
			CROSSROADS, SUNNY'S HOUSE, MEMORY LANE, BACKSTAGE, WHITE SPACE, HOSPITAL, FIN

		PROLOGUE, OMORI
			WHITE SPACE, SUNNY'S HOUSE, SOMETHING HEIGHTS, OTHERWORLD, CATTAIL FIELD
		THREE DAYS LEFT
			SUNNY'S HOUSE, CLEANING, SOMETHING SPIDERS, PYREFLY FOREST, SWEETHEART'S CASTLE, LOST LIBRARY
		TWO DAYS LEFT
			SUNNY'S HOUSE, WASH DISHES, BATHROOM, SOMETHING WATER, NORTH LAKE, DEEP WELL, LAST RESORT, UNDERWATER HIGHWAY, DEEPER WELL, HUMPHREY, BLACK SPACE, CHURCH OF SOMETHING, STRANGER, RED SPACE, NEIGHBOR'S BEDROOM
		ONE DAY LEFT
			SUNNY'S HOUSE, SORTING, SUICIDE OR CONTINUE, FOREST PLAYGROUND, OTHERWORLD, SNOWGLOBE MOUNTAIN, (in no order) LAST RESORT, HUMPHREY, ABYSS
		MOVING DAY / ???
			SUICIDE OR LEAVE
*/

::g_func_levelSystem <- function(str_chapter = "warmup", str_stage = "warmup") {
	if (::g_func_isWarmup()) {
		printl("WARMUP OVERRIDE : warmup warmup");
		str_chapter = "warmup";
		str_stage = "warmup";
		return;
	}

	local str_chapterFile = "";
	switch (g_str_currentMap) {
		case (g_str_currentMap == "omori"):
				str_chapterFile = "verd/omori/stages/" + str_chapter + ".nut";
		default:
			printl("[GLOBAL STRING currentMap] map not found in level cases. please add a case");
	}
	if (str_chapterFile != null || str_chapterFile != "") { IncludeScript(str_chapterFile); }

	str_chapter = str_chapter.tostring();
	str_stage = str_stage.tostring();
	printl("changing to ch_" + str_chapter + " st_" + str_stage);

	if (!(str_chapter in ::g_t_chapterRepo)) {
		printl("invalid chapter [" + str_chapter + "]");
		return false;
	}
	local t_stageRepo = ::g_t_chapterRepo[str_chapter];

	if (!(str_stage in t_stageRepo)) {
		printl("invalid stage [" + str_stage + "] for chapter [" + str_chapter + "]");
		return false;
	}

	::g_str_currentChapter = str_chapter;
	::g_str_currentStage = str_stage;

	t_stageRepo[str_stage]();
	return true;
}

// //// //
// init //
// //// //
::g_func_levelSystem("prologue", "intro");
/*
::g_func_levelSystem <- function(str_chapter = "warmup", str_stage = "warmup") {

	::g_str_currentChapter = str_chapter;
	::g_str_currentStage = str_stage;

	if (!(str_chapter in ::g_t_chapterRepo)) {
		local str_chapterFile = "verd/omori/stages/" + str_chapter + ".nut";
		IncludeScript(str_chapterFile);
	}

	if (str_chapter in ::g_t_chapterRepo) {
		local t_stageRepo = ::g_t_chapterRepo[str_chapter];

		if (str_stage in t_stageRepo) {
			t_stageRepo[str_stage]();
			return;
		}
		else {
		printl("invalid stage [" + str_stage + "] for chapter [" + str_chapter + "]");
		return;
		}
	}
	printl("WARN: invalid chapter [" + str_chapter + "]");

}
*/
