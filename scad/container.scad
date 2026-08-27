/**
 * SMD Component Container Rail(c) by T.Wirtl
 *
 * is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
 * You should have received a copy of the license along with this work. If not, see
 * <http://creativecommons.org/licenses/by-sa/4.0/>.
 *
 * Disclaimer: Profile shapes are imported from a model by @LordAsdi
 *
 **/


/* $fn is a special variable, resolved from the CALL SITE, so this line only
 * applies when container.scad is rendered directly. Anything that reaches
 * these modules through `use <container.scad>` takes its $fn from its own
 * top level - see the note in magazine_plate.scad. */
$fn = 100;

use <hardware.scad>   // countersunk_m2_5, shared with the other file

counterbore_spacing = 0.6;
/* Height of the lid's spigot under each screw boss. body() cuts the pocket it
 * plugs into as cylinder(h=1, d1=4, d2=5), so the spigot may not be taller
 * than 1mm or it bottoms out and holds the lid off its seat. */
lid_boss_h = 0.8;   // 0.2mm clearance in a 1.0mm pocket; 1.0 bottomed out
tape_spacing        = 0.8;
slider_spacing      = 0.5;
side_wall_thickness = 1.25;
slider_pos          = 33.5;

/* ------------------------------------------------------------------
 * G2-inspired options
 *
 * Badge: the size marking on the bottom face is recessed by exactly
 * one first layer, so a colour change at the start of layer 2 prints
 * it in a second colour. See test_plate.scad for the layout and the
 * generated 3MF for the colour-change G-code.
 *
 *   "deboss" - glyphs are cut in, so they come out in the 2nd colour
 *              on a body-coloured face  (black lettering on grey)
 *   "plate"  - the rounded badge is cut in and the glyphs stand proud,
 *              so the badge comes out in the 2nd colour with
 *              body-coloured lettering (grey text on a black badge)
 *   "none"   - no badge
 * ------------------------------------------------------------------ */
// Must match the slicer's first layer height, so the recess is a whole
// number of layers. 0.3 = Bambu H2D 0.6 nozzle, "0.24mm Balanced
// Strength". Use 0.5 for the original Varnerized Prusa 0.6/0.25 profile.
first_layer_height = 0.3;
badge_layers       = 1;        // badge recess depth, in first layers
badge_mode         = "deboss";

/* Anti-release shoulder, as on the G2.
 *
 * The left edge is a first-class lever. Two slots overlap: one opens at
 * the top edge and runs down to about y +13, the other opens at the
 * bottom edge and runs up to about y -13, so the outer strip is joined
 * to the body only in the middle. That leaves two free ends - a tab at
 * the top and the hook at the bottom, next to the rail. Press the top
 * tab and the hook swings out: that is the release.
 *
 * Which is also the problem. The top tab sits exactly where fingers land
 * when you pick a magazine up, so it lets go on its own.
 *
 * The G2 fix, read off the video: the tab is lowered, and the body's top
 * edge is carried out over it as a lip, leaving a notch underneath. The
 * tab stays free - it has to, it is the actuator - but a finger landing
 * on top of the magazine now rests on the lip instead of on the lever.
 * To release you reach in under the lip.
 *
 * Both halves are 2D profile edits extruded through the full body, so
 * they add no overhangs and cost no print time. */
shoulder       = true;
shoulder_drop  = 6.0;    // how far the lever's tab is lowered. 6.0 leaves
                         // a 4.8mm lip - the one that tested right
shoulder_gap   = 1.2;    // clearance between the tab and the lip above it
shoulder_lip_x = -36.4;  // how far out the lip reaches; -36.4 is flush
                         // with the tab, more negative makes it proud
shoulder_r     = 0.8;    // corner rounding

/* Measured off the profile: the top of the lever tab and of the body
 * beside it, and how far left the tab and its slot reach. */
profile_top   = 33.6;    // top of the lever tab, before it is lowered
body_top      = 33.9;    // top of the body next to it
tab_cut_x     = -31.6;   // right edge of the tab + slot
shoulder_in   = -29.0;   // how far in the lip is rooted in the body

/* ------------------------------------------------------------------
 * Size. body_scale stretches the imported profiles in XY only, so the
 * tape pocket grows while the tape width stays whatever `width` says.
 * Everything that has to stay a real-world size - screw holes, the coil
 * spring pocket, the label slot, the badge - keeps its true size and
 * only has its position scaled.
 *
 *   1.000  standard, r29.5 pocket, 75.0 x 68.5mm
 *   1.424  XL, r42 pocket, 106.8 x 97.6mm - dual rail only
 *
 * HONEST NOTE: no build sets this. Every shipped variant - standard and XL
 * alike - leaves it at 1.0 and gets its size from grow_x/grow_y below, and
 * neither build.sh nor compare_sizes.py ever passes it. It is a manual knob:
 * reachable with -D body_scale=... (like any other global here) or with
 * compare_sizes.py --set, and kept as the reference against which growth was
 * chosen, because scaling drags the tape exit and slider engagement with it.
 * Treat the eight multiplications it threads through this file as dead weight
 * on the shipped path, not as something the XL depends on.
 * ------------------------------------------------------------------ */
body_scale = 1.0;
function sp0(p) = [p[0]*body_scale, p[1]*body_scale];  // scale a position

/* ------------------------------------------------------------------
 * Growth. Instead of scaling, split the profile at x=0 / y=0 and push
 * the halves apart, filling the seam. Every feature keeps its exact
 * size and shape and simply moves - the tape pocket is what grows.
 *
 *   grow_x = grow_y = 0     standard, r29.5 pocket
 *   grow_x = grow_y = 12.5  XL, r42 pocket, 100 x 93mm
 *
 * The lever, the lid interface, the slider and the foot are untouched
 * in shape. What the seam does change is length: anything crossing a
 * split line gets longer, which for the lever means a softer spring.
 * ------------------------------------------------------------------ */
grow_x = 0;
grow_y = 0;

/* The seam smears anything it crosses. Three face features are centred on
 * the split lines and must not be stretched: the round viewing window, the
 * level slot above it, and (cosmetically) the badge. Plug what the seam
 * smeared and re-cut them true. */
window_d      = 15;    // viewing window, round
window_slot_w = 2;     // level slot above it, stays a slot
badge_note    = "";    // extra line on the badge, e.g. "XL"

// move a feature by the growth, without resizing it
function gp(p) = [ p[0] + (p[0] >= 0 ? grow_x : -grow_x),
                   p[1] + (p[1] >= 0 ? grow_y : -grow_y) ];
// scale then grow: the one transform every feature position goes through
function sp(p) = gp(sp0(p));

module half_lo_x() { translate([-300,-300]) square([300,600]); }
module half_hi_x() { translate([   0,-300]) square([300,600]); }
module half_lo_y() { translate([-300,-300]) square([600,300]); }
module half_hi_y() { translate([-300,   0]) square([600,300]); }

module stretch_x(d) {
    if (d <= 0) children();
    else {
        translate([-d,0]) intersection(){ children(); half_lo_x(); }
        translate([ d,0]) intersection(){ children(); half_hi_x(); }
        minkowski() {
            intersection(){ children(); translate([-0.05,-300]) square([0.1,600]); }
            square([2*d,0.001], center=true);
        }
    }
}
module stretch_y(d) {
    if (d <= 0) children();
    else {
        translate([0,-d]) intersection(){ children(); half_lo_y(); }
        translate([0, d]) intersection(){ children(); half_hi_y(); }
        minkowski() {
            intersection(){ children(); translate([-300,-0.05]) square([600,0.1]); }
            square([0.001,2*d], center=true);
        }
    }
}
module grow() { stretch_y(grow_y) stretch_x(grow_x) children(); }

/* ------------------------------------------------------------------
 * Seam-safe features.
 *
 * The seam has to run through x=0 and y=0: those are the only splits that
 * grow a circular pocket. Splits at the "clean" positions that miss every
 * feature (|x|>=25, |y|>=20) leave a band of the pocket stationary and
 * gain no capacity at all - 25^2+20^2 = 1025 against R^2 = 870.
 *
 * So instead of letting the seam smear these features and patching the
 * result, fill them in before the seam ever sees them and cut them back
 * afterwards at true shape. Nothing to plug, and no plug height to get
 * wrong.
 * ------------------------------------------------------------------ */
/* The imported profile's OWN round window, measured off it: the hole runs to
 * y 7.51, so 15.02 across. This is what 2d_window_fill has to plug, and it is
 * deliberately NOT window_d - window_d is the size we re-cut at afterwards,
 * which is 22 on the XL. Tying the plug to window_d would make the XL plug a
 * 22.4 disc over a 15.02 hole and change the part. */
profile_window_d = 15.0;
window_fill_margin = 0.4;   // plug this much proud of the hole it closes

/* The level slot's ends, in profile coordinates. 2d_slot_fill plugs the slot
 * before the seam sees it and 2d_face_cut re-cuts it true afterwards; the two
 * describe the same slot and must agree, or the plug and the cut miss each
 * other and leave a step. */
level_slot_y0 = 9.51;
level_slot_y1 = 28.00;

module 2d_window_fill() { circle(d = profile_window_d + window_fill_margin, $fn = 120); }

module 2d_slot_fill()
{
    hull() {
        translate([0, level_slot_y0 + 0.6]) circle(d = 2.6, $fn = 32);
        translate([0, level_slot_y1 - 0.6]) circle(d = 2.6, $fn = 32);
    }
}

module 2d_right_clean() { union() { 2d_right(); 2d_window_fill(); 2d_slot_fill(); } }
module 2d_lid_clean()   { union() { 2d_lid();   2d_window_fill(); 2d_lid_opening_stock(); } }

module p_right()       { grow() scale([body_scale,body_scale]) 2d_right_clean(); }
module p_mid_noslot()  { grow() scale([body_scale,body_scale]) 2d_mid_noslot(); }
module p_mid_slot()    { grow() scale([body_scale,body_scale]) 2d_mid_slot(); }
module p_mid_cutout()  { grow() scale([body_scale,body_scale]) 2d_mid_slot_cutout(); }
module p_lid()         { grow() scale([body_scale,body_scale]) 2d_lid_clean(); }
module p_slider()      { grow() scale([body_scale,body_scale]) 2d_slider(); }

// Imports from original data from @LordAsdi (https://www.printables.com/model/580643-smd-component-tape-magazine-8-12-16mm)
// which is licensed under CC-BY 4.0
module body_centered()
{
    translate([-0.4,-32.5,0])rotate([-90,0,0]) import("upstream/Body_8mm.stl");
}

module lid_centered()
{
    translate([-0.4,-32.5,-14.2])rotate([-90,0,0]) import("upstream/Lid.stl");
}

module slider_centered()
{
    translate([-0.4,-32.5,0])rotate([-90,0,0])  import("upstream/Slider_8mm.stl");
}

module 2d_right()
{
    projection(true) translate([0,0,-1.2])body_centered();
}

module 2d_mid_noslot()
{
    projection(true) translate([0,0,-2])body_centered();
}

module 2d_mid_slot()
{
    projection(true) translate([0,0,-3])body_centered();
}

module 2d_mid_slot_cutout()
{
    difference()
    {
        projection(true) translate([0,0,-3])body_centered();
        translate([29,33])square([10,5]);
    }
}
// The badge box grows downward only when there is a note, so the size
// text and the border above it stay exactly where they were - and it
// stays clear of the corner screw boss above.
function badge_drop() = badge_note == "" ? 0 : 6;

module 2d_badge_box(inner = false)
{
    d = badge_drop();
    r = inner ? 3.5 : 4;
    o = inner ? 5.5 : 6;
    hull() for (x = [1,-1]) {
        translate([o*x,  o    ]) circle(r = r);
        translate([o*x, -o - d]) circle(r = r);
    }
}

module 2d_label_glyphs(width=8)
{
    translate([0,3.5,0])mirror([1,0,0]) text(str(width),size=9,halign="center", valign="center", font="Liberation Sans:style=Bold");
    translate([0,-5,0])mirror([1,0,0]) text("mm",size=6,halign="center", valign="center", font="Liberation Sans:style=Bold");
    if (badge_note != "")
        translate([0,-11.5,0])mirror([1,0,0]) text(badge_note,size=5.5,halign="center", valign="center", font="Liberation Sans:style=Bold");
}

// outline ring + glyphs: cut in, so the 2nd colour ends up in the lettering
module 2d_label(width=8)
{
    difference()
    {
        2d_badge_box(false);
        2d_badge_box(true);
    }
    2d_label_glyphs(width);
}

// solid badge with the glyphs knocked out: cut in, so the 2nd colour
// ends up as the badge and the lettering stays body-coloured
module 2d_label_plate(width=8)
{
    difference()
    {
        2d_badge_box(false);
        2d_label_glyphs(width);
    }
}



/* The lid's access opening only crosses the vertical split, so the seam
 * does not change its shape - it just stretches it from 40.8 x 20.4 to
 * 65.8 x 20.4, a letterbox. Recover the real opening by closing the lid's
 * holes and subtracting the lid back off, which leaves the holes as
 * shapes; then isolate this one. Reusing it means the re-cut is the
 * original outline exactly, corner radii and all. */
module 2d_lid_opening_stock()
{
    intersection() {
        difference() {
            offset(r=-12) offset(r=12) 2d_lid();   // close the holes
            2d_lid();
        }
        // lower edge must clear the round window, whose top is at y 7.51,
        // or a sliver of it gets isolated and re-cut as a stray slot
        translate([-22, 8]) square([44, 23]);
    }
}


// the same two features, at true shape and in the grown positions
module 2d_face_cut()
{
    circle(d = window_d, $fn = 160);
    y0 = gp([0, level_slot_y0])[1];
    y1 = gp([0, level_slot_y1])[1];
    hull() {
        translate([0, y0 + window_slot_w/2]) circle(d = window_slot_w, $fn = 48);
        translate([0, y1 - window_slot_w/2]) circle(d = window_slot_w, $fn = 48);
    }
}

module 2d_variant_tag(tag)
{
    mirror([1,0,0]) text(tag, size=5, halign="center", valign="center", font="Liberation Sans:style=Bold");
}

function shoulder_tab_top(drop=shoulder_drop) = profile_top - drop;

// Removed from the top of the lever, lowering its tab so it sits under
// the lip. Takes the top of the slot with it.
module 2d_shoulder_cut(drop=shoulder_drop)
{
    tab = shoulder_tab_top(drop);
    polygon([[-44, tab], [tab_cut_x, tab], [tab_cut_x, 44], [-44, 44]]);
}

// The lip: the body's top edge carried out over the lowered tab, so a
// finger landing on top of the magazine rests on the body and cannot
// press the lever. To release you reach in under it.
module 2d_shoulder_lip(drop=shoulder_drop, gap=shoulder_gap, lip_x=shoulder_lip_x, r=shoulder_r)
{
    y0 = shoulder_tab_top(drop) + gap;
    offset(r=r) offset(r=-r) polygon([
        [lip_x,       y0],
        [shoulder_in, y0],
        [shoulder_in, body_top],
        [lip_x,       body_top],
    ]);
}

module 2d_lid()
{
    projection(true) lid_centered();
}

module 2d_slider()
{
    projection(true) translate([0,0,-8])slider_centered();
}

// The recess the lid drops into. Anything added to the body above
// z = wall+width has to be trimmed by this or the lid will not seat.
lid_clearance = 0.8;   // uniform pocket clearance, used on grown bodies

module lid_pocket(wall=1.2, width=8)
{
    translate([0, 0, wall+width]) linear_extrude(wall + .5) {
        if (grow_x > 0 || grow_y > 0)
            // A proportional scale gives clearance that varies with distance
            // from the origin. Once the seam runs through the profile the
            // body's edge and the lid's edge stop tracking each other, and
            // the scale leaves a sliver along the top edge. Offset instead.
            offset(delta = lid_clearance) p_lid();
        else
            translate([0.25, 0.2, 0]) scale([1.02, 1.02, 1]) p_lid();
    }
}

/* Lever stiffness. The lever is a flap hinged on a web running its whole
 * length, and the web is (width - slot)/2 thick. Growing the body lengthens
 * that web - 58mm of slot at standard, 83mm at XL - and a flap's stiffness
 * goes as (t/L)^3, so at equal thickness the XL lever is markedly softer for
 * the same push. Scale the web to compensate; the slot shrinks to pay for it.
 *
 *   1.00   stock
 *   1.43   83/58, matches the standard's feel at grow 12.5
 *
 * Only the FLOOR of the slot is scaled, and only the floor may be. body_base()
 * lays the web down as p_mid_noslot extruded to wall + web, then closes the
 * slot again with p_mid_slot extruded to wall + web + lever_slot_eff(). That
 * second height is the lip over the slot - the end wall of the slider channel,
 * which 2d_mid_slot_cutout() takes out of the full-height extrusion so the
 * slider can pass over it. It is a running clearance and has to stay where it
 * is, whatever the web does.
 *
 * Taking the SCALED web off both faces (width - 2*web) tied it to the knob and
 * dropped it by exactly as much as the floor rose. The lip has the larger
 * footprint of the two - 16.9mm2 against the floor's 9.2mm2, everything else
 * being buried inside the full-height p_mid_cutout extrusion - so thickening
 * the web came out net-negative: 1.00 -> 1.43 took 3.3mm3 off the body instead
 * of adding 4.0mm3, which is why the knob looked dead. One face moves, so one
 * web is scaled and the other stays nominal; wall + web + eff then reduces to
 * the constant wall + width - web0 and the lip cannot follow the knob.
 *
 * MEASURED, and it is not what the paragraph above assumes. p_mid_noslot and
 * p_mid_slot are the same outline everywhere except one 9.2mm2 patch at
 * x 27.7..37.5, y 32.4..35.5 - the top of the slider channel. The lever's own
 * slot is a notch in the OUTER boundary and it is cut identically into
 * p_right, p_mid_noslot and p_mid_slot alike, so it is open from z 0 to the
 * top: slice body(12) anywhere across the lever and the cross-section is the
 * same at every height. There is no web across the lever for this knob to
 * thicken, and 1.00 -> 1.43 moves 4.0mm3 at the far corner of the part. Making
 * this a real stiffness control means widening the material behind the lever
 * slot in XY, which is a change to the profile, not to an extrusion height.
 */
lever_web_scale = 1.0;

/* Lever hinge thickness.
 *
 * The lever is a full-depth flap: the slot beside it is cut through every
 * profile, so above the first-layer skin there is nothing joining it to the
 * body. The hinge is that skin - a 9.9mm wide bridge running 61.9mm in y
 * (x -29.95..-20.05, y -28.0..33.9, 332.7mm2), material at z=0.5 and open at
 * z=2.0. Everything the lever's stiffness depends on is its thickness.
 *
 * Growing the body lengthens that bridge without thickening it, and a hinge's
 * stiffness goes as t^3, so the XL is softer for the same push and the extra
 * leverage of the longer arm makes it softer again. This raises the bridge -
 * and only the bridge - so the standard part is untouched at the default.
 *
 *   side_wall_thickness (1.25)  stock
 *   2.5                         XL, twice the skin -> ~8x the hinge stiffness
 */
lever_hinge_h = side_wall_thickness;

/* The web carrying the back clip. Measured off an XL section at z=1.9: three
 * solid runs sit in that corner and the middle one is a constant 1.49mm strip
 * at x -43.4..-41.9 (XL) running y 25.2 until it merges into the wall near
 * y 31. In standard coordinates - which is what these are, gp() moves them -
 * that is x -30.90..-29.42, y 12.65..18.50.
 *
 * It has 2.07mm of clearance outboard and 0.58mm inboard, so it can only be
 * thickened outboard. lever_web_add is how much to add there; the XL wants
 * some because the same 1.49mm web carries a longer arm.
 *
 *   0     stock
 *   0.8   XL, 1.49 -> 2.29mm, still 1.27mm clear of the wall
 */
/* The web that carries the back clip: a constant 1.49mm strip at
 * x -30.90..-29.42 (standard coords; gp() moves them), running the height of
 * lever_web_lo/hi. It has 2.07mm clear outboard and only 0.58mm inboard, so it
 * can only grow outboard.
 *
 * lever_web_add is added as a CONSTANT thickness, parallel to the web's own
 * face, over the web's whole run - deliberately including both ends, so it
 * merges into the clip below and into the body above. No taper and no fade:
 * a section that thins back down would just move the weak point rather than
 * remove it. Where the slot is already narrower than lever_web_add the two
 * simply join, which is the intent.
 *
 *   0    off - stock geometry
 *   1.0  XL, web 1.49 -> 2.49mm solid from clip to body
 */
/* Root fillet radius for the clip arm, and the two joints to apply it at,
 * in standard coordinates (gp() moves them to the grown position).
 *   0    off - stock geometry
 *   1.2  XL
 */
/* ------------------------------------------------------------------
 * Clip-arm tip reinforcement.
 *
 * WHICH END IS ANCHORED. Section the body at z = 1.9 and sweep a horizontal
 * line: the leftmost solid run - the clip arm - is continuous from y -44.6 all
 * the way to y +40.1 in XL coordinates, 85mm of strip, and the release slot
 * beside it never closes (0.75mm below, 1.8..3.4mm above). Its only full-depth
 * tie to the body is the 1.48mm web at x -30.90..-29.42, y 12.65..18.50 in
 * STANDARD coordinates - the "Y" in the section. (Below z = 1.25 the first
 * layer skins over the slot; that skin is the flexure, the web is the tie.)
 *
 * So the ROOT is that web, and BOTH ends are free: the hook at std y -32 and
 * the release tab at std y +27.6. The tab is therefore a short cantilever
 * hanging off the root and pointing up, and it already tapers the right way -
 * 5.82mm at the root, 2.51mm at the tip. What is wrong is not the direction of
 * the taper but the floor: 2.51mm of PLA at the end of the lever fingers push
 * on is where it cracks.
 *
 * THE FIX. Keep the taper direction, raise the whole thing above a 4mm floor,
 * and never let it taper back down. The new inner face is one straight line
 * from the arm's own inner face AT the root (arm_tip_root, where the addition
 * has zero width, so there is no step) to the tab top (arm_tip_tip). The
 * material between that line and the existing face is the arm's own outline
 * smeared inboard - a Minkowski sum with a horizontal segment - so the new
 * face inherits the arm's shape and cannot be a pasted box or a detached blob.
 *
 * It goes INSIDE body()'s first difference, so 2d_shoulder_cut trims its top
 * flush with the tab and the two relief cones chamfer its outer edge exactly
 * as they chamfer the arm's.
 *
 * Only the INNER face may move. The outer face is the rail interface, and
 * below the root the release slot is only 0.75mm wide, so the long lower arm
 * cannot be thickened inboard at all - it is a constant 4.01mm there, already
 * above the floor.
 *
 * Measured, XL, z = 1.9, tab section: 2.508 -> 4.044mm minimum, monotone
 * 5.82 at the root to 4.04 at the tip, no adjacent-0.5mm step over 0.21mm.
 * Slot beside the tab 2.65 -> 1.12mm, still open. Body 31.887 -> 32.011cm3.
 *
 * OFF by default, so the standard body is bit-for-bit stock; build.sh turns it
 * on for the XL variants with -D arm_tip_fill=1.
 * ------------------------------------------------------------------ */
arm_tip_fill  = 0;                // 0 = stock tapered tab, 1 = reinforced
arm_tip_root  = [-31.25, 19.00];  // inner face at the web root - zero addition
arm_tip_tip   = [-33.00, 27.60];  // inner face at the tab top (profile_top - drop)
arm_tip_ytop  = 31.00;            // run the line past the tab; shoulder_cut trims
arm_tip_reach = 2.20;             // how far inboard the arm may be smeared

function arm_tip_x(y) = arm_tip_root[0] +
    (y - arm_tip_root[1]) * (arm_tip_tip[0] - arm_tip_root[0])
                          / (arm_tip_tip[1] - arm_tip_root[1]);

module 2d_arm_tip_fill()
{
    y0 = arm_tip_root[1];
    y1 = arm_tip_ytop;
    intersection() {
        minkowski() {
            intersection() {
                p_right();
                polygon([gp([-60, y0]), gp([-30, y0]), gp([-30, y1]), gp([-60, y1])]);
            }
            square([arm_tip_reach, 0.001]);
        }
        polygon([gp([-60, y0]),
                 gp([arm_tip_x(y0), y0]),
                 gp([arm_tip_x(y1), y1]),
                 gp([-60, y1])]);
    }
}

/* ------------------------------------------------------------------
 * Back-wall stiffening.
 *
 * WHICH WALL. "Back" is this file's own word for the -x edge - the edge the
 * rail clip lives on ("the web carrying the back clip", above). Section the XL
 * body at z=1.9 and the four walls of the shell measure:
 *
 *     back  (-x)   1.499mm   over y -17.5 .. +17.5   (35mm at <=1.51)
 *     front (+x)   1.499mm   over y -12.5 .. +12.5   (25mm, and the slider
 *                                                     channel buttresses it)
 *     top   (+y)   1.452mm   but the top edge is 5.7mm deep with the label
 *                            slot cut through it - a box section, not a panel
 *     foot  (-y)   2.507mm   over x -12.5 .. +12.5, and it sits ON the rail
 *
 * So the back wall is both the thinnest AND the one carrying the clip: the
 * magazine's whole weight goes rail hook -> clip arm -> the 1.48mm web at
 * y 25..31 -> this wall, and pressing the release tab drives the same web
 * against it. 1.5mm of PLA over a 35mm span is what flexes.
 *
 * WHAT CAN BE ADDED. Nothing outboard - that face is the release slot, 0.75mm
 * wide, and beyond it the arm, which is the rail interface and the 100mm
 * envelope. Inboard is the tape pocket, so the addition is bounded by the reel
 * and by nothing else. The pocket VOID is not a circle: growth splits the
 * profile's r30 pocket and pushes the halves apart, so at XL it is a 25 x 25
 * square dilated by r30 - half-width 42.5 on the axes but 47.7 out on the
 * diagonals. The reel is round. Everything in that shape outside r42 (the
 * pocket radius this file documents: 29.5 + 12.5 of growth) is dead space.
 *
 * THE LINER. A constant-thickness band on the inside of the pocket, built from
 * the pocket's own circle through the same grow() the pocket goes through, so
 * it tracks the pocket face exactly instead of being a pasted-on rectangle;
 * back_wall_bite sinks its outer edge into the existing wall so the two merge
 * rather than meeting on a coincident face. Then:
 *
 *   - circle(back_wall_keep_r()) is subtracted, so the r42 reel is untouched.
 *     That is what pinches the liner to 0.5mm at the wall's mid-span: there is
 *     genuinely no more room there.
 *   - a window trims it to the back wall, and the window's edge ramps from the
 *     liner's inner face at |y| = back_wall_y_full out to the pocket face at
 *     back_wall_y_end, so the liner ENDS AT ZERO THICKNESS in the corners
 *     instead of stopping on a square shoulder.
 *
 * Both circles and the window go through grow(), so the y=0 seam smears all
 * three the same way and they stay registered. Writing the window's vertices
 * through gp() instead would tear it open across the seam.
 *
 * Everything is in STANDARD coordinates.
 *
 *   0     off - stock geometry
 *   1.6   XL: back wall 1.499 -> 3.099mm on the flanks, 1.999mm at mid-span
 * ------------------------------------------------------------------ */
back_wall_add      = 0;      // new material added inboard, mm. 0 = stock
back_wall_bite     = 0.6;    // how far the liner reaches INTO the existing wall
back_wall_pocket_r = 30.0;   // the ungrown profile's tape pocket, measured
back_wall_keep_r0  = 29.7;   // reel radius that must stay clear, ungrown
back_wall_y_full   = 8.0;    // full thickness out to this |y|
back_wall_y_end    = 16.0;   // ...ramped back to zero thickness by here

// the reel circle, at true size in the grown frame: 29.5 + 12.5 = the r42 the
// header quotes for the XL. A circle, because a coil of tape is one.
function back_wall_keep_r() = back_wall_keep_r0 + grow_x;

function bw_out(y) = -sqrt(max(0.01, pow(back_wall_pocket_r + back_wall_bite, 2) - y*y));
function bw_in(y)  = -sqrt(max(0.01, pow(back_wall_pocket_r - back_wall_add,  2) - y*y));

// the window's right edge: at the liner's inner face while the wall is thin,
// ramped back out to the pocket face over y_full..y_end
function bw_edge(y) =
    let (a  = abs(y),
         t  = a <= back_wall_y_full ? 0
            : a >= back_wall_y_end  ? 1
            : (a - back_wall_y_full) / (back_wall_y_end - back_wall_y_full))
    bw_in(y) + (bw_out(y) - bw_in(y)) * t;

module 2d_back_wall_window(n = 64)
{
    y1 = back_wall_y_end;
    polygon(concat(
        [ for (i = [0:n]) let (y = -y1 + 2*y1*i/n) [bw_edge(y), y] ],
        [ [-60, y1], [-60, -y1] ]));
}

module 2d_back_wall_fill()
{
    difference() {
        intersection() {
            difference() {
                grow() circle(r = back_wall_pocket_r + back_wall_bite, $fn = 240);
                grow() circle(r = back_wall_pocket_r - back_wall_add,  $fn = 240);
            }
            grow() 2d_back_wall_window();
        }
        /* CIRCUMSCRIBED, not inscribed. circle() draws the polygon INSIDE the
         * radius asked for, so a plain circle(42) leaves its flats 1.6um in
         * from r42 and the reel envelope is breached by that much. Dividing by
         * cos(half the facet angle) puts the flats exactly on r42 instead. */
        circle(r = back_wall_keep_r() / cos(180 / 360), $fn = 360);
    }
}

/* ------------------------------------------------------------------
 * Carrying the tip reinforcement DOWN into the body.
 *
 * WHAT THE SECTION ACTUALLY SHOWS. Cut body(12) at z = 1.9 and sweep a
 * horizontal line across the clip corner. In STANDARD coordinates the arm's
 * inner face, the release slot and the body's left wall behave like this:
 *
 *   y  <= 1.5    arm | 0.75 slot | 1.50 wall            wall = pocket boundary
 *   y  1.5..12.3 arm |  slot opens to 2.77 | wall       still one wall
 *   y  12.33     the wall FORKS
 *   y  12.4..18.9  arm | 2.1..0.34 slot | 1.481 WEB | 0.33..3.08 | body
 *   y  18.89     the web merges into the arm - THE ROOT
 *   y  >= 18.9   arm+web as one 5.8mm mass | 3.08..1.14 tab travel | body
 *
 * So the tie is a "Y": below y 12.33 there is ONE 1.5mm left wall; at 12.33 it
 * forks into a 1.481mm WEB that leans outboard and lands on the arm at y 18.89,
 * and the body wall that carries on inboard. Every millimetre of load the
 * release tab sees goes tab -> arm -> root -> that 1.481mm web -> fork -> body.
 * Once arm_tip_fill has taken the tab off its 2.51mm floor, the web is the
 * thinnest thing left in the load path, and the moment there is LARGER than at
 * the root because the lever arm is longer.
 *
 * WHERE THERE IS ROOM. Measured at z = 1.9, over the web's run:
 *
 *   y      slot arm|web     gap web|body
 *   12.4      2.139            0.327
 *   14.0      1.700            1.647
 *   16.0      1.151            2.898
 *   18.0      0.602            3.064
 *   18.8      0.336            3.076
 *
 * The arm|web slot is the release slot's top end - the arm has to be able to
 * move, so nothing goes there. The web|body gap is a dead pocket, closed at the
 * bottom by the fork and bounded on both sides by body material. That is the
 * only room, and it is on the web's INBOARD face.
 *
 * WHY THAT IS THE CONTINUATION AND NOT A NEW FEATURE. At the root the inner
 * face of the reinforced section IS the web's inner face carried on: measured,
 * the reinforced face at std y 19.0 sits at x -31.62 and the web's inner face
 * extrapolated to y 19.0 sits at -31.586, 0.03mm apart, and arm_tip_root's own
 * x is -31.70. The two faces are collinear across the root to within 0.1mm.
 * Thickening the web inboard therefore continues the same surface downward -
 * it is not a blob stuck on the side of the slot.
 *
 * THE SHAPE. One straight line, hinged where the addition is already zero:
 * from the web's inner face AT the root (no step, exactly as arm_tip_fill
 * hinges on arm_tip_root) down to that face plus arm_root_carry at the fork.
 * The material between that line and the web is the web's own outline smeared
 * inboard - a Minkowski sum with a horizontal segment - so the new face is the
 * real web face translated, not a drawn quadrilateral. The smear is sourced
 * from a strip that starts arm_carry_bite INSIDE the web, so the construction
 * can never reach across the release slot even if the fitted face drifts.
 *
 * Nothing is added at the fork itself: there the wedge is buried inside the
 * merged wall, so the addition fades out into solid material instead of ending
 * on a face. Near y 12.4..13.5 it bridges the 0.33..1.3mm web|body gap, which
 * is what "into the main body" means here - the web lands on the body over a
 * broader run instead of on a corner.
 *
 *   0     off - stock geometry, and the standard body is bit-for-bit stock
 *   1.5   XL. Web 1.481 -> 2.98mm at the fork, tapering to 1.481 at the root.
 *
 * CEILING. The taper line must stay outboard of the tape pocket. The pocket
 * face is at std x -27.32 at the fork, the web's inner face at -29.31, so the
 * line runs out of room at 1.99mm; arm_carry_max keeps a margin on that.
 * ------------------------------------------------------------------ */
/* ------------------------------------------------------------------
 * Weld the clip arm to the web.
 *
 * The arm and the web are two separate springs with a void between them.
 * Everything added so far - the tab, the web root, the back wall - put
 * material either SIDE of that void and left the gap itself open, so the two
 * kept acting independently. Closing it makes them one member, which is a step
 * change in stiffness rather than a percentage.
 *
 * Measured at XL, z=1.9: the void is 2.71mm at y 22 and closes on its own by
 * y 31.5. Both its edges are straight, so the fill is the strip between them.
 * It tapers to a point at the bottom rather than stopping square.
 *
 * BELOW the taper the void keeps widening and is the lever's travel - filling
 * there would lock the clip shut, so weld_y0 must stay above it.
 *
 *   0  off - stock
 *   1  on, XL
 * ------------------------------------------------------------------ */
weld_arm_web = 0;
weld_y0      =  7.2;    // arm side starts here, standard coords (XL y 19.7)
weld_y0_web  = 10.4;    // web side starts higher, so the bottom is a taper
weld_y1      = 19.1;    // top, where the two merge anyway (XL y 31.6)
function weld_arm_x(y) = -32.76 - 0.0700 * (y - 9.5);   // arm's inner face
function weld_web_x(y) = -29.60 - 0.3189 * (y - 9.5);   // web's outer face

module 2d_weld_arm_web() {
    difference() {
        /* The bottom edge runs diagonally - the arm side starts lower than the
         * web side - so the fill tapers in rather than beginning square. */
        polygon([gp([weld_arm_x(weld_y0),      weld_y0]),
                 gp([weld_arm_x(weld_y1),      weld_y1]),
                 gp([weld_web_x(weld_y1),      weld_y1]),
                 gp([weld_web_x(weld_y0_web),  weld_y0_web])]);
        p_right();                      // only fills void, never overlaps
    }
}

arm_root_carry  = 0;        // 0 = off; inboard thickness added at the fork
arm_carry_lo    = 12.30;    // std y, just below the fork - addition is buried
arm_carry_hi    = 20.10;    // std y, the root - addition is zero
arm_carry_face  = [-29.554, 13.00];  // a measured point on the web's INNER face
arm_carry_slope = -0.34446;          // dx/dy of that face (fitted y 13.0..18.6)
arm_carry_bite  = 0.60;     // how far inside the web the smear is sourced from
arm_carry_in    = -20.00;   // std x, inboard limit of the source band (pocket)
arm_carry_max   = 1.80;     // beyond this the taper line reaches the pocket

// the web's inboard face, in standard coordinates
function arm_carry_web(y) =
    arm_carry_face[0] + (y - arm_carry_face[1]) * arm_carry_slope;

/* The addition's inner face: the web's own face at the root, that face plus
 * arm_root_carry at the fork. The guard lives HERE and not at the top level
 * because `use <>` does not run a file's top-level statements - a top-level
 * assert in this file is never evaluated by magazine_plate.scad. In the
 * expression it is checked every time the shape is actually built. */
function arm_carry_x(y) =
    let (x1 = arm_carry_web(arm_carry_hi),
         x0 = arm_carry_web(arm_carry_lo) + arm_root_carry)
    assert(arm_root_carry <= arm_carry_max,
           str("arm_root_carry=", arm_root_carry, " puts the taper line into ",
               "the tape pocket; the measured ceiling is ", arm_carry_max))
    x1 + (y - arm_carry_hi) * (x0 - x1) / (arm_carry_lo - arm_carry_hi);

module 2d_arm_root_carry()
{
    y0 = arm_carry_lo;
    y1 = arm_carry_hi;
    intersection() {
        minkowski() {
            intersection() {
                p_right();
                // sourced from inside the web, so the smear cannot reach the
                // release slot; runs inboard into the pocket, which is empty
                polygon([gp([arm_carry_web(y0) - arm_carry_bite, y0]),
                         gp([arm_carry_in, y0]),
                         gp([arm_carry_in, y1]),
                         gp([arm_carry_web(y1) - arm_carry_bite, y1])]);
            }
            square([arm_root_carry, 0.001]);
        }
        polygon([gp([-60, y0]),
                 gp([arm_carry_x(y0), y0]),
                 gp([arm_carry_x(y1), y1]),
                 gp([-60, y1])]);
    }
}

/* ------------------------------------------------------------------
 * ROOT BLEND - the fork's inner surface written as ONE curve.
 *
 * WHAT IS WRONG. Section the XL body at z=1.9 and follow the pocket-facing
 * face of the arm+web member upward. Two separate reinforcements own that
 * face and they own it over abutting, not overlapping, spans:
 *
 *   below std y 19.00   2d_arm_root_carry, face arm_carry_x(y), dx/dy -0.5368
 *   above std y 19.00   2d_arm_tip_fill,   face arm_tip_x(y),   dx/dy -0.2035
 *
 * 2d_arm_tip_fill's polygon is clipped at arm_tip_root[1] = 19.00 and the tip
 * face is 0.1592mm INBOARD of the carry face there, so the union hands the
 * surface over across a bare horizontal segment:
 *
 *   std  (-31.4092, 19.00) -> (-31.2500, 19.00)      XL  (-43.9092, 31.50) -> (-43.7500, 31.50)
 *
 * That segment is the defect. It is a square, re-entrant step in the middle of
 * a working face - a stress raiser and a print artefact - and it is exactly
 * what the owner ringed at XL (-43.69, 31.40), std (-31.19, 18.90).
 *
 * WHY A CLOSING CANNOT FIX IT. offset(r=R) offset(r=-R) fills a concave corner
 * only where two faces lie within R of each other. Here the handover is a step
 * between two nearly parallel lines; extended, they do meet, at std
 * (-31.1528, 18.5223) - but that crossing is 0.48mm BELOW the step, so between
 * 18.52 and 19.00 the tip face is the more inboard of the two and simply is not
 * drawn. There is no corner at 19.00 for a closing to find.
 *
 * THE SHAPE. Take the two faces as what they are - two straight lines - and
 * write the surface between them as one curve instead of two segments and a
 * jog. The curve is a quintic Bezier whose first three control points lie on
 * the LOWER line and whose last three lie on the UPPER line, so:
 *
 *   - it leaves the lower face at std y = root_blend_lo with that face's
 *     position, slope AND curvature (three collinear control points give zero
 *     end curvature), and rejoins the upper face at root_blend_hi the same
 *     way. G2 at both ends: no crease, no square cut-off, no fade to a taper.
 *   - a Bezier lies inside the convex hull of its control points, and here
 *     that hull is bounded outboard by the two lines themselves. So the curve
 *     is >= max(lower, upper) at every y: the blend can only ADD material,
 *     never cut, and it cannot wander off the two faces it is joining.
 *   - it is monotone in y, so the ribbon below is simple and cannot fold.
 *
 * The area unioned in is that curve and the same curve pushed root_blend_bite
 * outboard, i.e. a ribbon lying ALONG the new surface. Its two ends are
 * horizontal segments buried inside the member (the member is 1.8mm thick
 * there and the bite is 0.6mm), so nothing square ever reaches a face, and the
 * ribbon overlaps existing material along its whole length - it cannot detach.
 *
 * WHAT IT DOES NOT TOUCH. The release slot outboard of the arm is 2.3mm away
 * at its nearest, the body wall inboard is 2.4mm away, and the whole blend
 * lives at std y 17.6..20.0 - clear of the lever travel below std y 11.5. The
 * outer face of the part is not referenced at all.
 *
 * Measured, XL, z = 1.9: the member's inner edge steps +0.1592mm at y 31.50
 * before and is monotone to 1e-4 after. Body 32.07249 -> 32.07367cm3.
 *
 *   0  off - stock geometry, and the standard body is bit-for-bit stock
 *   1  on. Only meaningful with arm_tip_fill and arm_root_carry, which are
 *      what put the two faces there; asserted below.
 * ------------------------------------------------------------------ */
root_blend      = 0;        // 0 = off, 1 = blend the two faces into one curve
root_blend_lo   = 17.60;    // std y where the curve leaves the lower face
root_blend_hi   = 20.00;    // std y where the curve rejoins the upper face
root_blend_s1   = 0.40;     // control points 2 and 5, as a fraction of the way
root_blend_s2   = 0.80;     // control points 3 and 4, ... from the end to the corner
root_blend_bite = 0.60;     // ribbon thickness, sunk into the member
root_blend_n    = 96;       // curve samples

// The two faces, taken from the very functions that draw them, so the blend
// tracks arm_root_carry and the tab line instead of restating them.
function rb_lo(y) = arm_carry_x(y);
function rb_hi(y) = arm_tip_x(y);

/* Where the two lines cross, in standard coordinates. Sampled from the two
 * functions at y = 0 and 1 rather than restated, so it follows them. */
function rb_corner() =
    assert(arm_root_carry > 0 && arm_tip_fill,
           "root_blend joins the arm_tip_fill and arm_root_carry faces; with either off there is nothing to join")
    let (a0 = rb_lo(0), a1 = rb_lo(1) - a0,
         b0 = rb_hi(0), b1 = rb_hi(1) - b0,
         y  = (b0 - a0) / (a1 - b1))
    [a0 + a1 * y, y];

function rb_ctrl() =
    let (c  = rb_corner(),
         p0 = [rb_lo(root_blend_lo), root_blend_lo],
         p5 = [rb_hi(root_blend_hi), root_blend_hi],
         s1 = root_blend_s1, s2 = root_blend_s2)
    [ p0,
      p0 + s1 * (c - p0),
      p0 + s2 * (c - p0),
      p5 + s2 * (c - p5),
      p5 + s1 * (c - p5),
      p5 ];

// quintic Bezier, Bernstein form
function rb_at(t) =
    let (p = rb_ctrl(), u = 1 - t)
        pow(u,5)          * p[0] +  5*pow(u,4)*t     * p[1]
    + 10*pow(u,3)*t*t     * p[2] + 10*u*u*pow(t,3)   * p[3]
    +  5*u*pow(t,4)       * p[4] +    pow(t,5)       * p[5];

module 2d_root_blend()
{
    n   = root_blend_n;
    pts = [for (i = [0:n]) rb_at(i/n)];
    polygon(concat(
        [for (p = pts)      gp(p)],
        [for (i = [n:-1:0]) gp([pts[i][0] - root_blend_bite, pts[i][1]])]));
}

function lever_web0(width, slot)     = (width - slot) / 2;   // nominal, unscaled
function lever_web(width, slot)      = lever_web0(width, slot) * lever_web_scale;
function lever_slot_eff(width, slot) =
    let (e = width - lever_web(width, slot) - lever_web0(width, slot))
    assert(e > 0, str("lever_web_scale=", lever_web_scale, " leaves no slot: a ",
                      lever_web(width, slot), "mm web under a ",
                      lever_web0(width, slot), "mm lip does not fit in ",
                      width, "mm"))
    e;

module body_base(wall=1.2, width=8, slot=6)
{
    web = lever_web(width, slot);
    eff = lever_slot_eff(width, slot);
    linear_extrude(wall) union()
    {
        p_right();
        p_mid_noslot(); // added for the thumb rest
    }
    linear_extrude(wall+width) // label space removal
    {
        intersection()
        {
            p_right();
            // clip band follows the growth, or it spans the wrong region on a grown body
            translate([-50*body_scale - grow_x, 30*body_scale + grow_y])
                square([70*body_scale + 2*grow_x, 50*body_scale]);
        }
    }
    difference() {
        linear_extrude(2 * wall+width)p_mid_cutout();
        // Remove the lid. Resized because it fits weird...
        lid_pocket(wall, width);
        // Clean up...
        translate([-20, -40, wall+width]*[[body_scale,0,0],[0,body_scale,0],[0,0,1]]) cube([60*body_scale, 80*body_scale, wall]);
    }
    // The web floor - the one surface lever_web_scale is allowed to move.
    linear_extrude(wall + web) p_mid_noslot();
    // The lip over the slot. wall + web + eff == wall + width - web0, so this
    // stays put as the floor comes up; see lever_slot_eff().
    linear_extrude(wall + web + eff) p_mid_slot();
}

/* The four M2.5 screw bosses, in profile coordinates. Three separate features
 * land on these points - the body's tap holes, the lid's counterbores and the
 * lid's countersinks - and they only mate if all three read the same list.
 * Every user puts them through sp() for scale and growth. */
function screw_bosses() = [[-21,-27], [21,-27], [-25, 27], [18, 32.8]];

/* Depth of the badge recess: a whole number of first layers, so a colour
 * change at the start of layer badge_layers+1 prints it in the second colour.
 * body() cuts to this depth and badge_insert() is extruded to it, so the two
 * have to be the same number or the insert stops filling the recess. */
function badge_depth() = first_layer_height * badge_layers;


module body(width = 8,
            badge   = badge_mode,
            tag     = "",
            sh      = shoulder,
            sh_drop = shoulder_drop,
            sh_gap  = shoulder_gap,
            sh_lip  = shoulder_lip_x)
{
    spaced_width = width + tape_spacing;
    // The window and level slot are holes in the OUTER SKIN only, which is
    // side_wall_thickness. Patching to the mid layer's 2.25mm left both
    // repairs standing 1mm proud into the tape pocket.
    face_h       = side_wall_thickness;
    repair       = (grow_x > 0 || grow_y > 0);
    // The top edge rises at 2.75 degrees and the label slot is cut to match.
    // The seam replaces part of that edge with a horizontal plateau while the
    // slot stays tilted, so the pocket shallows to 3.03mm against a 3.3mm
    // card. Drop the slot to restore the standard 0.32mm margin.
    label_drop   = repair ? 0.6 : 0;

    difference()
    {
    union() {
    difference()
    {
        union() {
            body_base(side_wall_thickness, spaced_width, spaced_width - 2);

            if (weld_arm_web)
                linear_extrude(2 * side_wall_thickness + spaced_width)
                    2d_weld_arm_web();

            /* Clip-arm tip reinforcement. Inside this difference on purpose:
             * 2d_shoulder_cut trims its top flush with the tab, and the two
             * relief cones chamfer its outer edge as they do the arm's. */
            if (arm_tip_fill)
                difference() {
                    linear_extrude(2 * side_wall_thickness + spaced_width)
                        2d_arm_tip_fill();
                    lid_pocket(side_wall_thickness, spaced_width);
                }

            /* The same reinforcement carried down past the root: thickens the
             * web that ties the arm to the body, on its inboard face, and
             * merges into the body wall where the web lands. */
            if (arm_root_carry > 0)
                difference() {
                    linear_extrude(2 * side_wall_thickness + spaced_width)
                        2d_arm_root_carry();
                    lid_pocket(side_wall_thickness, spaced_width);
                }

            /* The fork's inner face, rewritten as one curve: joins the
             * arm_root_carry face below to the arm_tip_fill face above with a
             * G2 blend, so the member's inner surface runs through the root
             * without the 0.16mm square step the two used to hand over across.
             * Same place in the tree as the two faces it joins, so every cut
             * body() makes applies to it too. */
            if (root_blend > 0)
                difference() {
                    linear_extrude(2 * side_wall_thickness + spaced_width)
                        2d_root_blend();
                    lid_pocket(side_wall_thickness, spaced_width);
                }

            /* Back-wall stiffening liner. Same shape of construction as the
             * arm tip fill and for the same reason: inside this difference so
             * every cut body() makes still applies to it, and clipped by the
             * lid pocket so the lid still seats. */
            if (back_wall_add > 0)
                difference() {
                    linear_extrude(2 * side_wall_thickness + spaced_width)
                        2d_back_wall_fill();
                    lid_pocket(side_wall_thickness, spaced_width);
                }
        }


        // lower the lever's tab so the lip can overhang it
        if (sh)
            translate([0,0,-0.5]) linear_extrude(2 * side_wall_thickness + spaced_width + 1)
                translate([-grow_x, grow_y]) scale([body_scale,body_scale]) 2d_shoulder_cut(sh_drop);
        translate([sp([20,20]).x, sp([20,20]).y, -0.01]) linear_extrude(badge_depth() + 0.01)
        {
            if (badge == "plate")  2d_label_plate(width);
            else if (badge != "none") 2d_label(width);
        }
        if (tag != "")
            translate([sp([20,6]).x, sp([20,6]).y, -0.01]) linear_extrude(badge_depth() + 0.01) 2d_variant_tag(tag);

        for (raw = screw_bosses())
        {
            pos = sp(raw);
            translate([pos.x,pos.y,side_wall_thickness]) cylinder(h=spaced_width+.1,d=2.05); // tap
            translate([pos.x,pos.y,side_wall_thickness+spaced_width-2]) cylinder(h=1.25,d1=2.05,d2=2.75);
            translate([pos.x,pos.y,side_wall_thickness+spaced_width-1]) cylinder(h=1,d1=4,d2=5);
        }
        translate([sp([slider_pos+1,-18.79]).x, sp([slider_pos+1,-18.79]).y, spaced_width/2+side_wall_thickness])
            rotate([90,0,0])
            {
                cylinder(h=0.41, d=4.6);
                translate([0,0,1.81]) cylinder(h=8.00, d=6.0);
                cylinder(h=7.50, d=2.5);
            }

        // LABEL
        translate([sp([-8.75,33]).x, sp([-8.75,33]).y - label_drop, spaced_width/2+side_wall_thickness+0.01]) rotate([0,0,2.75])
        {
            translate([1, -1, 0]) cube([40+3,1.25,spaced_width], center=true);
            translate([1, 1,0])cube([40,4,spaced_width], center=true);
        }
        translate([sp([-54.5,25.85]).x, sp([-54.5,25.85]).y, -0.00])
            cylinder(d2=36*body_scale, d1=(36+1.6)*body_scale, h=2, $fn=300);
        translate([sp([-54.5,25.85]).x, sp([-54.5,25.85]).y, side_wall_thickness + width + tape_spacing / 4])
            cylinder(d1=36*body_scale, d2=(36+1.6)*body_scale, h=2, $fn=300);
    }


    if (sh)
        difference()
        {
            linear_extrude(2 * side_wall_thickness + spaced_width)
                translate([-grow_x, grow_y]) scale([body_scale,body_scale]) 2d_shoulder_lip(sh_drop, sh_gap, sh_lip);
            lid_pocket(side_wall_thickness, spaced_width);
        }

    hull()
    {
        translate([sp([34.6,30]).x,   sp([34.6,30]).y,   0]) cylinder(h=side_wall_thickness,d=3);
        translate([sp([34.6,-20.3]).x,sp([34.6,-20.3]).y,0]) cylinder(h=side_wall_thickness,d=3);
    }

    translate([sp([slider_pos,-5.3]).x, sp([slider_pos,-5.3]).y, 0]) cylinder(h=side_wall_thickness + 1,d=1.9);
    hull()
    {
        translate([sp([slider_pos,16.3]).x, sp([slider_pos,16.3]).y, 0]) cylinder(h=side_wall_thickness + 1,d=1.9);
        translate([sp([slider_pos,10.5]).x, sp([slider_pos,10.5]).y, 0]) cylinder(h=side_wall_thickness + 1,d=1.9);
    }

        /* Thicken the lever hinge, if asked. Same 2D outline the first layer
         * already uses, extruded taller and clipped to the bridge, so it adds
         * meat under the lever and nowhere else. Sits inside the union so the
         * window, label slot and badge still cut it. No-op at the default. */
        if (lever_hinge_h > side_wall_thickness)
            linear_extrude(lever_hinge_h) intersection() {
                /* Exactly the material the first layer has and the layers above
                 * do not - i.e. the bridge across the slot, and nothing else.
                 * Derived from the profiles, so it cannot creep into the tape
                 * pocket the way a hand-picked bounding box did. */
                difference() {
                    union() { p_right(); p_mid_noslot(); }
                    p_mid_slot();
                }
                translate([-200, -200]) square([200 + lever_hinge_side, 400]);
            }


        /* Thicken the back-clip web, outboard only.
         *
         * NOT a pasted rectangle - that squared off a tapered web and overhung
         * the slot. Instead take the profile itself, shift it lever_web_add
         * outboard, and keep only what that covers of the empty slot beside the
         * web. The new face is the web's own face moved over, so it inherits
         * the taper and the fillets exactly, and it can never overlap material
         * that is already there. The box only bounds WHERE this applies. */
    }

        // cut them at true shape; the profile no longer carries them at all
        translate([0,0,-0.5]) linear_extrude(face_h + 0.5) 2d_face_cut();
    }
}

module lid()
{
    difference()
    {
    difference()
    {
        group()
        {
            linear_extrude(side_wall_thickness) p_lid();

            for (raw = screw_bosses())
            {
                pos = sp(raw);
                translate([pos.x,pos.y,-lid_boss_h]) cylinder(h=lid_boss_h, d1=4 - counterbore_spacing, d2=5 - counterbore_spacing);
            }

            hull()
            {
                translate([sp([34.6,30]).x,   sp([34.6,30]).y,   0]) cylinder(h=side_wall_thickness,d=3);
                translate([sp([34.6,-20.3]).x,sp([34.6,-20.3]).y, 0]) cylinder(h=side_wall_thickness,d=3);
            }
        }

        for (raw = screw_bosses())
        {
            pos = sp(raw);
            translate([pos.x,pos.y,side_wall_thickness]) rotate([180,0,0]) countersunk_m2_5();
        }

        hull()
        {
            translate([sp([slider_pos,-15.7]).x, sp([slider_pos,-15.7]).y, -.01]) cylinder(h=1.4,d=2.2);
            translate([sp([slider_pos,-5.3]).x,  sp([slider_pos,-5.3]).y,  -.01]) cylinder(h=1.4,d=2.2);
        }
        hull()
        {
            translate([sp([slider_pos,16.3+10.4]).x, sp([slider_pos,16.3+10.4]).y, -.01]) cylinder(h=1.4,d=2.2);
            translate([sp([slider_pos,10.5]).x,      sp([slider_pos,10.5]).y,      -.01]) cylinder(h=1.4,d=2.2);
        }
    }

        // cut them at true shape; the profile no longer carries them at all
        translate([0,0,-0.5]) linear_extrude(side_wall_thickness + 1) {
            circle(d = window_d, $fn = 160);
            translate([0, grow_y]) 2d_lid_opening_stock();
        }
    }
}

module slider(width=8)
{

    width = width + tape_spacing - slider_spacing;
    difference()
    {
        group()
        {
            linear_extrude(width) p_slider();

            translate([sp([slider_pos,-15.7]).x, sp([slider_pos,-15.7]).y, 0]) cylinder(h=width + 1,d=1.9);
            hull()
            {
                translate([sp([slider_pos,16.3]).x, sp([slider_pos,16.3]).y, 0]) cylinder(h=width + 1,d=1.9);
                translate([sp([slider_pos,10.5]).x, sp([slider_pos,10.5]).y, 0]) cylinder(h=width + 1,d=1.9);
            }
        }
        hull()
        {
            translate([sp([slider_pos,-15.7]).x, sp([slider_pos,-15.7]).y, -.01]) cylinder(h=1.6,d=2.2);
            translate([sp([slider_pos,-5.3]).x,  sp([slider_pos,-5.3]).y,  -.01]) cylinder(h=1.6,d=2.2);
        }
        hull()
        {
            translate([sp([slider_pos,16.3]).x,      sp([slider_pos,16.3]).y,      -.01]) cylinder(h=1.6,d=2.2);
            // NB 10.5-10.4 = +0.1, which sits 0.1mm from the sign flip in
            // gp(). It resolves correctly, but nudging it negative would
            // throw this end of the slot 2*grow_y out of position.
            translate([sp([slider_pos,10.5-10.4]).x, sp([slider_pos,10.5-10.4]).y, -.01]) cylinder(h=1.6,d=2.2);
        }
        translate([sp([slider_pos+1,-18.61]).x, sp([slider_pos+1,-18.61]).y, width/2])
            rotate([-90,0,0])
            {
                cylinder(h=5.61,  d=4.6);
                cylinder(h=16.01, d=3.6);
            }

    }
    // Detent bumps stay at true 3mm pitch, but the track has to reach both
    // guide slots - and growth moves those 2*grow_y apart. Deriving the end
    // from sp() rather than assuming a fixed 30mm track keeps the upper slot
    // engaged; with a fixed length it fell 8.5mm short and lost contact.
    det_x  = sp([slider_pos,-15])[0];
    det_y0 = sp([slider_pos,-15])[1];
    det_y1 = sp([slider_pos, 15])[1];
    for (y = [det_y0 : 3 : det_y1])
        translate([det_x, y, 0.105+1.4]) cube([3,1,0.21],center=true);

}

module label(width=8)
{
    translate([-5,40,0]) {
        cube([40 + 2 - counterbore_spacing , width+tape_spacing - counterbore_spacing, .8]);
        translate([1, 0, 0.8]) cube([40 - counterbore_spacing, width + tape_spacing - counterbore_spacing, 2.5]);
    }
}

// lid flipped and sitting on the bed, the way it prints
module lid_on_plate() { translate([0,0,side_wall_thickness]) rotate([180,0,0]) lid(); }

/* The badge as a solid that exactly fills the recess body() cuts, for
 * printers that can do the second colour as a real material rather than
 * a layer swap. Load it as a second part of the body object and assign
 * it to the second extruder: only the badge changes colour, with none of
 * the pinstripe a layer-range colour change leaves round the part. */
module badge_insert(width = 8, badge = badge_mode, tag = "")
{
    linear_extrude(badge_depth())
    {
        // must track the recess body() cuts, which moves with scale and growth
        translate(sp([20,20]))
        {
            if (badge == "plate")     2d_label_plate(width);
            else if (badge != "none") 2d_label(width);
        }
        if (tag != "") translate(sp([20,6])) 2d_variant_tag(tag);
    }
}

module preview(width=8)
{
    translate([0,10,side_wall_thickness+slider_spacing/2 ])slider(width);
    translate([0,0,side_wall_thickness + width+tape_spacing+0.1]) lid();
    body(width);
}

module build_plate(width=8)
{
    translate([65,5,0])rotate([0,0,90])slider(width);
   translate([75,0,side_wall_thickness])rotate([180,0,0])lid();
    body(width);
    label(width);
}

/* Guarded so this file can be `include`d without also rendering the
 * build plate. Set render_build_plate = false in the including file. */
render_build_plate = true;
if (render_build_plate) build_plate(12);
