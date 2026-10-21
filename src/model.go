package main

import "fmt"

type Element struct {
	ID   int    `yaml:"id"   validate:"required,min=1"`
	Name string `yaml:"name" validate:"required"`
	// Group names the set of elements performing the same function; any one
	// of them suffices. An element without a group is critical.
	Group string `yaml:"group,omitempty"`
}

type Link struct {
	From  int    `yaml:"from"  validate:"required,min=1"`
	To    int    `yaml:"to"    validate:"required,min=1"`
	Label string `yaml:"label"`
}

// Config is system.yaml.
type Config struct {
	N        int       `yaml:"N"        validate:"required,min=1"`
	Elements []Element `yaml:"elements" validate:"required,min=1,dive"`
	Links    []Link    `yaml:"links"    validate:"dive"`
}

// Count is n, the number of elements.
func (c Config) Count() int { return len(c.Elements) }

func (c Config) String() string { return fmt.Sprintf("N=%d n=%d", c.N, c.Count()) }
