# Firestore.jl

This package provides utilities for reading & writing Google Firestore documents with Julia using the REST API.

This package is unofficial and not sponsored or supported by Google.

## Setup

1. Create a new Firebase project at https://firebase.google.com.
2. Create a Firestore Database in your project.
3. In your `.julia/startup/config.jl` file, add `ENV["FIRESTORE_PROJECT"] = "<my_project_id>"`.
  - Alternatively, use `Firestore.set_project!(::String)`.

## High-Level Usage 

Firestore supports the following datatypes (in Julia-speak):

- `Bool`
- `Int64`
- `Float64`
- `Nothing`
- `String`
- `DateTime`
- `Dict{String, SupportedType}`
- `Vector{SupportedType}`

Firestore.jl will convert your data into the appropriate type if it is able to do so (e.g. `OrderedDict` -> `Dict`).

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

# `patch` will overwrite an existing doc whereas `createDocument` will not
Firestore.patch("test_collection/test_doc", doc)
```

### Read 

```julia
Firestore.get("test_collection/test_doc")
```

```
Dict{Symbol, Any} with 8 entries:
  :today => DateTime("2021-03-29T00:00:00")
  :x2    => "a string"
  :x5    => nothing
  :x7    => Any[1, "two", Dict(:three=>3)]
  :x3    => Dict{Symbol, Any}(:sub2=>Any[1, "two"], :sub1=>1)
  :x4    => false
  :now   => DateTime("2021-03-29T14:21:17.409")
  :x1    => 1
```

## Supported Operations

See https://firebase.google.com/docs/firestore/reference/rest#rest-resource:-v1beta1.projects.databases.documents.

- `createDocument`
- `delete`
- `get`
- `patch`

## Authorization

- NOTE: Currently only email/password-based auth is supported.

### Authenticating Only Yourself

#### In your Firebase "Authentication" page:

1. Go to your Firebase "Authentication" page:
  a. Under "Sign-In Method", enable the "Email/Password" provider.
  b. Under "Users", add your email and password.
  c. Add `ENV["FIRESTORE_EMAIL"] = <your email>` and `ENV["FIRESTORE_PASSWORD"] = <your pw>` to your `~/.julia/startup.config.jl` file.
2. Go to your Project Settings (Click the cog next to "Project Overview") page:
  a. Add `ENV["FIRESTORE_API_KEY"] = <Web API Key>` to your `~/.julia/startup/config.jl`
3. Go to your Firebase "Firestore Database" page:
  a. Copy/paste this to your "Rules":
  ```
  // Allow read/write access on all documents to any user signed in to the application
  service cloud.firestore {
    match /databases/{database}/documents {
      match /{document=**} {
        allow read, write: if request.auth != null;
      }
    }
  }
  ```