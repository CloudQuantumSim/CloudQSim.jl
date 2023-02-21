using Test
import CloudQSim

@testset "unit" begin
    include("unit.jl")
end

@testset "integration" begin
    include("integration.jl")
end
