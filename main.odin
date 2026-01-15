package qr_odin

import stbi "vendor:stb/image"

main :: proc() {
	level   := Error_Correction_Level.L
	mask    := 6
	version := 1
	size    := (version - 1) * 4 + 21
	pixels  := make([]byte, size * size, context.temp_allocator)
	place_fixed_patterns(pixels, size, version)
	place_info_bits(pixels, size, version, level, mask)

	eci := error_correction_infos[version][level]

	out := make([]byte, eci.data_words)
	n   := generate_data_bits(version, level, transmute([]byte)string("shutdown now"), out)

	PAD_A :: u8(0b00110111)
	PAD_B :: u8(0b10001000)

	pad := PAD_A
	for n < int(eci.data_words) {
		out[n] = pad
		n     += 1
		pad   ~= PAD_A ~ PAD_B
	}

	einfo := error_correction_infos[version][level]
	ecs   := make([]byte, einfo.error_words_per_block * (einfo.blocks_group1 + einfo.blocks_group2))
	error_correction_codes_generate(einfo, out, ecs)

	place_data_bits(pixels, size, einfo, version, out, ecs, mask)

	finalize(pixels)
	stbi.write_png("output.png", i32(size), i32(size), 1, raw_data(pixels), 0)
}
