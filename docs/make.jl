using Documenter
using CloudQSim

makedocs(
    sitename = "CloudQSim",
    format = Documenter.HTML(),
    modules = [CloudQSim]
)

deploydocs(
    repo = "github.com/CloudQuantumSim/CloudQSim.jl.git",
    devbranch = "master",
)
