package main

import (
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

// PlotPoint is one sample of N_R(t) for the point-3e chart.
type PlotPoint struct {
	T  int     `yaml:"t"`
	Nr float64 `yaml:"nr"`
}

// Redundancy carries point 3: the series element DupID is duplicated by a
// parallel spare SpareID with the same λ.
type Redundancy struct {
	DupID    int    `yaml:"dupId"`    // duplicated element
	DupName  string `yaml:"dupName"`  // name of the duplicated element
	SpareID  int    `yaml:"spareId"`  // added spare
	DupUnits int    `yaml:"dupUnits"` // λ of the duplicated element, in units of Micro

	// Topology the report renders (3a, 3b): the base system plus the spare.
	Elements  []model.Element `yaml:"elements"`  // elements incl. the spare
	Links     []model.Link    `yaml:"links"`     // links incl. the spare's
	Structure model.Node      `yaml:"structure"` // reliability structure with the spare

	Terms   []Term `yaml:"terms"`   // 3c, R_r(t) = Σ c·e^(-rμt)
	Rr      string `yaml:"rr"`      // 3c, R_r(t)
	RrDelta string `yaml:"rrDelta"` // R_r(t+Δ)
	Pr      string `yaml:"pr"`      // 3c, P_r(t,t+Δ)
	Etr     string `yaml:"etr"`     // 3c, ET_r [h]
	EtrSum  string `yaml:"etrSum"`  // 3c, the dimensionless Σ c/r

	NrT string `yaml:"nrT"` // 3d, N_R(t)
	Nr0 string `yaml:"nr0"` // 3d, N_R(0)
	NpT string `yaml:"npT"` // 3d, N_P(t,t+Δ)
	Net string `yaml:"net"` // 3d, N_ET

	Horizon int         `yaml:"horizon"` // 3e, right end of the search interval
	TStar   int         `yaml:"tStar"`   // 3e, argmax of N_R(t)
	MaxNr   string      `yaml:"maxNr"`   // 3e, max N_R(t)
	Plot    []PlotPoint `yaml:"plot"`    // 3e, chart samples
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

	Redundancy Redundancy `yaml:"redundancy"` // 3
}

func compute(cfg model.Config) Result {
	n := cfg.Count()
	t := reliability.Instant(cfg.N)
	res := Result{N: cfg.N, Count: n, T: t, DeltaT: reliability.Delta}

	for _, e := range cfg.Elements {
		units := reliability.LambdaUnits(cfg.N, n, e.ID)
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
	for _, m := range expansion.SortedByRate(cfg.N, n) {
		res.Monomials = append(res.Monomials, Monomial{
			Elements: m.Elements, Coeff: m.Coeff, Rate: m.Rate(cfg.N, n),
		})
	}

	rs := expansion.Terms(cfg.N, n)
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

	res.Redundancy = redundancy(cfg, rs, et, t)
	return res
}

// redundancy computes point 3: duplicate the first element with a parallel
// spare carrying the same λ, then recompute R_r, P_r, ET_r and the benefit
// indices N against the base system.
func redundancy(cfg model.Config, rs reliability.Terms, ets *big.Rat, t int) Redundancy {
	n := cfg.Count()
	dupID := 1
	spareID := n + 1
	dupUnits := reliability.LambdaUnits(cfg.N, n, dupID)

	var dupName string
	for _, e := range cfg.Elements {
		if e.ID == dupID {
			dupName = e.Name
		}
	}
	red := Redundancy{DupID: dupID, DupName: dupName, SpareID: spareID, DupUnits: dupUnits}

	// Topology with the spare: the report renders this, it does not derive it.
	red.Elements = append(slices.Clone(cfg.Elements), model.Element{ID: spareID, Name: dupName})
	red.Links = slices.Clone(cfg.Links)
	for _, l := range cfg.Links {
		if l.From == dupID {
			red.Links = append(red.Links, model.Link{From: spareID, To: l.To, Label: l.Label})
		}
	}
	red.Structure = cfg.Structure.Duplicate(dupID, spareID)

	rr := rs.Redundant(dupUnits)
	for _, r := range slices.Sorted(maps.Keys(rr)) {
		red.Terms = append(red.Terms, Term{Rate: r, Coeff: rr[r]})
	}
	red.Rr = round(rr.At(t))
	red.RrDelta = round(rr.At(t + reliability.Delta))
	red.Pr = round(rr.NoFailure(t, reliability.Delta))

	etr := rr.ExpectedUptime()
	red.Etr = etr.FloatString(1)
	red.EtrSum = new(big.Rat).Mul(etr, big.NewRat(1, 1_000_000)).FloatString(8)

	red.NrT = round(rr.At(t) / rs.At(t))
	red.Nr0 = round(rr.At(0) / rs.At(0))
	red.NpT = round(rr.NoFailure(t, reliability.Delta) / rs.NoFailure(t, reliability.Delta))
	red.Net = new(big.Rat).Quo(etr, ets).FloatString(Digits)

	const horizon = 100_000
	red.Horizon = horizon
	best, bestT := -1.0, 0
	for tt := 0; tt <= horizon; tt += 100 {
		if v := rr.At(tt) / rs.At(tt); v > best {
			best, bestT = v, tt
		}
	}
	red.TStar, red.MaxNr = bestT, round(best)
	for tt := 0; tt <= horizon; tt += 2500 {
		red.Plot = append(red.Plot, PlotPoint{T: tt, Nr: rr.At(tt) / rs.At(tt)})
	}
	return red
}
