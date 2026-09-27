shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 10.0) = 3.0;

void fragment() {
	vec4 color = vec4(0.0);
	float total_weight = 0.0;
	int samples = 8;
	
	for (int i = 0; i < samples; i++) {
		float angle = float(i) / float(samples) * TAU;
		vec2 offset = vec2(cos(angle), sin(angle)) * blur_amount * SCREEN_PIXEL_SIZE;
		color += texture(TEXTURE, UV + offset);
		total_weight += 1.0;
	}
	
	COLOR = color / total_weight;
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
