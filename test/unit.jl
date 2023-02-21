
@testset "CloudConfig" begin
    clconf = CloudQSim.CloudConfig()
    CloudQSim.add_server!(clconf, "localhost", 8000)
    @test length(clconf) == 1
    CloudQSim.add_server!(clconf, "localhost2", 8001, 2)
    @test length(clconf) == 2
    @test clconf.worker_counts == [1, 2]
    @test clconf.addrs == ["localhost", "localhost2"]
    @test clconf.ports == [8000, 8001]
end

@testset "Compression" begin
    data = "Mary had a little lamb, little lamb, little lamb. Mary had a little lamb, its fleece was white as snow."
    compressed = CloudQSim.compress(data)
    @test compressed != data
    @test CloudQSim.decompress(compressed) == data
end
