# CloudQS
[![Build status (Github Actions)](https://github.com/CloudQuantumSim/CloudQS.jl/workflows/CI/badge.svg)](https://github.com/CloudQuantumSim/CloudQS.jl/actions)

## Installation

```
pkg> add CloudQS
```

## Usage

```julia
using Bloqade
include CloudQS 
nsites = 10
atoms = generate_sites(ChainLattice(), nsites, scale = 5.74)
h = rydberg_h(atoms; Ω = 4 * 2π, Δ = 0)

clconf = CloudQSServer.CloudConfig()
CloudQSServer.add_server!(clconf, "https://lykov.tech/cloudqs-jl", 80)

isodd = [Base.isodd(x) for x in 1:2^N]
rydberg = [Base.count_ones(x) for x in 1:2^N]
time_points = 10
observables = [isodd, rydberg]
CloudQSServer.cloud_simulate(h, time_points, observables)
```

See `examples/` folder for more usage.

