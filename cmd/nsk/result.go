package main

import (
	"maps"
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
	EtsExact  string     `yaml:"etsExact"`  // 2c, exact fraction
	Paths     [][]int    `yaml:"paths"`     // 2d
	Cuts      [][]int    `yaml:"cuts"`      // 2e
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

	els := make([]int, n)
	for i := range els {
		els[i] = i + 1
	}
	res.Paths = reliability.MinPaths(cfg.Structure, els)
	res.Cuts = reliability.MinCuts(cfg.Structure, els)
	return res
}
