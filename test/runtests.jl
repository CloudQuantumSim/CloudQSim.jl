using Test
import CloudQS

@testset "unit" begin
    include("unit.jl")
end

@testset "integration" begin
    include("integration.jl")
end
