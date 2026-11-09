shader_type canvas_item;

render_mode unshaded;



uniform vec4 ink : source_color = vec4(0.318, 0.161, 0.102, 1.0);



// Flood only the center's connected clear pixels. If they reach a window

// edge, leave the opening alone. Each uint encodes nine native pixels.

bool enclosed(uint empty_rows[9]) {

	uint reachable[9] = {0u, 0u, 0u, 0u, 16u, 0u, 0u, 0u, 0u};

	for (int step = 0; step < 81; step++) {

		uint next_rows[9];

		bool changed = false;

		for (int y = 0; y < 9; y++) {

			uint bits = reachable[y];

			uint up = y > 0 ? reachable[y - 1] : 0u;

			uint down = y < 8 ? reachable[y + 1] : 0u;

			uint grown = (bits | (bits << 1u) | (bits >> 1u) | up | down) & empty_rows[y];

			if ((grown & 257u) != 0u || ((y == 0 || y == 8) && grown != 0u)) {

				return false;

			}

			changed = changed || grown != bits;

			next_rows[y] = grown;

		}

		if (!changed) {

			return true;

		}

		for (int y = 0; y < 9; y++) {

			reachable[y] = next_rows[y];

		}

	}

	return false;

}



void fragment() {

	vec4 pixel = texture(TEXTURE, UV);

	float row = UV.y / TEXTURE_PIXEL_SIZE.y;

	float col = UV.x / TEXTURE_PIXEL_SIZE.x;

	// The articulated joints sit inside this band on the 144 x 112 canvas.

	if (pixel.a < 0.5 && row >= 56.0 && row < 92.0 && col >= 47.0 && col < 97.0) {

		uint empty_rows[9];

		for (int y = 0; y < 9; y++) {

			uint bits = 0u;

			for (int x = 0; x < 9; x++) {

				vec2 sample_uv = UV + vec2(float(x - 4), float(y - 4)) * TEXTURE_PIXEL_SIZE;

				if (texture(TEXTURE, sample_uv).a < 0.5) {

					bits |= 1u << uint(x);

				}

			}

			empty_rows[y] = bits;

		}

		if (enclosed(empty_rows)) {

			pixel = ink;

		}

	}

	COLOR = pixel;

}

