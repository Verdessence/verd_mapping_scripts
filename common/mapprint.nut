// message display manager
// thanks berke

::g_func_mapPrintAll <- function(str_text) {
	ClientPrint(null, EHudNotify.HUD_PRINTTALK, e_colors.str_default + "[Map]" + " " + str_text);
}

::g_func_dialogue <- function(str_speaker, str_text, bool_world = false /* false --> DW, true --> FW */) {
	ClientPrint(null, EHudNotify.HUD_PRINTTALK, (bool_world == false ? e_dialogue.str_dwColor : e_colors.str_human) + str_speaker + " : " + str_text);
}
