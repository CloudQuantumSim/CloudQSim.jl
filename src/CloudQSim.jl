"""
Cloud simulation of quantum evolution using Bloqade.jl

"""
module CloudQSim

    include("compress.jl")
    include("auth.jl")
    include("api.jl")
    include("client.jl")

    export CloudConfig,
           cloud_simulate,
           add_server!,
           del_server!

end # module
