# SMD Component Tape Magazines

Magazines for SMD parts on cut tape, in two capacities and three tape widths,
plus the rail they clip to.

A derivative work — the geometry that matters is not mine. Credits and licence
are at the end of this document.

---

## What to print

Take the magazines from the folder matching **your nozzle**. The badge recess is
cut exactly one first layer deep, so its depth is a property of the nozzle:
0.2 mm at 0.4, 0.3 mm at 0.6. Print a 0.3 mm recess with a 0.2 mm first layer
and the badge stands proud by a layer; the other way round it never fills.

| | |
|---|---|
| `magazine-standard-8/12/16mm` | holds about 800 of 0603 |
| `magazine-xl-8/12/16mm` | holds about 1600 of 0603 |
| `rail-100mm`, `rail-300mm` | standard magazines |
| `rail-xl-100mm`, `rail-xl-300mm` | XL magazines |

The rails suit **either nozzle** — one set works with both.

Each magazine plate carries three objects and four parts. The badge is a second
*part* of the body object rather than a separate object, so a slicer's Arrange
moves the pair together and cannot slide it out of its recess.

### Print settings

Nothing exotic. No supports, no brim except on the long rail.

- **Layer height** whatever suits your nozzle. The first layer must match the
  folder you took the files from.
- **Two colours** — the badge comes assigned to filament 2, so it arrives on
  the second colour with nothing to set up, and only the size marking changes
  colour. On a single extruder, delete the badge part and swap filament at
  layers 2 and 3 instead; that leaves a thin accent line round the whole part,
  which the separate badge avoids.
- **The 300 mm rail prints standing**, 302 mm tall on a 70.7 × 34.2 mm
  footprint. Slender enough to want a brim, and it needs 325 mm of build height.
- **The leaf spring ships in segments** — a 300 mm rail gets 3 × 100 mm. They
  butt end to end in the channel and are held by the rail base and the cap,
  exactly as one long leaf would be. Past about 100 mm a 0.8 mm ribbon curls off
  the bed and is awkward to thread.

---

## What you need besides the print

Per magazine:

| | |
|---|---|
| 4 × **M2.5 × 6 mm countersunk**, hex drive, thread-forming | into 2.05 mm holes |
| 1 × **M3 × 16 mm button head** (ISO 7380), thread-forming | the coil spring's guide, into a 2.5 mm hole |
| 1 × compression spring | about 4 mm outside diameter, 20 mm free length, 0.4 mm wire |

The screws thread straight into the plastic — no inserts, no nuts. The M3 head
sits recessed so it cannot catch as you click the magazine onto the rail.

The rail's leaf spring is printed, not bought. The rail has mounting feet at
95 mm centres; what goes through them depends on where you are putting it.

---

## Assembly

1. **Body.** Drop the coil spring into the pocket at the front, then run the M3
   button head down its middle and into the tapped hole. It threads into bare
   plastic; stop when the head is seated, do not crank it.
2. **Slider.** The slider's bore runs over the M3 shank, so the screw guides the
   spring instead of the spring wandering. Check it moves freely before the lid
   goes on.
3. **Badge.** If you printed it as a separate part, it drops into the recess.
4. **Lid.** Four M2.5 × 6 mm countersunk screws. Thread-forming into bare plastic, so
   go gently on the first turn.
5. **Label.** Print a label card and slide it into the slot on the top edge.
6. **Rail.** Thread the leaf spring segments into the channel end to end, then
   fit the cap. Mount the rail, then click the magazines on.

---

## Labelling them

There is a label maker for these — a single web page. Scan a reel barcode with
a USB scanner or paste a code, and it tells you which magazine to print for that
part and generates a two-colour label card sized to the slot.

It reads DigiKey and Mouser Data Matrix, LCSC/JLCPCB QR, and bare part numbers,
and works out the tape width from the package and standard-against-XL from the
reel quantity. Nothing is looked up online — the barcode already carries the
part number and quantity.

**https://www.meshmeld.com/smd-magazines/**

---

## Source

The whole thing is parametric OpenSCAD, and the build produces plain core-spec
3MF — geometry and filament assignment, no slicer profile baked in.

**https://github.com/infamy/smd-magazines**

---

## Credit and licence

This is a derivative work. The geometry that matters — body, lid, slider, rail
and leaf spring — is not mine.

- **@LordAsdi** — the original SMD Component Tape Magazine, CC-BY 4.0.
  <https://www.printables.com/model/580643>
- **T. Wirtl (tobi)** — the parametric OpenSCAD remix that turned those STLs
  into adjustable code, CC-BY-SA 4.0.
- **Bryan Varner** — the Varnerized Edition, the version this started from,
  CC-BY-SA 4.0. <https://www.printables.com/model/1350841>
- **Robin Reiter** — not a code ancestor, the *inspiration*. His "SMD Magazines
  G2" video is where the anti-release lip idea comes from.

Added here: the anti-release lip, the two-colour badge, the XL size, the long
rail, and a label maker.

**Licensed CC-BY-SA 4.0**, inherited from the chain above — not a choice.
Anything you make from this carries the same licence and the same credits.

---
