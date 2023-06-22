# Galois prover benchmarks

This benchmarking suite extract the various characteristics of the CometBLS ZK circuit (constraints, coefficients, size of public/secret inputs...) and provide an accurate end-to-end time measurement of a proving roundtrip through gRPC (client requesting the server to prove).

The suite is sequentially benchmarking the circuit for 4, 8, 16, 32, 64, 128 maximum validators.

## Available benchmarks

- [c6i.x32large](./c6i.x32large)

## Getting started

[Nix package manager](https://nixos.org) is required.

Re-generating the benchmark: `nix --extra-experimental-features nix-command --extra-experimental-features flakes run .#benchmark -- --output $(pwd)/report.html`

