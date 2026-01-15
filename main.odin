package qr_odin

import "core:fmt"

import stbi "vendor:stb/image"

main :: proc() {
	data   := "Hello World!"
	level  := Error_Correction_Level.L
	size   := bitmap_width(len(data), level) or_else panic("")
	pixels := make([]byte, size * size)
	generate_bitmap(data, pixels, level, 0)
	fmt.println("penalty:", evaluate_penalty(pixels, size))
	stbi.write_png("output.png", i32(size), i32(size), 1, raw_data(pixels), 0)
}
