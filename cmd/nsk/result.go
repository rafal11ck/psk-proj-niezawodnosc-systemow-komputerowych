package main

import (
	"cmp"
	"maps"
	"math/big"
	"slices"
	"strconv"

	"nsk/internal/model"
	"nsk/internal/reliability"
)

// Digits is how many decimal places the report shows for probabilities. They
// are rounded once, here, where the exact value is known. Times in hours are
// formatted separately: five decimals would be meaningless precision there.
const Digits = 6

func round(x float64) string { return strconv.FormatFloat(x, 'f', Digits, 64) }

// ElementResult carries the per-element figures of point 2's preamble.
type ElementResult struct {
	model.Element `yaml:",inline"`
	LambdaUnits   int    `yaml:"lambdaUnits"` // multiples of 1e-6 1/h
	Lambda        string `yaml:"lambda"`      // 1/h, exact
	R             string `yaml:"R"`           // R_i(t)
	ET            string `yaml:"et"`          // h
}

// Monomial is one product term of the multiplied-out structure function,
// before the exponentials are collected. The report shows these so the
// derivation of R_s(t) can be followed step by step.
type Monomial struct {
	Elements []int `yaml:"elements"`
	Coeff    int   `yaml:"coeff"`
	Rate     int   `yaml:"rate"`
}

// Term is one summand of R_s(t) = Σ c·e^(-r·μ·t).
type Term struct {
	Rate  int `yaml:"rate"`
	Coeff int `yaml:"coeff"`
}

// PlotPoint is one sample of N_R(t) for the chart.
type PlotPoint struct {
	T  int     `yaml:"t"`
	Nr float64 `yaml:"nr"`
}

// Spare is an element added in parallel to element Of, with the same λ.
type Spare struct {
	Of    int `yaml:"of"`
	ID    int `yaml:"id"`
	Units int `yaml:"units"`
}

// Variant is one redundancy variant (point 3 onwards), compared against the
// base system.
type Variant struct {
	Spares []Spare `yaml:"spares"`
	// Every duplicated element is a series factor of the base system, so
	// R_r = Π(2 - R_k)·R_s and N_R(t) = Π(2 - e^(-λ_k t)) hold.
	Series bool `yaml:"series"`

	Elements  []model.Element `yaml:"elements"`
	Links     []model.Link    `yaml:"links"`
	Structure model.Node      `yaml:"structure"`

	Terms   []Term `yaml:"terms"`
	Rr      string `yaml:"rr"`
	RrDelta string `yaml:"rrDelta"`
	Pr      string `yaml:"pr"`
	Etr     string `yaml:"etr"`
	EtrSum  string `yaml:"etrSum"`

	NrT string `yaml:"nrT"`
	Nr0 string `yaml:"nr0"`
	NpT string `yaml:"npT"`
	Net string `yaml:"net"`

	Horizon int         `yaml:"horizon"`
	Step    int         `yaml:"step"`
	TStar   int         `yaml:"tStar"`
	MaxNr   string      `yaml:"maxNr"`
	Plot    []PlotPoint `yaml:"plot"`

	benefit benefit
}

// benefit keeps the unrounded measures so variants are ranked on exact values,
// not on the six printed decimals, where some of them tie.
type benefit struct{ nrT, npT, net, maxNr float64 }

// Order lists indexes into Variants from the largest benefit to the smallest,
// one list per measure (conclusion b).
type Order struct {
	NrT   []int `yaml:"nrT"`
	NpT   []int `yaml:"npT"`
	Net   []int `yaml:"net"`
	MaxNr []int `yaml:"maxNr"`
}

func rank(vs []Variant, key func(benefit) float64) []int {
	idx := make([]int, len(vs))
	for i := range idx {
		idx[i] = i
	}
	slices.SortStableFunc(idx, func(a, b int) int {
		return cmp.Compare(key(vs[b].benefit), key(vs[a].benefit))
	})
	return idx
}

type Result struct {
	N        int             `yaml:"N"`
	Count    int             `yaml:"count"`
	T        int             `yaml:"t"`
	DeltaT   int             `yaml:"deltaT"`
	Elements []ElementResult `yaml:"elements"`

	Monomials []Monomial `yaml:"monomials"` // 2a, after multiplying out
	Terms     []Term     `yaml:"terms"`     // 2a, after collecting exponents
	Rs        string     `yaml:"rs"`        // 2a, R_s(t)
	RsDelta   string     `yaml:"rsDelta"`   // R_s(t+Δ)
	Ps        string     `yaml:"ps"`        // 2b
	Ets       string     `yaml:"ets"`       // 2c, hours
	EtsSum    string     `yaml:"etsSum"`    // 2c, the dimensionless Σ c/r
	EtsExact  string     `yaml:"etsExact"`  // 2c, exact fraction (not rendered)
	Paths     [][]int    `yaml:"paths"`     // 2d
	Cuts      [][]int    `yaml:"cuts"`      // 2e

	Variants []Variant `yaml:"variants"` // 3 onwards, in system.yaml order
	Order    Order     `yaml:"order"`
}

func compute(cfg model.Config) Result {
	n := cfg.Count()
	t := reliability.Instant(cfg.N)
	res := Result{N: cfg.N, Count: n, T: t, DeltaT: reliability.Delta}
	rates := reliability.BaseRates(cfg.N, n)

	for _, e := range cfg.Elements {
		units := rates[e.ID]
		res.Elements = append(res.Elements, ElementResult{
			Element:     e,
			LambdaUnits: units,
			// denominator is 1e6, so six places are exact
			Lambda: reliability.Lambda(units).FloatString(6),
			R:      round(reliability.Survival(units, t)),
			ET:     reliability.ElementUptime(units).FloatString(1),
		})
	}

	expansion := reliability.Expand(cfg.Structure)
	for _, m := range expansion.SortedByRate(rates) {
		res.Monomials = append(res.Monomials, Monomial{
			Elements: m.Elements, Coeff: m.Coeff, Rate: m.Rate(rates),
		})
	}

	rs := expansion.Terms(rates)
	for _, r := range slices.Sorted(maps.Keys(rs)) {
		res.Terms = append(res.Terms, Term{Rate: r, Coeff: rs[r]})
	}
	res.Rs = round(rs.At(t))
	res.RsDelta = round(rs.At(t + reliability.Delta))
	res.Ps = round(rs.NoFailure(t, reliability.Delta))

	et := rs.ExpectedUptime()
	res.Ets = et.FloatString(1)
	res.EtsExact = et.RatString()
	// ET = (1/μ)·Σ c/r, so the bracketed sum is ET·μ. Printing that instead of
	// the exact fraction keeps the numbers readable: the common denominator of
	// 153, 168, 183 … runs to eleven digits and tells the reader nothing.
	res.EtsSum = new(big.Rat).Mul(et, big.NewRat(1, 1_000_000)).FloatString(8)

	els := make([]int, n)
	for i := range els {
		els[i] = i + 1
	}
	res.Paths = reliability.MinPaths(cfg.Structure, els)
	res.Cuts = reliability.MinCuts(cfg.Structure, els)

	next := n + 1
	for _, v := range cfg.Redundancy {
		res.Variants = append(res.Variants, variant(cfg, v.Dup, next, rates, rs, et, t))
		next += len(v.Dup)
	}
	res.Order = Order{
		NrT:   rank(res.Variants, func(b benefit) float64 { return b.nrT }),
		NpT:   rank(res.Variants, func(b benefit) float64 { return b.npT }),
		Net:   rank(res.Variants, func(b benefit) float64 { return b.net }),
		MaxNr: rank(res.Variants, func(b benefit) float64 { return b.maxNr }),
	}
	return res
}

func variant(cfg model.Config, dup []int, first int, base reliability.Rates, rs reliability.Terms, ets *big.Rat, t int) Variant {
	v := Variant{
		Series:    true,
		Elements:  slices.Clone(cfg.Elements),
		Links:     slices.Clone(cfg.Links),
		Structure: cfg.Structure,
	}
	rates := maps.Clone(base)
	for k, of := range dup {
		id := first + k
		rates[id] = base[of]
		v.Spares = append(v.Spares, Spare{Of: of, ID: id, Units: base[of]})
		v.Series = v.Series && cfg.Structure.IsSeries(of)

		at := slices.IndexFunc(cfg.Elements, func(e model.Element) bool { return e.ID == of })
		v.Elements = append(v.Elements, model.Element{ID: id, Name: cfg.Elements[at].Name})
		for _, l := range cfg.Links {
			switch of {
			case l.From:
				v.Links = append(v.Links, model.Link{From: id, To: l.To, Label: l.Label})
			case l.To:
				v.Links = append(v.Links, model.Link{From: l.From, To: id, Label: l.Label})
			}
		}
		v.Structure = v.Structure.Duplicate(of, id)
	}

	rr := reliability.Of(v.Structure, rates)
	for _, r := range slices.Sorted(maps.Keys(rr)) {
		v.Terms = append(v.Terms, Term{Rate: r, Coeff: rr[r]})
	}
	v.Rr = round(rr.At(t))
	v.RrDelta = round(rr.At(t + reliability.Delta))
	v.Pr = round(rr.NoFailure(t, reliability.Delta))

	etr := rr.ExpectedUptime()
	v.Etr = etr.FloatString(1)
	v.EtrSum = new(big.Rat).Mul(etr, big.NewRat(1, 1_000_000)).FloatString(8)

	net := new(big.Rat).Quo(etr, ets)
	v.benefit.nrT = rr.At(t) / rs.At(t)
	v.benefit.npT = rr.NoFailure(t, reliability.Delta) / rs.NoFailure(t, reliability.Delta)
	v.benefit.net, _ = net.Float64()
	v.NrT = round(v.benefit.nrT)
	v.Nr0 = round(rr.At(0) / rs.At(0))
	v.NpT = round(v.benefit.npT)
	v.Net = net.FloatString(Digits)

	v.Horizon, v.Step = reliability.Horizon, reliability.Step
	best, bestT := -1.0, 0
	for tt := 0; tt <= reliability.Horizon; tt += reliability.Step {
		if nr := rr.At(tt) / rs.At(tt); nr > best {
			best, bestT = nr, tt
		}
	}
	v.TStar, v.MaxNr = bestT, round(best)
	v.benefit.maxNr = best
	for tt := 0; tt <= reliability.Horizon; tt += reliability.Horizon / 40 {
		v.Plot = append(v.Plot, PlotPoint{T: tt, Nr: rr.At(tt) / rs.At(tt)})
	}
	return v
}
