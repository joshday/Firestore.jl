module Firestore

using Dates
using JSON3
using HTTP
using StructTypes: StructTypes

export fval, Fields

function __init__()
    if haskey(ENV, "FIRESTORE_PROJECT")
        set_project!(ENV["FIRESTORE_PROJECT"])
    else
        @warn "No FIRESTORE_PROJECT key found in ENV.  `set_project!` must be called before this package will work properly."
    end
end

project = Ref{String}()

set_project!(s::String) = (project[] = s)

abstract type FirestoreType end
StructTypes.StructType(::Type{<:FirestoreType}) = StructTypes.Struct()

fval(x) = error("No Julia-to-Firestore value mapping for $(typeof(x)).")

#-----------------------------------------------------------------------------# Fields/Values
struct Fields <: FirestoreType
    fields::Dict{String, FirestoreType}
    Fields(x::AbstractDict) = new(Dict(string(k) => fval(v) for (k,v) in pairs(x)))
end
Fields(; kw...) = Fields(Dict(kw))

struct Values <: FirestoreType 
    values::Vector{FirestoreType}
end
Values(args...) = Values(collect(args))

#-----------------------------------------------------------------------------# ArrayValue
struct ArrayValue <: FirestoreType
    arrayValue::Values
end
fval(x::AbstractVector) = ArrayValue(Values(collect(fval.(x))))

#-----------------------------------------------------------------------------# BooleanValue
struct BooleanValue <: FirestoreType
    booleanValue::Bool 
end
fval(x::Bool) = BooleanValue(x)

#-----------------------------------------------------------------------------# DoubleValue
struct DoubleValue <: FirestoreType
    doubleValue::Float64 
end
fval(x::AbstractFloat) = DoubleValue(Float64(x))

#-----------------------------------------------------------------------------# IntegerValue
struct IntegerValue <: FirestoreType
    integerValue::String 
end
fval(x::Int) = IntegerValue(string(x))

#-----------------------------------------------------------------------------# MapValue 
struct MapValue <: FirestoreType
    mapValue::Fields
end
fval(x::AbstractDict) = MapValue(Fields(x))
fval(x::NamedTuple) = fval(Dict(pairs(x)))

#-----------------------------------------------------------------------------# NullValue 
struct NullValue <: FirestoreType
    nullValue::Nothing 
    NullValue() = new(nothing)
end
fval(x::Nothing) = NullValue()

#-----------------------------------------------------------------------------# StringValue 
struct StringValue <: FirestoreType
    stringValue::String
end
fval(x::AbstractString) = StringValue(String(x))

#-----------------------------------------------------------------------------# TimestampValue
"A timestamp with microsecond precision."
struct TimestampValue <: FirestoreType
    timestampValue::String 
end
fval(x::Dates.TimeType) = TimestampValue(string(DateTime(x)) * "Z")

#-----------------------------------------------------------------------------# BytesValue
"A Base64-encoded string."
struct BytesValue <: FirestoreType
    bytesValue::String
end 

#-----------------------------------------------------------------------------# ReferenceValue
"""
A Reference to another Firestore document. E.g.

    projects/{project_id}/databases/{databaseId}/documents/{document_path}
"""
struct ReferenceValue <: FirestoreType
    referenceValue::String
end 

#-----------------------------------------------------------------------------# GeoPointValue
struct LatLng <: FirestoreType
    latitude::Float64 
    longitude::Float64 
end

"A geo point value representing a point on the surface of Earth."
struct GeoPointValue <: FirestoreType
    geoPointValue::LatLng
end

fval(x::LatLng) = GeoPointValue(x)

#-----------------------------------------------------------------------------# API 
function endpoint(proj::String; db="(default)", path="temp/temp/")
    "https://firestore.googleapis.com/v1beta1/projects/$proj/databases/$db/documents/$path"
end

# API methods (https://firebase.google.com/docs/firestore/reference/rest/)

function patch(path::String, doc::Fields, proj::String = project[]; db="(default)")
    HTTP.patch(endpoint(proj; db, path), ["Content-Type: application/json"], JSON3.write(doc))
end

function post(path::String, doc::Fields, proj::String = project[]; db="(default)")
    HTTP.post(endpoint(proj; db, path), ["Content-Type: application/json"], JSON3.write(doc))
end

#-----------------------------------------------------------------------------# get/read
function write(path::String, doc::AbstractDict; db="(default)", proj=project[])
    iseven(length(split(path, '/', keepempty=false))) ||
        error("Path must be split into an even number of subpaths.")
    patch(path, Fields(doc))
end

function read(path; db = "(default)", proj=project[]) 
    res = HTTP.get(endpoint(proj; db, path))
    fields = JSON3.read(res.body).fields
    Dict(k => firestore2julia(v) for (k,v) in pairs(fields))
end



function firestore2julia(x::JSON3.Object)
    prop = propertynames(x)[1]
    val = getproperty(x, prop)
    if prop === :arrayValue 
        firestore2julia.(val.values)
    elseif prop === :mapValue 
        Dict(field => firestore2julia(val.fields[field]) for field in propertynames(val.fields))
    elseif prop === :integerValue 
        parse(Int, val)
    elseif prop === :nullValue 
        nothing
    elseif prop === :timestampValue 
        DateTime(val[1:end-1])
    else
        val
    end
end


end # module
