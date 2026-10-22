// Command nsk reads system.yaml, checks it against the rules the assignment
// puts on the system description, and writes the reliability figures the
// report renders.
package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"

	"nsk/internal/model"
)

func main() {
	log.SetFlags(0)
	in := flag.String("in", "system.yaml", "input data file")
	out := flag.String("out", filepath.Join("out", "results.yaml"), "output file")
	flag.Parse()

	cfg, err := load(*in)
	if err != nil {
		log.Fatalf("%s:\n  - %v", *in, err)
	}
	if err := save(*out, compute(cfg)); err != nil {
		log.Fatalf("%s: %v", *out, err)
	}
	fmt.Printf("%s -> %s (%s)\n", *in, *out, cfg)
}

func load(path string) (model.Config, error) {
	var cfg model.Config
	raw, err := os.ReadFile(path)
	if err != nil {
		return cfg, err
	}
	if err := yaml.Unmarshal(raw, &cfg); err != nil {
		return cfg, err
	}
	return cfg, model.Validate(cfg)
}

func save(path string, res Result) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	raw, err := yaml.Marshal(res)
	if err != nil {
		return err
	}
	const header = "# Wygenerowane z system.yaml przez `task calc`. Nie edytować ręcznie.\n"
	return os.WriteFile(path, append([]byte(header), raw...), 0o644)
}
