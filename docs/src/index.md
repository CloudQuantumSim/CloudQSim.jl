# CloudQSim.jl

Documentation for CloudQSim.jl package
## Usage

To start simulating on the cloud, you will need:
1. Hostname and port of the server. `cloudqs.lykov.tech:7700` is the demo server
2. `CLODUQS_TOKEN` - authorization token to run tasks
3. A [Bloqade.jl](https://queracomputing.github.io/Bloqade.jl/dev/) hamiltonian
4. A set of observables to measure. See [observables](@ref)

Please refer to [`cloud_simulate`](@ref) function for the main API.


```@docs
CloudQSim
```

## Module Index

```@index
Modules = [CloudQSim]
Order   = [:constant, :type, :function, :macro]
```





## [Creating observables for simulation](@id observables)

The default format for observables is a diagonal observable, which is
represented by a vector where each element represents the observable value for
each corresponding state.

While a general observable may be to expensive to send,
most non-diagonal observables can be represented
as a sum of local terms.

The following definition of observables describes how to specify such set of observables.

### Using observables

The observable expression is defined as a sum of local terms
applied to different qubits.

1. Create definitions of local terms
2. Apply the local terms to qubits and add to the sum

Note that one can use any local observable as defined by matrix
or ``n``-dimensional array.

Example:

```julia
obs = CloudQSObservable()
X = define_operator!(obs, [[0, 1], [1, 0]], nqubits=1)
XX = define_operator!(obs, ..., nqubits=2)

set_sum!(obs, X[0], X[1], X[2], XX[0, 2], XX[0, 1])

res = cloud_simulate(hams, obs, clconf)
```

Currently, the only way to define a local operator is to provide the full
matrix. In other words, one has to obtain the matrix by using for example,
[Yao](https://docs.yaoquantum.org/dev/):

```julia
using Yao
XX_mat = mat(kron(X for _ in 1:2))
```

It future, this package may provide a more native way to construct
observables in a way [QSpin](https://pypi.org/project/qspin/) does it.

### Data structure
This is the string that will be sent over to the server:
```
{
    defs: {
        "X": ndarray
        "XX": ndarray
        },
    sum_terms: [
        {label: "X", qubits: [0]},
        {label: "X", qubits: [1]},
        {label: "X", qubits: [2]},
        {label: "XX", qubits: [0, 2]},
        {label: "XX", qubits: [0, 1]},
    ]
}
```

## Detailed API

```@autodocs
Modules = [CloudQSim]
Order   = [:constant, :type, :function, :macro]
```
