package reliability

import (
	"math"
	"math/big"
)

// Micro is the unit failure rates are expressed in: 1e-6 1/h.
const Micro = 1e-6

// Delta is the interval width Δ = 100 h from the assignment (point 2b).
const Delta = 100

// Instant is the instant t = 100 + 5N [h] the assignment evaluates at.
func Instant(bigN int) int { return 100 + 5*bigN }

// LambdaUnits returns λ_i in multiples of Micro. The assignment writes the
// even case as 3N(9-i) because it assumes n=8; here the 9 is n+1, so the
// element count is never hard-coded.
func LambdaUnits(bigN, n, i int) int {
	if i%2 == 1 {
		return 2 * bigN * i
	}
	return 3 * bigN * (n + 1 - i)
}

// Lambda returns λ exactly: an integer over 1e6.
func Lambda(units int) *big.Rat { return new(big.Rat).SetFrac64(int64(units), 1_000_000) }

// ElementUptime returns ET_i = 1/λ exactly.
func ElementUptime(units int) *big.Rat {
	return new(big.Rat).SetFrac64(1_000_000, int64(units))
}

// Survival returns R(t) = e^(-λt) for a rate given in units of Micro. The
// value is transcendental, so float64's ~16 significant digits stand against
// the 6 the report prints.
func Survival(units, t int) float64 {
	return math.Exp(-float64(units) * Micro * float64(t))
}
