using JSONWebTokens

VERSION::String = "0.1.0"
TOKEN_ENV_VAR::String = "CLOUDQS_TOKEN"

function _get_token(token::Union{String, Nothing})::Union{String, Nothing}
    if token === nothing
        token = get(ENV, TOKEN_ENV_VAR, nothing)
    end
    return token
end

function auth_encode(
        out_data::Dict{String, Any}
        ; token::Union{String, Nothing}=nothing
    )::Dict{String, Any}
    token = _get_token(token)
    if token === nothing
        return out_data
    end
    return Dict(
                "auth_data" => out_data,
                "auth_version" => VERSION,
                "auth_token"=>token
               )
end
