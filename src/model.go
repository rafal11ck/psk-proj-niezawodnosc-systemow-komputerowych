package main

import "fmt"

type Element struct {
	ID   int    `yaml:"id"   validate:"required,min=1"`
	Name string `yaml:"name" validate:"required"`
}

type Link struct {
	From  int    `yaml:"from"  validate:"required,min=1"`
	To    int    `yaml:"to"    validate:"required,min=1"`
	Label string `yaml:"label"`
}

// Node is a node of the reliability structure tree; exactly one field is set.
// One key per mapping is what lets yaml.v3 decode the tree with no custom
// unmarshaller.
type Node struct {
	El  int    `yaml:"el,omitempty"`
	Ser []Node `yaml:"ser,omitempty"`
	Par []Node `yaml:"par,omitempty"`
}

func (n Node) kids() []Node { return append(append([]Node{}, n.Ser...), n.Par...) }

// Elements lists every element id in the subtree, in order.
func (n Node) Elements() []int {
	if n.El != 0 {
		return []int{n.El}
	}
	var out []int
	for _, c := range n.kids() {
		out = append(out, c.Elements()...)
	}
	return out
}

// HasParallel reports whether any elements perform alternative functions.
func (n Node) HasParallel() bool {
	if len(n.Par) > 0 {
		return true
	}
	for _, c := range n.kids() {
		if c.HasParallel() {
			return true
		}
	}
	return false
}

func (n Node) Walk(fn func(Node)) {
	fn(n)
	for _, c := range n.kids() {
		c.Walk(fn)
	}
}

// filled counts how many of the three variants the node sets.
func (n Node) filled() int {
	c := 0
	for _, set := range []bool{n.El != 0, len(n.Ser) > 0, len(n.Par) > 0} {
		if set {
			c++
		}
	}
	return c
}

// Config is system.yaml.
type Config struct {
	N         int       `yaml:"N"         validate:"required,min=1"`
	Elements  []Element `yaml:"elements"  validate:"required,min=1,dive"`
	Links     []Link    `yaml:"links"     validate:"dive"`
	Structure Node      `yaml:"structure"`
}

// Count is n, the number of elements. Nothing here assumes 8.
func (c Config) Count() int { return len(c.Elements) }

func (c Config) String() string { return fmt.Sprintf("N=%d n=%d", c.N, c.Count()) }
