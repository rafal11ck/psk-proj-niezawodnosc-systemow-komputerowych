package main

import (
	"errors"
	"fmt"
	"slices"
	"strings"

	"github.com/go-playground/validator/v10"
)

// validate runs the struct tags plus the whole-document rules, reporting every
// problem at once.
func validate(cfg Config) error {
	v := validator.New(validator.WithRequiredStructEnabled())
	v.RegisterStructValidation(checkDocument, Config{})

	var ve validator.ValidationErrors
	err := v.Struct(cfg)
	if !errors.As(err, &ve) {
		return err
	}
	msgs := make([]string, len(ve))
	for i, fe := range ve {
		if msgs[i] = fe.Param(); msgs[i] == "" { // checkDocument puts its message in Param
			msgs[i] = fmt.Sprintf("pole %q nie spełnia reguły %q", fe.Field(), fe.Tag())
		}
	}
	return errors.New(strings.Join(msgs, "\n  - "))
}

func checkDocument(sl validator.StructLevel) {
	cfg := sl.Current().Interface().(Config)
	n := cfg.Count()
	fail := func(field, tag, msg string) { sl.ReportError(cfg, field, field, tag, msg) }

	ids := make([]int, len(cfg.Elements))
	for i, e := range cfg.Elements {
		ids[i] = e.ID
	}
	if !isPermutation(ids, n) {
		fail("elements", "ids", fmt.Sprintf("numery elementów muszą tworzyć zbiór 1..%d, otrzymano %v",
			n, slices.Sorted(slices.Values(ids))))
	}

	for _, l := range cfg.Links {
		for _, id := range []int{l.From, l.To} {
			if id < 1 || id > n {
				fail("links", "range", fmt.Sprintf("połączenie wskazuje na nieistniejący element %d", id))
			}
		}
	}

	shaped := true
	cfg.Structure.Walk(func(nd Node) { shaped = shaped && nd.filled() == 1 })
	if !shaped {
		fail("structure", "shape", "każdy węzeł musi mieć dokładnie jedno z pól el/ser/par")
	}
	if used := cfg.Structure.Elements(); !isPermutation(used, n) {
		fail("structure", "cover", fmt.Sprintf(
			"struktura musi obejmować każdy element dokładnie raz, otrzymano %v",
			slices.Sorted(slices.Values(used))))
	}
	// Point 1 requires at least two elements performing alternative functions.
	if !cfg.Structure.HasParallel() {
		fail("structure", "parallel",
			"treść zadania wymaga co najmniej 2 elementów pełniących funkcje alternatywne (węzeł par)")
	}
}

// isPermutation reports whether ids contains each of 1..n exactly once.
func isPermutation(ids []int, n int) bool {
	if len(ids) != n {
		return false
	}
	seen := make([]bool, n+1)
	for _, id := range ids {
		if id < 1 || id > n || seen[id] {
			return false
		}
		seen[id] = true
	}
	return true
}
