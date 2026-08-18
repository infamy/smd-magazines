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

/* M2.5 countersunk screw: head recess, the 90-degree cone under it, and the
 * shank clearance. l2 is how far the flat head is sunk below the surface,
 * l1 the shank length. */
module countersunk_m2_5(l1 = 10, l2 = 0.25)
{
    cylinder(h = l2, d = 5);
    translate([0, 0, l2]) {
        cylinder(h = 1.5, d1 = 5, d2 = 2.6);
        cylinder(h = l1, d = 2.6);
    }
}
