package model

import "testing"

// Duplicate replaces the targeted series element with a parallel pair and
// leaves the rest of the tree, and the input, untouched.
func TestDuplicate(t *testing.T) {
	base := Node{Ser: []Node{
		{El: 1},
		{El: 2},
		{Par: []Node{{El: 3}, {El: 4}}},
	}}
	got := base.Duplicate(1, 9)

	first := got.Ser[0]
	if len(first.Par) != 2 || first.Par[0].El != 1 || first.Par[1].El != 9 {
		t.Errorf("pierwszy blok = %+v, want para {1,9}", first)
	}
	if got.Ser[1].El != 2 {
		t.Errorf("drugi blok zmieniony: %+v", got.Ser[1])
	}
	// the untouched parallel group stays as it was
	if last := got.Ser[2]; len(last.Par) != 2 || last.Par[0].El != 3 || last.Par[1].El != 4 {
		t.Errorf("grupa rownolegla zmieniona: %+v", last)
	}
	// the input tree must not be mutated
	if base.Ser[0].El != 1 || len(base.Ser[0].Par) != 0 {
		t.Errorf("Duplicate zmienilo wejscie: %+v", base.Ser[0])
	}
}
