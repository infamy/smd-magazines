#!/bin/bash
# Build every printable variant: six magazines and two rails.
#
#   ./build.sh              everything
#   ./build.sh magazine-standard-12mm   one variant
#
# Outputs land in ../print (ready-to-load 3MFs) and ../stl/<variant> (raw STLs).
# Outputs are plain core-spec 3MFs: geometry and two filament colours, no slicer
# profile baked in. Building needs only OpenSCAD and python3 - no slicer at all.
# The badge is grouped with its body as 3MF components, so a slicer's Arrange
# cannot slide it out of its recess.
set -euo pipefail

OPENSCAD=${OPENSCAD:-/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD}
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
PRINT="$ROOT/print"
STL="$ROOT/stl"

BODY_COLOUR="#9AA0A6"
ACCENT_COLOUR="#101010"

# Magazines are built once per nozzle, because the badge recess must be exactly
# one first layer deep and that height is a property of the nozzle. Nothing else
# in the design is nozzle-dependent, so the rails are built once and work with
# either - rail.scad's line_width (1.3mm) is two 0.65 perimeters on a 0.6 and
# three 0.43 lines on a 0.4, and narrowing it would only stop 0.4-nozzle caps
# fitting 0.6-nozzle rails.
NOZZLES="0.4 0.6"
first_layer_for() { [ "$1" = "0.4" ] && echo 0.2 || echo 0.3; }

VARIANTS="all
magazine-standard-8mm magazine-standard-12mm magazine-standard-16mm
magazine-xl-8mm magazine-xl-12mm magazine-xl-16mm
rail-100mm rail-300mm rail-xl-100mm rail-xl-300mm"

WANT=${1:-all}
case " $(echo $VARIANTS) " in
    *" $WANT "*) ;;
    *) echo "unknown variant: $WANT"; echo "one of:"; echo "$VARIANTS" | tail -n +2 \
       | tr ' ' '\n' | sed '/^$/d;s/^/  /'; exit 1 ;;
esac
mkdir -p "$PRINT" "$STL"

# ------------------------------------------------------------------- magazines
# $1 variant name  $2 tape width  $3 extra -D options  $4..$6 bed positions
magazine() {
    local name=$1 w=$2 opts=$3 pbody=$4 plid=$5 pslider=$6 noz=$7
    [ "$WANT" = "all" ] || [ "$WANT" = "$name" ] || return 0
    local flh; flh=$(first_layer_for "$noz")
    local out="$STL/${noz}mm-nozzle/$name"
    local dest="$PRINT/${noz}mm-nozzle"
    mkdir -p "$out" "$dest"
    opts="$opts -D first_layer_height=$flh"
    echo "==> $name  (${noz}mm nozzle, ${flh}mm first layer)"
    for p in body badge lid slider; do
        printf '    %-7s ' "$p"
        rm -f "$out/$p.stl"          # never let a stale part survive a failure
        if ! bash -c "\"$OPENSCAD\" $opts -D plate_width=$w -D 'PART=\"$p\"' \
                 -o '$out/$p.stl' '$HERE/magazine_plate.scad'" 2>"$out/$p.err"; then
            echo "FAILED"; sed 's/^/      /' "$out/$p.err"; exit 1
        fi
        [ -s "$out/$p.stl" ] || { echo "FAILED - no output"; exit 1; }
        rm -f "$out/$p.err"
        echo "ok"
    done
    # body and badge move together so the badge stays in its recess
    python3 "$HERE/place_stl.py" --at "$pbody"   "$out/body.stl" "$out/badge.stl"
    python3 "$HERE/place_stl.py" --at "$plid"    "$out/lid.stl"
    python3 "$HERE/place_stl.py" --at "$pslider" "$out/slider.stl"
    python3 "$HERE/make_3mf.py" "$dest/$name.3mf" \
        --colours "$BODY_COLOUR,$ACCENT_COLOUR" \
        --object "$out/body.stl@1,$out/badge.stl@2" \
        --object "$out/lid.stl@1" --object "$out/slider.stl@1"
}

STD_OPTS=""
XL_OPTS="-D grow_x=12.5 -D grow_y=12.5 -D window_d=22 -D badge_note=\\\"XL\\\""

for noz in $NOZZLES; do
    for w in 8 12 16; do
        magazine "magazine-standard-${w}mm" "$w" "$STD_OPTS" "5,5" "90,5"  "170,5" "$noz"
    done
    for w in 8 12 16; do
        magazine "magazine-xl-${w}mm"       "$w" "$XL_OPTS"  "5,5" "115,5" "220,5" "$noz"
    done
done

# ----------------------------------------------------------------------- rails
rail() {
    local len=$1
    local grow=$2
    local tag=$3
    local name="rail${tag}-${len}mm"
    [ "$WANT" = "all" ] || [ "$WANT" = "$name" ] || return 0
    local out="$STL/rails/$name"
    mkdir -p "$out" "$PRINT/rails"
    echo "==> $name  (either nozzle)"
    for p in rail cap spring; do
        printf '    %-7s ' "$p"
        rm -f "$out/$p.stl"
        if ! "$OPENSCAD" -D "rail_grow_x=$grow" -D "PART=\"$p\"" -D "rail_len=$len" \
                -o "$out/$p.stl" "$HERE/rail_plate.scad" 2>"$out/$p.err"; then
            echo "FAILED"; sed 's/^/      /' "$out/$p.err"; exit 1
        fi
        [ -s "$out/$p.stl" ] || { echo "FAILED - no output"; exit 1; }
        rm -f "$out/$p.err"
        echo "ok"
    done
    python3 "$HERE/place_stl.py" --at "5,5"   "$out/rail.stl"
    python3 "$HERE/place_stl.py" --at "5,60"  "$out/cap.stl"
    python3 "$HERE/place_stl.py" --at "115,5" "$out/spring.stl"
    python3 "$HERE/make_3mf.py" "$PRINT/rails/$name.3mf" \
        --colours "$BODY_COLOUR" \
        --object "$out/rail.stl@1" --object "$out/cap.stl@1" --object "$out/spring.stl@1"
}

rail 100 0    ""
rail 300 0    ""
rail 100 12.5 "-xl"
rail 300 12.5 "-xl"

echo
echo "Done. Load anything from $PRINT"
find "$PRINT" -name '*.3mf' | sed "s|$PRINT/|  |" | sort
