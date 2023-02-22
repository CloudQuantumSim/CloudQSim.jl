import Sockets
import Logging
import JSON
import BloqadeSchema
import TOML

API_VERSION = 1

# -- Cloud Managment
# Given many servers, it is possible to distribute the tasks
# between them. This is done by the following functions.
#
# CloudConfig is a configuration structure that holds the information about the
# cloud servers. Can be read from a TOML file. 

"""
Configuration for cloud simulation servers.

# Fields
- `addrs`: Hosts to connect to
- `ports`: Ports to use 
- `worker_counts`: Number of workers on each server to use in load balancing

# Example
```julia-repl
julia> clconf = CloudConfig()
julia> add_server!(clconf, "cloudqs.lykov.tech", 7700)
```
"""
struct CloudConfig
    addrs :: Vector{String}
    ports :: Vector{Int}
    worker_counts :: Vector{Int}

    function CloudConfig(addrs, ports, worker_counts)
        if length(addrs) != length(ports)
            error("addrs and ports must have the same length")
        end
        return new(addrs, ports, worker_counts)
    end

    function CloudConfig(addrs, ports)
        return CloudConfig(addrs, ports, fill(1, length(addrs)))
    end

    function CloudConfig()
        return new([], [], [])
    end
end

get_empty_task() = CloudQSimTask(bloqade_tasks=[], time_points=1, subspace_radius=0, observs=[[]])

function read_toml_clconf(path::String="CloudConfig.toml")
    config = TOML.parsefile(path)
    cloud_server_info = config["server_info"]
    hosts = cloud_server_info["hosts"]
    ports = cloud_server_info["ports"]
    worker_counts = get(cloud_server_info, "worker_counts", fill(1, length(hosts)))
    return CloudConfig(hosts, ports, worker_counts)
end

Base.getindex(config::CloudConfig, i::Int) = (config.addrs[i], config.ports[i], config.worker_counts[i])
Base.getindex(config::CloudConfig, i::Symbol) = getfield(config, i)
Base.getindex(config::CloudConfig, sl::AbstractVector) = CloudConfig(config.addrs[sl], config.ports[sl], config.worker_counts[sl])
Base.length(config::CloudConfig) = length(config.addrs)

function add_server!(cloud_config::CloudConfig, addr, port, workers=1)
    push!(cloud_config.addrs, addr)
    push!(cloud_config.ports, port)
    push!(cloud_config.worker_counts, workers)
end

function del_server!(cloud_config::CloudConfig, addr, port)
    idx = findfirst(x -> x[1] == addr && x[2] == port, collect(zip(cloud_config.addrs, cloud_config.ports)))
    if idx === nothing
        error("Server not found")
    end
    deleteat!(cloud_config.addrs, idx)
    deleteat!(cloud_config.ports, idx)
    deleteat!(cloud_config.worker_counts, idx)
end

# --

# -- Cloud Simulation utils

function send_task_cloud(sock, task)
    jsn = task |> serialize_task |> auth_encode
    while isopen(sock)
        addr, port = Sockets.getpeername(sock)
        t_net_wait = @elapsed begin
            println(sock, jsn)
            println("$addr:$port 🠔── $(length(task.bloqade_tasks)) hamiltonians")
            result = readline(sock)
        end
        t_parse_results = @elapsed begin
            outs = parse_results(result)
        end
        results, meta = outs["results"], outs["meta"]
        # merge meta with client meta
        client_meta = Dict("net_wait" => t_net_wait, "parse_results" => t_parse_results)
        meta = merge(meta, client_meta)
        return results, meta
    end
end

function get_working_servers(clconf, show_errors=false)
    println("[CQS] #> Testing servers...")
    empty_task = get_empty_task()
    working_server_ids = []
    metas = []
    for i in 1:length(clconf.addrs)
        try
            sock = Sockets.connect(clconf.addrs[i], clconf.ports[i])
            data, meta = fetch(send_task_cloud(sock, empty_task))
            Sockets.close(sock)
            push!(working_server_ids, i)
            push!(metas, meta)
        catch e
            if show_errors
                Logging.@error e
            end
            continue
        end
    end
    return working_server_ids, metas
end

"""
Split one [`CloudQSimTask`](@ref) into many for balancing of jobs betwen worker
    servers
"""
function split_task(task::CloudQSimTask, portions::Vector{Int})
    total_workers = sum(portions)
    # -- Divide into sub-tasks: create a task for each server in config,
    # with number of task.blaqade_tasks distributed according to worker_counts.
    task_cnt = length(task.bloqade_tasks)
    task_counts = []
    for wc in portions
        push!(task_counts, Int(floor(task_cnt * wc / total_workers)))
    end
    # task_cont - sum(task_count) < K
    for i in 1:(task_cnt - sum(task_counts))
        task_counts[i] += 1
    end
    tasks::Vector{CloudQSimTask} = []
    start = 1
    for i in 1:length(portions)
        push!(tasks, CloudQSimTask(
            task.bloqade_tasks[start:start+task_counts[i]-1],
            task.time_points,
            task.subspace_radius,
            task.observs
        ))
        start += task_counts[i]
    end
    return tasks
end

unzip(a) = map(x->getfield.(a, x), fieldnames(eltype(a)))

function distribute_task(task::CloudQSimTask, clconf::CloudConfig)
    tasks = split_task(task, clconf.worker_counts)

    function map_fn(task, addr, port)
        sock = Sockets.connect(addr, port)
        ret, meta = send_task_cloud(sock, task)
        println("$(length(ret)) results 🠔── $(addr):$(port)")
        return ret, meta
    end
    results = asyncmap(map_fn, tasks, clconf.addrs, clconf.ports)
    # merge results
    res, meta = unzip(results)
    return reduce(vcat, res), reduce(reduce_meta, meta)
end

function convert_final_result(ret_list)
    # -- Convert output from list of lists to an array
    l1 = length(ret_list)
    l2 = length(ret_list[1])
    l3 = length(ret_list[1][1])
    dims = (l1, l2, l3)
    mat = flatten(ret_list)
    mat = reshape(mat, reverse(dims))
    ret = permutedims(mat, (3, 2, 1))
    return ret
end

# -- Manage meta about the simulation
global last_meta = Dict()
"""
Get metadata about the last simulation,
such as time spent in network, parsing results, etc.
"""
function get_last_meta()
    return last_meta
end
function set_last_meta(meta)
    global last_meta = meta
end
# -- Public API

"""
Run quantum evolution of multiple Hamiltonians in the cloud.

# Arguments
- `hamiltonian::Vector`: List of Hamiltonians
- `time_points::Int`: How many evaluations of observables to do
    throughout the simulation
- `observables::Vector{<:Vector}`: List of observables to evaluate
- `subspace_radius::Float64=0.`: Radius of the subspace to use for
    the Bloqade subspace evolution

# Returns
- `results::Array`: Array of results, with dimensions
    (hamiltonians, time_points, observables)
"""
function cloud_simulate(
        hamiltonian::AbstractVector,
        time_points :: Int64,
        observables::Vector{<:Vector},
        cloud_config::CloudConfig
        ; subspace_radius=0.
    )
    t_to_schema = @elapsed begin
        bloqade_tasks = [BloqadeSchema.to_schema(h, n_shots=1)
            for h in hamiltonian]
        task = CloudQSimTask(bloqade_tasks, time_points, subspace_radius, observables)
    end
    t_submit = @elapsed begin
        # Don't check for working servers if there is no choice of servers
        if length(cloud_config) ≤ 1
            working_server_ids = fill(1, length(cloud_config))
        else
            working_server_ids, _ = get_working_servers(cloud_config)
            println("[CQS] <# Working servers Ids: ", working_server_ids)
        end
        if length(working_server_ids) == 0
            error("No working servers found")
        end
        working_clconf = cloud_config[working_server_ids]
        results, meta = distribute_task(task, working_clconf)
    end
    meta = reduce_meta(meta, Dict("to_schema" => t_to_schema, "submit" => t_submit))
    set_last_meta(meta)
    ret = convert_final_result(results)
    return ret
end

function cloud_simulate(
        hamiltonian::AbstractVector,
        time_points :: Int64,
        observables::Vector{<:AbstractArray}
        ; subspace_radius=0.,
    )
    clconf_default = CloudConfig(
        ["localhost"],
        [8000],
    )
    return cloud_simulate(hamiltonian, time_points, observables, clconf_default; subspace_radius=subspace_radius)
end

# -- Single-hamiltonian versions
function cloud_simulate(hamiltonian, rest...; kwargs...)
    cloud_simulate([hamiltonian], rest...; kwargs...)[1, :, :]
end
# --

function cloud_simulate(
        hamiltonian::AbstractVector,
        time_points :: Int64,
        subspace_radius,
        observables::Vector{<:AbstractArray},
        clconf:: CloudConfig
    )
    cloud_simulate(hamiltonian, time_points, observables, clconf; subspace_radius=subspace_radius)
end

function test_client()
    include("../tests/run_sim.jl")
    ham, time_points, observables = get_test_task()
    _ = cloud_simulate(ham, time_points, observables)
end

#main()
