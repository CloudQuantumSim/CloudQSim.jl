using JSONWebTokens
import JSON

VERSION::String = "0.1.1"
TOKEN_ENV_VAR::String = "CLOUDQS_TOKEN"

function _get_token(token::Union{String, Nothing})::Union{String, Nothing}
    if token === nothing
        token = get(ENV, TOKEN_ENV_VAR, nothing)
    end
    return token
end

function auth_encode(
        out_data::String
        ; token::Union{String, Nothing}=nothing
    )::String
    token = _get_token(token)
    if token === nothing
        return out_data
    end
    return JSON.json(Dict(
                "auth_data" => out_data,
                "auth_version" => VERSION,
                "auth_token"=>token
                ))
end
