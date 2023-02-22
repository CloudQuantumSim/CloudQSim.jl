import Configurations
import JSON
import BloqadeSchema

"""
Simple wrapper for cloud server task
"""
@Base.kwdef struct CloudQSimTask
    bloqade_tasks :: Vector{BloqadeSchema.TaskSpecification}
    time_points :: Int64
    subspace_radius :: Float64
    observs :: Vector{Vector{Float64}}
end

function reduce_meta(old, update)
    # for each key of `update` that is not in `old`, add it to `old`
    for (k, v) in update
        if !haskey(old, k)
            old[k] = v
        else
            old[k] = old[k] + v
        end
    end

    payload_label = "payload"
    overhead_label = "overhead"
    ignore_labels = [payload_label, overhead_label, "pmap"]
    # sum all values except for the payload and overhead
    overhead = sum([v for (k, v) in old if k ∉ ignore_labels])
    # add the overhead to meta
    old[overhead_label] = overhead
    return old
end


## - Serialize task

function serialize_task(task:: CloudQSimTask)
    data = Dict(
        "version" => API_VERSION,
        "bloqade_tasks" =>
        [ Configurations.to_dict(t) for t in task.bloqade_tasks],
        "time_points" => task.time_points,
        "subspace_radius" => task.subspace_radius,
        "observables" => task.observs
       )
    return data |> JSON.json
end

function serialize_hamiltonian(ham)
    return BloqadeSchema.to_json(ham, n_shots=1)
end


## - Parse results


flatten(x) = x
flatten(x::AbstractArray) = vcat(map(flatten, x)...)

function parse_results(data)
    sar = data |> JSON.parse
    if length(sar) == 0
        println("No results")
        return []
    end
    mat = sar["results"]
    return Dict("results" => mat, "meta" => sar["meta"])
end
