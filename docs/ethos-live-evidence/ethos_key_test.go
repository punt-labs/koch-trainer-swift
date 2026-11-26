package hook

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
)

func init() {
	root := os.Getenv("KOCH_KEY_ROOT")
	if root == "" {
		return
	}
	value, err := kochKey(root)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	fmt.Println(string(value))
	os.Exit(0)
}

func kochKey(root string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(context.Background(), gateInputTime)
	defer cancel()
	paths, err := worktreeSnapshotInputs(ctx, root)
	if err != nil {
		return nil, err
	}
	state, proof, err := handoffGateInputs(ctx, root, paths)
	if err != nil {
		return nil, err
	}
	return json.Marshal(struct {
		State string   `json:"state"`
		Proof string   `json:"proof"`
		Paths []string `json:"paths"`
	}{state, proof, paths})
}
