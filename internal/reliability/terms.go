package reliability

import (
	"math/big"

	"nsk/internal/model"
)

// Terms represents a reliability function as a sum of exponentials,
//
//	R(t) = Σ c_r · e^(-r·Micro·t),
//
// mapping the integer rate r (a multiple of Micro) to its integer coefficient.
// Keeping both integral means the whole composition stays exact.
type Terms map[int]int

// prune drops cancelled terms so equality comparisons stay meaningful.
func (x Terms) prune() Terms {
	for r, c := range x {
		if c == 0 {
			delete(x, r)
		}
	}
	return x
}

// Of builds R_s(t) for a structure tree (point 2a), going through Expand so
// that the report and the numbers come from one and the same derivation.
func Of(node model.Node, bigN, n int) Terms { return Expand(node).Terms(bigN, n) }

// At evaluates R(t).
func (x Terms) At(t int) float64 {
	sum := 0.0
	for r, c := range x {
		sum += float64(c) * Survival(r, t)
	}
	return sum
}

// NoFailure is P_s(t, t+dt) = 1 - [R(t) - R(t+dt)]  (point 2b).
func (x Terms) NoFailure(t, dt int) float64 { return 1 - (x.At(t) - x.At(t+dt)) }

// Redundant builds R_r(t) for a series element duplicated by an identical
// parallel spare (point 3). The spare carries the same λ as the original, so
// its series factor R_k = e^(-k·Micro·t) turns into 1-(1-R_k)² = 2R_k - R_k²,
// i.e. the whole function is multiplied by (2 - R_k):
//
//	R_r = (2 - R_k)·R_s = 2·R_s − R_k·R_s.
//
// Multiplying by R_k only shifts every exponent up by k units, so the result
// is again a sum of exponentials with integer coefficients and rates — exact.
// This holds because the duplicated element is a plain series factor of R_s.
func (x Terms) Redundant(dupUnits int) Terms {
	out := Terms{}
	for r, c := range x {
		out[r] += 2 * c
		out[r+dupUnits] -= c
	}
	return out.prune()
}

// ExpectedUptime is ET = ∫₀^∞ R(t) dt = Σ c_r/(r·Micro)  (point 2c).
// A sum of fractions, so it is exact; no numeric integration takes place.
func (x Terms) ExpectedUptime() *big.Rat {
	sum := new(big.Rat)
	for r, c := range x {
		if r == 0 {
			panic("składnik stały ⇒ ET rozbieżne")
		}
		sum.Add(sum, new(big.Rat).SetFrac64(int64(c)*1_000_000, int64(r)))
	}
	return sum
}
