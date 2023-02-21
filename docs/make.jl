using Documenter
using CloudQSim

makedocs(
    sitename = "CloudQSim",
    format = Documenter.HTML(),
    modules = [CloudQSim]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "<repository url>"
)=#
