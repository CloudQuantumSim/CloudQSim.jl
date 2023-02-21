
@testset "CloudConfig" begin
    clconf = CloudQS.CloudConfig()
    CloudQS.add_server!(clconf, "localhost", 8000)
    @test length(clconf) == 1
    CloudQS.add_server!(clconf, "localhost2", 8001, 2)
    @test length(clconf) == 2
    @test clconf.worker_counts == [1, 2]
    @test clconf.addrs == ["localhost", "localhost2"]
    @test clconf.ports == [8000, 8001]
end

@testset "Compression" begin
    data = "Mary had a little lamb, little lamb, little lamb. Mary had a little lamb, its fleece was white as snow."
    compressed = CloudQS.compress(data)
    @test compressed != data
    @test CloudQS.decompress(compressed) == data
end
