# MakerWorld listing

Paste-ready. Two placeholders to fill once the repository exists:
`{{REPO_URL}}` and `{{PAGES_URL}}`.

**Set on the upload form, not in the text:**

| field | value |
|---|---|
| Licence | **CC-BY-SA 4.0** — required, inherited, not a choice |
| Origin | **Remix / derivative**, crediting Bryan Varner's Varnerized Edition |
| Category | Hobby & DIY → Organization |

Two things worth knowing before uploading here, neither of which is a reason
not to:

**MakerWorld's remix credit only points at models hosted on MakerWorld.** The
whole chain here lives on Printables, so the attribution has to carry in the
description text — which is where it is below. Do not let it get trimmed.

**Share-alike and the points scheme sit awkwardly together.** CC-BY-SA lets
anyone use this commercially, so earning points on it is allowed. But everyone
upstream licensed their work on the understanding that derivatives stay equally
free, and their names are the only thing they asked for. Keeping the credits
prominent is the whole of the bargain.

---

## Title

SMD Component Tape Magazines — XL size, anti-release lip, and a label maker

## Description

Cut tape is miserable to store. Loose in a bag it curls, tangles and loses its
own label, and you end up counting parts through the cover tape with a torch.
These are magazines: the tape coils inside, feeds out through a slot, and a
sprung slider holds it where you left it.

This is a remix several generations down — most of the geometry is not mine.
Full credit chain and licence at the bottom.

---

### What I added

**An XL size** — the standard holds roughly 800 of 0603, the XL about 1600.
Same mechanism, bigger coil pocket, its own slightly wider rail.

**An anti-release lip** so a magazine cannot walk off its rail. The idea is
Robin Reiter's; the mechanism is mine — a full-depth flap, not a cantilever.

**A two-colour size badge**, so a rack of mixed tape widths reads at a glance.
It is a second *part* of the body object rather than a separate object, so
Arrange moves the pair together and cannot slide it out of its recess.

**A 300 mm rail** — prints standing in 302 mm, 26 8 mm magazines per rail
instead of 8. Its leaf spring ships as 3 × 100 mm segments that butt end to end
in the channel; past about 100 mm a 0.8 mm printed ribbon curls off the bed and
is a nuisance to thread.

**A label maker** — see below.

### Printing

**Take the magazine matching your nozzle.** The badge recess is cut exactly one
first layer deep, so its depth is a property of the nozzle: 0.2 mm at 0.4,
0.3 mm at 0.6. The wrong one either stands proud by a layer or never fills. The
rails suit either nozzle.

No supports. A brim on the 300 mm rail, which needs 325 mm of build height.

The files are STL and plain **core-spec 3MF** — geometry and filament
assignment, no slicer profile baked in, so your own settings apply. The badge
is on filament 2; on a single extruder, delete the badge part and swap filament
at layers 2 and 3 instead.

### What you need besides the print

Per magazine: **4 × M2.5 × 6 mm countersunk** screws, hex drive (into 2.05 mm
holes), **1 × M3 × 16 mm button head** (ISO 7380) as the coil spring's guide, and a
**compression spring** about 4 mm outside diameter, 20 mm free length, 0.4 mm
wire. All threads form straight in the plastic — no inserts, no nuts. The
rail's leaf spring is printed.

Full assembly instructions are in the PDF with the download.

### The label maker

Scan a reel barcode with a USB scanner, or paste a code, and it tells you which
magazine to print for that part and generates a two-colour label card sized to
the slot.

**{{PAGES_URL}}**

DigiKey and Mouser Data Matrix, LCSC/JLCPCB QR, or bare part numbers. It works
the tape width out of the package, standard-against-XL out of the reel
quantity, and checks the lettering is coarse enough for your nozzle before you
print. Nothing is looked up online, so it works on a bench PC with no internet.

### Source

Parametric OpenSCAD and the tooling that builds every plate:
**{{REPO_URL}}**

---

### This is a remix — the credit chain

Most of this geometry is not mine:

- **@LordAsdi** — the original SMD Component Tape Magazine, CC-BY 4.0
  https://www.printables.com/model/580643
- **T. Wirtl (tobi)** — rebuilt it as parametric OpenSCAD, CC-BY-SA 4.0
- **Bryan Varner** — the Varnerized Edition, the version this started from,
  CC-BY-SA 4.0 — https://www.printables.com/model/1350841
- **Robin Reiter** — not a code ancestor, the inspiration for the release lip

Licensed **CC-BY-SA 4.0**, inherited from that chain. Anything you make from
this carries the same licence and the same credits.
