package qr_odin

import "core:fmt"
import "core:os"
import "core:flags"

import stbi "vendor:stb/image"

Options :: struct {
	file:                   os.Handle `args:"pos=0,required,file=r" usage:"Input file."`,
	output:                 cstring   `args:"pos=1,required" usage:"Output file."`,
	error_correction_level: Error_Correction_Level `usage:"Set the error correction level."`,
}

main :: proc() {
	options: Options
	flags.parse_or_exit(&options, os.args)

	data, ok := os.read_entire_file(options.file, context.temp_allocator)
	if !ok {
		fmt.eprintln("Failed to read input file")
		os.exit(1)
	}
	size: int
	size, ok = bitmap_width(len(data), options.error_correction_level)
	if !ok {
		fmt.eprintln("Input file to large")
		os.exit(1)
	}
	pixels := make([]u8, size * size, context.temp_allocator)
	generate_bitmap(data, pixels, options.error_correction_level)
	if stbi.write_png(options.output, i32(size), i32(size), 1, raw_data(pixels), 0) == 0 {
		fmt.eprintln("Failed to write output file")
		os.exit(1)
	}
}
