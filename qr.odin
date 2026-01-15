package qr_odin

import "base:intrinsics"

import "core:slice"

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

VERSION_MAX :: 40

@(private, rodata)
level_capacities := [Error_Correction_Level][VERSION_MAX]i16 {
	.L = {
		17,   32,   53,   78,   106,  134,  154,  192,  230,  271,
		321,  367,  425,  458,  520,  586,  644,  718,  792,  858,
		929,  1003, 1091, 1171, 1273, 1367, 1465, 1528, 1628, 1732,
		1840, 1952, 2068, 2188, 2303, 2431, 2563, 2699, 2809, 2953,
	},
	.M = {
		14,   26,   42,   62,   84,   106,  122,  152,  180,  213,
		251,  287,  331,  362,  412,  450,  504,  560,  624,  666,
		711,  779,  857,  911,  997,  1059, 1125, 1190, 1264, 1370,
		1452, 1538, 1628, 1722, 1809, 1911, 1989, 2099, 2213, 2331,
	},
	.Q = {
		11,   20,   32,   46,   60,   74,   86,   108,  130,  151,
		177,  203,  241,  258,  292,  322,  364,  394,  442,  482,
		509,  565,  611,  661,  715,  751,  805,  868,  908,  982,
		1030, 1112, 1168, 1228, 1283, 1351, 1423, 1499, 1579, 1663,
	},
	.H = {
		7,   14,  24,  34,  44,  58,   64,   84,   98,   119,
		137, 155, 177, 194, 220, 250,  280,  310,  338,  382,
		403, 439, 461, 511, 535, 593,  625,  658,  698,  742,
		790, 842, 898, 958, 983, 1051, 1093, 1139, 1219, 1273,
	},
}

Error_Correction_Info :: struct {
	data_words:                  i16,
	error_words_per_block:       i16,
	blocks_group1:               i16,
	data_words_per_block_group1: i16,
	blocks_group2:               i16,
	data_words_per_block_group2: i16,
}

@(private, rodata)
error_correction_infos := [VERSION_MAX + 1 /* one based indexing */][Error_Correction_Level]Error_Correction_Info {
	1 = {
		.L = {   19,  7,  1,  19,  0,   0 },
		.M = {   16, 10,  1,  16,  0,   0 },
		.Q = {   13, 13,  1,  13,  0,   0 },
		.H = {    9, 17,  1,   9,  0,   0 },
	},
	2 = {
		.L = {   34, 10,  1,  34,  0,   0 },
		.M = {   28, 16,  1,  28,  0,   0 },
		.Q = {   22, 22,  1,  22,  0,   0 },
		.H = {   16, 28,  1,  16,  0,   0 },
	},
	3 = {
		.L = {   55, 15,  1,  55,  0,   0 },
		.M = {   44, 26,  1,  44,  0,   0 },
		.Q = {   34, 18,  2,  17,  0,   0 },
		.H = {   26, 22,  2,  13,  0,   0 },
	},
	4 = {
		.L = {   80, 20,  1,  80,  0,   0 },
		.M = {   64, 18,  2,  32,  0,   0 },
		.Q = {   48, 26,  2,  24,  0,   0 },
		.H = {   36, 16,  4,   9,  0,   0 },
	},
	5 = {
		.L = {  108, 26,  1, 108,  0,   0 },
		.M = {   86, 24,  2,  43,  0,   0 },
		.Q = {   62, 18,  2,  15,  2,  16 },
		.H = {   46, 22,  2,  11,  2,  12 },
	},
	6 = {
		.L = {  136, 18,  2,  68,  0,   0 },
		.M = {  108, 16,  4,  27,  0,   0 },
		.Q = {   76, 24,  4,  19,  0,   0 },
		.H = {   60, 28,  4,  15,  0,   0 },
	},
	7 = {
		.L = {  156, 20,  2,  78,  0,   0 },
		.M = {  124, 18,  4,  31,  0,   0 },
		.Q = {   88, 18,  2,  14,  4,  15 },
		.H = {   66, 26,  4,  13,  1,  14 },
	},
	8 = {
		.L = {  194, 24,  2,  97,  0,   0 },
		.M = {  154, 22,  2,  38,  2,  39 },
		.Q = {  110, 22,  4,  18,  2,  19 },
		.H = {   86, 26,  4,  14,  2,  15 },
	},
	9 = {
		.L = {  232, 30,  2, 116,  0,   0 },
		.M = {  182, 22,  3,  36,  2,  37 },
		.Q = {  132, 20,  4,  16,  4,  17 },
		.H = {  100, 24,  4,  12,  4,  13 },
	},
	10 = {
			.L = {  274, 18,  2,  68,  2,  69 },
			.M = {  216, 26,  4,  43,  1,  44 },
			.Q = {  154, 24,  6,  19,  2,  20 },
			.H = {  122, 28,  6,  15,  2,  16 },
	},
	11 = {
			.L = {  324, 20,  4,  81,  0,   0 },
			.M = {  254, 30,  1,  50,  4,  51 },
			.Q = {  180, 28,  4,  22,  4,  23 },
			.H = {  140, 24,  3,  12,  8,  13 },
	},
	12 = {
			.L = {  370, 24,  2,  92,  2,  93 },
			.M = {  290, 22,  6,  36,  2,  37 },
			.Q = {  206, 26,  4,  20,  6,  21 },
			.H = {  158, 28,  7,  14,  4,  15 },
	},
	13 = {
			.L = {  428, 26,  4, 107,  0,   0 },
			.M = {  334, 22,  8,  37,  1,  38 },
			.Q = {  244, 24,  8,  20,  4,  21 },
			.H = {  180, 22, 12,  11,  4,  12 },
	},
	14 = {
			.L = {  461, 30,  3, 115,  1, 116 },
			.M = {  365, 24,  4,  40,  5,  41 },
			.Q = {  261, 20, 11,  16,  5,  17 },
			.H = {  197, 24, 11,  12,  5,  13 },
	},
	15 = {
			.L = {  523, 22,  5,  87,  1,  88 },
			.M = {  415, 24,  5,  41,  5,  42 },
			.Q = {  295, 30,  5,  24,  7,  25 },
			.H = {  223, 24, 11,  12,  7,  13 },
	},
	16 = {
			.L = {  589, 24,  5,  98,  1,  99 },
			.M = {  453, 28,  7,  45,  3,  46 },
			.Q = {  325, 24, 15,  19,  2,  20 },
			.H = {  253, 30,  3,  15, 13,  16 },
	},
	17 = {
			.L = {  647, 28,  1, 107,  5, 108 },
			.M = {  507, 28, 10,  46,  1,  47 },
			.Q = {  367, 28,  1,  22, 15,  23 },
			.H = {  283, 28,  2,  14, 17,  15 },
	},
	18 = {
			.L = {  721, 30,  5, 120,  1, 121 },
			.M = {  563, 26,  9,  43,  4,  44 },
			.Q = {  397, 28, 17,  22,  1,  23 },
			.H = {  313, 28,  2,  14, 19,  15 },
	},
	19 = {
			.L = {  795, 28,  3, 113,  4, 114 },
			.M = {  627, 26,  3,  44, 11,  45 },
			.Q = {  445, 26, 17,  21,  4,  22 },
			.H = {  341, 26,  9,  13, 16,  14 },
	},
	20 = {
			.L = {  861, 28,  3, 107,  5, 108 },
			.M = {  669, 26,  3,  41, 13,  42 },
			.Q = {  485, 30, 15,  24,  5,  25 },
			.H = {  385, 28, 15,  15, 10,  16 },
	},
	21 = {
			.L = {  932, 28,  4, 116,  4, 117 },
			.M = {  714, 26, 17,  42,  0,   0 },
			.Q = {  512, 28, 17,  22,  6,  23 },
			.H = {  406, 30, 19,  16,  6,  17 },
	},
	22 = {
			.L = { 1006, 28,  2, 111,  7, 112 },
			.M = {  782, 28, 17,  46,  0,   0 },
			.Q = {  568, 30,  7,  24, 16,  25 },
			.H = {  442, 24, 34,  13,  0,   0 },
	},
	23 = {
			.L = { 1094, 30,  4, 121,  5, 122 },
			.M = {  860, 28,  4,  47, 14,  48 },
			.Q = {  614, 30, 11,  24, 14,  25 },
			.H = {  464, 30, 16,  15, 14,  16 },
	},
	24 = {
			.L = { 1174, 30,  6, 117,  4, 118 },
			.M = {  914, 28,  6,  45, 14,  46 },
			.Q = {  664, 30, 11,  24, 16,  25 },
			.H = {  514, 30, 30,  16,  2,  17 },
	},
	25 = {
			.L = { 1276, 26,  8, 106,  4, 107 },
			.M = { 1000, 28,  8,  47, 13,  48 },
			.Q = {  718, 30,  7,  24, 22,  25 },
			.H = {  538, 30, 22,  15, 13,  16 },
	},
	26 = {
			.L = { 1370, 28, 10, 114,  2, 115 },
			.M = { 1062, 28, 19,  46,  4,  47 },
			.Q = {  754, 28, 28,  22,  6,  23 },
			.H = {  596, 30, 33,  16,  4,  17 },
	},
	27 = {
			.L = { 1468, 30,  8, 122,  4, 123 },
			.M = { 1128, 28, 22,  45,  3,  46 },
			.Q = {  808, 30,  8,  23, 26,  24 },
			.H = {  628, 30, 12,  15, 28,  16 },
	},
	28 = {
			.L = { 1531, 30,  3, 117, 10, 118 },
			.M = { 1193, 28,  3,  45, 23,  46 },
			.Q = {  871, 30,  4,  24, 31,  25 },
			.H = {  661, 30, 11,  15, 31,  16 },
	},
	29 = {
			.L = { 1631, 30,  7, 116,  7, 117 },
			.M = { 1267, 28, 21,  45,  7,  46 },
			.Q = {  911, 30,  1,  23, 37,  24 },
			.H = {  701, 30, 19,  15, 26,  16 },
	},
	30 = {
			.L = { 1735, 30,  5, 115, 10, 116 },
			.M = { 1373, 28, 19,  47, 10,  48 },
			.Q = {  985, 30, 15,  24, 25,  25 },
			.H = {  745, 30, 23,  15, 25,  16 },
	},
	31 = {
			.L = { 1843, 30, 13, 115,  3, 116 },
			.M = { 1455, 28,  2,  46, 29,  47 },
			.Q = { 1033, 30, 42,  24,  1,  25 },
			.H = {  793, 30, 23,  15, 28,  16 },
	},
	32 = {
			.L = { 1955, 30, 17, 115,  0,   0 },
			.M = { 1541, 28, 10,  46, 23,  47 },
			.Q = { 1115, 30, 10,  24, 35,  25 },
			.H = {  845, 30, 19,  15, 35,  16 },
	},
	33 = {
			.L = { 2071, 30, 17, 115,  1, 116 },
			.M = { 1631, 28, 14,  46, 21,  47 },
			.Q = { 1171, 30, 29,  24, 19,  25 },
			.H = {  901, 30, 11,  15, 46,  16 },
	},
	34 = {
			.L = { 2191, 30, 13, 115,  6, 116 },
			.M = { 1725, 28, 14,  46, 23,  47 },
			.Q = { 1231, 30, 44,  24,  7,  25 },
			.H = {  961, 30, 59,  16,  1,  17 },
	},
	35 = {
			.L = { 2306, 30, 12, 121,  7, 122 },
			.M = { 1812, 28, 12,  47, 26,  48 },
			.Q = { 1286, 30, 39,  24, 14,  25 },
			.H = {  986, 30, 22,  15, 41,  16 },
	},
	36 = {
			.L = { 2434, 30,  6, 121, 14, 122 },
			.M = { 1914, 28,  6,  47, 34,  48 },
			.Q = { 1354, 30, 46,  24, 10,  25 },
			.H = { 1054, 30,  2,  15, 64,  16 },
	},
	37 = {
			.L = { 2566, 30, 17, 122,  4, 123 },
			.M = { 1992, 28, 29,  46, 14,  47 },
			.Q = { 1426, 30, 49,  24, 10,  25 },
			.H = { 1096, 30, 24,  15, 46,  16 },
	},
	38 = {
			.L = { 2702, 30,  4, 122, 18, 123 },
			.M = { 2102, 28, 13,  46, 32,  47 },
			.Q = { 1502, 30, 48,  24, 14,  25 },
			.H = { 1142, 30, 42,  15, 32,  16 },
	},
	39 = {
			.L = { 2812, 30, 20, 117,  4, 118 },
			.M = { 2216, 28, 40,  47,  7,  48 },
			.Q = { 1582, 30, 43,  24, 22,  25 },
			.H = { 1222, 30, 10,  15, 67,  16 },
	},
	40 = {
			.L = { 2956, 30, 19, 118,  6, 119 },
			.M = { 2334, 28, 18,  47, 31,  48 },
			.Q = { 1666, 30, 34,  24, 34,  25 },
			.H = { 1276, 30, 20,  15, 61,  16 },
	},
}

@(private) galois_pow_2_lut: [256]u8
@(private) galois_log_2_lut: [256]u8

@(init)
_lookup_tables_init :: proc "contextless" () {
	for i in 0 ..< 255 {
		value := 1
		for _ in 0 ..< i {
			value <<= 1
			if (value > 255) {
				value ~= 285
			}
		}

		galois_pow_2_lut[i]     = u8(value)
		galois_log_2_lut[value] = u8(i)
	}
}

galois_mul_u8 :: proc(a, b: u8) -> (result: u8) {
	if a == 0 || b == 0 {
		return 0
	}

	a_log2 := int(galois_log_2_lut[a])
	b_log2 := int(galois_log_2_lut[b])
	return galois_pow_2_lut[(a_log2 + b_log2) % 255]
}

Galois_Polynomial :: []u8

galois_polynomial_generator :: proc(p: Galois_Polynomial) {
	assert(len(p) >= 3);
	intrinsics.mem_zero(raw_data(p), size_of(p[0]) * len(p))

	p[0] = galois_pow_2_lut[1]
	p[1] = galois_pow_2_lut[25]
	p[2] = galois_pow_2_lut[0]

	for i in 3 ..< len(p) {
		for j := i; j >= 0; j -= 1 {
			a   := p[j]
			a_  := j > 0 ? p[j - 1] : 0
			p[j] = a_ ~ galois_mul_u8(a, galois_pow_2_lut[i - 1])
		}
	}
}

galois_polynomial_modulo :: proc(dividend, divisor:  Galois_Polynomial) {
	for i := len(dividend) - 1; i >= 0; i -= 1 {
		if i + 1 < len(divisor) {
			break
		}

		m := dividend[i]
		for j in 0 ..< len(divisor) {
			dividend[i + j - len(divisor) + 1] ~= galois_mul_u8(m, divisor[j])
		}
	}
}

required_version :: proc(data_len: int, correction_level: Error_Correction_Level) -> int {
	for cap, version in level_capacities[correction_level] {
		if data_len <= int(cap) {
			return version + 1
		}
	}

	return -1
}

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

@(private, rodata)
alignment_locations := [VERSION_MAX + 1][7]u8 {
	2  = { 6, 18,  0,  0,   0,   0,   0, },
	3  = { 6, 22,  0,  0,   0,   0,   0, },
	4  = { 6, 26,  0,  0,   0,   0,   0, },
	5  = { 6, 30,  0,  0,   0,   0,   0, },
	6  = { 6, 34,  0,  0,   0,   0,   0, },
	7  = { 6, 22, 38,  0,   0,   0,   0, },
	8  = { 6, 24, 42,  0,   0,   0,   0, },
	9  = { 6, 26, 46,  0,   0,   0,   0, },
	10 = { 6, 28, 50,  0,   0,   0,   0, },
	11 = { 6, 30, 54,  0,   0,   0,   0, },
	12 = { 6, 32, 58,  0,   0,   0,   0, },
	13 = { 6, 34, 62,  0,   0,   0,   0, },
	14 = { 6, 26, 46, 66,   0,   0,   0, },
	15 = { 6, 26, 48, 70,   0,   0,   0, },
	16 = { 6, 26, 50, 74,   0,   0,   0, },
	17 = { 6, 30, 54, 78,   0,   0,   0, },
	18 = { 6, 30, 56, 82,   0,   0,   0, },
	19 = { 6, 30, 58, 86,   0,   0,   0, },
	20 = { 6, 34, 62, 90,   0,   0,   0, },
	21 = { 6, 28, 50, 72,  94,   0,   0, },
	22 = { 6, 26, 50, 74,  98,   0,   0, },
	23 = { 6, 30, 54, 78, 102,   0,   0, },
	24 = { 6, 28, 54, 80, 106,   0,   0, },
	25 = { 6, 32, 58, 84, 110,   0,   0, },
	26 = { 6, 30, 58, 86, 114,   0,   0, },
	27 = { 6, 34, 62, 90, 118,   0,   0, },
	28 = { 6, 26, 50, 74,  98, 122,   0, },
	29 = { 6, 30, 54, 78, 102, 126,   0, },
	30 = { 6, 26, 52, 78, 104, 130,   0, },
	31 = { 6, 30, 56, 82, 108, 134,   0, },
	32 = { 6, 34, 60, 86, 112, 138,   0, },
	33 = { 6, 30, 58, 86, 114, 142,   0, },
	34 = { 6, 34, 62, 90, 118, 146,   0, },
	35 = { 6, 30, 54, 78, 102, 126, 150, },
	36 = { 6, 24, 50, 76, 102, 128, 154, },
	37 = { 6, 28, 54, 80, 106, 132, 158, },
	38 = { 6, 32, 58, 84, 110, 136, 162, },
	39 = { 6, 26, 54, 82, 110, 138, 166, },
	40 = { 6, 30, 58, 86, 114, 142, 170, },
}

@(private)
FIXED_MASK :: 0x80

place_fixed_patterns :: proc(pixels: []u8, size: int, version: int) {
	finder_pixel :: proc(pixels: []u8, size: int, x, y: int, v: bool) {
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

finalize :: proc(pixels: []u8) {
	when true {
		for &pixel in pixels {
			pixel = -(pixel & 1)
		}
	} else {
		for &pixel in pixels {
			switch pixel {
			case FIXED_MASK:
				pixel = 0x80
			case FIXED_MASK | 1:
				pixel = 0x80 | 0x40
			case 1:
				pixel = 0x40
			}
		}
	}
}

@(private, rodata)
format_strings := [Error_Correction_Level][8]u16 {
	.L = {
		0b111011111000100,
		0b111001011110011,
		0b111110110101010,
		0b111100010011101,
		0b110011000101111,
		0b110001100011000,
		0b110110001000001,
		0b110100101110110,
	},
	.M = {
		0b101010000010010,
		0b101000100100101,
		0b101111001111100,
		0b101101101001011,
		0b100010111111001,
		0b100000011001110,
		0b100111110010111,
		0b100101010100000,
	},
	.Q = {
		0b011010101011111,
		0b011000001101000,
		0b011111100110001,
		0b011101000000110,
		0b010010010110100,
		0b010000110000011,
		0b010111011011010,
		0b010101111101101,
	},
	.H = {
		0b001011010001001,
		0b001001110111110,
		0b001110011100111,
		0b001100111010000,
		0b000011101100010,
		0b000001001010101,
		0b000110100001100,
		0b000100000111011,
	},
}

@(private, rodata)
version_info_strings := [41]u32 {
	 7 = 0b000111110010010100,
	 8 = 0b001000010110111100,
	 9 = 0b001001101010011001,
	10 = 0b001010010011010011,
	11 = 0b001011101111110110,
	12 = 0b001100011101100010,
	13 = 0b001101100001000111,
	14 = 0b001110011000001101,
	15 = 0b001111100100101000,
	16 = 0b010000101101111000,
	17 = 0b010001010001011101,
	18 = 0b010010101000010111,
	19 = 0b010011010100110010,
	20 = 0b010100100110100110,
	21 = 0b010101011010000011,
	22 = 0b010110100011001001,
	23 = 0b010111011111101100,
	24 = 0b011000111011000100,
	25 = 0b011001000111100001,
	26 = 0b011010111110101011,
	27 = 0b011011000010001110,
	28 = 0b011100110000011010,
	29 = 0b011101001100111111,
	30 = 0b011110110101110101,
	31 = 0b011111001001010000,
	32 = 0b100000100111010101,
	33 = 0b100001011011110000,
	34 = 0b100010100010111010,
	35 = 0b100011011110011111,
	36 = 0b100100101100001011,
	37 = 0b100101010000101110,
	38 = 0b100110101001100100,
	39 = 0b100111010101000001,
	40 = 0b101000110001101001,
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

Encoding :: enum {
	Byte = 0b0100,
}

generate_data_bits :: proc(
	version:          int,
	correction_level: Error_Correction_Level,
	data:             []byte,
	out:              []byte,
) -> int {
	bit_cursor: int
	append_bits(out, &bit_cursor, Encoding.Byte, 4)
	append_bits(out, &bit_cursor, len(data), character_count_bits(version))

	assert(bit_cursor % 8 == 4)
	for d in data {
		out[bit_cursor >> 3    ] |= d >> 4
		out[bit_cursor >> 3 + 1] |= d << 4
		bit_cursor                += 8
	}

	append_bits(out, &bit_cursor, 0, 4) // zero padding up to the next full byte

	return bit_cursor >> 3
}

evaluate_mask :: proc(mask, row, col: int) -> bool {
	switch (mask) {
	case 0:
		return ((col + row) % 2) == 0
	case 1:
		return row % 2 == 0
	case 2:
		return col % 3 == 0
	case 3:
		return (col + row) % 3 == 0
	case 4:
		return ((row / 2 + col / 3) % 2) == 0
	case 5:
		return ((row * col) % 2) + ((row * col) % 3) == 0
	case 6:
		return (((row * col) % 2) + ((row * col) % 3)) % 2 == 0
	case 7:
		return (((row + col) % 2) + ((row * col) % 3)) % 2 == 0
	}

	return false
}

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

place_data_bits :: proc(
	pixels:  []u8,
	size:    int,
	info:    Error_Correction_Info,
	version: int,
	data:    []byte,
	ecs:     []byte,
	mask:    int,
) {
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

error_correction_codes_generate :: proc(
	info: Error_Correction_Info,
	data: []byte,
	ecs:  []byte,
) {
	assert(len(data) == int(info.data_words))

	g := make(Galois_Polynomial, info.error_words_per_block + 1, context.temp_allocator)
	galois_polynomial_generator(g)

	_m := make(Galois_Polynomial, max(info.data_words_per_block_group1, info.data_words_per_block_group2) + info.error_words_per_block, context.temp_allocator)
	m := _m[:info.data_words_per_block_group1 + info.error_words_per_block]

	data_offset, ecs_offset: int

	for _ in 0 ..< info.blocks_group1 {
		slice.zero(m)
		for d, i in data[data_offset:][:info.data_words_per_block_group1] {
			m[int(info.error_words_per_block) + int(info.data_words_per_block_group1) - i - 1] = d
	    }

		galois_polynomial_modulo(m, g)

		out := m[:info.error_words_per_block]
		slice.reverse(out)

		copy(ecs[ecs_offset:], out)
		ecs_offset  += len(out)
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

		copy(ecs[ecs_offset:], out)
		ecs_offset  += len(out)
		data_offset += int(info.data_words_per_block_group2)
	}
}

@(private, rodata)
remainder_bits := [VERSION_MAX + 1]u8 {
	1 = 0,
	2 = 7,
	3 = 7,
	4 = 7,
	5 = 7,
	6 = 7,
	7 = 0,
	8 = 0,
	9 = 0,
	10 = 0,
	11 = 0,
	12 = 0,
	13 = 0,
	14 = 3,
	15 = 3,
	16 = 3,
	17 = 3,
	18 = 3,
	19 = 3,
	20 = 3,
	21 = 4,
	22 = 4,
	23 = 4,
	24 = 4,
	25 = 4,
	26 = 4,
	27 = 4,
	28 = 3,
	29 = 3,
	30 = 3,
	31 = 3,
	32 = 3,
	33 = 3,
	34 = 3,
	35 = 0,
	36 = 0,
	37 = 0,
	38 = 0,
	39 = 0,
	40 = 0,
}
