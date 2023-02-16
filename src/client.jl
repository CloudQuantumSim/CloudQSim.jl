import Sockets
import JSON
import BloqadeSchema

API_VERSION = 1

# -- Cloud Managment
# Given many servers, it is possible to distribute the tasks
# between them. This is done by the following functions.

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

function add_server!(cloud_config::CloudConfig, addr, port, workers=1)
    push!(cloud_config.addrs, addr)
    push!(cloud_config.ports, port)
    push!(cloud_config.worker_counts, workers)
end

function del_server!(cloud_config::CloudConfig, addr, port)
    idx = findfirst(x -> x[1] == addr && x[2] == port, collect(zip(cloud_config.addrs, cloud_config.ports)))
    if idx == nothing
        error("Server not found")
    end
    deleteat!(cloud_config.addrs, idx)
    deleteat!(cloud_config.ports, idx)
    deleteat!(cloud_config.worker_counts, idx)
end

# -- Cloud Simulation

function submit_task_cloud(sock, task)
    jsn = serialize_task(task)
    @async while isopen(sock)
        addr, port = Sockets.getpeername(sock)
        t_net_wait = @elapsed begin
            println(sock, jsn)
            println("$addr:$port 🠔── $(length(task.bloqade_tasks)) hamiltonians")
            sleep(0.002)
            result = readline(sock)
        end
        t_parse_results = @elapsed begin
            outs = parse_results(result)
        end
        results, meta = outs["results"], outs["meta"]
        # merge meta with client meta
        client_meta = Dict(
            "net_wait" => t_net_wait,
            "parse_results" => t_parse_results
        )
        meta = merge(meta, client_meta)
        # print meta
        println("Server meta from $addr:$port : ", meta)
        return results, meta
    end
end

function get_working_servers(clconf, print_errors=false)
    empty_task = CloudQSimTask(bloqade_tasks=[], time_points=1, subspace_radius=0, observs=[[]])
    working_server_ids = []
    for i in 1:length(clconf.addrs)
        try
            sock = Sockets.connect(clconf.addrs[i], clconf.ports[i])
            res, meta = fetch(submit_task_cloud(sock, empty_task))
            Sockets.close(sock)
            push!(working_server_ids, i)
        catch e
            if print_errors
                println("Error connecting to server $(clconf.addrs[i]):$(clconf.ports[i])")
                println(e)
            end
            continue
        end
    end
    return working_server_ids
end

function submit_task(cloud_config::CloudConfig, task::CloudQSimTask)
    # create a task for each server in config,
    # with number of task.blaqade_tasks distributed according to worker_counts.
    task_cnt = length(task.bloqade_tasks)

    println("[CQS] #> Testing servers...")
    working_server_ids = get_working_servers(cloud_config)
    println("[CQS] <# Working servers Ids: ", working_server_ids)
    total_workers = sum(cloud_config.worker_counts[working_server_ids])
        
    task_counts = []
    for wc in cloud_config.worker_counts[working_server_ids]
        push!(task_counts, Int(floor(task_cnt * wc / total_workers)))
    end
    # task_cont - sum(task_count) < K
    for i in 1:(task_cnt - sum(task_counts))
        task_counts[i] += 1
    end
    tasks = []
    start = 1
    for i in 1:length(working_server_ids)
        push!(tasks, CloudQSimTask(
            task.bloqade_tasks[start:start+task_counts[i]-1],
            task.time_points,
            task.subspace_radius,
            task.observs
        ))
        start += task_counts[i]
    end

    num_workers = length(working_server_ids)
    function map_fn(task, i)
        # -- Connection to a worker may fail. In this case,
        # try to connect to another worker.
        # If all workers fail, throw an error.
        sock = nothing
        addr, port = cloud_config.addrs[i], cloud_config.ports[i]
        sock = connect(addr, port)
        # --
        # Parsing may fail. This will not be handled
        ret, meta = fetch(submit_task_cloud(sock, task))
        println("$(length(ret)) results 🠔── $(addr):$(port)")
        return ret, meta
    end

    results = asyncmap(map_fn, tasks, working_server_ids; ntasks=total_workers)

    # merge results
    meta_common= Dict()
    res = []
    for (ret, m) in results
        push!(res, ret)
        meta_common= reduce_meta(meta_common, m)
    end
    # TODO: reduce(vcat, res)?
    return vcat(res...), meta_common
end

function convert_final_result(ret_list)
    # -- Convert output from list of lists to an array
    l1 = length(ret_list)
    l2 = length(ret_list[1])
    l3 = length(ret_list[1][1])
    l4 = length(ret_list[1][1][1])
    dims = (l1, l2, l3, l4)
    mat = flatten(ret_list)
    mat = reshape(mat, reverse(dims))
    ret = permutedims(mat, (4, 3, 2, 1))
    return ret
end


function cloud_simulate(
        hamiltonian::AbstractVector,
        time_points :: Int64,
        subspace_radius,
        observables::Vector{<:AbstractArray{<:Number}},
        cloud_config::CloudConfig
    )
    t_to_schema = @elapsed begin
        bloqade_tasks = [BloqadeSchema.to_schema(h, n_shots=1)
            for h in hamiltonian]
        task = CloudQSimTask(bloqade_tasks, time_points, subspace_radius, observables)
    end
    @async begin
        t_submit = @elapsed begin
            results, meta = submit_task(cloud_config, task)
        end
        meta = reduce_meta(meta, Dict("to_schema" => t_to_schema, "submit" => t_submit))
        println("Cloud Meta: ", meta)
        ret = convert_final_result(results)
        return ret, meta
    end
end


function cloud_simulate(
        hamiltonian::AbstractVector,
        time_points :: Int64,
        subspace_radius,
        observables::Vector{Vector{Any}}
    )
    t_to_schema = @elapsed begin
        bloqade_tasks = [BloqadeSchema.to_schema(h, n_shots=1)
            for h in hamiltonian]
        task = CloudQSimTask(bloqade_tasks, time_points, subspace_radius, observables)
    end
    sock = Sockets.connect("127.0.0.1", 8000)
    @async begin 
        ret_list, meta = fetch(submit_task_cloud(sock, task))
        meta = reduce_meta(meta, Dict("to_schema" => t_to_schema))
        ret = convert_final_result(ret_list)
        return ret, meta
    end
end

function cloud_simulate(
        hamiltonian,
        time_points :: Int64,
        observables::Vector{Vector{Any}}
    )
    return cloud_simulate([hamiltonian], time_points, observables)
end


function test_client()
    include("../tests/run_sim.jl")
    ham, time_points, observables = get_test_task()
    ret = cloud_simulate(ham, time_points, observables)
end

#main()
