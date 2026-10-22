package reliability

import (
	"testing"

	"gopkg.in/yaml.v3"

	"nsk/internal/model"
)

// systemDoc is the analysed system: E1-E2-E3-(E4∥E5)-(E6∥E7)-E8 with N=3.
// Reference values in the tests were computed independently in Python
// (decimal, 40 digits) for N=3, n=8, t=115 h, Δ=100 h.
const systemDoc = `
N: 3
elements:
  - {id: 1, name: a}
  - {id: 2, name: b}
  - {id: 3, name: c}
  - {id: 4, name: d}
  - {id: 5, name: e}
  - {id: 6, name: f}
  - {id: 7, name: g}
  - {id: 8, name: h}
links: []
structure:
  ser:
    - el: 1
    - el: 2
    - el: 3
    - par: [{el: 4}, {el: 5}]
    - par: [{el: 6}, {el: 7}]
    - el: 8
`

// parse decodes a document without validating it.
func parse(t *testing.T, doc string) model.Config {
	t.Helper()
	var cfg model.Config
	if err := yaml.Unmarshal([]byte(doc), &cfg); err != nil {
		t.Fatalf("yaml: %v", err)
	}
	return cfg
}

// system returns the analysed system together with its reliability function.
func system(t *testing.T) (model.Config, Terms) {
	t.Helper()
	cfg := parse(t, systemDoc)
	return cfg, Of(cfg.Structure, cfg.N, cfg.Count())
}

// allElements lists 1..n for the analysed system.
func allElements(cfg model.Config) []int {
	out := make([]int, cfg.Count())
	for i := range out {
		out[i] = i + 1
	}
	return out
}
