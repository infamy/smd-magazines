# Printables listing

Paste-ready.

**Set on the upload form, not in the text:**

| field | value |
|---|---|
| Licence | **CC-BY-SA 4.0** — required, inherited, not a choice |
| Remix of | `https://www.printables.com/model/1350841` (Bryan Varner) |
| Category | Tools & Gadgets → Organizers |

Printables links one parent only, so Varner goes in the Remix field and the
rest of the chain is credited in the body below.

---

## Title

SMD Component Tape Magazines — XL size, anti-release lip, and a label maker

## Summary

Wall-mounted magazines for SMD parts on cut tape, in three tape widths and two
capacities, on a rail that takes 26 of them per 300 mm.

## Description

Cut tape is miserable to store. Loose in a bag it curls, tangles and loses its
own label, and you end up counting parts through the cover tape with a torch.
These are magazines: the tape coils inside, feeds out through a slot, and a
sprung slider holds it where you left it.

This is a remix a few generations down. **@LordAsdi** designed the original,
**T. Wirtl (tobi)** rebuilt it as parametric OpenSCAD, and **Bryan Varner**'s
Varnerized Edition is what I started from. What I added:

**An XL size.** The standard holds roughly 800 of 0603. The XL holds about
1600 — same mechanism, bigger coil pocket, on its own slightly wider rail.

**An anti-release lip**, so a magazine cannot walk off its rail. The idea is
from Robin Reiter's "SMD Magazines G2" video; the mechanism here is my own — a
full-depth flap rather than a cantilever.

**A two-colour size badge.** The tape width is moulded into the front on a
second filament — already assigned in the file, so it loads that way — so a
rack of mixed widths reads at a glance. It is a second
*part* of the body object rather than a separate object, so a slicer's Arrange
cannot slide it out of its recess. Single extruder? Delete the badge part and
swap filament at layers 2 and 3.

**A 300 mm rail.** Prints standing in 302 mm, which an H2D takes. 26 8 mm
magazines per rail instead of 8. Its leaf spring ships as 3 × 100 mm segments
that butt end to end in the channel — past about 100 mm, a 0.8 mm printed
ribbon curls off the bed and is a nuisance to thread.

**A label maker**, below.

### What is in the download

STLs and plain **core-spec 3MF** — geometry and filament assignment, nothing
else. No slicer profile is baked in, so import into whatever slicer you use and
apply your own settings. A PDF of the assembly instructions is included.

Magazines come in a **0.4 and a 0.6 nozzle variant**. The badge recess is cut
exactly one first layer deep, so its depth is a property of the nozzle — take
the folder matching yours. The rails suit either.

### What you need besides the print

Per magazine: **4 × M2.5 × 6 mm countersunk** screws, hex drive (into 2.05 mm
holes), **1 × M3 × 16 mm button head** (ISO 7380, the coil spring's guide), and a
**compression spring** about 4 mm outside diameter, 20 mm free length, 0.4 mm
wire. Everything threads straight into the plastic — no inserts, no nuts. The
rail's leaf spring is printed.

### The label maker

Scan a reel barcode with a USB scanner, or paste a code, and it tells you which
magazine to print for that part and generates a two-colour label card sized to
the slot.

**https://www.meshmeld.com/smd-magazines/**

It reads DigiKey and Mouser Data Matrix, LCSC/JLCPCB QR and bare part numbers,
works the tape width out of the package and standard-against-XL out of the reel
quantity, and checks the lettering is coarse enough for your nozzle before you
print it. Nothing is looked up online — the barcode already carries the part
number and the quantity — so it works on a bench PC with no internet.

---

### Source

Parametric OpenSCAD, and the tooling that builds every plate:
**https://github.com/infamy/smd-magazines**

---

### Credit and licence

Not mine, most of it:

- **@LordAsdi** — the original SMD Component Tape Magazine, CC-BY 4.0.
  https://www.printables.com/model/580643
- **T. Wirtl (tobi)** — the parametric OpenSCAD remix, CC-BY-SA 4.0.
- **Bryan Varner** — the Varnerized Edition, what this started from,
  CC-BY-SA 4.0. https://www.printables.com/model/1350841
- **Robin Reiter** — not a code ancestor, the inspiration for the lip.

**CC-BY-SA 4.0**, inherited from that chain. Anything you make from this
carries the same licence and the same credits.
