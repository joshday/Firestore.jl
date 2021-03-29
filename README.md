# Firestore

This package provides utilities for writing Google Firestore documents with Julia using the REST API.

This package is unofficial and not sponsored or supported by Google.

## Setup

- Create a new Firebase project at https://firebase.google.com.
- Create a Firestore Database in your project.
- In your `.julia/startup/config.jl` file, add `ENV["FIRESTORE_PROJECT"] = "<my_project_id>"`.
  - Alternatively, use `Firestore.set_project!(::String)`.

## High-Level Usage 

Firestore supports the following datatypes (in Julia-speak):

- `Bool`
- `Int64`
- `Float64`
- `Nothing`
- `AbstractString`
- `Dates.TimeType`
- `AbstractDict{String, SupportedType}`
- `Vector{SupportedType}`

However, because Firestore supports concrete types (e.g. not `AbstractDict`), some types will not survive a round trip.  For example:

- An `OrderedDict` will be changed to `Dict`.
- A `Date` will be changed to `DateTime`.

### Write

```julia
using Firestore
using Dates

doc = Dict(
    :x1 => 1,
    :x2 => "a string",
    :x3 => Dict(:sub1 => 1, :sub2 => [1, "two"]),
    :x4 => false,
    :x5 => nothing,
    :now => now(),
    :today => today(),
    :x7 => [1, "two", Dict("three" => 3)]
)

Firestore.write("test_collection/test_doc", doc)
```

### Read 

```julia
Firestore.read("test_collection/test_doc")
```