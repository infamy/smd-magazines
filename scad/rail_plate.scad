/**
 * A rail, its cap and its leaf spring on one plate.
 *
 * The rail prints standing, so its length is limited by build height, not bed
 * area: an H2D takes 325mm, and the rail needs l + 2. The spring prints flat
 * and is l long, so it is the part that runs out of bed first - hence the
 * computed layout below rather than fixed coordinates.
 *
 *   rail_len = 100   the original size
 *   rail_len = 300   fills an H2D, 3x the magazines per rail
 *
 * Feet are spaced by rail_foot_pitch in rail.scad, so a long rail gets
 * intermediate mounts instead of just two at the ends.
 *
 * Each part is exported in its own OpenSCAD pass and combined into one Bambu
 * 3MF - build.sh does that. PART selects one part.
 *
 * There is no XL rail. Widening by stretching cannot keep the underside
 * planar and there is no clean split position on the left end - see README.
 */

use <rail.scad>

/* $fn is a special variable: it is looked up from the CALL SITE, and `use <>`
 * does not carry the used file's value across. Setting it in container.scad /
 * rail.scad therefore has no effect on anything exported from here - every
 * build ran at OpenSCAD's default until this line existed, which turned the
 * M2.5 tap holes into pentagons 1.66mm across the flats against a 2.05mm
 * design. Set it here, at the top level, or it does not apply. */
$fn = 100;

rail_len = 100;
bed      = [350, 320, 325];      // H2D: the third figure is what limits a rail

/* The leaf spring prints flat and is as long as the rail. Past about 100mm it
 * is a 0.8mm ribbon that curls off the bed and is awkward to thread into the
 * channel, so it ships in segments instead: the rail length is divided into
 * equal pieces no longer than spring_max_len, laid end to end along y on the
 * plate. They butt end to end in the channel and are retained by the rail base and
 * the cap, exactly as one long leaf would be.
 *
 *   rail_len 100 -> 1 x 100mm
 *   rail_len 300 -> 3 x 100mm
 */
spring_max_len = 100;
spring_count   = ceil(rail_len / spring_max_len);
spring_seg_len = rail_len / spring_count;
spring_gap     = 4;

/* Stacked along y, not side by side in x. The width is spring_span(), which
 * grows by 2*rail_grow_x: the XL leaf is 76.5mm wide against the standard
 * 51.5mm, and a fixed x pitch sized for the standard leaf fused the XL
 * segments into one slab. Three XL segments side by side need 237.5mm, which
 * does not fit beside the rail; three end to end need 308mm of y, which does,
 * whatever the width. */
spring_pitch   = spring_seg_len + spring_gap;

/* Parts render at their natural position; build.sh moves them onto the bed with
 * place_stl.py, the same way the magazine parts are placed. Doing it in one
 * place means the layout does not have to know how wide rail_grow_x made the
 * part. */

PART = "all";

/* With PART = "spring", SEG picks one segment so build.sh can export each to
 * its own STL and give it its own 3MF object - all of them in one mesh is one
 * object to the slicer, however far apart they sit. -1 renders every segment. */
SEG = -1;

if (PART == "rail"   || PART == "all") rail_weighted_round(rail_len);
/* The cap is a 1mm wall ring with 2mm of full body stacked on top, so printed
 * as modelled its widest face is in the air and the ring underneath it is a
 * thin, unsupported perimeter. Flipped, the full face goes down on the bed and
 * the ring is the last thing printed. place_stl.py drops it back onto z=0. */
if (PART == "cap"    || PART == "all") rotate([180, 0, 0]) rail_weighted_round_cap();
if (PART == "spring" || PART == "all")
    for (i = [0 : spring_count - 1]) if (SEG < 0 || SEG == i)
        translate([0, i * spring_pitch, 0.4]) spring(spring_seg_len);

assert(SEG < spring_count, str("SEG ", SEG, " but only ", spring_count, " segments"));
assert(rail_len + 2 <= bed[2],
       str("rail is ", rail_len + 2, "mm tall, over the ", bed[2], "mm build height"));
assert(spring_count * spring_pitch - spring_gap <= bed[1] - 10,
       str(spring_count, " spring segments will not fit along the bed"));
