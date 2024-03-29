# CloudQSim
[![Build status (Github Actions)](https://github.com/CloudQuantumSim/CloudQSim.jl/workflows/CI/badge.svg)](https://github.com/CloudQuantumSim/CloudQSim.jl/actions)

## Installation

```
pkg> add CloudQSim
```

## Usage

CloudQSim allows to calculate evolution of observables for quantum hamiltonians.
Any diagonal observable is supported. An observable is defined by a vector that
maps each quantum state to the observable value.

Parameters:
* `hamiltonians` - a Bloqade.jl hamiltonian
* `time_points` - number of poinst in time when observables are evaluated
* `observables` - Vector of observables to evaluate
* `clconf` - `CloudQSim.CloudConfig` specifies the servers to use
* `subspace_radius` (optional keyword) - used to generate subspace for faster
  evolution


### Minimal example

```julia
using BloqadeExpr, BloqadeLattices, BloqadeWaveforms
import CloudQSim

nsites = 10
atoms = generate_sites(ChainLattice(), nsites, scale = 5.74)
T_end = 1.
Δ = piecewise_linear(; clocks = [0, T_end], values = [0., 0.])
ϕ = piecewise_constant(; clocks = [0, T_end], values = [0.])
Ω = piecewise_linear(; clocks = [0, T_end], values = [2π, 2π])
h = rydberg_h(atoms; Ω = Ω, Δ = Δ, ϕ = ϕ)

clconf = CloudQSim.CloudConfig()
CloudQSim.add_server!(clconf, "cloudqs.lykov.tech", 7700)

qstates = 0:2^nsites-1
isodd = [x%2 for x in qstates]
rydberg = [Base.count_ones(x) for x in qstates]
observables = [isodd, rydberg]
time_points = 10
data = CloudQSim.cloud_simulate(h, time_points, observables, clconf)
```

See `examples/` folder for more usage.

