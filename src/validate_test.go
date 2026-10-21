package main

import (
	"strings"
	"testing"

	"gopkg.in/yaml.v3"
)

const good = `
N: 3
elements:
  - {id: 1, name: A}
  - {id: 2, name: B, group: g}
  - {id: 3, name: C, group: g}
links:
  - {from: 1, to: 2, label: x}
`

func check(t *testing.T, doc string) error {
	t.Helper()
	var cfg Config
	if err := yaml.Unmarshal([]byte(doc), &cfg); err != nil {
		t.Fatalf("yaml: %v", err)
	}
	return validate(cfg)
}

func TestValidDocumentPasses(t *testing.T) {
	if err := check(t, good); err != nil {
		t.Fatalf("poprawny dokument odrzucony: %v", err)
	}
}

func TestInvalidDocumentsAreRejected(t *testing.T) {
	cases := map[string]struct{ doc, want string }{
		"numer elementu poza 1..n": {
			strings.Replace(good, "{id: 3, name: C, group: g}", "{id: 50, name: C, group: g}", 1), "zbiór 1..3"},
		"powtorzony numer": {
			strings.Replace(good, "{id: 3, name: C, group: g}", "{id: 2, name: C, group: g}", 1), "zbiór 1..3"},
		"link do nieistniejacego elementu": {
			strings.Replace(good, "to: 2", "to: 99", 1), "nieistniejący element 99"},
		"element bez nazwy": {
			strings.Replace(good, "{id: 2, name: B, group: g}", "{id: 2, group: g}", 1), `"Name"`},
		"grupa jednoelementowa": {
			strings.Replace(good, "{id: 3, name: C, group: g}", "{id: 3, name: C}", 1),
			"zawiera tylko element"},
		"brak elementow alternatywnych": {
			strings.ReplaceAll(good, ", group: g", ""), "funkcje alternatywne"},
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
