/**
 * Scenes for the README images. Not part of any print.
 *
 *   SCENE = "exploded"  body, lid and slider spread out
 *   SCENE = "widths"    8, 12 and 16mm side by side
 *   SCENE = "rail"      rail with its cap and spring
 *
 * render.sh drives this; size comes from container.scad's globals via -D,
 * exactly as the print plates do.
 */

use <container.scad>
use <rail.scad>

/* $fn is a special variable: it is looked up from the CALL SITE, and `use <>`
 * does not carry the used file's value across. Setting it in container.scad /
 * rail.scad therefore has no effect on anything exported from here - every
 * build ran at OpenSCAD's default until this line existed, which turned the
 * M2.5 tap holes into pentagons 1.66mm across the flats against a 2.05mm
 * design. Set it here, at the top level, or it does not apply. */
$fn = 100;

SCENE = "exploded";
W     = 12;
SPAN  = 75;      // body width at this size, for spacing the scene

/* Everything stays in print orientation. The badge is cut into the z=0 face,
 * so the scenes are shot from below (camera rx > 90) rather than by flipping
 * the model - flipping would mirror the badge text. */
module exploded() {
    body(W);
    color("#101010") badge_insert(W);
    translate([0, 0, -34]) lid_on_plate();
    translate([SPAN * 0.95, 0, 0]) rotate([0, 0, 90]) slider(W);
}

module widths() {
    for (i = [0 : 2]) {
        w = [8, 12, 16][i];
        translate([i * (SPAN + 12), 0, 0]) {
            body(w);
            color("#101010") badge_insert(w);
        }
    }
}

module rail_scene() {
    rail_weighted_round(100);
    translate([0, 58, 0]) rail_weighted_round_cap();
    translate([0, -46, 0]) spring(100);
}

if (SCENE == "exploded") exploded();
if (SCENE == "widths")   widths();
if (SCENE == "rail")     rail_scene();
