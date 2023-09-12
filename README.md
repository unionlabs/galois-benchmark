# Galois prover benchmarks

This benchmarking suite extract the various characteristics of the CometBLS ZK circuit (constraints, coefficients, size of public/secret inputs...) and provide an accurate end-to-end time measurement of a proving roundtrip through gRPC (client requesting the server to prove).

The suite is sequentially benchmarking the circuit for 4, 8, 16, 32, 64, 128 maximum validators.

## Available benchmarks

- [c6i.x32large](./c6i.x32large)

## Getting started

[Nix package manager](https://nixos.org) is required.

Reference (c6i.x32large) specs:
- 256G RAM
- 128 CPU
- 256G DISK

You need to have a [GitHub PAT available to run the command](https://github.com/unionlabs/union/wiki/Personal-Access-Token-%28PAT%29-Setup).
Note: the PAT must have read-only access to both unionlabs/union and unionlabs/galois-benchmark.

To re-generate this benchmark, you don't have to clone the repo, but simply run the following command in the benchmarking machine: `nix --extra-experimental-features nix-command --extra-experimental-features flakes run github:unionlabs/galois-benchmark#benchmark -L --option access-tokens github.com=<YOUR_GITHUB_PAT> -- --output $(pwd)/report.html`

