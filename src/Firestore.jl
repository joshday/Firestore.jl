module Firestore

using Dates
using JSON3
using OrderedCollections

export fdict, Document, NullValue, BooleanValue, IntegerValue, DoubleValue, TimestampValue,
    StringValue, BytesValue, ReferenceValue, GeoPointValue, ArrayValue, MapValue

const D = OrderedDict

document(x) = D(:fields => x)

fdict(x::Nothing) = D(:nullValue => nothing)
fdict(x::Bool) = D(:booleanValue => x)
fdict(x::Integer) = D(:integerValue => string(x))
fdict(x::Real) = D(:doubleValue => Float64(x))
fdict(x::Dates.TimeType) = D(:timestampValue => string(DateTime(x)) * 'Z')
fdict(x::String) = D(:stringValue => x)
fdict(x::Vector) = D(:arrayValue => fdict.(x))
fdict(x::D) = D(:mapValue => D(k => fdict(v) for (k,v) in x))

#-----------------------------------------------------------------------------# Special Values
abstract type Value end

struct BytesValue <: Value
    x::String
end 
fdict(v::BytesValue) = D(:bytesValue => v.x)

struct ReferenceValue <: Value 
    x::String
end 
fdict(v::ReferenceValue) = D(:referenceValue => v.x)

struct GeoPointValue <: Value
    lat::Float64
    long::Float64
end
fdict(v::GeoPointValue) = D(:latitude => v.lat, :longitude => v.long)

end
