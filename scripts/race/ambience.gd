class_name Ambience
extends RefCounted
## Lumière et ciel d'un circuit : ciel dessiné (dégradé, soleil, nuages
## lointains), lumière ambiante et reflets venus du ciel, soleil, brume au
## loin, et rendu de l'image (couleurs, éclat des lumières) selon la qualité
## des graphismes. Utilisé par la course et par la vitrine des modèles.

const SKY_SHADER := """
shader_type sky;
uniform vec3 top_color : source_color = vec3(0.18, 0.5, 0.88);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.86, 1.0);
uniform vec3 ground_color : source_color = vec3(0.3, 0.45, 0.25);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.82);
uniform vec3 cloud_color : source_color = vec3(1.0);
uniform vec3 cloud_shadow : source_color = vec3(0.72, 0.78, 0.9);
uniform float cloud_cover = 0.45;
uniform float sun_size = 0.035;

float hash2(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x),
		mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise2(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	vec3 col;
	if (d.y >= 0.0) {
		col = mix(horizon_color, top_color, pow(clamp(d.y, 0.0, 1.0), 0.5));
	} else {
		col = mix(horizon_color, ground_color, clamp(-d.y * 5.0, 0.0, 1.0));
	}
	vec3 sun_dir = LIGHT0_ENABLED ? LIGHT0_DIRECTION : normalize(vec3(0.4, 0.6, -0.5));
	float sd = max(dot(d, sun_dir), 0.0);
	// nuages : couche dessinée au-dessus de l'horizon, plus claire côté soleil
	if (d.y > 0.0 && cloud_cover > 0.0) {
		vec2 uv = d.xz / (d.y + 0.18) * 1.6;
		float n = fbm(uv);
		float c = smoothstep(1.0 - cloud_cover, 1.18 - cloud_cover, n);
		float n2 = fbm(uv + normalize(sun_dir.xz + vec2(0.001)) * 0.12);
		float lit = clamp((n - n2) * 5.0 + 0.55, 0.0, 1.0);
		vec3 cc = mix(cloud_shadow, cloud_color, lit) + sun_color * pow(sd, 6.0) * 0.25;
		col = mix(col, cc, c * smoothstep(0.0, 0.18, d.y) * 0.95);
	}
	// soleil et halo
	float disk = smoothstep(cos(sun_size), cos(sun_size * 0.7), sd);
	col += sun_color * (disk * (AT_CUBEMAP_PASS ? 2.0 : 5.0) + pow(sd, 250.0) * 0.8 + pow(sd, 10.0) * 0.12);
	COLOR = col;
}
"""

static var _sky_shader: Shader


## Applique le thème d'un circuit (ciel, soleil, brume) et la qualité des graphismes.
static func apply(env: Environment, sun: DirectionalLight3D, th: TrackTheme, level: int, advanced: bool) -> void:
	if _sky_shader == null:
		_sky_shader = Shader.new()
		_sky_shader.code = SKY_SHADER
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = _sky_shader
	sky_mat.set_shader_parameter("top_color", th.sky_top)
	sky_mat.set_shader_parameter("horizon_color", th.sky_horizon)
	sky_mat.set_shader_parameter("ground_color", th.hills_color.darkened(0.25))
	sky_mat.set_shader_parameter("sun_color", th.sun_color)
	sky_mat.set_shader_parameter("cloud_cover", th.sky_clouds)
	sky_mat.set_shader_parameter("cloud_shadow", th.sky_horizon.lerp(th.sky_top, 0.35).lerp(Color("#8d99ae"), 0.25))
	if env.sky == null:
		env.sky = Sky.new()
	env.sky.sky_material = sky_mat
	env.sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.background_mode = Environment.BG_SKY
	# lumière ambiante et reflets : ceux du ciel (dessus bleuté, dessous couleur du sol)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = th.ambient_energy * 1.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# brume au loin (perspective atmosphérique)
	env.fog_enabled = true
	env.fog_light_color = th.fog_color
	env.fog_density = th.fog_density
	env.fog_sky_affect = 0.0
	sun.light_color = th.sun_color
	sun.light_energy = th.sun_energy * 2.2
	sun.rotation_degrees = th.sun_rotation
	# Ombres du soleil : seulement avec le moteur de rendu avancé. Avec le rendu
	# « Compatibilité », une lumière qui fait des ombres est ajoutée dans une
	# seconde passe, mélangée après la conversion des couleurs (sRGB) : l'image
	# devient plus claire et délavée. Les karts et les arbres ont donc des
	# ombres douces dessinées sous eux (Kart, Scenery).
	sun.shadow_enabled = advanced
	sun.shadow_blur = 1.6 if advanced else 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 140.0 if level == AppSettings.Graphics.BEAU else 90.0
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 2.0
	# rendu de l'image : couleurs vives, lumières qui brillent un peu
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.1
	env.glow_enabled = level != AppSettings.Graphics.SIMPLE
	env.glow_intensity = 0.6
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# effets du moteur de rendu avancé (mode « Beau »)
	env.ssao_enabled = advanced
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.0
	env.ssao_light_affect = 0.2
