import bpy
import bmesh
import math
import os
import random
from mathutils import Vector, Matrix

out_dir = "/home/kensai/sol-survivor/assets/models"
os.makedirs(out_dir, exist_ok=True)

# Strict Palette Constants
COL_PEACH = (0.957, 0.663, 0.533, 1.0)
COL_RUST = (0.757, 0.314, 0.180, 1.0)
COL_LAVENDER = (0.612, 0.533, 0.722, 1.0)
COL_DEEP_BLUE = (0.169, 0.227, 0.404, 1.0)
COL_OFFWHITE = (0.953, 0.902, 0.855, 1.0)
COL_TEAL = (0.310, 0.820, 0.773, 1.0)
COL_MAUVE_BROWN = (0.361, 0.259, 0.282, 1.0)
COL_BOOT_TINT = (0.58, 0.26, 0.18, 1.0)

def create_matte_material(name, color, roughness=0.92, metallic=0.0, emissive=None, emission_strength=1.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emissive:
        bsdf.inputs["Emission Color"].default_value = emissive
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

# ==============================================================================
# 1. FOREGROUND BOULDER (Faceted sharp low-poly boulder in mauve-brown #5C4248)
# ==============================================================================
def generate_foreground_boulder():
    clear_scene()
    mat = create_matte_material("Mat_Boulder", COL_MAUVE_BROWN, roughness=0.92)

    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)

    # Deform vertices to match reference low-poly faceted rock
    random.seed(42)
    for v in bm.verts:
        p = v.co
        # Flatten underside so it sits flush on the sand
        if p.z < -0.25:
            p.z = -0.25 + (p.z + 0.25) * 0.15
        # Scale into elongated blocky boulder
        p.x *= 1.4
        p.y *= 1.1
        p.z *= 0.85
        # Angular facet perturbations
        if p.x > 0.3 and p.z > 0.1:
            p.x *= 1.15
            p.z += 0.2
        if p.x < -0.2:
            p.y *= 1.25
        # Random faceted jitter
        p += Vector((random.uniform(-0.06, 0.06), random.uniform(-0.06, 0.06), random.uniform(-0.04, 0.04)))
    
    bmesh.ops.triangulate(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new("BoulderMesh")
    bm.to_mesh(mesh)
    bm.free()

    obj = bpy.data.objects.new("ForegroundBoulder", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    for p in obj.data.polygons:
        p.use_smooth = False

    path = os.path.join(out_dir, "foreground_boulder.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=False)
    print("Generated foreground_boulder.glb")

# ==============================================================================
# 2. MOUNTAIN BACKDROP (Layered low-poly faceted mountain ranges)
# ==============================================================================
def generate_mountain_backdrop():
    clear_scene()
    
    mat_near = create_matte_material("Mat_NearMtn", (0.54, 0.29, 0.28, 1.0), roughness=0.95)
    mat_mid = create_matte_material("Mat_MidMtn", (0.68, 0.38, 0.32, 1.0), roughness=0.95)
    mat_far = create_matte_material("Mat_FarMtn", (0.82, 0.52, 0.42, 1.0), roughness=0.95)

    ranges = [
        {"name": "NearRange", "radius": 45.0, "height": 14.0, "count": 22, "mat": mat_near, "z_min": -0.8},
        {"name": "MidRange",  "radius": 65.0, "height": 22.0, "count": 26, "mat": mat_mid,  "z_min": -0.7},
        {"name": "FarRange",  "radius": 95.0, "height": 34.0, "count": 30, "mat": mat_far,  "z_min": -0.6},
    ]

    for r in ranges:
        bm = bmesh.new()
        count = r["count"]
        radius = r["radius"]
        base_h = r["height"]
        
        # Arc covering the horizon behind outpost in -Z direction
        # In Blender, +Y exports to -Z in Godot!
        start_ang = -1.2
        end_ang = 1.2
        
        pts_top = []
        pts_bot = []
        
        random.seed(int(radius))
        for i in range(count + 1):
            t = i / float(count)
            ang = start_ang + t * (end_ang - start_ang)
            rad_var = radius + random.uniform(-2.0, 2.0)
            x = math.sin(ang) * rad_var
            y = math.cos(ang) * rad_var # +Y in Blender = -Z in Godot (in front of camera!)
            
            # Mountain peak profile
            h_var = base_h * (0.65 + 0.7 * abs(math.sin(t * 7.5 + radius)))
            h_var += random.uniform(-2.0, 3.5)
            
            v_bot = bm.verts.new((x, y, -1.0))
            v_top = bm.verts.new((x, y, h_var))
            pts_bot.append(v_bot)
            pts_top.append(v_top)
            
        bm.verts.ensure_lookup_table()
        # Create triangular facets between adjacent columns
        for i in range(count):
            b0 = pts_bot[i]
            b1 = pts_bot[i + 1]
            t0 = pts_top[i]
            t1 = pts_top[i + 1]
            
            # Midpoint vertex for low-poly faceted look
            mid_x = (b0.co.x + b1.co.x + t0.co.x + t1.co.x) * 0.25 + random.uniform(-1.0, 1.0)
            mid_y = (b0.co.y + b1.co.y + t0.co.y + t1.co.y) * 0.25 + random.uniform(-1.0, 1.0)
            mid_z = (t0.co.z + t1.co.z) * 0.45 + random.uniform(-1.0, 1.5)
            v_mid = bm.verts.new((mid_x, mid_y, mid_z))
            
            bm.faces.new((b0, b1, v_mid))
            bm.faces.new((b1, t1, v_mid))
            bm.faces.new((t1, t0, v_mid))
            bm.faces.new((t0, b0, v_mid))
            
        bmesh.ops.triangulate(bm, faces=bm.faces)
        mesh = bpy.data.meshes.new(r["name"] + "Mesh")
        bm.to_mesh(mesh)
        bm.free()
        
        obj = bpy.data.objects.new(r["name"], mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.data.materials.append(r["mat"])
        for p in obj.data.polygons:
            p.use_smooth = False

    path = os.path.join(out_dir, "mountain_backdrop.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=False)
    print("Generated mountain_backdrop.glb")

# ==============================================================================
# 3. FACETED LOW-POLY TERRAIN (Faceted triangles in peach/rust with gentle dunes)
# ==============================================================================
def generate_faceted_terrain():
    clear_scene()
    
    mat_terrain = create_matte_material("Mat_Terrain", COL_PEACH, roughness=0.92)
    
    bm = bmesh.new()
    size = 110.0
    segs = 36
    step = size / segs
    half = size * 0.5
    
    grid = []
    random.seed(1337)
    for ix in range(segs + 1):
        col = []
        for iy in range(segs + 1):
            gx = -half + ix * step
            gy = -half + iy * step
            dist = math.sqrt(gx * gx + gy * gy)
            
            # Keep base outpost flat in center, gentle dunes outside
            z = 0.0
            if dist > 8.0:
                dune = math.sin(gx * 0.08) * math.cos(gy * 0.06) * 0.8
                dune += math.sin(gx * 0.15 + 1.2) * 0.35
                jitter = random.uniform(-0.12, 0.12)
                z = dune + jitter
            else:
                z = random.uniform(-0.02, 0.02)
                
            v = bm.verts.new((gx, gy, z))
            col.append(v)
        grid.append(col)
        
    bm.verts.ensure_lookup_table()
    for ix in range(segs):
        for iy in range(segs):
            v0 = grid[ix][iy]
            v1 = grid[ix + 1][iy]
            v2 = grid[ix + 1][iy + 1]
            v3 = grid[ix][iy + 1]
            # Triangulate alternating for crisp low-poly facet look
            if (ix + iy) % 2 == 0:
                bm.faces.new((v0, v1, v2))
                bm.faces.new((v0, v2, v3))
            else:
                bm.faces.new((v0, v1, v3))
                bm.faces.new((v1, v2, v3))
                
    bmesh.ops.triangulate(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new("TerrainMesh")
    bm.to_mesh(mesh)
    bm.free()
    
    obj = bpy.data.objects.new("TerrainGround", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(mat_terrain)
    for p in obj.data.polygons:
        p.use_smooth = False
        
    path = os.path.join(out_dir, "terrain_ground.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=False)
    print("Generated terrain_ground.glb")

# ==============================================================================
# 4. CABLE SYSTEM WITH CLAMPS (Thick dark cables running hab -> gh -> solar)
# ==============================================================================
def generate_cable_system():
    clear_scene()
    mat_cable = create_matte_material("Mat_Cable", COL_DEEP_BLUE, roughness=0.90)
    mat_clamp = create_matte_material("Mat_Clamp", (0.28, 0.32, 0.42, 1.0), roughness=0.85)

    # Waypoints for main cable running from hab stairs across sand towards greenhouse and solar
    # Blender coords (Blender -Y = Godot +Z towards camera, Blender +Y = Godot -Z towards horizon)
    waypoints = [
        Vector((-3.2, -0.4, 0.03)), # Base of hab stairs (Godot: X=-3.2, Z=0.4)
        Vector((-2.4, -0.8, 0.03)),
        Vector((-1.2, -1.2, 0.03)),
        Vector((0.0, -1.0, 0.03)),  # Mid sand curve
        Vector((1.4, -0.6, 0.03)),
        Vector((2.4, 0.4, 0.03)),   # Near greenhouse base ring
        Vector((3.8, 0.2, 0.03)),
        Vector((5.2, -0.2, 0.03)),  # Heading to solar arrays
        Vector((7.0, -0.5, 0.03)),
        Vector((9.2, -0.4, 0.03)),
    ]

    # Create multi-segment cylinder cable
    cable_bm = bmesh.new()
    for i in range(len(waypoints) - 1):
        p0 = waypoints[i]
        p1 = waypoints[i + 1]
        mid = (p0 + p1) * 0.5
        delta = p1 - p0
        length = delta.length
        
        # Segment cylinder
        cyl_bm = bmesh.new()
        bmesh.ops.create_cone(cyl_bm, cap_ends=True, cap_tris=False, segments=8, radius1=0.045, radius2=0.045, depth=length)
        
        # Align cylinder (default Z axis) along delta vector
        up = Vector((0, 0, 1))
        axis = up.cross(delta)
        angle = up.angle(delta)
        if axis.length > 0.0001:
            axis.normalize()
            rot_mat = Matrix.Rotation(angle, 4, axis)
        else:
            rot_mat = Matrix.Identity(4)
        trans_mat = Matrix.Translation(mid)
        cyl_bm.transform(trans_mat @ rot_mat)
        
        # Transform cylinder verts directly
        cyl_bm.transform(trans_mat @ rot_mat)
        
        v_map = {}
        for v in cyl_bm.verts:
            v_map[v] = cable_bm.verts.new(v.co)
        for f in cyl_bm.faces:
            cable_bm.faces.new([v_map[v] for v in f.verts])
        cyl_bm.free()

    bmesh.ops.triangulate(cable_bm, faces=cable_bm.faces)
    cable_mesh = bpy.data.meshes.new("CableMesh")
    cable_bm.to_mesh(cable_mesh)
    cable_bm.free()
    cable_obj = bpy.data.objects.new("GroundCables", cable_mesh)
    bpy.context.scene.collection.objects.link(cable_obj)
    cable_obj.data.materials.append(mat_cable)
    for p in cable_obj.data.polygons:
        p.use_smooth = False

    # Clamps along the cable
    clamp_bm = bmesh.new()
    clamp_indices = [1, 3, 5, 7, 9]
    for idx in clamp_indices:
        pos = waypoints[idx]
        bmesh.ops.create_cube(clamp_bm, size=1.0)
        # Scale to clamp size: wide across cable, thin along cable
        # Transform last cube
        clamp_verts = clamp_bm.verts[-8:]
        for v in clamp_verts:
            v.co.x *= 0.16
            v.co.y *= 0.08
            v.co.z *= 0.06
            v.co += pos + Vector((0, 0, 0.02))

    bmesh.ops.triangulate(clamp_bm, faces=clamp_bm.faces)
    clamp_mesh = bpy.data.meshes.new("ClampMesh")
    clamp_bm.to_mesh(clamp_mesh)
    clamp_bm.free()
    clamp_obj = bpy.data.objects.new("CableClamps", clamp_mesh)
    bpy.context.scene.collection.objects.link(clamp_obj)
    clamp_obj.data.materials.append(mat_clamp)
    for p in clamp_obj.data.polygons:
        p.use_smooth = False

    path = os.path.join(out_dir, "cable_system.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=False)
    print("Generated cable_system.glb")

# ==============================================================================
# 5. FOOTPRINT TRAIL (Boot tread prints leading from hab stairs into foreground)
# ==============================================================================
def generate_footprint_trail():
    clear_scene()
    mat_boot = create_matte_material("Mat_Bootprint", COL_BOOT_TINT, roughness=0.98)

    bm = bmesh.new()
    
    # Trail starts at hab stairs (-3.2, -0.4 in Blender -> Godot X=-3.2, Z=0.4)
    # and winds forward into camera foreground (0.0, -5.8 in Blender -> Godot X=0.0, Z=5.8)
    steps_count = 16
    for i in range(steps_count):
        t = i / float(steps_count - 1)
        # S-curve path across the sand
        x_center = -3.2 * (1.0 - t) + 0.05 * t + math.sin(t * 3.1415) * 0.6
        y_center = -0.4 * (1.0 - t) + (-5.8) * t
        
        # Alternating left and right feet
        side = -0.15 if (i % 2 == 0) else 0.15
        step_x = x_center + side
        step_y = y_center
        
        # Heel oval
        heel_bm = bmesh.new()
        bmesh.ops.create_cone(heel_bm, cap_ends=True, cap_tris=False, segments=12, radius1=0.07, radius2=0.07, depth=0.012)
        # Scale into shoe heel
        for v in heel_bm.verts:
            v.co.x *= 1.0
            v.co.y *= 1.3
            v.co += Vector((step_x, step_y - 0.09, 0.008))
            
        # Sole / ball of foot oval
        sole_bm = bmesh.new()
        bmesh.ops.create_cone(sole_bm, cap_ends=True, cap_tris=False, segments=12, radius1=0.085, radius2=0.085, depth=0.012)
        for v in sole_bm.verts:
            v.co.x *= 1.15
            v.co.y *= 1.6
            v.co += Vector((step_x, step_y + 0.08, 0.008))
            
        # Add heel to main bm
        v_map_heel = {v: bm.verts.new(v.co) for v in heel_bm.verts}
        for f in heel_bm.faces:
            bm.faces.new([v_map_heel[v] for v in f.verts])
        heel_bm.free()
        
        # Add sole to main bm
        v_map_sole = {v: bm.verts.new(v.co) for v in sole_bm.verts}
        for f in sole_bm.faces:
            bm.faces.new([v_map_sole[v] for v in f.verts])
        sole_bm.free()

    bmesh.ops.triangulate(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new("FootprintMesh")
    bm.to_mesh(mesh)
    bm.free()

    obj = bpy.data.objects.new("FootprintTrail", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(mat_boot)
    for p in obj.data.polygons:
        p.use_smooth = False

    path = os.path.join(out_dir, "footprint_trail.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=False)
    print("Generated footprint_trail.glb")

# Run all generators
generate_foreground_boulder()
generate_mountain_backdrop()
generate_faceted_terrain()
generate_cable_system()
generate_footprint_trail()
print("All reference assets generated successfully!")
