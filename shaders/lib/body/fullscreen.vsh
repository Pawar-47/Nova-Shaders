#ifndef NOVA_BODY_FULLSCREEN_VSH
#define NOVA_BODY_FULLSCREEN_VSH

/* Composite and final are drawn as a single quad that already covers the whole
   viewport: Iris sets the matrices up so the unit quad lands on the screen.
   There is nothing to transform, and every fragment is written anyway, so this
   stage is three words of work. */

void main() {
    gl_Position = ftransform();
}

#endif
