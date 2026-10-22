package reliability

import (
	"slices"

	"nsk/internal/model"
)

// Works is the structure function φ(x): is the system up when exactly the
// elements in `up` are working?
func Works(node model.Node, up []int) bool {
	switch {
	case node.El != 0:
		return slices.Contains(up, node.El)
	case len(node.Ser) > 0:
		for _, c := range node.Ser {
			if !Works(c, up) {
				return false
			}
		}
		return true
	default:
		for _, c := range node.Par {
			if Works(c, up) {
				return true
			}
		}
		return false
	}
}

// allSubsets lists every subset of items, as a bitmask walk over 2^n.
func allSubsets(items []int) [][]int {
	out := make([][]int, 0, 1<<len(items))
	for mask := range 1 << len(items) {
		var s []int
		for i, x := range items {
			if mask&(1<<i) != 0 {
				s = append(s, x)
			}
		}
		out = append(out, s)
	}
	return out
}

// isSubsetOf reports whether every element of inner occurs in outer.
func isSubsetOf(inner, outer []int) bool {
	for _, x := range inner {
		if !slices.Contains(outer, x) {
			return false
		}
	}
	return true
}

// keepMinimal keeps only the sets that contain no other set of the family,
// then orders them by size and content.
func keepMinimal(sets [][]int) [][]int {
	var out [][]int
	for _, s := range sets {
		if !slices.ContainsFunc(sets, func(o []int) bool {
			return len(o) < len(s) && isSubsetOf(o, s)
		}) {
			out = append(out, s)
		}
	}
	slices.SortFunc(out, func(a, b []int) int {
		if d := len(a) - len(b); d != 0 {
			return d
		}
		return slices.Compare(a, b)
	})
	return out
}

// complement returns the elements not in s.
func complement(elements, s []int) []int {
	out := make([]int, 0, len(elements))
	for _, e := range elements {
		if !slices.Contains(s, e) {
			out = append(out, e)
		}
	}
	return out
}

// MinPaths lists the minimal path sets: minimal sets of elements whose joint
// operation keeps the system up regardless of the others  (point 2d).
func MinPaths(node model.Node, elements []int) [][]int {
	var paths [][]int
	for _, s := range allSubsets(elements) {
		if Works(node, s) {
			paths = append(paths, s)
		}
	}
	return keepMinimal(paths)
}

// MinCuts lists the minimal cut sets: minimal sets of elements whose joint
// failure brings the system down regardless of the others  (point 2e).
func MinCuts(node model.Node, elements []int) [][]int {
	var cuts [][]int
	for _, s := range allSubsets(elements) {
		if !Works(node, complement(elements, s)) {
			cuts = append(cuts, s)
		}
	}
	return keepMinimal(cuts)
}
