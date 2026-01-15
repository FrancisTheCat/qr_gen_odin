package qr_odin

import "core:fmt"
import "core:time"

import stbi "vendor:stb/image"

main :: proc() {
	WARMUP :: 1000
	RUNS   :: 5000
	
	data    := "this is a qr code"
	level   := Error_Correction_Level.H
	version := 20
	size    := bitmap_width(len(data), level, version) or_else panic("")
	pixels  := make([]u8, size * size)
	for _ in 0 ..< WARMUP {
		generate_bitmap(data, pixels, level, min_version = version)
	}
	start_time := time.now()
	for _ in 0 ..< RUNS {
		generate_bitmap(data, pixels, level, min_version = version)
	}
	fmt.println(time.since(start_time) / RUNS)
	stbi.write_png("output.png", i32(size), i32(size), 1, raw_data(pixels), 0)
}
