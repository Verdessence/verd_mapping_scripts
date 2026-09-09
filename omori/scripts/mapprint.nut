// message display manager
// thanks berke
IncludeScript("verd/omori/mapcore.nut");

::MapPrintAll <- function(str_text) {
	ClientPrint(null, HUD_PRINTTALK, e_colors.str_default + "[Map]" + " " + str_text);
}

::Dialogue <- function(str_speaker, str_text, bool_world = false /* false --> DW, true --> FW */) {
	ClientPrint(null, HUD_PRINTTALK, (bool_world == false ? e_dialogue.str_dwColor : e_colors.str_human) + str_speaker + " : " + str_text);
}