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
    if haskey(ENV, "FIRESTORE_API_KEY")
        set_api_key!(ENV["FIRESTORE_API_KEY"])
    else
        @warn "No FIRESTORE_API_KEY key found in ENV.  `set_api_key!` must be called before authentication will work."
    end
end

project = Ref{String}()
api_key = Ref{String}()
token = Ref{String}()
db = Ref{String}("(default)")

set_project!(s::String) = (project[] = s)
set_api_key!(s::String) = (api_key[] = s)
set_token!(s::String) = (token[] = s)
set_db!(s::String) = (db[] = s)

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
fval(x::Missing) = NullValue()

#-----------------------------------------------------------------------------# StringValue 
struct StringValue <: FirestoreType
    stringValue::String
end
fval(x::AbstractString) = StringValue(String(x))
fval(x::Symbol) = fval(string(x))

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

#-----------------------------------------------------------------------------# Auth 
function get_token!()
    email = ENV["FIRESTORE_EMAIL"]
    password = ENV["FIRESTORE_PASSWORD"]
    url = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$(api_key[])"
	data = JSON3.write(Dict(:email => email, :password => password, :returnSecureToken => true))
	res = HTTP.post(url, ["Content-Type: application/json"], data)
	set_token!(JSON3.read(res.body).idToken)
end

#-----------------------------------------------------------------------------# API 
# API methods (https://firebase.google.com/docs/firestore/reference/rest/)
function _url(path::String)
    "https://firestore.googleapis.com/v1beta1/projects/$(project[])/databases/$(db[])/documents/$path"
end
_data(x) = JSON3.write(Fields(x))

function createDocument(path::String, doc::AbstractDict)
    split_path = split(path, '/'; keepempty=false)
    documentId = split_path[end]
    h = ["Authorization" => "Bearer $(token[])", "Content-Type: application/json"]
    HTTP.post(
        _url(join(split_path[1:end-1], '/') * "?documentId=$documentId"), 
        h, 
        _data(doc)
    )
end

delete(path::String) = HTTP.delete(_url(path), ["Authorization" => "Bearer $(token[])"])

function get(path) 
    res = HTTP.get(_url(path))
    fields = JSON3.read(res.body).fields
    Dict(k => f2j(v) for (k,v) in pairs(fields))
end

function patch(path::String, doc::AbstractDict)
    h = ["Authorization" => "Bearer $(token[])", "Content-Type: application/json"]
    HTTP.patch(_url(path), h, _data(doc))
end





#-----------------------------------------------------------------------------# Firestore-to-Julia
function f2j(x::JSON3.Object)
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
