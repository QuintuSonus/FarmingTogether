// highlight_outline.gdshader (Corrected Identifier)
shader_type spatial;
// Use cull_front for the outline pass, cull_back for the main pass.
// We'll control this via the material's cull mode property instead of render_mode here.
// render_mode unshaded; // Keep unshaded if you don't want lighting

// Uniforms to control the outline from GDScript
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 0.0, 1.0); // Yellow default
uniform float outline_width : hint_range(0.0, 0.1) = 0.01;
uniform bool enabled = true; // Toggle the effect

void vertex() {
	// Only apply offset if the outline is enabled
	if (enabled) {
			// Apply offset to VERTEX (vec3) in model space, not POSITION (vec4)
			VERTEX += NORMAL * outline_width;
	}
}

void fragment() {
	// Only apply color if the outline is enabled
	if (enabled) {
		// This fragment shader is primarily for the OUTLINE pass (when cull_mode is CULL_FRONT).
		// It assumes the material using this shader has cull_mode set to CULL_FRONT.
		ALBEDO = outline_color.rgb;
		ALPHA = outline_color.a;

		// Example using FRONT_FACE (underscore, not space) if not using separate cull modes:
		// if (!FRONT_FACE) { // Back faces (outline) - Correct identifier
		//	 ALBEDO = outline_color.rgb;
		//	 ALPHA = outline_color.a;
		// } else { // Front faces (original object)
		//	 // Discard or sample original texture
		//	 discard; // Or ALPHA = 0.0;
		// }
	} else {
		// If disabled, discard the fragment entirely.
		discard; // Or ALPHA = 0.0;
	}
}

