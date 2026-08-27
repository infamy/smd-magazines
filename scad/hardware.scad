/**
 * Fastener geometry shared by container.scad and rail.scad.
 *
 * This lived in both files, byte-identical. render.scad `use`s both, so the two
 * definitions collided there and whichever came last silently won - harmless
 * only for as long as they stayed the same. One copy removes that.
 *
 * `use <>` is not transitive, so a file that calls these must `use <hardware.scad>`
 * itself. Both callers do; a file that only uses container.scad or rail.scad does
 * not need to, because the calls resolve in their defining file's scope.
 */

/* M2.5 countersunk screw recess - DIN 965 / ISO 7046 head.
 *
 * The head of a DIN 965 / ISO 7046 M2.5 screw is a 90-degree INCLUDED cone
 * (45 degrees off the axis) with an actual head diameter dk of 4.7mm max.
 * The old recess ran d5.0 -> d2.6 over 1.5mm, which is
 *     2*atan(((5.0-2.6)/2)/1.5) = 2*atan(0.8) = 77.32 degrees,
 * so the screw and the recess were different cones and touched on a circle at
 * the head's sharp top edge instead of bearing on their faces.
 *
 * Everything below is a named parameter; the geometry is derived, not typed in,
 * so the cone angle cannot drift away from the head angle again.
 */

/* Confirmed against the built part: M2.5 x 6mm countersunk, hex drive. The
 * mouth is head_d + clr = 5.0, which clears a hex-socket countersunk head as
 * well as the cross-recess one this figure is taken from - both are 90 degree
 * heads and neither exceeds 5.0 across the top. */
csk_m2_5_head_d   = 4.7;   // DIN 965 / ISO 7046 dk, max
csk_m2_5_head_ang = 90;    // included angle of that head
csk_m2_5_head_clr = 0.3;   // diametral print clearance on the head cone (0.15 radial)
csk_m2_5_shank_d  = 2.8;   // free-fit clearance hole for M2.5 (ISO 273 fine 2.7 / medium 2.9)

/* l2 - straight bore of mouth diameter above the cone; how much further the
 *      head is buried below the surface than the clearance alone gives.
 * l1 - shank length below the mouth (total hole depth is l2 + l1, as before). */
module countersunk_m2_5(l1 = 10, l2 = 0.25,
                        head_d  = csk_m2_5_head_d + csk_m2_5_head_clr,
                        ang     = csk_m2_5_head_ang,
                        shank_d = csk_m2_5_shank_d)
{
    cone_h = (head_d - shank_d) / 2 / tan(ang / 2);
    assert(l1 > cone_h, "countersunk_m2_5: l1 is shorter than the head cone");
    cylinder(h = l2, d = head_d);
    translate([0, 0, l2]) {
        cylinder(h = cone_h, d1 = head_d, d2 = shank_d);
        cylinder(h = l1, d = shank_d);
    }
}
