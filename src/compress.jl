import LibDeflate
COMPRESS_DELIMITER = ':'
function compress(data::String)::String
    compressor = LibDeflate.Compressor()
    outvec = zeros(UInt8, length(data))
    nbytes = LibDeflate.compress!(compressor, outvec, data)
    if typeof(nbytes) == LibDeflate.LibDeflateError
        throw(nbytes)
    end
    println("Compressed $(length(data)) -> $nbytes bytes")
    # convert nbytes to string
    nbytes_str = string(length(data))
    prefix = nbytes_str * COMPRESS_DELIMITER
    return prefix * String(outvec[1:nbytes])
end

function decompress(data::String)::String
    decompressor = LibDeflate.Decompressor()
    prefix, data = split(data, COMPRESS_DELIMITER, limit=2)
    nbytes = parse(Int, prefix)
    outvec = zeros(UInt8, nbytes)
    nbytes = LibDeflate.decompress!(decompressor, outvec, data)
    if typeof(nbytes) == LibDeflate.LibDeflateError
        throw(nbytes)
    end
    println("Decompressed $(length(data)) -> $nbytes bytes")
    return String(outvec[1:nbytes])
end

