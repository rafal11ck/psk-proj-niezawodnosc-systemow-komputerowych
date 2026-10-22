package reliability

import (
	"fmt"
	"testing"
)

func fmtSets(ss [][]int) string {
	out := ""
	for _, s := range ss {
		out += fmt.Sprintf("%v", s)
	}
	return out
}

func TestMinPathsAndCuts(t *testing.T) {
	cfg, _ := system(t)
	els := allElements(cfg)

	paths := MinPaths(cfg.Structure, els)
	if got, want := fmtSets(paths), "[1 2 3 4 6 8][1 2 3 4 7 8][1 2 3 5 6 8][1 2 3 5 7 8]"; got != want {
		t.Errorf("sciezki minimalne:\n got %s\nwant %s", got, want)
	}

	cuts := MinCuts(cfg.Structure, els)
	if got, want := fmtSets(cuts), "[1][2][3][8][4 5][6 7]"; got != want {
		t.Errorf("ciecia minimalne:\n got %s\nwant %s", got, want)
	}
}

// φ on the trivial states, independent of the reference values.
func TestWorksBoundaries(t *testing.T) {
	cfg, _ := system(t)
	if !Works(cfg.Structure, []int{1, 2, 3, 4, 5, 6, 7, 8}) {
		t.Error("komplet zdatnych elementow: system powinien byc zdatny")
	}
	if Works(cfg.Structure, nil) {
		t.Error("brak zdatnych elementow: system powinien byc niezdatny")
	}
}

// Every single-element cut must be an element that appears in every path:
// those are exactly the critical elements of point 1d.
func TestSingleCutsAreTheCriticalElements(t *testing.T) {
	cfg, _ := system(t)
	els := allElements(cfg)
	paths := MinPaths(cfg.Structure, els)

	for _, c := range MinCuts(cfg.Structure, els) {
		if len(c) != 1 {
			continue
		}
		for _, p := range paths {
			if !isSubsetOf(c, p) {
				t.Errorf("element %v jest cieciem jednoelementowym, ale brak go w sciezce %v", c, p)
			}
		}
	}
}
