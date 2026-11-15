"""
Sol Survivor - enterable habitat module generator  (v2: game-matching detail)
==============================================================================
Blender 3.6 - 4.x.  Builds a complete, walk-in replacement for the current hab
in the SAME hard-surface style as the models already in the game, then exports
a GLB.

WHAT "SAME STYLE" MEANS (measured from the game's hab.glb / bed / terminal ...)
  * ~22,000 triangles for the hab, beveled and smooth shaded (rounded edges).
  * Riveted cream wall plates with dark seams between them, orange bands, a
    thick rounded dark rim ring where wall meets dome, bolt heads around a dark
    base plate, a silver dome with dark ribs + latitude rings + glowing light
    bars, apex hub with dish, mast and red beacon.
  * Hazard-striped door frame with dark pillars and slid-open door leaves,
    framed windows with navy glass, mullions and a teal light strip, steps with
    amber nosing and silver hand rails.
  * The game's own PBR material set (same colours / metallic / roughness /
    emission strengths), so it sits next to the existing models without a seam.
  Every object gets a Bevel + Edge Split modifier (applied by the GLB export)
  and smooth shading, exactly like the existing kit.

FURNITURE
  The bed, terminal, power switch and heater ALREADY EXIST in the game as
  bed.glb / terminal.glb / power_switch.glb / heater.glb. They are NOT rebuilt
  here: the script drops MARKER_* empties (position + facing) where those models
  go, and I place the real models there in Godot. Only things the kit does not
  have are modelled: lockers, a table with stools, conduits, light fittings,
  hatches, wall trim, floor deck. (Set PLACEHOLDER_FURNITURE = True to also get
  rough stand-ins for the four kit models.)

HOW TO RUN
  1. Blender -> Scripting workspace -> Open this file -> Run Script.
  2. Save the .blend first (File > Save As) if you want the GLB written next to
     it; otherwise it is written to your home folder (path is printed).
  3. Copy hab_enterable.glb to  res://assets/models/outpost/hab_enterable.glb
     and tell me; I wire it in (swap the old hab, place the kit furniture at the
     markers, interior lights, entry ramp if the 0.1 m steps need one).
  If Blender prints an error, paste the console text to me.

COORDINATES / ORIENTATION  (Blender Z-up, metres)
  * Origin = centre of the hab on the ground. Godot places it at (0, 0, -8).
  * Door faces -Y in Blender = +Z in Godot (towards the player spawn).
  * Floor top Z = 0.30, flush with the top step (steps rise 0.10 each).
  * Inner radius 3.2, outer wall 3.5, straight wall 2.85, interior apex ~4.9.
  * Door 1.81 m wide, 2.15 m tall above the floor, steps + rails outside.
  * Corridor docking collars at +X and -X (corridors end at x = +-3.7).

MARKERS (empties; rotation Z makes the model's FRONT face the room centre)
  MARKER_bed, MARKER_terminal, MARKER_power_switch, MARKER_heater (kit models)
  MARKER_door, MARKER_spawn_inside, MARKER_light_center, MARKER_light_desk
"""

import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

# ----------------------------------------------------------------------------
# Settings
# ----------------------------------------------------------------------------
EXPORT_GLB = True
EXPORT_FILENAME = "hab_enterable.glb"
PLACEHOLDER_FURNITURE = False      # True = rough stand-ins for bed/terminal/etc.

ROUND_SEGS = 48                    # segments for round parts (dome, cylinders)
PANELS = 24                        # wall plate columns (15 degrees each)
PANEL_DEG = 360.0 / PANELS

R_OUT = 3.50                       # outer plate surface
R_IN = 3.20                        # inner wall surface
CORE_R = R_OUT - 0.12              # silver core wall outer radius
WALL_H = 2.85                      # top of the straight wall
DOME_RISE_OUT = 2.25
DOME_RISE_IN = 2.05
FLOOR_Z = 0.30
DOOR_H = 2.15
DOOR_TOP = FLOOR_Z + DOOR_H
DOOR_A0, DOOR_A1 = 255.0, 285.0    # door gap in degrees (centred on 270 = -Y)
PHIS = [0, 10, 20, 30, 40, 50, 60, 70, 80]   # dome latitude samples (degrees)

WINDOW_ANGLES = [52.5, 97.5, 127.5, 232.5, 307.5]   # panel centres (no plate there)

# Bevel widths in metres (grouped so each object has one bevel setting).
B_NONE, B_TINY, B_SMALL, B_MED, B_LARGE, B_XL = 0.0, 0.004, 0.012, 0.020, 0.035, 0.060
# Thin parts bevel with 1 segment, chunky parts with 2, rivets/bolts not at all.
# This keeps the finished hab near the game's ~22k-triangle hab instead of far above it.
BEVEL_SEGMENTS_THIN = 1
BEVEL_SEGMENTS_CHUNKY = 2

# The game's material set, copied from the running game:
#   key: (sRGB hex, metallic, roughness, emission strength or 0)
MATERIALS = {
    "slate":    ("3B3550", 0.55, 0.45, 0.0),   # M05 deep slate
    "silver":   ("A7A9BD", 0.85, 0.30, 0.0),   # M08 silver metal
    "beige":    ("B7A28D", 0.10, 0.70, 0.0),   # M02 beige lining
    "orange":   ("E0622D", 0.10, 0.50, 0.0),   # M04 orange bands
    "mauve":    ("5E4D5C", 0.40, 0.50, 0.0),   # M06 mauve frames / ribs
    "cream":    ("E0CFBB", 0.05, 0.60, 0.0),   # M01 rivets, stools
    "pale":     ("EADCCB", 0.05, 0.55, 0.0),   # M00 wall plates
    "glass":    ("2C3A6B", 0.20, 0.12, 0.0),   # M10 navy glass
    "teal":     ("4FD1C5", 0.00, 0.50, 1.0),   # M13 teal glow
    "teal_hot": ("4FD1C5", 0.00, 0.50, 1.9),   # M12 bright teal
    "door":     ("CBB9A6", 0.10, 0.55, 0.0),   # M03 door leaves
    "amber":    ("F5A623", 0.10, 0.55, 0.0),   # M15 amber (steps, hazard blocks)
    "amber_on": ("F5A623", 0.00, 0.50, 2.3),   # M14 amber lamp
    "red_on":   ("FF3B30", 0.00, 0.50, 4.0),   # M16 red beacon
    "grey":     ("8A7585", 0.45, 0.45, 0.0),   # M07 mauve-grey
    "fab_lav":  ("9C88B8", 0.00, 0.90, 0.0),   # M38 lavender fabric
    "fab_teal": ("6FBFB6", 0.00, 0.90, 0.0),   # M39 teal fabric
}


# ----------------------------------------------------------------------------
# Small helpers
# ----------------------------------------------------------------------------
def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_to_rgba(hexstr):
    r = int(hexstr[0:2], 16) / 255.0
    g = int(hexstr[2:4], 16) / 255.0
    b = int(hexstr[4:6], 16) / 255.0
    return (srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b), 1.0)


def set_input(node, names, value):
    for name in names:
        if name in node.inputs:
            node.inputs[name].default_value = value
            return True
    return False


def get_material(key):
    name = "HabMat_" + key
    hexstr, metallic, rough, emission = MATERIALS[key]
    rgba = hex_to_rgba(hexstr)
    # Re-use an existing material but ALWAYS re-apply the values: a .blend that was
    # built by an older version of this script still holds stale HabMat_* materials
    # (wrong metallic/roughness, glowing amber) and would otherwise leak into the export.
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf is not None:
        set_input(bsdf, ["Base Color"], rgba)
        set_input(bsdf, ["Metallic"], metallic)
        set_input(bsdf, ["Roughness"], rough)
        if emission > 0.0:
            set_input(bsdf, ["Emission Color", "Emission"], rgba)
            set_input(bsdf, ["Emission Strength"], emission)
        else:
            set_input(bsdf, ["Emission Strength"], 0.0)
    mat.diffuse_color = rgba
    return mat


def rot_z(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Z")


def pol(r, a_rad, z):
    return Vector((r * math.cos(a_rad), r * math.sin(a_rad), z))


def radial_axis_rot(a_deg):
    """Rotation that turns a Z-axis cylinder so its axis points radially outward at a_deg."""
    return rot_z(a_deg) @ Matrix.Rotation(math.radians(90.0), 3, "Y")


class Loc:
    """Polar floor-plan spot. Local axes: dx radially outward, dy tangential (CCW)."""

    def __init__(self, radius, angle_deg):
        self.r = radius
        self.a = angle_deg
        self.rot = rot_z(angle_deg)
        self.base = pol(radius, math.radians(angle_deg), 0.0)

    def p(self, dx, dy, z):
        v = self.rot @ Vector((dx, dy, 0.0))
        return Vector((self.base.x + v.x, self.base.y + v.y, z))


def dome_point(radius, rise, phi_deg, a_rad, lift=0.0):
    phi = math.radians(phi_deg)
    return pol((radius + lift) * math.cos(phi), a_rad, WALL_H + (rise + lift) * math.sin(phi))


def dome_normal(phi_deg, a_rad):
    phi = math.radians(phi_deg)
    return Vector((math.cos(phi) * math.cos(a_rad), math.cos(phi) * math.sin(a_rad), math.sin(phi)))


# ----------------------------------------------------------------------------
# Geometry kit: closed solids grouped per (material, bevel width)
# ----------------------------------------------------------------------------
class Kit:
    def __init__(self):
        self.groups = {}

    def _bm(self, mat, bevel):
        key = (mat, bevel)
        if key not in self.groups:
            self.groups[key] = bmesh.new()
        return self.groups[key]

    # -- generic prism between two equally sized rings ------------------------
    def ring_prism(self, mat, bevel, top, bottom):
        bm = self._bm(mat, bevel)
        n = len(top)
        vt = [bm.verts.new(tuple(p)) for p in top]
        vb = [bm.verts.new(tuple(p)) for p in bottom]
        bm.faces.new(vt)
        bm.faces.new(list(reversed(vb)))
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new([vt[i], vt[j], vb[j], vb[i]])

    def box(self, mat, bevel, center, size, rot=None):
        sx, sy, sz = size[0] / 2.0, size[1] / 2.0, size[2] / 2.0
        r = rot if rot is not None else Matrix.Identity(3)
        c = Vector(center)
        corners = [(-sx, -sy), (sx, -sy), (sx, sy), (-sx, sy)]
        bottom = [c + r @ Vector((x, y, -sz)) for x, y in corners]
        top = [c + r @ Vector((x, y, sz)) for x, y in corners]
        self.ring_prism(mat, bevel, top, bottom)

    def cyl(self, mat, bevel, center, radius, height, seg=12, rot=None):
        r = rot if rot is not None else Matrix.Identity(3)
        c = Vector(center)
        h = height / 2.0
        top, bottom = [], []
        for i in range(seg):
            a = 2.0 * math.pi * i / seg
            x, y = radius * math.cos(a), radius * math.sin(a)
            top.append(c + r @ Vector((x, y, h)))
            bottom.append(c + r @ Vector((x, y, -h)))
        self.ring_prism(mat, bevel, top, bottom)

    def beam(self, mat, bevel, p0, p1, width, thick, up=(0.0, 0.0, 1.0)):
        """Rectangular bar from p0 to p1; `thick` is measured along `up`."""
        p0, p1 = Vector(p0), Vector(p1)
        d = (p1 - p0)
        if d.length < 1e-6:
            return
        d = d * (1.0 / d.length)
        upv = Vector(up)
        side = d.cross(upv)
        if side.length < 1e-6:
            side = d.cross(Vector((1.0, 0.0, 0.0)))
        side = side * (1.0 / side.length)
        nrm = side.cross(d)
        nrm = nrm * (1.0 / nrm.length)
        hw, ht = width / 2.0, thick / 2.0
        offs = [(-hw, -ht), (hw, -ht), (hw, ht), (-hw, ht)]
        bottom = [p0 + side * x + nrm * y for x, y in offs]
        top = [p1 + side * x + nrm * y for x, y in offs]
        self.ring_prism(mat, bevel, top, bottom)

    # -- arc segment of a wall (outer radius > inner radius), shared vertices --
    def arc(self, mat, bevel, r_out, r_in, a0, a1, z0, z1, max_step=7.5):
        bm = self._bm(mat, bevel)
        span = a1 - a0
        closed = span >= 359.999
        n = max(3 if closed else 1, int(math.ceil(span / max_step)))
        count = n if closed else n + 1
        angles = [math.radians(a0 + span * i / n) for i in range(count)]
        ob = [bm.verts.new(tuple(pol(r_out, a, z0))) for a in angles]
        ot = [bm.verts.new(tuple(pol(r_out, a, z1))) for a in angles]
        ib = [bm.verts.new(tuple(pol(r_in, a, z0))) for a in angles]
        it = [bm.verts.new(tuple(pol(r_in, a, z1))) for a in angles]
        last = count if closed else count - 1
        for i in range(last):
            j = (i + 1) % count
            bm.faces.new([ob[i], ob[j], ot[j], ot[i]])      # outer
            bm.faces.new([ib[i], it[i], it[j], ib[j]])      # inner
            bm.faces.new([ob[i], ib[i], ib[j], ob[j]])      # bottom
            bm.faces.new([ot[i], ot[j], it[j], it[i]])      # top
        if not closed:
            bm.faces.new([ob[0], ib[0], it[0], ot[0]])
            bm.faces.new([ob[-1], ot[-1], it[-1], ib[-1]])

    # -- solid of revolution; profile runs axis -> axis ------------------------
    def lathe_solid(self, mat, bevel, profile, segs=ROUND_SEGS, center=(0, 0, 0), rot=None):
        bm = self._bm(mat, bevel)
        r = rot if rot is not None else Matrix.Identity(3)
        c = Vector(center)
        rings = []
        for rad, z in profile:
            if rad < 1e-9:
                rings.append([bm.verts.new(tuple(c + r @ Vector((0.0, 0.0, z))))])
            else:
                ring = []
                for i in range(segs):
                    a = 2.0 * math.pi * i / segs
                    ring.append(bm.verts.new(tuple(c + r @ Vector((rad * math.cos(a), rad * math.sin(a), z)))))
                rings.append(ring)
        for k in range(len(rings) - 1):
            A, B = rings[k], rings[k + 1]
            if len(A) == 1 and len(B) == 1:
                continue
            for i in range(segs):
                j = (i + 1) % segs
                if len(A) == 1:
                    bm.faces.new([A[0], B[i], B[j]])
                elif len(B) == 1:
                    bm.faces.new([A[i], A[j], B[0]])
                else:
                    bm.faces.new([A[i], A[j], B[j], B[i]])

    # -- hollow shell of revolution (open at both ends of the profile) --------
    def lathe_shell(self, mat, bevel, outer, inner, segs=ROUND_SEGS):
        bm = self._bm(mat, bevel)
        O = [[bm.verts.new(tuple(pol(rad, 2.0 * math.pi * i / segs, z))) for i in range(segs)] for rad, z in outer]
        I = [[bm.verts.new(tuple(pol(rad, 2.0 * math.pi * i / segs, z))) for i in range(segs)] for rad, z in inner]
        for k in range(len(O) - 1):
            for i in range(segs):
                j = (i + 1) % segs
                bm.faces.new([O[k][i], O[k][j], O[k + 1][j], O[k + 1][i]])
                bm.faces.new([I[k][i], I[k + 1][i], I[k + 1][j], I[k][j]])
        for ring_o, ring_i in ((O[0], I[0]), (O[-1], I[-1])):
            for i in range(segs):
                j = (i + 1) % segs
                bm.faces.new([ring_o[i], ring_o[j], ring_i[j], ring_i[i]])


# ----------------------------------------------------------------------------
# Wall helpers
# ----------------------------------------------------------------------------
def panel_is_door(p):
    a0 = p * PANEL_DEG
    return a0 >= DOOR_A0 - 0.01 and a0 + PANEL_DEG <= DOOR_A1 + 0.01


def panel_center(p):
    return p * PANEL_DEG + PANEL_DEG / 2.0


def panel_is_window(p):
    c = panel_center(p)
    return any(abs(c - w) < 0.01 for w in WINDOW_ANGLES)


def panel_is_leaf(p):
    a0 = p * PANEL_DEG
    return abs(a0 - (DOOR_A0 - PANEL_DEG)) < 0.01 or abs(a0 - DOOR_A1) < 0.01


def rivet(kit, a_deg, r, z, outward=1.0):
    """Small round rivet head with its axis along the wall normal."""
    kit.cyl("cream", B_NONE, pol(r + outward * 0.006, math.radians(a_deg), z), 0.022, 0.014,
            seg=6, rot=radial_axis_rot(a_deg))


def window(kit, a_deg, r, side):
    """Framed window: dark frame, navy glass, mullions, teal strip. side=+1 outside, -1 inside."""
    rot = rot_z(a_deg)
    a = math.radians(a_deg)
    zc = 1.45
    kit.box("slate", B_SMALL, pol(r, a, zc), (0.14, 0.98, 0.76), rot)
    kit.box("glass", B_TINY, pol(r + side * 0.035, a, zc), (0.05, 0.84, 0.62), rot)
    kit.box("slate", B_TINY, pol(r + side * 0.07, a, zc), (0.025, 0.035, 0.64), rot)
    kit.box("slate", B_TINY, pol(r + side * 0.07, a, zc), (0.025, 0.86, 0.035), rot)
    kit.box("teal_hot", B_TINY, pol(r + side * 0.075, a, zc - 0.22), (0.02, 0.60, 0.04), rot)


# ----------------------------------------------------------------------------
# Shell
# ----------------------------------------------------------------------------
def build_walls(kit):
    # Silver core wall (also the interior wall structure) with the door gap + lintel.
    kit.arc("silver", B_MED, CORE_R, R_IN, DOOR_A1, DOOR_A0 + 360.0, 0.0, WALL_H)
    kit.arc("silver", B_MED, CORE_R, R_IN, DOOR_A0, DOOR_A1, DOOR_TOP, WALL_H)

    # Orange bands (rounded), continuous except the door; dark rim ring wall/dome.
    kit.arc("orange", B_LARGE, R_OUT + 0.035, CORE_R - 0.01, DOOR_A1, DOOR_A0 + 360.0, 0.34, 0.66)
    kit.arc("orange", B_LARGE, R_OUT + 0.035, CORE_R - 0.01, DOOR_A1, DOOR_A0 + 360.0, 2.10, 2.42)
    kit.arc("slate", B_XL, R_OUT + 0.12, R_IN, 0.0, 360.0, 2.50, 2.82)

    # Dark base plate with bolt heads (door left open).
    kit.arc("slate", B_XL, 3.98, 3.30, DOOR_A1, DOOR_A0 + 360.0, 0.0, 0.28)
    for k in range(48):
        a = k * 7.5
        if DOOR_A0 - 4.0 < a < DOOR_A1 + 4.0:
            continue
        kit.cyl("cream", B_SMALL, pol(3.76, math.radians(a), 0.31), 0.075, 0.06, seg=8)

    # Riveted outer plates between the bands: one per 15 degrees, skipping the
    # door, the two door-leaf panels and the window panels.
    for p in range(PANELS):
        if panel_is_door(p) or panel_is_leaf(p) or panel_is_window(p):
            continue
        a0 = p * PANEL_DEG
        kit.arc("pale", B_MED, R_OUT, CORE_R - 0.01, a0 + 0.9, a0 + PANEL_DEG - 0.9, 0.72, 2.02)
        for da in (2.2, PANEL_DEG - 2.2):
            for z in (0.82, 1.92):
                rivet(kit, a0 + da, R_OUT, z)

    # Interior lining plates (beige) with rivets; skip the door and window panels.
    for p in range(PANELS):
        if panel_is_door(p) or panel_is_window(p):
            continue
        a0 = p * PANEL_DEG
        kit.arc("beige", B_MED, R_IN, R_IN - 0.06, a0 + 0.9, a0 + PANEL_DEG - 0.9, 0.55, 2.40)
        for da in (2.2, PANEL_DEG - 2.2):
            for z in (0.68, 2.27):
                rivet(kit, a0 + da, R_IN - 0.06, z, outward=-1.0)
    # Interior skirting (dark) and upper trim (mauve).
    kit.arc("slate", B_MED, R_IN, R_IN - 0.14, DOOR_A1, DOOR_A0 + 360.0, FLOOR_Z, 0.55)
    kit.arc("mauve", B_MED, R_IN, R_IN - 0.10, 0.0, 360.0, 2.40, 2.62)

    # Windows: outside and matching (blind) windows inside.
    for a in WINDOW_ANGLES:
        window(kit, a, R_OUT, +1)
        window(kit, a, R_IN - 0.06, -1)


def build_dome(kit):
    ro, ri = R_OUT - 0.05, R_IN
    outer = [(ro * math.cos(math.radians(p)), WALL_H + DOME_RISE_OUT * math.sin(math.radians(p))) for p in PHIS]
    inner = [(ri * math.cos(math.radians(p)), WALL_H + DOME_RISE_IN * math.sin(math.radians(p))) for p in PHIS]
    kit.lathe_shell("silver", B_MED, outer, inner)

    last = PHIS[-1]
    top_out = WALL_H + DOME_RISE_OUT * math.sin(math.radians(last))
    top_in = WALL_H + DOME_RISE_IN * math.sin(math.radians(last))

    # Outer ribs: 12 meridians + two latitude rings (mauve), light bars (teal).
    steps = PHIS[:-1] + [78]
    for k in range(12):
        a = math.radians(k * 30.0)
        pts = [dome_point(ro, DOME_RISE_OUT, p, a, 0.014) for p in steps]
        for i in range(len(pts) - 1):
            kit.beam("mauve", B_TINY, pts[i], pts[i + 1], 0.075, 0.03, dome_normal(steps[i], a))
    for lat in (35, 60):
        pts = [dome_point(ro, DOME_RISE_OUT, lat, math.radians(i * 360.0 / 48), 0.014) for i in range(48)]
        for i in range(48):
            a = math.radians(i * 360.0 / 48)
            kit.beam("mauve", B_TINY, pts[i], pts[(i + 1) % 48], 0.06, 0.03, dome_normal(lat, a))
    for a_deg in (240.0, 300.0):
        a = math.radians(a_deg)
        kit.beam("teal_hot", B_SMALL, dome_point(ro, DOME_RISE_OUT, 27, a, 0.02),
                 dome_point(ro, DOME_RISE_OUT, 33, a, 0.02), 0.20, 0.04, dome_normal(30, a))

    # Apex hub, dish, mast and beacon (outside).
    kit.lathe_solid("slate", B_LARGE, [(0, -0.10), (0.78, -0.10), (0.78, 0.10), (0.55, 0.22), (0, 0.22)],
                    center=(0, 0, top_out))
    kit.cyl("slate", B_SMALL, (0, 0, top_out + 0.60), 0.045, 0.80, seg=10)
    kit.lathe_solid("red_on", B_SMALL, [(0, -0.09), (0.06, -0.06), (0.09, 0), (0.06, 0.06), (0, 0.09)],
                    segs=16, center=(0, 0, top_out + 1.04))
    dish_rot = Matrix.Rotation(math.radians(-28.0), 3, "X")
    kit.lathe_solid("cream", B_SMALL, [(0, -0.03), (0.34, -0.03), (0.34, 0.03), (0, 0.03)],
                    segs=24, center=(0.0, -0.30, top_out + 0.42), rot=dish_rot)
    kit.beam("grey", B_TINY, (0.0, 0.0, top_out + 0.22), (0.0, -0.30, top_out + 0.42), 0.04, 0.04)
    kit.beam("silver", B_TINY, (0.45, 0.10, top_out + 0.2), (0.60, 0.10, top_out + 1.5), 0.012, 0.012)

    # Interior: ribs, ring conduit, light bars, hub underside and pendant lamp.
    for k in range(12):
        a = math.radians(k * 30.0)
        pts = [dome_point(ri, DOME_RISE_IN, p, a, -0.012) for p in steps]
        for i in range(len(pts) - 1):
            kit.beam("mauve", B_TINY, pts[i], pts[i + 1], 0.07, 0.03, -dome_normal(steps[i], a))
    for lat, mat, w in ((18, "silver", 0.07), (45, "grey", 0.05)):
        pts = [dome_point(ri, DOME_RISE_IN, lat, math.radians(i * 360.0 / 48), -0.04) for i in range(48)]
        for i in range(48):
            a = math.radians(i * 360.0 / 48)
            kit.beam(mat, B_TINY, pts[i], pts[(i + 1) % 48], w, w, -dome_normal(lat, a))
    for k in range(6):
        a = math.radians(k * 60.0 + 30.0)
        kit.beam("teal_hot", B_SMALL, dome_point(ri, DOME_RISE_IN, 33, a, -0.03),
                 dome_point(ri, DOME_RISE_IN, 41, a, -0.03), 0.18, 0.04, -dome_normal(37, a))
    kit.lathe_solid("slate", B_LARGE, [(0, -0.06), (0.80, -0.06), (0.80, 0.08), (0, 0.08)],
                    center=(0, 0, top_in - 0.05))
    kit.cyl("slate", B_TINY, (0, 0, top_in - 0.36), 0.03, 0.55, seg=8)
    kit.lathe_solid("teal_hot", B_SMALL, [(0, -0.05), (0.34, -0.05), (0.34, 0.03), (0.20, 0.07), (0, 0.07)],
                    center=(0, 0, top_in - 0.68))


def build_door_and_steps(kit):
    centre = 270.0
    for s, a_e in ((-1.0, DOOR_A0), (1.0, DOOR_A1)):
        loc = Loc(R_OUT - 0.02, a_e)
        pos = loc.p(0.0, s * 0.14, (DOOR_TOP + 0.20) / 2.0)
        kit.box("slate", B_LARGE, pos, (0.40, 0.30, DOOR_TOP + 0.20), loc.rot)
        kit.box("teal_hot", B_TINY, loc.p(0.22, s * 0.04, 1.30), (0.03, 0.05, 0.75), loc.rot)
        kit.box("teal", B_TINY, loc.p(0.22, s * 0.17, 1.85), (0.03, 0.09, 0.09), loc.rot)

    # Lintel with hazard blocks.
    lin = Loc(R_OUT - 0.02, centre)
    door_w = 2.0 * R_OUT * math.sin(math.radians(PANEL_DEG))
    kit.box("slate", B_LARGE, lin.p(0.0, 0.0, DOOR_TOP + 0.10), (0.40, door_w + 0.62, 0.36), lin.rot)
    for i in range(7):
        dy = (i - 3) * 0.36
        kit.box("amber", B_SMALL, lin.p(0.22, dy, DOOR_TOP + 0.10), (0.03, 0.20, 0.20), lin.rot)

    # Door leaves slid open over the neighbouring panels (pale, grooved, orange handle).
    for s, a_c in ((-1.0, DOOR_A0 - 7.5), (1.0, DOOR_A1 + 7.5)):
        loc = Loc(R_OUT + 0.075, a_c)
        kit.box("door", B_MED, loc.p(0.0, 0.0, 1.38), (0.09, 0.86, 2.15), loc.rot)
        for z in (0.55, 1.30, 2.05):
            kit.box("slate", B_TINY, loc.p(0.05, 0.0, z), (0.015, 0.82, 0.02), loc.rot)
        kit.box("orange", B_SMALL, loc.p(0.06, -s * 0.28, 1.05), (0.03, 0.05, 0.50), loc.rot)
        for dy in (-0.36, 0.36):
            for z in (0.40, 2.30):
                kit.cyl("cream", B_NONE, loc.p(0.05, dy, z), 0.02, 0.014, seg=6, rot=radial_axis_rot(a_c))

    # Threshold, steps with amber nosing, silver hand rails.
    kit.box("slate", B_MED, (0.0, -3.30, FLOOR_Z - 0.05), (door_w, 0.60, 0.10))
    steps = [(0.3, -3.35, -3.95), (0.2, -3.95, -4.35), (0.1, -4.35, -4.75)]
    for height, y_near, y_far in steps:
        depth = abs(y_far - y_near)
        yc = (y_near + y_far) / 2.0
        kit.box("mauve", B_MED, (0.0, yc, height / 2.0), (1.9, depth, height))
        kit.box("amber", B_SMALL, (0.0, y_far + 0.03, height + 0.004), (1.9, 0.06, 0.012))
    for x in (-1.02, 1.02):
        for y, h in ((-3.50, 0.95), (-4.66, 0.70)):
            kit.cyl("silver", B_SMALL, (x, y, h / 2.0), 0.03, h, seg=10)
        kit.beam("silver", B_SMALL, (x, -3.50, 0.95), (x, -4.66, 0.72), 0.045, 0.045)
        kit.beam("silver", B_SMALL, (x, -3.50, 0.55), (x, -4.66, 0.40), 0.03, 0.03)


def build_docking_collars(kit):
    for a_deg in (0.0, 180.0):
        rot = radial_axis_rot(a_deg)
        out = Loc(R_OUT + 0.18, a_deg)
        kit.cyl("slate", B_LARGE, out.p(0, 0, 1.10), 0.80, 0.50, seg=24, rot=rot)
        kit.cyl("amber", B_SMALL, out.p(0.20, 0, 1.10), 0.86, 0.05, seg=24, rot=rot)
        for k in range(8):
            ang = 2.0 * math.pi * k / 8.0
            bolt = out.p(0.24, 0.69 * math.cos(ang), 1.10 + 0.69 * math.sin(ang))
            kit.cyl("cream", B_NONE, bolt, 0.02, 0.016, seg=6, rot=rot)

        # Interior hatch: flange, amber ring, wheel and status lamp.
        inn = Loc(R_IN - 0.08, a_deg)
        kit.cyl("slate", B_LARGE, inn.p(0, 0, 1.10), 0.74, 0.12, seg=24, rot=rot)
        kit.cyl("amber", B_SMALL, inn.p(-0.04, 0, 1.10), 0.66, 0.05, seg=24, rot=rot)
        kit.cyl("mauve", B_SMALL, inn.p(-0.09, 0, 1.10), 0.55, 0.07, seg=24, rot=rot)
        for k in range(3):
            ang = math.radians(90.0 + k * 120.0)
            tip = inn.p(-0.15, 0.46 * math.cos(ang), 1.10 + 0.46 * math.sin(ang))
            kit.beam("silver", B_TINY, inn.p(-0.15, 0, 1.10), tip, 0.045, 0.03, inn.rot @ Vector((1, 0, 0)))
        kit.cyl("silver", B_SMALL, inn.p(-0.16, 0, 1.10), 0.07, 0.05, seg=10, rot=rot)
        kit.box("teal_hot", B_TINY, inn.p(-0.06, 0, 1.10 + 0.62), (0.03, 0.14, 0.05), inn.rot)


# ----------------------------------------------------------------------------
# Floor and interior props (things the kit does not have)
# ----------------------------------------------------------------------------
def build_floor(kit):
    kit.lathe_solid("slate", B_MED, [(0, FLOOR_Z - 0.20), (R_IN - 0.01, FLOOR_Z - 0.20),
                                     (R_IN - 0.01, FLOOR_Z), (0, FLOOR_Z)])
    kit.arc("orange", B_TINY, 2.32, 2.20, 0.0, 360.0, FLOOR_Z, FLOOR_Z + 0.014)
    kit.arc("teal", B_TINY, 3.02, 2.98, 0.0, 360.0, FLOOR_Z, FLOOR_Z + 0.012)
    for k in range(12):
        a = k * 30.0
        kit.beam("mauve", B_TINY, pol(0.9, math.radians(a), FLOOR_Z + 0.006),
                 pol(2.18, math.radians(a), FLOOR_Z + 0.006), 0.03, 0.012)
    kit.lathe_solid("fab_lav", B_TINY, [(0, 0), (1.30, 0), (1.30, 0.014), (0, 0.014)], segs=32,
                    center=(0, 0.8, FLOOR_Z))


def build_props(kit):
    z0 = FLOOR_Z
    # Lockers (silver doors, vents, orange cap stripe, amber handles, status lamp).
    lock = Loc(2.88, 320.0)
    r = lock.rot
    for dy in (-0.68, 0.0, 0.68):
        kit.box("silver", B_MED, lock.p(0, dy, z0 + 0.95), (0.55, 0.62, 1.90), r)
        kit.box("orange", B_SMALL, lock.p(-0.28, dy, z0 + 1.84), (0.03, 0.62, 0.08), r)
        for k in range(4):
            kit.box("slate", B_TINY, lock.p(-0.28, dy, z0 + 1.42 + k * 0.05), (0.02, 0.36, 0.018), r)
        kit.box("amber", B_SMALL, lock.p(-0.29, dy + 0.20, z0 + 0.95), (0.04, 0.05, 0.26), r)
        kit.box("teal_hot", B_TINY, lock.p(-0.28, dy - 0.20, z0 + 1.62), (0.02, 0.05, 0.05), r)
    kit.box("slate", B_MED, lock.p(0, 0, z0 + 0.04), (0.60, 2.15, 0.08), r)

    # Round table with stools (lathe, matching the kit's rounded look).
    kit.lathe_solid("mauve", B_SMALL, [(0, 0), (0.36, 0), (0.36, 0.04), (0.08, 0.10), (0.08, 0.68), (0, 0.68)],
                    segs=20, center=(0.0, 0.8, z0))
    kit.lathe_solid("beige", B_SMALL, [(0, 0.68), (0.58, 0.68), (0.58, 0.74), (0.52, 0.76), (0, 0.76)],
                    segs=28, center=(0.0, 0.8, z0))
    kit.lathe_solid("amber", B_TINY, [(0, 0.76), (0.50, 0.76), (0.50, 0.768), (0, 0.768)], segs=28,
                    center=(0.0, 0.8, z0))
    for sx, sy in ((-0.98, 0.8), (0.98, 0.8), (0.0, 1.78)):
        kit.lathe_solid("slate", B_SMALL, [(0, 0), (0.16, 0), (0.05, 0.05), (0.05, 0.34), (0, 0.34)],
                        segs=14, center=(sx, sy, z0))
        kit.lathe_solid("fab_teal", B_SMALL, [(0, 0.34), (0.22, 0.34), (0.22, 0.43), (0.17, 0.46), (0, 0.46)],
                        segs=16, center=(sx, sy, z0))

    # Wall conduits with clamps between the bed and the terminal.
    for a_deg in (84.0, 90.0):
        loc = Loc(R_IN - 0.16, a_deg)
        kit.cyl("mauve", B_SMALL, loc.p(0, 0, 1.55), 0.045, 2.5, seg=10)
        for z in (0.6, 1.4, 2.2):
            kit.box("silver", B_TINY, loc.p(0, 0, z), (0.07, 0.14, 0.05), loc.rot)
    kit.beam("silver", B_SMALL, Loc(R_IN - 0.16, 84.0).p(0, 0, 2.5), Loc(R_IN - 0.16, 90.0).p(0, 0, 2.5), 0.05, 0.05)

    # Light panels above the lockers and the table.
    kit.box("teal", B_SMALL, Loc(R_IN - 0.08, 320.0).p(0, 0, 2.18), (0.05, 1.7, 0.10), Loc(R_IN, 320.0).rot)


# ----------------------------------------------------------------------------
# Optional rough stand-ins for the four kit models
# ----------------------------------------------------------------------------
def build_placeholders(kit, spots):
    for name, (loc, size, mat) in spots.items():
        kit.box(mat, B_MED, loc, size)


# ----------------------------------------------------------------------------
# Scene output
# ----------------------------------------------------------------------------
def clear_old():
    for obj in list(bpy.data.objects):
        if obj.name.startswith("Hab_") or obj.name.startswith("MARKER_"):
            bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        if mesh.name.startswith("Hab_") and mesh.users == 0:
            bpy.data.meshes.remove(mesh)
    for mat in list(bpy.data.materials):
        if mat.name.startswith("HabMat_") and mat.users == 0:
            bpy.data.materials.remove(mat)


def add_modifiers(obj, bevel):
    if bevel > 0.0:
        bev = obj.modifiers.new("HabBevel", "BEVEL")
        bev.width = bevel
        bev.segments = BEVEL_SEGMENTS_CHUNKY if bevel >= B_MED else BEVEL_SEGMENTS_THIN
        bev.limit_method = "ANGLE"
        bev.angle_limit = math.radians(40.0)
        bev.use_clamp_overlap = True
    split = obj.modifiers.new("HabEdgeSplit", "EDGE_SPLIT")
    split.use_edge_angle = True
    split.use_edge_sharp = False
    split.split_angle = math.radians(38.0)


def finish(kit, markers):
    collection = bpy.context.scene.collection
    created = []
    for (mat_key, bevel), bm in kit.groups.items():
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        name = "Hab_%s_b%02d" % (mat_key, int(round(bevel * 1000.0)))
        mesh = bpy.data.meshes.new(name)
        bm.to_mesh(mesh)
        bm.free()
        if hasattr(mesh, "shade_smooth"):
            mesh.shade_smooth()
        else:
            for poly in mesh.polygons:
                poly.use_smooth = True
        mesh.materials.append(get_material(mat_key))
        obj = bpy.data.objects.new(name, mesh)
        collection.objects.link(obj)
        add_modifiers(obj, bevel)
        created.append(obj)

    for name, (loc, yaw_deg) in markers.items():
        empty = bpy.data.objects.new(name, None)
        empty.empty_display_type = "PLAIN_AXES"
        empty.empty_display_size = 0.3
        empty.location = loc
        empty.rotation_euler = (0.0, 0.0, math.radians(yaw_deg))
        collection.objects.link(empty)
        created.append(empty)
    return created


def build_markers():
    """Kit furniture goes here. yaw = a - 90 makes the model's front (-Y) face the centre."""
    def spot(radius, a_deg, z):
        loc = Loc(radius, a_deg)
        return (loc.p(0, 0, z), a_deg - 90.0)

    markers = {
        "MARKER_bed": spot(2.55, 50.0, FLOOR_Z),
        "MARKER_terminal": spot(2.70, 115.0, FLOOR_Z),
        "MARKER_power_switch": spot(R_IN - 0.55, 150.0, FLOOR_Z),
        "MARKER_heater": spot(2.80, 210.0, FLOOR_Z),
        "MARKER_door": (Vector((0.0, -3.30, FLOOR_Z)), 0.0),
        "MARKER_spawn_inside": (Vector((0.0, -1.5, FLOOR_Z)), 0.0),
        "MARKER_light_center": (Vector((0.0, 0.0, 3.9)), 0.0),
        "MARKER_light_desk": (Vector((-1.2, 2.2, 2.6)), 0.0),
    }
    return markers


def export_glb():
    folder = os.path.dirname(bpy.data.filepath) if bpy.data.filepath else os.path.expanduser("~")
    path = os.path.join(folder, EXPORT_FILENAME)
    try:
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True)
        print("[hab] exported GLB ->", path)
    except Exception as exc:  # noqa: BLE001 - report instead of failing silently
        print("[hab] GLB export failed:", exc)
        print("[hab] Use File > Export > glTF 2.0 (.glb) manually (tick Apply Modifiers).")
    return path


def main():
    clear_old()
    kit = Kit()
    build_walls(kit)
    build_dome(kit)
    build_door_and_steps(kit)
    build_docking_collars(kit)
    build_floor(kit)
    build_props(kit)
    markers = build_markers()
    if PLACEHOLDER_FURNITURE:
        build_placeholders(kit, {
            "bed": (markers["MARKER_bed"][0] + Vector((0, 0, 0.6)), (2.5, 1.2, 1.2), "fab_lav"),
            "terminal": (markers["MARKER_terminal"][0] + Vector((0, 0, 0.85)), (1.5, 1.1, 1.7), "slate"),
            "power": (markers["MARKER_power_switch"][0] + Vector((0, 0, 1.3)), (1.2, 1.0, 2.6), "slate"),
            "heater": (markers["MARKER_heater"][0] + Vector((0, 0, 0.85)), (1.1, 0.7, 1.7), "orange"),
        })
    objs = finish(kit, markers)
    print("[hab] built %d objects (door %.2f m, floor Z %.2f, inner radius %.2f)"
          % (len(objs), 2.0 * R_OUT * math.sin(math.radians(PANEL_DEG)), FLOOR_Z, R_IN))
    if EXPORT_GLB:
        export_glb()


main()
