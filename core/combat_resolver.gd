extends RefCounted

# C experimental simultaneous integer attrition; never a measured original formula.
static func resolve(a: int, b: int, factor_a: int, factor_b: int, divisor: int) -> Array:
	return [mini(a, maxi(1, b * factor_b / maxi(1, divisor * factor_a))), mini(b, maxi(1, a * factor_a / maxi(1, divisor * factor_b)))]
