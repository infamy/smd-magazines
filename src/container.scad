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
    translate([-0.4,-32.5,0])rotate([-90,0,0]) import("LordAsdi_sources/Body_8mm.stl");
}

module lid_centered()
{
    translate([-0.4,-32.5,-14.2])rotate([-90,0,0]) import("LordAsdi_sources/Lid.stl");
}

module slider_centered()
{
    translate([-0.4,-32.5,0])rotate([-90,0,0])  import("LordAsdi_sources/Slider_8mm.stl");
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
        body_base(side_wall_thickness, spaced_width, spaced_width - 2);

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
            rotate([90,0,0])cylinder(h=1.51,d=4.4);

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
                translate([pos.x,pos.y,-1.2]) cylinder(h=1.2, d1=4 - counterbore_spacing, d2=5 - counterbore_spacing);
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
            rotate([-90,0,0])cylinder(h=4.51,d=4.4);

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
