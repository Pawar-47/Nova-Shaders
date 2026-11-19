#ifndef NOVA_BODY_SKY_VSH
#define NOVA_BODY_SKY_VSH

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util.glsl"

/* The sky dome, the void plane, the sun and the moon all share this vertex
   stage. The camera sits at the origin of the view space, so the view space
   position of any sky vertex is also the direction to that piece of sky. */

out vec3 vSkyView;

void main() {
    gl_Position = ftransform();
    vSkyView = (gl_ModelViewMatrix * gl_Vertex).xyz;
}

#endif
