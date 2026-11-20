package main

import (
	"slices"
	"testing"

	"gopkg.in/yaml.v3"

	"nsk/internal/model"
)

// Reference values were computed independently in Python (Simpson for ET,
// a 1 h scan for t*) for N=3, t=115 h, Δ=100 h.
const doc = `
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
redundancy:
  - dup: [1]
  - dup: [2]
  - dup: [3]
  - dup: [4]
  - dup: [5]
  - dup: [6]
  - dup: [7]
  - dup: [8]
`

func computed(t *testing.T) Result {
	t.Helper()
	var cfg model.Config
	if err := yaml.Unmarshal([]byte(doc), &cfg); err != nil {
		t.Fatalf("yaml: %v", err)
	}
	return compute(cfg)
}

func TestVariants(t *testing.T) {
	res := computed(t)
	want := []struct {
		id         int
		series     bool
		etr, net   string
		tStar      int
		maxNr, nrT string
	}{
		{9, true, "8806.1", "1.043825", 100000, "1.451188", "1.000690"},
		{10, true, "11213.4", "1.329166", 100000, "1.998164", "1.007219"},
		{11, true, "9460.5", "1.121391", 100000, "1.834701", "1.002068"},
		{12, false, "8835.9", "1.047351", 51257, "1.240253", "1.000018"},
		{13, false, "8944.8", "1.060262", 100000, "1.775281", "1.000018"},
		{14, false, "8890.1", "1.053774", 100000, "1.760517", "1.000015"},
		{15, false, "8791.8", "1.042123", 53499, "1.228146", "1.000015"},
		{16, true, "8979.7", "1.064403", 100000, "1.593430", "1.001034"},
	}
	if len(res.Variants) != len(want) {
		t.Fatalf("liczba wariantow = %d, want %d", len(res.Variants), len(want))
	}
	for k, w := range want {
		v := res.Variants[k]
		if got := v.Spares[0].ID; got != w.id {
			t.Errorf("wariant %d: zapas E%d, want E%d", k, got, w.id)
		}
		if v.Series != w.series || v.Etr != w.etr || v.Net != w.net ||
			v.TStar != w.tStar || v.MaxNr != w.maxNr || v.NrT != w.nrT {
			t.Errorf("wariant E%d: got series=%v ETr=%s N_ET=%s t*=%d max=%s N_R=%s, want %+v",
				v.Spares[0].Of, v.Series, v.Etr, v.Net, v.TStar, v.MaxNr, v.NrT, w)
		}
	}
}

// E4/E5 and E6/E7 tie on six decimals of N_R(t), so the order must come from
// the exact values: the spare for the more reliable element of a pair wins.
func TestOrder(t *testing.T) {
	o := computed(t).Order
	for _, c := range []struct {
		name      string
		got, want []int
	}{
		{"nrT", o.NrT, []int{1, 2, 7, 0, 4, 3, 5, 6}},
		{"npT", o.NpT, []int{1, 2, 7, 0, 4, 3, 5, 6}},
		{"net", o.Net, []int{1, 2, 7, 4, 5, 3, 0, 6}},
		{"maxNr", o.MaxNr, []int{1, 2, 4, 5, 7, 0, 3, 6}},
	} {
		if !slices.Equal(c.got, c.want) {
			t.Errorf("%s = %v, want %v", c.name, c.got, c.want)
		}
	}
}
