// ============================================================
// bf16 ↔ fp32 conversion reference (correct bit layout)
// bf16: 1 sign, 8 exp, 7 mantissa (same exponent range as fp32)
// fp32: 1 sign, 8 exp, 23 mantissa
// ============================================================
//
// bf16 → fp32: {bf16, 16'h0000}  -- pad lower 16 mantissa bits with zeros
//
// fp32 → bf16 (round-to-nearest):
//   truncated = fp32[31:16];
//   bf16 = (fp32[15] && truncated != 16'hFFFF) ? (truncated + 1) : truncated;
