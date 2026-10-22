package reliability

import (
	"fmt"
	"slices"

	"nsk/internal/model"
)

// Monomial is one product term of the multiplied-out structure function: the
// signed product of the reliabilities of a set of elements, e.g. -R1R2R4R5.
type Monomial struct {
	Elements []int
	Coeff    int
}

// Rate is the exponent this monomial contributes once R_i = e^(-λ_i t) is
// substituted: the exponents of a product add up.
func (m Monomial) Rate(bigN, n int) int {
	sum := 0
	for _, i := range m.Elements {
		sum += LambdaUnits(bigN, n, i)
	}
	return sum
}

// Expansion is the structure function multiplied out, still written in the
// element reliabilities. Keeping the element sets is what lets the report show
// where each exponent comes from; Terms alone would lose that.
type Expansion []Monomial

func unit() Expansion          { return Expansion{{Coeff: 1}} }
func variable(i int) Expansion { return Expansion{{Elements: []int{i}, Coeff: 1}} }

// normalize merges monomials over the same element set and drops the ones that
// cancelled out.
func (x Expansion) normalize() Expansion {
	index := map[string]int{}
	var out Expansion
	for _, m := range x {
		set := slices.Clone(m.Elements)
		slices.Sort(set)
		key := fmt.Sprint(set)
		if at, seen := index[key]; seen {
			out[at].Coeff += m.Coeff
			continue
		}
		index[key] = len(out)
		out = append(out, Monomial{Elements: set, Coeff: m.Coeff})
	}
	return slices.DeleteFunc(out, func(m Monomial) bool { return m.Coeff == 0 })
}

// Mul multiplies two expansions: element sets join, coefficients multiply.
// The sets are always disjoint because the structure tree partitions the
// elements, so no element is ever squared.
func (x Expansion) Mul(y Expansion) Expansion {
	var out Expansion
	for _, a := range x {
		for _, b := range y {
			out = append(out, Monomial{
				Elements: append(slices.Clone(a.Elements), b.Elements...),
				Coeff:    a.Coeff * b.Coeff,
			})
		}
	}
	return out.normalize()
}

// Sub returns x - y.
func (x Expansion) Sub(y Expansion) Expansion {
	out := slices.Clone(x)
	for _, m := range y {
		out = append(out, Monomial{Elements: m.Elements, Coeff: -m.Coeff})
	}
	return out.normalize()
}

// Expand multiplies out the structure function of a tree (point 2a, step one).
func Expand(node model.Node) Expansion {
	switch {
	case node.El != 0:
		return variable(node.El)

	case len(node.Ser) > 0: // every part must work: the reliabilities multiply
		out := unit()
		for _, c := range node.Ser {
			out = out.Mul(Expand(c))
		}
		return out

	default: // 1 - Π(1 - R_i): the group fails only if every part fails
		failed := unit()
		for _, c := range node.Par {
			failed = failed.Mul(unit().Sub(Expand(c)))
		}
		return unit().Sub(failed)
	}
}

// SortedByRate orders the monomials the way the report lists them.
func (x Expansion) SortedByRate(bigN, n int) Expansion {
	out := slices.Clone(x)
	slices.SortFunc(out, func(a, b Monomial) int {
		if d := a.Rate(bigN, n) - b.Rate(bigN, n); d != 0 {
			return d
		}
		return slices.Compare(a.Elements, b.Elements)
	})
	return out
}

// Terms substitutes R_i = e^(-λ_i t) and collects monomials that share an
// exponent — that collecting is where coefficients above 1 come from.
func (x Expansion) Terms(bigN, n int) Terms {
	out := Terms{}
	for _, m := range x {
		out[m.Rate(bigN, n)] += m.Coeff
	}
	return out.prune()
}
