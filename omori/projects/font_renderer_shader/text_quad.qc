// text_quad.qc -- compile with studiomdl
// $mostlyopaque is required for the custom shader on models (per
// ficool2/sdk_screenspace_shaders), together with $softwareskin 1 and
// $translucent 1 added to the VMT.
$modelname "verd/omori/text_quad.mdl"
$cdmaterials "effects/shaders"
$body body "text_quad_ref.smd"
$sequence idle "text_quad_ref.smd" fps 1
$mostlyopaque
$surfaceprop "default"
// no $staticprop: this must spawn as prop_dynamic so it can be parented
// and carry MMC children
