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

$fn=100;

use <hardware.scad>   // countersunk_m2_5, shared with the other file

line_width = 1.3;

/* Clearance for features that have to slide or seat, used here by the spring
 * channel in 2d_spring_cutout() and by the cap-wall inset in
 * rail_weighted_round().
 *
 * NOTE: container.scad defines counterbore_spacing too, and at 0.6, not 0.4.
 * Same name, same concept, different value - deliberately left alone, because
 * the two are not the same fit: this one sets how loosely the 0.8mm leaf
 * spring rides in its curved channel, while container.scad's sets the
 * clearance on its M2.5 screw counterbores and label plate. They were tuned
 * against different features and changing either moves printed geometry.
 * Flagged so the mismatch is not read as a typo; anyone unifying the two
 * names has to re-check the fit on both parts. */
counterbore_spacing = 0.4;

/* ------------------------------------------------------------------
 * Rail width.
 *
 * The XL magazine's foot is the standard foot with both engagement points
 * moved 12.5mm apart in x, keeping their 3.83mm height difference. So the
 * rail's hooks must separate HORIZONTALLY - not along the underside.
 *
 * Sliding rigid halves cannot do both jobs at once, because the rail's two
 * faces are not parallel: the underside is a single flat plane at 17.97 deg
 * while the body's top is flat at y=0. Slide along the plane and the top
 * steps; slide horizontally and the underside steps, which is what made the
 * earlier XL rail refuse to sit flat.
 *
 * The way out is that those two faces are independent. Widening is allowed to
 * make the wedge thicker. So: stretch horizontally, which puts the hooks
 * exactly where the foot wants them, then RESTORE the underside by filling up
 * to a single plane and trimming anything below it. The wedge grows; the
 * mounting angle and both hooks do not move.
 *
 * Only 2d_rail_body() goes through this. It is one closed contour with no
 * holes, so the seam cannot smear a rod channel - the spring channel and the
 * three rod channels are cut afterwards, at their own positions.
 *
 *   rail_grow_x = 0     standard
 *   rail_grow_x = 12.5  XL, hooks 25mm further apart
 * ------------------------------------------------------------------ */
rail_grow_x = 0;

/* The underside plane. It must pass under BOTH hooks, and widening moves them
 * 25mm apart without changing their 3.83mm height difference - so the plane
 * necessarily gets shallower. That is forced, not a choice: hold the angle at
 * 17.97 and the plane cuts 4.87mm off the moved right hook.
 *
 *   standard  rise 19.498 over run 60.121  ->  17.97 deg
 *   XL        rise 19.498 over run 85.121  ->  12.90 deg
 *
 * Everything keyed to the mounting angle - the feet and the screw bosses -
 * reads rail_angle(), so it follows. */
rail_ref_lo  = [-23.312, -22.723];   // where the underside starts, measured
rail_ref_run = 60.121;
rail_ref_rise = 19.498;

function rail_plane_m(d = rail_grow_x) = rail_ref_rise / (rail_ref_run + 2*d);
function rail_angle(d = rail_grow_x)   = atan(rail_plane_m(d));
function rail_plane_c(d = rail_grow_x) =
    rail_ref_lo[1] - rail_plane_m(d) * (rail_ref_lo[0] - d);

rail_split_x = 0;           // on the flat plane, clear of both hooks

/* How far out in x the cutting half-plane is drawn. A bound, not a dimension:
 * it only has to reach past the widest rail, and the widening already adds d
 * to each side. The standard rail ends at x = 37.5 and the XL at x = 50. */
rail_half_span = 70;

module 2d_below_plane(d) {
    // half-plane under the underside, extended to cover the widened rail
    m = rail_plane_m(d); c = rail_plane_c(d);
    x_lo = -rail_half_span - d;
    x_hi =  rail_half_span + d;
    polygon([[x_lo, m*x_lo + c], [x_hi, m*x_hi + c],
             [x_hi, -90], [x_lo, -90]]);
}

/* The three rigid pieces, moved apart horizontally. The underside now steps by
 * rail_plane_m*d: the left half floats that far above the plane, the right half
 * dips that far below it. */
module 2d_rail_stretched(d) {
    translate([-d, 0]) intersection() {
        2d_rail_body();
        translate([-200, -90]) square([200 + rail_split_x, 180]);
    }
    translate([ d, 0]) intersection() {
        2d_rail_body();
        translate([rail_split_x, -90]) square([200, 180]);
    }
    // seam: the slice at the split, swept horizontally across the gap
    translate([-d, 0]) minkowski() {
        intersection() {
            2d_rail_body();
            translate([rail_split_x - 0.05, -90]) square([0.1, 180]);
        }
        square([2*d, 0.001]);
    }
}

/* Widen any single-contour 2D shape by inserting a band at its middle. Used
 * for the spring channel, which just needs to be longer.
 *
 * The band goes in at x = 0. This used to take a `split` parameter for that
 * position, but no caller ever passed one, so it is written out at 0 - which
 * also makes this the exact counterpart of container.scad's stretch_x(). The
 * rail body splits elsewhere and has its own module, 2d_rail_stretched(),
 * which keeps rail_split_x. */
module 2d_stretch_x(d) {
    if (d <= 0) children();
    else {
        translate([-d, 0]) intersection() {
            children(); translate([-300, -300]) square([300, 600]);
        }
        translate([ d, 0]) intersection() {
            children(); translate([0, -300]) square([300, 600]);
        }
        translate([-d, 0]) minkowski() {
            intersection() { children(); translate([-0.05, -300]) square([0.1, 600]); }
            square([2*d, 0.001]);
        }
    }
}

/* The stretched underside, written out as the polyline it actually is: down at
 * the left hook, up the sloped face to the split, flat across the band that was
 * inserted there, then up the sloped face again to the right hook. Both end
 * points are hook contacts, and rail_plane_c is defined so the plane passes
 * through them - so this polyline sits above the plane left of the seam and
 * below it to the right, and nowhere else does it matter.
 *
 * Lifted by a hair, because rail_ref_* are measurements rounded to 3 decimals
 * and the imported outline wanders about 0.00005mm off them. Sitting exactly on
 * the nominal line, the fill would fall below the real underside here and there
 * and leave hairline voids along it. The lift is trimmed off with everything
 * else below the plane, so it costs nothing. */
rail_fill_lift = 0.01;

function rail_under_pts(d) =
    let (seam_y = rail_plane_m(0) * rail_split_x + rail_plane_c(0) + rail_fill_lift)
    [[rail_ref_lo[0] - d,                rail_ref_lo[1] + rail_fill_lift],
     [rail_split_x - d,                  seam_y],
     [rail_split_x + d,                  seam_y],
     [rail_ref_lo[0] + rail_ref_run + d, rail_ref_lo[1] + rail_ref_rise + rail_fill_lift]];

/* Everything below that polyline, over exactly its own x span. Union this in
 * and the underside is buried; cut the half-plane back off and what is left is
 * the plane itself. Nothing is added outside [left hook, right hook], so the
 * steep end face and the hook noses are untouched. */
module 2d_under_stretched(d) {
    p = rail_under_pts(d);
    polygon(concat(p, [[p[3][0], -60], [p[0][0], -60]]));
}

module 2d_rail_body_wide(d = rail_grow_x) {
    if (d <= 0) 2d_rail_body();
    else difference() {
        union() {
            2d_rail_stretched(d);
            2d_under_stretched(d);   // bury the step, both the float and the dip
        }
        2d_below_plane(d);           // then plane it off in one cut
    }
}

// Imports from original data from @LordAsdi (https://www.printables.com/model/580643-smd-component-tape-magazine-8-12-16mm)
// which is licensed under CC-BY 4.0
module rail_centered()
{
    rotate([-90,0,0])translate([0,0,1])import("LordAsdi_sources/rail_100mm.stl");
}

/* ------------------------------------------------------------------
 * Leaf spring geometry, taken off the channel it has to live in.
 *
 * Measured off 2d_spring_cutout() intersected with 2d_rail_body(): the leaf
 * rides in a slot running r = 99.100 to r = 100.099 about (0,-98) - 0.999mm
 * for a 0.8mm leaf - with a bead pocket 2.598mm deep centred on r = 99.200 at
 * +-14 degrees.  The leaf's mid-surface therefore sits on r = 99.5995, and its
 * DEVELOPED half-width out to the bead centre is that radius times the pocket
 * angle: 24.3367mm, so 48.6735mm bead to bead.
 *
 * It used to be cut at 50mm, i.e. 1.3265mm (2.7%) too wide, and that is a hard
 * interference, not slop: bent onto the channel's own arc, 1.44mm2 of the
 * leaf's cross-section lands inside solid rail, 0.35mm of each bead sticking
 * out past its pocket.  The leaf cannot lose the extra length by squashing -
 * 2.7% compressive strain is 82MPa, past PLA's yield - and the free 39.9mm
 * span between the two captive edges buckles at about 1/124 of that load.  So
 * it folds instead of taking the arc.  Best case the excess goes into one
 * smooth extra hump: the crown rises 3.3mm above where the channel wants it
 * and the peak bending strain is 2.0%, right at PLA's limit.  Localised into
 * one 4mm ligament instead, the fold radius is 1.4mm and the strain 28%.
 * Either way the part takes a permanent set - which is the reported symptom.
 *
 * Fixed outright rather than put behind a flag: the part as drawn does not fit
 * the rail it is for.  Correct leaf: 51.4735 wide, 48.6735 bead to bead.
 * ------------------------------------------------------------------ */
spring_seat_r     = 99.5995;   // mid-surface radius of the channel slot
spring_seat_angle = 14;        // where 2d_spring_cutout() puts the bead pockets
spring_t          = 0.8;       // the slot is 0.999mm, so this cannot grow past
                               // about 0.85 without cutting a new rail
spring_bead_d     = 2.8;       // pocket is 3.4 -> 0.3mm radial slack, and the
                               // bead must lift 1.4mm to escape while the leaf
                               // can only lift 0.0995mm.  Capture is positive.
spring_slot_pitch = 6;
spring_slot_w     = 2;
spring_slot_land  = 3;         // slot end centre, measured in from the bead

/* Continuous, unslotted land down the centre line of the leaf.
 *
 * 0 reproduces the old pattern exactly, and the old pattern makes the leaf a
 * ladder: every 6mm a slot severs 44.7 of the 51.5mm width, leaving the two
 * 3.4mm beaded edges - 13% of the width - as the only thing joining the two
 * halves.  Effective torsional constant 2.754mm4 against 8.785 for the same
 * plate unslotted, i.e. 31%, which is why the leaf racks and takes a set when
 * it is handled, and why anything riding on the crown crosses an open 2mm gap
 * fifteen times in 100mm.
 *
 * spring_spine = 6 splits each slot in two and leaves 6mm of unbroken plate
 * along the crown - the line that actually stands proud of the rail.  J_eff
 * goes to 4.377mm4 (50% of solid, +59%) and the crown becomes a continuous
 * running surface.  Costs 15% of the slot area.  Not the default, because it
 * changes a printed part that is not itself wrong. */
spring_spine      = 0;

/* Developed bead-centre-to-bead-centre width.  +2*rail_grow_x because
 * 2d_stretch_x() inserts exactly that much STRAIGHT band into the middle of
 * the channel, and a straight band develops 1:1. */
function spring_span() =
    2 * spring_seat_r * spring_seat_angle * PI / 180 + 2 * rail_grow_x;

function spring_slot_runs(w) =
    let (o = w/2 - spring_slot_land)
    spring_spine > 0 ? [[-o, -(spring_spine/2 + spring_slot_w/2)],
                        [ (spring_spine/2 + spring_slot_w/2), o]]
                     : [[-o, o]];

module spring(l=100)
{
    // Width across x, between the centres of the two bead rods. `l` is the
    // length along y, so this is deliberately not called a length.
    spring_w = spring_span();

    difference()
    {
        group()
        {
            cube([spring_w + spring_bead_d, l, spring_t], center=true);
            for (x=[1,-1]) translate([x*spring_w/2, l/2, spring_t/2]) difference()
            {
                rotate([90,0,0]) cylinder(d=spring_bead_d, h=l);
                translate([-(spring_bead_d+0.2)/2, -l-1, -3])
                    cube([spring_bead_d+0.2, l+2, 3]);
            }
        }

        /* Stop short of the free end. At l=300 the old range ended exactly on
         * y=l/2, putting the last slot across the end face and shaving the
         * plate's last millimetre over 46 of its 52.8mm width. Keep >=4mm of
         * land. dir starts at the second hole so y=0 is not cut twice. */
        for (y = [0 : spring_slot_pitch :
                  floor((l/2 - 4)/spring_slot_pitch)*spring_slot_pitch])
        {
            for (dir = (y == 0 ? [1] : [1,-1]))
              for (run = spring_slot_runs(spring_w)) hull()
              {
                translate([run[0], y*dir, -1]) cylinder(d=spring_slot_w, h=spring_t+2);
                translate([run[1], y*dir, -1]) cylinder(d=spring_slot_w, h=spring_t+2);
              }
        }
    }
}

module 2d_rail_body()
{
    projection(true) translate([0,0,50])rail_centered();
}

module 2d_spring_cutout($fn=1000)
{
    intersection()
    {
        difference()
        {
            translate([0,-98]) circle(d=200+(counterbore_spacing / 2));
            translate([0,-98]) circle(d=200-0.8*2-(counterbore_spacing / 2));
        }
        translate([-24,-4])square([48,8]);
    }


    intersection()
    {
        difference()
        {
            translate([0,-98]) circle(d=200+2);
            translate([0,-98]) circle(d=200-0.8*2-(counterbore_spacing / 2));
        }
        translate([-22,-4])square([44,8]);
    }

    intersection()
    {
        group()
        {
            translate([0,-98])rotate(-14)translate([0,100-0.8])circle(d=3 + (counterbore_spacing));
            translate([0,-98])rotate( 14)translate([0,100-0.8])circle(d=3 + (counterbore_spacing));
        }
        translate([0,-98]) circle(d=200+(counterbore_spacing / 2));
    }


    intersection()
    {
        translate([0,98]) circle(d=200);
        translate([-25,-4])square([50,8]);
    }

}

module 2d_rail_profile()
{
    difference()
    {
        2d_rail_body_wide();
        translate([2,0]) 2d_stretch_x(rail_grow_x) 2d_spring_cutout();
    }
}

module 2d_cutout_round_weight(d=8)
{

    difference()
    {
        circle(d=d+0.4);
        translate([(d+0.4)/2,0])circle(d=1.3);
    }
    difference()
    {
        translate([(d+0.4)/2,0])circle(d=3);
        translate([(d+0.4)/2,0])circle(d=1.3);
        translate([(d+0.4)/2-0.5,0])square([1,4]);
    }
}

module 2d_rail_profile_weights_round()
{
    difference()
    {
        2d_rail_profile();
        /* The two left channels ride out with the left half: that end of the
         * wedge only gets thicker as the rail widens, so their clearance grows.
         *
         * The third one must NOT ride out with the right half. Widening rotates
         * the underside shallower about the hooks, which THINS everything right
         * of the split - at rail_grow_x = 12.5 the wedge at x = 15 is 9.1mm
         * deep and the channel is 8.5mm across, so a channel carried out to
         * there breaks straight through the mounting face and opens a 7mm notch
         * in it. Left where it is, it sits in the band inserted at the seam,
         * which is the part that stays deep, and it keeps 1.6mm of floor. */
        translate([-19 - rail_grow_x, -11]) rotate(60)  2d_cutout_round_weight(12.75);
        translate([ -7 - rail_grow_x, -10]) rotate(120) 2d_cutout_round_weight(8.1);
        translate([2.75,               -8])             2d_cutout_round_weight(8.1);

    }
}


/* Mounting-foot spacing. The first and last sit 10mm in from each end; the
 * rest are spread evenly so no gap exceeds rail_foot_pitch. At l=100 this
 * gives exactly the original pair at z=10 and z=90. */
rail_foot_pitch = 95;
function foot_zs(l) =
    let (span = l - 20,
         n    = max(2, ceil(span / rail_foot_pitch) + 1))
    [for (i = [0 : n-1]) 10 + i * span / (n - 1)];

/* A foot is a shallow pad milled into the underside, so its anchor has to be
 * read off whichever plane is current. Widening slides the pad out with its
 * half AND tilts the plane under it: at rail_grow_x = 12.5 the left pad ends up
 * 0.51mm inside the rail - a sealed void, with no pad on the face at all - and
 * the right one 0.46mm outside it, leaving a pad half the intended depth.
 * Carrying the pad's own offset from the plane keeps it on the face at any
 * width, and is identically zero at rail_grow_x = 0. */
function rail_foot_xy(x0, y0, s) =
    let (x = x0 + s * rail_grow_x)
    [x, y0 + ((rail_plane_m()  * x  + rail_plane_c())
            - (rail_plane_m(0) * x0 + rail_plane_c(0)))];

/* The three cap screws. The rail gets a 2mm tap hole at each, the cap a
 * countersunk clearance hole - so the two lists must agree exactly, which is
 * why they are one list. The outer two ride out with their own half as the
 * rail widens, matching the hooks they sit over. */
function rail_boss_xy() = [[-26.5 - rail_grow_x, -11],
                           [-26.5 - rail_grow_x,   4],
                           [   18 + rail_grow_x, -11]];

module rail_weighted_round(l=100)
{
    difference()
    {
        group()
        {
            // wide, like everything above it: the un-widened body would hang
            // 2.7mm below the mounting plane and stand the rail off the wall
            linear_extrude(2) 2d_rail_body_wide();
            linear_extrude(l+2) 2d_rail_profile_weights_round();
        }
        translate([0,0,l+1])linear_extrude(1.01) difference()
        {
            2d_rail_profile();
            offset(r=-(line_width + counterbore_spacing)) 2d_rail_profile();
        }
        for (pos = rail_boss_xy()) rotate([0,0,rail_angle()])translate([pos.x,pos.y,l+2-12])cylinder(h=12.01,d=2);


        // Mounting feet. Originally two per side, pinned at z=10 and z=l-10,
        // which is fine at l=100 but leaves a 280mm unsupported span once the
        // rail gets tall. Space them at most rail_foot_pitch apart instead.
        for (z = foot_zs(l), xy = [rail_foot_xy(-18, -21, -1), rail_foot_xy(32, -4.78, 1)])
        {
            translate([xy[0], xy[1], z]) rotate([-90,0,rail_angle()])
                translate([0,0,-0.01]) cylinder(d=9.2,h=1.01);
        }
    }
}


module rail_weighted_round_cap()
{
    difference()
    {
        group()
        {
            translate([0,0,1])linear_extrude(2) 2d_rail_body_wide();
            linear_extrude(3) difference()
            {
                2d_rail_profile();
                offset(r=-line_width) 2d_rail_profile();
            }
        }

        for (pos = rail_boss_xy()) rotate([0,0,rail_angle()])translate([pos.x,pos.y,3])rotate([180,0,0]) countersunk_m2_5();
    }
}

/* Guarded so this file can be `include`d without also rendering a preview.
 * Set render_rail_preview = false in the including file.
 *
 * Every consumer today uses `use <rail.scad>`, which ignores top-level
 * geometry, so the bare call this replaces never rendered anywhere - it was
 * inert by luck, not by design, and one `include` would have quietly added a
 * cap to someone else's plate. Same pattern as container.scad. */
render_rail_preview = true;
if (render_rail_preview) rail_weighted_round_cap();
