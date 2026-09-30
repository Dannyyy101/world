class_name WeatherEffects
extends CanvasLayer
## Wetter-Partikel und Nebel-Overlay (Besitzer: Agent 3). Liegt auf Layer 5 (unter der UI auf Layer 10,
## über der Welt). Reagiert auf EventBus.weather_changed. Wird von PlayerStats als Kind erzeugt.

const VIEW_SIZE: Vector2 = Vector2(480.0, 270.0)
const FOG_SHADER: String = """
shader_type canvas_item;
uniform float density : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fog_color : source_color = vec4(0.82, 0.86, 0.9, 1.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
void fragment() {
	vec2 uv = UV * vec2(6.0, 3.5);
	float n = noise(uv + vec2(TIME * 0.05, 0.0)) * 0.6 + noise(uv * 2.0 - vec2(TIME * 0.03, TIME * 0.01)) * 0.4;
	COLOR = vec4(fog_color.rgb, density * (0.35 + 0.65 * n));
}
"""
const FOG_FADE_SPEED: float = 0.6

var _rain: CPUParticles2D
var _snow: CPUParticles2D
var _fog: ColorRect
var _fog_material: ShaderMaterial
var _fog_density: float = 0.0
var _fog_target: float = 0.0


func _ready() -> void:
	layer = 5
	_rain = _make_rain()
	_snow = _make_snow()
	add_child(_rain)
	add_child(_snow)
	_fog = ColorRect.new()
	_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog.size = VIEW_SIZE
	var shader: Shader = Shader.new()
	shader.code = FOG_SHADER
	_fog_material = ShaderMaterial.new()
	_fog_material.shader = shader
	_fog.material = _fog_material
	add_child(_fog)
	EventBus.weather_changed.connect(_on_weather_changed)


func _process(delta: float) -> void:
	_fog_density = move_toward(_fog_density, _fog_target, delta * FOG_FADE_SPEED)
	_fog_material.set_shader_parameter("density", _fog_density)
	_fog.visible = _fog_density > 0.001


func _on_weather_changed(weather: StringName) -> void:
	_rain.emitting = weather == &"rain" or weather == &"storm"
	_snow.emitting = weather == &"snow"
	if weather == &"storm":
		_rain.amount = 260
		_rain.initial_velocity_min = 260.0
		_rain.initial_velocity_max = 320.0
		_rain.direction = Vector2(-0.45, 1.0)
	else:
		_rain.amount = 120
		_rain.initial_velocity_min = 190.0
		_rain.initial_velocity_max = 230.0
		_rain.direction = Vector2(-0.15, 1.0)
	match weather:
		&"fog":
			_fog_target = 0.55
		&"snow":
			_fog_target = 0.12
		&"storm":
			_fog_target = 0.15
		_:
			_fog_target = 0.0


func _make_rain() -> CPUParticles2D:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.texture = _solid_texture(Vector2i(1, 4), Color(0.72, 0.82, 1.0, 0.75))
	p.position = Vector2(VIEW_SIZE.x * 0.5, -8.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(VIEW_SIZE.x * 0.7, 1.0)
	p.direction = Vector2(-0.15, 1.0)
	p.spread = 4.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 190.0
	p.initial_velocity_max = 230.0
	p.lifetime = 1.4
	p.amount = 120
	p.preprocess = 1.4
	p.emitting = false
	return p


func _make_snow() -> CPUParticles2D:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.texture = _solid_texture(Vector2i(2, 2), Color(1, 1, 1, 0.9))
	p.position = Vector2(VIEW_SIZE.x * 0.5, -8.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(VIEW_SIZE.x * 0.6, 1.0)
	p.direction = Vector2(0.0, 1.0)
	p.spread = 25.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 18.0
	p.initial_velocity_max = 34.0
	p.lifetime = 9.0
	p.amount = 110
	p.preprocess = 9.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	p.emitting = false
	return p


static func _solid_texture(size: Vector2i, col: Color) -> ImageTexture:
	var img: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(col)
	return ImageTexture.create_from_image(img)
