package reliability

import "testing"

// The multiplied-out structure function has one monomial per choice of branch
// in each parallel group: 3 × 3 for the two groups of our system.
func TestExpansionMonomials(t *testing.T) {
	cfg, _ := system(t)
	got := Expand(cfg.Structure)
	if len(got) != 9 {
		t.Fatalf("jednomianow = %d, want 9: %v", len(got), got)
	}
	for _, m := range got {
		if m.Coeff != 1 && m.Coeff != -1 {
			t.Errorf("jednomian %v ma wspolczynnik %d, oczekiwano ±1", m.Elements, m.Coeff)
		}
		// every monomial must contain the four elements that are always needed
		for _, e := range []int{1, 2, 3, 8} {
			if !isSubsetOf([]int{e}, m.Elements) {
				t.Errorf("jednomian %v nie zawiera krytycznego elementu %d", m.Elements, e)
			}
		}
	}
}

// Nine monomials collapse to eight exponents: two different element sets share
// the rate 168, which is where the coefficient 2 comes from.
func TestCollectingSharesAnExponent(t *testing.T) {
	cfg, _ := system(t)
	exp := Expand(cfg.Structure)
	if got, want := len(exp.Terms(cfg.N, cfg.Count())), 8; got != want {
		t.Fatalf("roznych wykladnikow = %d, want %d", got, want)
	}

	var at168 [][]int
	for _, m := range exp {
		if m.Rate(cfg.N, cfg.Count()) == 168 {
			at168 = append(at168, m.Elements)
		}
	}
	if len(at168) != 2 {
		t.Errorf("wykladnik 168 pochodzi z %d jednomianow, want 2: %v", len(at168), at168)
	}
}
