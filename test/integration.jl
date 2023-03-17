using BloqadeExpr, BloqadeLattices, BloqadeWaveforms
import CloudQSim 
HOSTNAME = "cloudqs.lykov.tech"
PORT = 7700
remote_config = CloudQSim.CloudConfig()
CloudQSim.add_server!(remote_config, HOSTNAME, PORT)

@testset "Send to server" begin
    nsites = 10
    atoms = generate_sites(ChainLattice(), nsites, scale = 5.74)
    T_end = 1.
    Δ = piecewise_linear(; clocks = [0, T_end], values = [0., 0.])
    ϕ = piecewise_constant(; clocks = [0, T_end], values = [0.])
    Ω = piecewise_linear(; clocks = [0, T_end], values = [2π, 2π])
    h = rydberg_h(atoms; Ω = Ω, Δ = Δ, ϕ=ϕ)

    qstates = 0:2^nsites-1
    isodd = [x%2 for x in qstates]
    rydberg = [Base.count_ones(x) for x in qstates]
    observables = [isodd, rydberg]
    time_points = 10
    data = CloudQSim.cloud_simulate([h], time_points, observables, remote_config)
    @test size(data) == (1, 10, 2)
    data = CloudQSim.cloud_simulate(h, time_points, observables, remote_config)
    @test size(data) == (10, 2)

    data = CloudQSim.cloud_simulate(fill(h, 3), time_points, observables, remote_config)
    @test size(data) == (3, 10, 2)
end
