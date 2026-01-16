#+private
package qr_odin

import "base:intrinsics"

Galois_Polynomial :: []u8

galois_pow_2_lut: [256]u8
galois_log_2_lut: [256]u8

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

galois_polynomial_modulo :: proc(dividend, divisor: Galois_Polynomial) {
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
