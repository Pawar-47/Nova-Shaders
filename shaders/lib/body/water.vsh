#ifndef NOVA_BODY_WATER_VSH
#define NOVA_BODY_WATER_VSH

/* Water needs exactly the same vertex data as an opaque surface: the wave
   normal is built in world space inside the fragment stage, so there is no
   reason to compute anything differently here. */

#include "/lib/body/opaque.vsh"

#endif
