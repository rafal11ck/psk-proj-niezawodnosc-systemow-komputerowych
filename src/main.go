// Command nsk reads system.yaml and checks it against the rules the assignment
// puts on the system description. The report draws its tables and its diagram
// straight from that file, so a typo there would otherwise pass unnoticed.
package main

import (
	"flag"
	"fmt"
	"log"
	"os"

	"gopkg.in/yaml.v3"
)

func main() {
	log.SetFlags(0)
	in := flag.String("in", "system.yaml", "input data file")
	flag.Parse()

	cfg, err := load(*in)
	if err != nil {
		log.Fatalf("%s:\n  - %v", *in, err)
	}
	fmt.Printf("%s: OK (%s)\n", *in, cfg)
}

func load(path string) (Config, error) {
	var cfg Config
	raw, err := os.ReadFile(path)
	if err != nil {
		return cfg, err
	}
	if err := yaml.Unmarshal(raw, &cfg); err != nil {
		return cfg, err
	}
	return cfg, validate(cfg)
}
