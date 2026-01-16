package qr_odin

import "core:fmt"
import "core:flags"
import "core:os"
import "core:time"

import stbi "vendor:stb/image"

Options :: struct {
	file:                   os.Handle `args:"pos=0,required,file=r" usage:"Input file."`,
	output:                 cstring   `args:"pos=1,required" usage:"Output file."`,
	error_correction_level: Error_Correction_Level `usage:"Set the error correction level."`,
	min_version:            int `usage:"Set the minimum QR code version."`,
	print_time:             bool `usage:"Print the time it took to generate the QR code."`,
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
	size, ok = bitmap_width(len(data), options.error_correction_level, options.min_version)
	if !ok {
		fmt.eprintln("Input file to large")
		os.exit(1)
	}
	pixels := make([]u8, size * size, context.temp_allocator)
	start := time.now()
	generate_bitmap(data, pixels, options.error_correction_level, min_version = options.min_version)
	if options.print_time {
		fmt.println(time.since(start))
	}
	if stbi.write_png(options.output, i32(size), i32(size), 1, raw_data(pixels), 0) == 0 {
		fmt.eprintln("Failed to write output file")
		os.exit(1)
	}
}
