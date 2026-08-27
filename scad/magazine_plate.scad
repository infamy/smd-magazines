/**
 * One magazine part per OpenSCAD pass.
 *
 * Each part is exported at its natural position and moved onto the bed
 * afterwards by place_stl.py, which keeps the body and its badge as one rigid
 * group so the badge stays seated in its recess. build.sh drives both.
 *
 *   PART         body | badge | lid | slider
 *   plate_width  tape width: 8, 12 or 16
 *
 * Size comes from container.scad's globals, set with -D:
 *   standard   (defaults)
 *   XL         -D grow_x=12.5 -D grow_y=12.5 -D window_d=22 -D badge_note="XL"
 */

use <container.scad>

/* $fn is a special variable: it is looked up from the CALL SITE, and `use <>`
 * does not carry the used file's value across. Setting it in container.scad /
 * rail.scad therefore has no effect on anything exported from here - every
 * build ran at OpenSCAD's default until this line existed, which turned the
 * M2.5 tap holes into pentagons 1.66mm across the flats against a 2.05mm
 * design. Set it here, at the top level, or it does not apply. */
$fn = 100;

plate_width = 12;
PART = "all";

if (PART == "body"   || PART == "all") body(plate_width);
if (PART == "badge"  || PART == "all") badge_insert(plate_width);
if (PART == "lid"    || PART == "all") lid_on_plate();
if (PART == "slider" || PART == "all") rotate([0,0,90]) slider(plate_width);
