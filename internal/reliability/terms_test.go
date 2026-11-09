package reliability

import (
	"math"
	"testing"
)

func TestLambdaUnits(t *testing.T) {
	want := []int{6, 63, 18, 45, 30, 27, 42, 9}
	for i, w := range want {
		if got := LambdaUnits(3, 8, i+1); got != w {
			t.Errorf("λ_%d = %d, want %d", i+1, got, w)
		}
	}
	// The 9 in the even-index formula must come from n+1, not a constant.
	if got, want := LambdaUnits(1, 6, 2), 15; got != want {
		t.Errorf("LambdaUnits(1, 6, 2) = %d, want %d", got, want)
	}
}

func TestExponentialForm(t *testing.T) {
	_, rs := system(t)
	want := Terms{153: 1, 168: 2, 183: 1, 195: -1, 198: -1, 210: -1, 213: -1, 240: 1}
	if len(rs) != len(want) {
		t.Fatalf("liczba skladnikow = %d, want %d: %v", len(rs), len(want), rs)
	}
	for r, c := range want {
		if rs[r] != c {
			t.Errorf("skladnik e^(-%dμt): wspolczynnik %d, want %d", r, rs[r], c)
		}
	}
}

func TestReliabilityValues(t *testing.T) {
	cfg, rs := system(t)
	tt := Instant(cfg.N)
	if tt != 115 {
		t.Fatalf("t = %d, want 115", tt)
	}
	for _, c := range []struct {
		at   int
		want float64
	}{{115, 0.988988361865}, {215, 0.979459942518}} {
		if got := rs.At(c.at); math.Abs(got-c.want) > 1e-12 {
			t.Errorf("Rs(%d) = %.12f, want %.12f", c.at, got, c.want)
		}
	}
	if got, want := rs.NoFailure(tt, Delta), 0.990471580653; math.Abs(got-want) > 1e-12 {
		t.Errorf("Ps = %.12f, want %.12f", got, want)
	}
}

// R(0) = 1 and R(t) → 0: holds for any structure, independent of the reference.
func TestReliabilityBoundaries(t *testing.T) {
	_, rs := system(t)
	if got := rs.At(0); math.Abs(got-1) > 1e-12 {
		t.Errorf("Rs(0) = %.15f, want 1", got)
	}
	if got := rs.At(10_000_000); got > 1e-6 {
		t.Errorf("Rs(1e7) = %g, want ~0", got)
	}
}

// Duplicating the series element E1 with an equal parallel spare multiplies
// R_s by (2 - R_1): R_r(t) = (2 - e^(-λ_1 t))·R_s(t), and R_r(0) = 1.
func TestRedundant(t *testing.T) {
	cfg, rs := system(t)
	rr := rs.Redundant(LambdaUnits(cfg.N, cfg.Count(), 1)) // λ_1 = 6 units
	if got := rr.At(0); math.Abs(got-1) > 1e-12 {
		t.Errorf("Rr(0) = %.15f, want 1", got)
	}
	for _, at := range []int{0, 115, 215, 50_000} {
		want := (2 - Survival(6, at)) * rs.At(at)
		if got := rr.At(at); math.Abs(got-want) > 1e-12 {
			t.Errorf("Rr(%d) = %.12f, want (2-R1)Rs = %.12f", at, got, want)
		}
	}
	// redundancy raises the expected uptime, and it stays an exact fraction
	if etr, ets := rr.ExpectedUptime(), rs.ExpectedUptime(); etr.Cmp(ets) <= 0 {
		t.Errorf("ETr %s nie wieksze od ETs %s", etr.RatString(), ets.RatString())
	} else if etr.IsInt() {
		t.Errorf("ETr wyszlo calkowite (%s), spodziewany ulamek", etr.RatString())
	}
}

func TestExpectedUptime(t *testing.T) {
	_, rs := system(t)
	got, _ := rs.ExpectedUptime().Float64()
	if want := 8436.406537; math.Abs(got-want) > 1e-5 {
		t.Errorf("ETs = %.6f, want %.6f", got, want)
	}
	// exact, not a float artefact
	if r := rs.ExpectedUptime(); r.IsInt() {
		t.Errorf("ETs wyszlo calkowite (%s), spodziewany ulamek", r.RatString())
	}
}
