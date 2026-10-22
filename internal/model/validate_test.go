package model

import (
	"strings"
	"testing"

	"gopkg.in/yaml.v3"
)

const good = `
N: 3
elements:
  - {id: 1, name: A}
  - {id: 2, name: B}
  - {id: 3, name: C}
links:
  - {from: 1, to: 2, label: x}
structure:
  ser:
    - el: 1
    - par: [{el: 2}, {el: 3}]
`

func check(t *testing.T, doc string) error {
	t.Helper()
	var cfg Config
	if err := yaml.Unmarshal([]byte(doc), &cfg); err != nil {
		t.Fatalf("yaml: %v", err)
	}
	return Validate(cfg)
}

func TestValidDocumentPasses(t *testing.T) {
	if err := check(t, good); err != nil {
		t.Fatalf("poprawny dokument odrzucony: %v", err)
	}
}

func TestInvalidDocumentsAreRejected(t *testing.T) {
	cases := map[string]struct{ doc, want string }{
		"numer elementu poza 1..n": {
			strings.Replace(good, "{id: 3, name: C}", "{id: 50, name: C}", 1), "zbiór 1..3"},
		"powtorzony numer": {
			strings.Replace(good, "{id: 3, name: C}", "{id: 2, name: C}", 1), "zbiór 1..3"},
		"link do nieistniejacego elementu": {
			strings.Replace(good, "to: 2", "to: 99", 1), "nieistniejący element 99"},
		"element bez nazwy": {
			strings.Replace(good, "{id: 2, name: B}", "{id: 2}", 1), `"Name"`},
		"struktura pomija element": {
			strings.Replace(good, "    - el: 1\n", "", 1), "dokładnie raz"},
		"struktura powtarza element": {
			strings.Replace(good, "par: [{el: 2}, {el: 3}]", "par: [{el: 2}, {el: 2}]", 1), "dokładnie raz"},
		"wezel z dwoma polami naraz": {
			strings.Replace(good, "- el: 1\n", "- {el: 1, ser: [{el: 9}]}\n", 1), "dokładnie jedno z pól"},
		"brak elementow alternatywnych": {
			strings.Replace(good, "par: [{el: 2}, {el: 3}]", "ser: [{el: 2}, {el: 3}]", 1), "funkcje alternatywne"},
	}
	for name, c := range cases {
		t.Run(name, func(t *testing.T) {
			err := check(t, c.doc)
			if err == nil {
				t.Fatal("blad nie zostal wykryty")
			}
			if !strings.Contains(err.Error(), c.want) {
				t.Errorf("komunikat %q nie zawiera %q", err, c.want)
			}
		})
	}
}
