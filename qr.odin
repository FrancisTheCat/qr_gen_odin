package qr_odin

import "core:slice"

import "base:intrinsics"

Error_Correction_Level :: enum {
	Low      = 0,
	Medium   = 1,
	Quartile = 2,
	High     = 3,

	L = Low,
	M = Medium,
	Q = Quartile,
	H = High,
}

Data_Encoding :: enum {
	Byte = 0b0100,
}

VERSION_MAX    :: 40
MASK_AUTOMATIC :: -1

@(private)
FIXED_MASK :: 0x80

generate_bitmap :: proc {
	generate_bitmap_bytes,
	generate_bitmap_string,
}

generate_bitmap_string :: proc(
	data:     string,
	bitmap:   []u8,
	ec_level: Error_Correction_Level,
	mask        := MASK_AUTOMATIC,
	min_version := 1,
) {
	generate_bitmap_bytes(transmute([]byte)data, bitmap, ec_level, mask, min_version)
}

generate_bitmap_bytes :: proc(
	data:     []byte,
	bitmap:   []u8,
	ec_level: Error_Correction_Level,
	mask        := MASK_AUTOMATIC,
	min_version := 1,
) {
	assert(mask < 8)
	slice.zero(bitmap)

	version := max(min_version, required_version(len(data), ec_level))
	size    := version_size(version)
	place_fixed_patterns(bitmap, size, version)

	eci := error_correction_infos[version][ec_level]

	_data_bits := make([]byte, eci.data_words + eci.error_words_per_block * (eci.blocks_group1 + eci.blocks_group2), context.temp_allocator)
	data_bits  := _data_bits[:eci.data_words]
	ecc_bits   := _data_bits[eci.data_words:]
	n          := generate_data_bits(version, ec_level, data, data_bits)

	PAD_A :: u8(0b00110111)
	PAD_B :: u8(0b10001000)

	pad := PAD_A
	for n < int(eci.data_words) {
		data_bits[n] = pad
		n           += 1
		pad         ~= PAD_A ~ PAD_B
	}

	error_correction_codes_generate(eci, data_bits, ecc_bits)

	if mask >= 0 {
		place_info_bits(bitmap, size, version, ec_level, mask)
		place_data_bits(bitmap, size, eci, version, data_bits, ecc_bits, mask)
	} else {
		place_info_bits(bitmap, size, version, ec_level, 0)
		place_data_bits(bitmap, size, eci, version, data_bits, ecc_bits, 0)

		best_mask := find_best_mask(bitmap, size, 0)

		if best_mask != 0 {
			place_info_bits(bitmap, size, version, ec_level, best_mask)
			change_mask(bitmap, size, 0, best_mask)
		}
	}

	finalize(bitmap)

	return
}

required_version :: proc(data_len: int, correction_level: Error_Correction_Level) -> int {
	for cap, version in level_capacities[correction_level] {
		if data_len <= int(cap) {
			return version + 1
		}
	}

	return -1
}

bitmap_width :: proc(data_len: int, correction_level: Error_Correction_Level, min_version := 1) -> (size: int, ok: bool) {
	version := required_version(data_len, correction_level)
	if version < 0 {
		return
	}

	return version_size(max(version, min_version)), true
}

version_size :: proc(version: int) -> int {
	return (version - 1) * 4 + 21
}

@(private)
character_count_bits :: proc(version: int) -> int {
	switch version {
	case 0 ..< 10:
		return 8
	case 10 ..< 27:
		return 16
	case 27 ..< 41:
		return 16
	case:
		unreachable()
	}
}

@(private)
place_fixed_patterns :: proc(pixels: []u8, size: int, version: int) {
	finder_pixel :: proc(pixels: []u8, size, x, y: int, v: bool) {
		pixels[x            +  y * size            ] = u8(v) | FIXED_MASK
		pixels[size - x - 1 +  y * size            ] = u8(v) | FIXED_MASK
		pixels[x            + (size - y - 1) * size] = u8(v) | FIXED_MASK
	}

	@(rodata, static)
	finder_pattern := [8][8]u8 {
		{ 0, 0, 0, 0, 0, 0, 0, 1, },
		{ 0, 1, 1, 1, 1, 1, 0, 1, },
		{ 0, 1, 0, 0, 0, 1, 0, 1, },
		{ 0, 1, 0, 0, 0, 1, 0, 1, },
		{ 0, 1, 0, 0, 0, 1, 0, 1, },
		{ 0, 1, 1, 1, 1, 1, 0, 1, },
		{ 0, 0, 0, 0, 0, 0, 0, 1, },
		{ 1, 1, 1, 1, 1, 1, 1, 1, },
	}

	for y in 0 ..< 8 {
		for x in 0 ..< 8 {
			#force_inline finder_pixel(pixels, size, x, y, finder_pattern[x][y] == 1)
		}
	}

	alignment_locations := alignment_locations[version]
	for y in alignment_locations {
		y := int(y)
		if y == 0 {
			break
		}
		for x in alignment_locations {
			x := int(x)
			if x == 0 {
				break
			}

			skip: bool
			for y in y - 2 ..= y + 2 {
				for x in x - 2 ..= x + 2 {
					if pixels[x + y * size] & FIXED_MASK != 0 {
						skip = true
					}
				}
			}

			if skip {
				continue
			}

			for y_ in y - 2 ..= y + 2 {
				for x_ in x - 2 ..= x + 2 {
					dx := abs(x - x_)
					dy := abs(y - y_)
					pixels[x_ + y_ * size] = u8(max(dx, dy) & 1) | FIXED_MASK
				}
			}
		}
	}

	// Timing patterns
	for i in 8 ..< size - 8 {
		pixels[i + size * 6] = u8(i & 1) | FIXED_MASK
		pixels[i * size + 6] = u8(i & 1) | FIXED_MASK
	}
}

@(private)
place_info_bits :: proc(pixels: []u8, size: int, version: int, level: Error_Correction_Level, mask: int) {
	format_string := format_strings[level][mask]
	assert(format_string != 0)

	pixels[(size - 8) * size + 8] = 0 | FIXED_MASK
	for i in 0 ..< 7 {
		v := u8(format_string & (1 << uint(14 - i)) == 0) | FIXED_MASK
		pixels[8 + size * (size - i - 1)] = v
	}
	for i in 0 ..< 8 {
		v := u8(format_string & (1 << uint(7 - i)) == 0) | FIXED_MASK
		pixels[8 * size + (size + i - 8)] = v
	}

	for i in 0 ..< 6 {
		v := u8(format_string & (1 << uint(14 - i)) == 0) | FIXED_MASK
		pixels[8 * size + i] = v
	}
	pixels[8 * size + 7] = u8(format_string & (1 << uint(14 - 6)) == 0) | FIXED_MASK
	pixels[8 * size + 8] = u8(format_string & (1 << uint(14 - 7)) == 0) | FIXED_MASK
	pixels[7 * size + 8] = u8(format_string & (1 << uint(14 - 8)) == 0) | FIXED_MASK
	for i in 0 ..< 6 {
		v := u8(format_string & (1 << uint(5 - i)) == 0) | FIXED_MASK
		pixels[(5 - i) * size + 8] = v
	}

	if version < 7 {
		return
	}

	version_info_string := version_info_strings[version]
	assert(version_info_string != 0)

	for i in 0 ..< 18 {
		v := u8(((version_info_string >> uint(i)) & 1) == 0) | FIXED_MASK
		pixels[i / 3 + size * (i % 3 + size - 11)] = v
		pixels[i % 3 + size - 11 + size * (i / 3)] = v
	}
}

@(private)
finalize :: proc(pixels: []u8) {
	for &pixel in pixels {
		pixel = -(pixel & 1)
	}
}

@(private)
append_bits :: proc(bytes: []byte, cursor: ^int, value: $T, n := size_of(T) << 3) {
	value := u64(value)
	for i in 0 ..< n {
		bit                 := u8((value >> uint(n - i - 1)) & 1)
		bytes[cursor^ >> 3] |= bit << (7 - uint(cursor^ & 7))
		cursor^             += 1
	}
}

@(private)
generate_data_bits :: proc(
	version:          int,
	correction_level: Error_Correction_Level,
	data:             []byte,
	out:              []byte,
) -> int {
	bit_cursor: int
	append_bits(out, &bit_cursor, Data_Encoding.Byte, 4)
	append_bits(out, &bit_cursor, len(data), character_count_bits(version))

	assert(bit_cursor % 8 == 4)
	for d in data {
		out[bit_cursor >> 3    ] |= d >> 4
		out[bit_cursor >> 3 + 1] |= d << 4
		bit_cursor                += 8
	}

	return (bit_cursor + 4) >> 3
}

@(private)
evaluate_mask :: proc(mask, row, col: int) -> bool {
	switch (mask) {
	case 0:
		return (col + row) % 2 == 0
	case 1:
		return row % 2 == 0
	case 2:
		return col % 3 == 0
	case 3:
		return (col + row) % 3 == 0
	case 4:
		return (row / 2 + col / 3) % 2 == 0
	case 5:
		return ((row * col) % 2) + ((row * col) % 3) == 0
	case 6:
		return (((row * col) % 2) + ((row * col) % 3)) % 2 == 0
	case 7:
		return (((row + col) % 2) + ((row * col) % 3)) % 2 == 0
	}

	return false
}

@(private)
place_data_bits :: proc(
	pixels:  []u8,
	size:    int,
	info:    Error_Correction_Info,
	version: int,
	data:    []byte,
	ecs:     []byte,
	mask:    int,
) {
	Cursor :: struct {
		x, y:       int,
		left, down: bool,
	}

	place_data_bit :: proc(
		pixels:  []u8,
		size:    int,
		cursor: ^Cursor,
		value:   bool,
		mask:    int,
	) {
		if cursor.x == 6 {
			cursor.x   -= 1
			cursor.left = false
		}

		row := cursor.y
		col := cursor.x - int(cursor.left)

		pixels[col + row * size] = u8(value ~ evaluate_mask(mask, row, col))

		step :: proc(
			pixels:  []u8,
			size:    int,
			cursor: ^Cursor,
		) {
			if !cursor.left {
				cursor.left = true
				return
			}

			cursor.left = false
			if cursor.down {
				cursor.y += 1
				if cursor.y == size {
					cursor.y   -= 1
					cursor.down = !cursor.down
					cursor.x   -= 2
				}
			} else {
				cursor.y -= 1
				if cursor.y < 0 {
					cursor.y    = 0
					cursor.down = !cursor.down
					cursor.x   -= 2
				}
			}
		}

		step(pixels, size, cursor)
		for pixels[cursor.x - int(cursor.left) + cursor.y * size] & FIXED_MASK != 0 {
			step(pixels, size, cursor)
		}
	}

	cursor := Cursor {
		x = size - 1,
		y = size - 1,
	}

	for dw in 0 ..< max(info.data_words_per_block_group1, info.data_words_per_block_group2) {
		if (dw < info.data_words_per_block_group1) {
			for block in 0 ..< info.blocks_group1 {
				d := data[dw + info.data_words_per_block_group1 * block]
				for j in 0 ..< uint(8) {
					b := (d & (0x80 >> j)) == 0
					place_data_bit(pixels, size, &cursor, b, mask)
				}
			}
		}

		if (dw < info.data_words_per_block_group2) {
			for block in 0 ..< info.blocks_group2 {
				d := data[dw + info.data_words_per_block_group2 * block + info.blocks_group1 * info.data_words_per_block_group1]
				for j in 0 ..< uint(8) {
					b := (d & (0x80 >> j)) == 0
					place_data_bit(pixels, size, &cursor, b, mask)
				}
			}
		}
	}

	for ew in 0 ..< info.error_words_per_block {
		for block in 0 ..< info.blocks_group1 + info.blocks_group2 {
			d := ecs[ew + block * info.error_words_per_block]
			for j in 0 ..< uint(8) {
				b := (d & (0x80 >> j)) == 0
				place_data_bit(pixels, size, &cursor, b, mask)
			}
		}
	}

	remainder_bits := remainder_bits[version]
	for _ in 0 ..< remainder_bits {
		place_data_bit(pixels, size, &cursor, true, mask)
	}
}

@(private)
error_correction_codes_generate :: proc(
	info: Error_Correction_Info,
	data: []byte,
	ecc:  []byte,
) {
	assert(len(data) == int(info.data_words))

	g := make(Galois_Polynomial, info.error_words_per_block + 1, context.temp_allocator)
	galois_polynomial_generator(g)

	_m := make(Galois_Polynomial, max(info.data_words_per_block_group1, info.data_words_per_block_group2) + info.error_words_per_block, context.temp_allocator)
	m  := _m[:info.data_words_per_block_group1 + info.error_words_per_block]

	data_offset, ecc_offset: int

	for _ in 0 ..< info.blocks_group1 {
		slice.zero(m)
		for d, i in data[data_offset:][:info.data_words_per_block_group1] {
			m[int(info.error_words_per_block) + int(info.data_words_per_block_group1) - i - 1] = d
	    }

		galois_polynomial_modulo(m, g)

		out := m[:info.error_words_per_block]
		slice.reverse(out)

		copy(ecc[ecc_offset:], out)
		ecc_offset  += len(out)
		data_offset += int(info.data_words_per_block_group1)
	}

	m = _m[:info.data_words_per_block_group2 + info.error_words_per_block]

	for _ in 0 ..< info.blocks_group2 {
		slice.zero(m)
		for d, i in data[data_offset:][:info.data_words_per_block_group2] {
			m[int(info.error_words_per_block) + int(info.data_words_per_block_group2) - i - 1] = d
	    }

		galois_polynomial_modulo(m, g)

		out := m[:info.error_words_per_block]
		slice.reverse(out)

		copy(ecc[ecc_offset:], out)
		ecc_offset  += len(out)
		data_offset += int(info.data_words_per_block_group2)
	}
}

// this functions is be mostly equivalent to `find_best_mask`,
// but doing one mask at a time is relatively slow
@(require_results)
evaluate_penalty :: proc(pixels: []byte, size: int) -> int {
	penalty_squares:     int
	penalty_consecutive: int
	penalty_pattern:     int
	penalty_balance:     int

	PATTERN_1 :: 0b01000101111
	PATTERN_2 :: 0b11110100010

	n_dark: int
	for row in 0 ..< size {
		window: u16

		run := 0
		run_value: u8
		for col in 0 ..< size {
			v := pixels[col + row * size] & 1

			// Balance
			if v == 0 {
				n_dark += 1
			}

			// Pattern
			window <<= 1
			window  |= u16(v)
			window  &= (1 << 12) - 1

			if (window == PATTERN_1 || window == PATTERN_2) && row >= 11 {
				penalty_pattern += 40
			}

			// Run lengths
			if v == run_value {
				run += 1
			} else {
				if (run >= 5) {
					penalty_consecutive += 3 + run - 5;
				}
				run       = 1
				run_value = v
			}

			// Squares
			if row > 0 && col > 0 &&
				v == pixels[col - 1 + (row - 0) * size] & 1 &&
				v == pixels[col - 0 + (row - 1) * size] & 1 &&
				v == pixels[col - 1 + (row - 1) * size] & 1
			{
				penalty_squares += 3
			}
		}
	}

	for col in 0 ..< size {
		window: u16

		run := 0
		run_value: u8
		for row in 0 ..< size {
			v := pixels[col + row * size] & 1

			window <<= 1
			window  |= u16(v)
			window  &= (1 << 12) - 1

			if (window == PATTERN_1 || window == PATTERN_2) && col >= 11 {
				penalty_pattern += 40
			}

			if v == run_value {
				run += 1
			} else {
				if (run >= 5) {
					penalty_consecutive += 3 + run - 5;
				}
				run       = 1
				run_value = v
			}
		}
	}

	portion_dark   := int(100 * f64(n_dark) / f64(size * size))
	prev_multiple  := (portion_dark / 5) * 5
	next_multiple  := prev_multiple + 5

	prev_multiple   = abs(prev_multiple - 50)
	next_multiple   = abs(next_multiple - 50)

	penalty_balance = min(prev_multiple, next_multiple) / 5 * 10

	return penalty_squares + penalty_consecutive + penalty_pattern + penalty_balance
}

// evaluates all masks at once as that is a good bit faster than evaluating each mask separately
// 
// this implementation is not a 100% correct since technically the metadata would
// need to be different for each mask and incorporated into the evaluation, but the
// error introduced by this should be pretty small
@(require_results)
find_best_mask :: proc(pixels: []byte, size: int, current_mask: int) -> (best_mask: int) {
	PATTERN_1 :: 0b01000101111
	PATTERN_2 :: 0b11110100010

	MAX_WIDTH :: (40 - 1) * 4 + 21

	State :: struct {
		penalty:        int,
		n_dark:         int,
		window:         u16,
		run:            int,
		run_value:      bool,
		square_counter: [2][MAX_WIDTH + 2]i8,
	}

	@(thread_local)
	square_counters: [8][2][MAX_WIDTH + 2]i8

	states: [8]State
	for &state, i in states {
		state.square_counter = square_counters[i]
	}

	for row in 0 ..< size {
		square_row      := row & 1
		prev_square_row := (row + 1) & 1

		for &state in states {
			state.window = 0
			state.run    = 0
			intrinsics.mem_zero(
				raw_data(&state.square_counter[prev_square_row]),
				size_of(state.square_counter[prev_square_row]),
			)
		}

		for col in 0 ..< size {
			p     := pixels[col + row * size]
			fixed := p & FIXED_MASK != 0
			v     := p & 1          != 0

			if !fixed {
				v ~= evaluate_mask(current_mask, row, col)
			}

			for &state, mask in states {
				v := v
				if !fixed {
					v ~= evaluate_mask(mask, row, col)
				}

				// balance
				if !v {
					state.n_dark += 1
				}

				// squares
				if v {
					state.square_counter[     square_row][col + 0] += 1
					state.square_counter[     square_row][col + 1] += 1
					state.square_counter[prev_square_row][col + 0] += 1
					state.square_counter[prev_square_row][col + 1] += 1
				}

				// pattern
				state.window <<= 1
				state.window  |= u16(v)
				state.window  &= (1 << 12) - 1

				if state.window == PATTERN_1 || state.window == PATTERN_2 && row >= 11 {
					state.penalty += 40
				}

				// run lengths
				if v == state.run_value {
					state.run += 1
				} else {
					if (state.run >= 5) {
						state.penalty += 3 + state.run - 5
					}
					state.run       = 1
					state.run_value = v
				}
			}
		}

		if row != 0 && row != size - 1 {
			for &state in states {
				for ctr in state.square_counter[square_row][1:][:size] {
					if ctr & 3 == 0 {
						state.penalty += 3
					}
				}
			}
		}
	}

	// These vertical passes are quite expensive, but there is not much we can do if we want to stick to the standard
	for col in 0 ..< size {
		for &state in states {
			state.window = 0
			state.run    = 0
		}

		for row in 0 ..< size {
			p     := pixels[col + row * size]
			fixed := p & FIXED_MASK != 0
			v     := p & 1          != 0

			if !fixed {
				v ~= evaluate_mask(0, row, col)
			}

			for &state, mask in states {
				v := v
				if !fixed {
					v ~= evaluate_mask(mask, row, col)
				}

				// pattern
				state.window <<= 1
				state.window  |= u16(v)
				state.window  &= (1 << 12) - 1

				if state.window == PATTERN_1 || state.window == PATTERN_2 && row >= 11 {
					state.penalty += 40
				}

				// run lengths
				if v == state.run_value {
					state.run += 1
				} else {
					if (state.run >= 5) {
						state.penalty += 3 + state.run - 5
					}
					state.run       = 1
					state.run_value = v
				}
			}
		}
	}

	for &state in states {
		portion_dark  := int(100 * f64(state.n_dark) / f64(size * size))
		prev_multiple := (portion_dark / 5) * 5
		next_multiple := prev_multiple + 5

		prev_multiple  = abs(prev_multiple - 50)
		next_multiple  = abs(next_multiple - 50)

		state.penalty += min(prev_multiple, next_multiple) / 5 * 10
	}

	min_penalty := max(int)
	for state, mask in states {
		if state.penalty < min_penalty {
			best_mask   = mask
			min_penalty = state.penalty
		}
	}

	return
}

@(private)
change_mask :: proc(pixels: []u8, size: int, old, new: int) {
	for row in 0 ..< size {
		for col in 0 ..< size {
			if pixels[col + row * size] & FIXED_MASK == 0 {
				pixels[col + row * size] ~= u8(evaluate_mask(old, row, col) ~ evaluate_mask(new, row, col))
			}
		}
	}
}
