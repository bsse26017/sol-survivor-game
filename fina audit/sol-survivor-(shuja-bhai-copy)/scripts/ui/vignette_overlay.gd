## Full-screen subtle vignette and film grain overlay for cinematic pastel atmosphere.
extends CanvasLayer

func _ready() -> void:
	layer = 5 # Below HUD and dialogs, above 3D world
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

void fragment() {
    vec2 uv = UV - 0.5;
    float dist = length(uv);
    float vignette = smoothstep(0.35, 0.75, dist) * 0.28;
    float noise = fract(sin(dot(UV * 500.0 + vec2(TIME * 0.05), vec2(12.9898, 78.233))) * 43758.5453);
    COLOR = vec4(0.12, 0.08, 0.2, vignette + (noise - 0.5) * 0.015);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	add_child(rect)
