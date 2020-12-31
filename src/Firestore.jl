module Firestore

using Dates
using JSON3
using OrderedCollections
using HTTP

export fdict, Document, NullValue, BooleanValue, IntegerValue, DoubleValue, TimestampValue,
    StringValue, BytesValue, ReferenceValue, GeoPointValue, ArrayValue, MapValue

const D = OrderedDict

project = Ref{String}()

document(x::D) = JSON3.write(D(:fields => OrderedDict(k => fdict(v) for (k,v) in x)))

fdict(x::Nothing) = D(:nullValue => nothing)
fdict(x::Bool) = D(:booleanValue => x)
fdict(x::Integer) = D(:integerValue => string(x))
fdict(x::Real) = D(:doubleValue => Float64(x))
fdict(x::Dates.TimeType) = D(:timestampValue => string(DateTime(x)) * 'Z')
fdict(x::String) = D(:stringValue => x)
fdict(x::Vector) = D(:arrayValue => fdict.(x))
fdict(x::D) = D(:mapValue => D(:fields => D(k => fdict(v) for (k,v) in x)))


#-----------------------------------------------------------------------------# Special Values
struct BytesValue
    x::String
end 
fdict(v::BytesValue) = D(:bytesValue => v.x)

struct ReferenceValue 
    x::String
end 
fdict(v::ReferenceValue) = D(:referenceValue => v.x)

struct GeoPointValue
    lat::Float64
    long::Float64
end
fdict(v::GeoPointValue) = D(:latitude => v.lat, :longitude => v.long)

#-----------------------------------------------------------------------------# API 
const URL = "https://firestore.googleapis.com/v1beta1/"

struct Project 
    name::String
end
endpoint(p::Project) = URL * "projects/$(p.name)/databases/(default)/documents/"

function setproject!(s::String)
    project[] = s
end

# API methods (https://firebase.google.com/docs/firestore/reference/rest/)

function patch(path, doc, proj=Project(project[]))
    HTTP.patch(endpoint(proj) * path, ["Content-Type: application/json"], doc)
end

get(path, proj=Project(project[])) = HTTP.get(endpoint(proj) * path)



end # module
