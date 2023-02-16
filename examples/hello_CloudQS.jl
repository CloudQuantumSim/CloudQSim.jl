using Bloqade
include CloudQS 
nsites = 10
atoms = generate_sites(ChainLattice(), nsites, scale = 5.74)
h = rydberg_h(atoms; Ω = 4 * 2π, Δ = 0)

clconf = CloudQSServer.CloudConfig()
CloudQSServer.add_server!(clconf, "127.0.0.1", 8000)

isodd = [Base.isodd(x) for x in 1:2^N]
rydberg = [Base.count_ones(x) for x in 1:2^N]
time_points = 10
observables = [isodd, rydberg]
CloudQSServer.cloud_simulate(h, time_points, observables)
