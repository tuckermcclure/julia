# This file is a part of Julia. License is MIT: https://julialang.org/license

"""
    RowVector(vector)

A lazy-view wrapper of an [`AbstractVector`](@ref), which turns a length-`n` vector into a `1×n`
shaped row vector and represents the transpose of a vector (the elements are also transposed
recursively). This type is usually constructed (and unwrapped) via the [`transpose`](@ref)
function or `.'` operator (or related [`adjoint`](@ref) or `'` operator).

By convention, a vector can be multiplied by a matrix on its left (`A * v`) whereas a row
vector can be multiplied by a matrix on its right (such that `v.' * A = (A.' * v).'`). It
differs from a `1×n`-sized matrix by the facts that its transpose returns a vector and the
inner product `v1.' * v2` returns a scalar, but will otherwise behave similarly.
"""
struct RowVector{T,V<:AbstractVector{T}} <: AbstractMatrix{T}
    vec::V
end

const ConjRowVector{T,CV<:ConjVector{T}} = RowVector{T,CV}
const AdjointRowVector{T,AV<:AdjointVector{T}} = RowVector{T,AV}
const ConjAdjointRowVector{T,CAV<:ConjAdjointVector{T}} = RowVector{T,CAV}

parent(rowvec::RowVector) = rowvec.vec

# Constructors that take a vector
@inline RowVector(vec::AbstractVector{T}) where {T} = RowVector{T,typeof(vec)}(vec)
@inline RowVector{T}(vec::AbstractVector{T}) where {T} = RowVector{T,typeof(vec)}(vec)

# Constructors that take a size and default to Array
@inline RowVector{T}(n::Int) where {T} = RowVector{T}(Vector{T}(n))
@inline RowVector{T}(n1::Int, n2::Int) where {T} = n1 == 1 ?
    RowVector{T}(Vector{T}(n2)) :
    error("RowVector expects 1×N size, got ($n1,$n2)")
@inline RowVector{T}(n::Tuple{Int}) where {T} = RowVector{T}(Vector{T}(n[1])) # TODO: is this right?
@inline RowVector{T}(n::Tuple{Int,Int}) where {T} = n[1] == 1 ?
    RowVector{T}(Vector{T}(n[2])) :
    error("RowVector expects 1×N size, got $n")

# Conversion of underlying storage
convert(::Type{RowVector{T,V}}, rowvec::RowVector) where {T,V<:AbstractVector{T}} =
    RowVector{T,V}(convert(V,parent(rowvec)))

# similar tries to maintain the RowVector wrapper and the parent type
@inline similar(rowvec::RowVector) = RowVector(similar(parent(rowvec)))
@inline similar(rowvec::RowVector, ::Type{T}) where {T} = RowVector(similar(parent(rowvec), T))

# Resizing similar currently loses its RowVector property.
@inline similar(rowvec::RowVector, ::Type{T}, dims::Dims{N}) where {T,N} = similar(parent(rowvec), T, dims)

# Basic methods
"""
    transpose(v::AbstractVector)

The transposition operator (`.'`).

# Examples
```jldoctest
julia> v = [1,2,3]
3-element Array{Int64,1}:
 1
 2
 3

julia> transpose(v)
1×3 RowVector{Int64,Array{Int64,1}}:
 1  2  3
```
"""
@inline transpose(vec::AbstractVector) = RowVector(vec)
@inline adjoint(vec::AbstractVector) = RowVector(_adjoint(vec))

# For the moment, we remove the ConjArray wrapper from any raw vector of numbers, to allow for BLAS specializations
@inline transpose(rowvec::RowVector) = parent(rowvec)
@inline transpose(rowvec::ConjRowVector{<:Number}) = copy(parent(rowvec))

@inline adjoint(rowvec::RowVector{<:Real}) = parent(rowvec)
@inline adjoint(rowvec::RowVector{<:Number}) = conj(parent(rowvec))
@inline adjoint(rowvec::ConjRowVector{<:Number}) = parent(rowvec)
@inline adjoint(rowvec::RowVector) = _adjoint(parent(rowvec))

"""
    conj(v::RowVector)

Returns a [`ConjArray`](@ref) lazy view of the input, where each element is conjugated.

# Examples
```jldoctest
julia> v = [1+im, 1-im].'
1×2 RowVector{Complex{Int64},Array{Complex{Int64},1}}:
 1+1im  1-1im

julia> conj(v)
1×2 RowVector{Complex{Int64},ConjArray{Complex{Int64},1,Array{Complex{Int64},1}}}:
 1-1im  1+1im
```
"""
@inline conj(rowvec::RowVector) = RowVector(_conj(parent(rowvec)))
@inline conj(rowvec::RowVector{<:Real}) = rowvec

# AbstractArray interface
@inline length(rowvec::RowVector) =  length(parent(rowvec))
@inline size(rowvec::RowVector) = (1, length(parent(rowvec)))
@inline size(rowvec::RowVector, d) = ifelse(d==2, length(parent(rowvec)), 1)
@inline indices(rowvec::RowVector) = (Base.OneTo(1), indices(parent(rowvec))[1])
@inline indices(rowvec::RowVector, d) = ifelse(d == 2, indices(parent(rowvec))[1], Base.OneTo(1))
IndexStyle(::RowVector) = IndexLinear()
IndexStyle(::Type{<:RowVector}) = IndexLinear()

@propagate_inbounds getindex(rowvec::RowVector, i) = parent(rowvec)[i]
@propagate_inbounds setindex!(rowvec::RowVector, v, i) = setindex!(parent(rowvec), v, i)

# Cartesian indexing is distorted by getindex
# Furthermore, Cartesian indexes don't have to match shape, apparently!
@inline function getindex(rowvec::RowVector, i::CartesianIndex)
    @boundscheck if !(i.I[1] == 1 && i.I[2] ∈ indices(parent(rowvec))[1] && check_tail_indices(i.I...))
        throw(BoundsError(rowvec, i.I))
    end
    @inbounds return parent(rowvec)[i.I[2]]
end
@inline function setindex!(rowvec::RowVector, v, i::CartesianIndex)
    @boundscheck if !(i.I[1] == 1 && i.I[2] ∈ indices(parent(rowvec))[1] && check_tail_indices(i.I...))
        throw(BoundsError(rowvec, i.I))
    end
    @inbounds parent(rowvec)[i.I[2]] = v
end

@propagate_inbounds getindex(rowvec::RowVector, ::CartesianIndex{0}) = getindex(rowvec)
@propagate_inbounds getindex(rowvec::RowVector, i::CartesianIndex{1}) = getindex(rowvec, i.I[1])

@propagate_inbounds setindex!(rowvec::RowVector, v, ::CartesianIndex{0}) = setindex!(rowvec, v)
@propagate_inbounds setindex!(rowvec::RowVector, v, i::CartesianIndex{1}) = setindex!(rowvec, v, i.I[1])

@inline check_tail_indices(i1, i2) = true
@inline check_tail_indices(i1, i2, i3, is...) = i3 == 1 ? check_tail_indices(i1, i2, is...) : false

# helper function for below
@inline to_vec(rowvec::RowVector) = parent(rowvec)
@inline to_vec(x::Number) = x
@inline to_vecs(rowvecs...) = (map(to_vec, rowvecs)...)

# map: Preserve the RowVector by un-wrapping and re-wrapping
@inline map(f, rowvecs::RowVector...) = RowVector(map(f, to_vecs(rowvecs...)...))

# broacast (other combinations default to higher-dimensional array)
# (in future, should use broadcast infrastructure to manage this?)
@inline broadcast(f, rowvecs::Union{Number,RowVector}...) =
    RowVector(broadcast(f, to_vecs(rowvecs...)...))

# Horizontal concatenation #

@inline hcat(X::RowVector...) = transpose(vcat(map(transpose, X)...))
@inline hcat(X::Union{RowVector,Number}...) = transpose(vcat(map(transpose, X)...))

@inline typed_hcat(::Type{T}, X::RowVector...) where {T} =
    transpose(typed_vcat(T, map(transpose, X)...))
@inline typed_hcat(::Type{T}, X::Union{RowVector,Number}...) where {T} =
    transpose(typed_vcat(T, map(transpose, X)...))

# Multiplication #

# inner product -> dot product specializations
@inline *(rowvec::RowVector{T}, vec::AbstractVector{T}) where {T<:Real} = dot(parent(rowvec), vec)
#@inline *(rowvec::ConjRowVector{T}, vec::AbstractVector{T}) where {T<:Real} = dot(rowvec', vec)
#@inline *(rowvec::ConjRowVector, vec::AbstractVector) = dot(rowvec', vec)

# Generic behavior
@inline function *(rowvec::RowVector, vec::AbstractVector)
    if length(rowvec) != length(vec)
        throw(DimensionMismatch("A has dimensions $(size(rowvec)) but B has dimensions $(size(vec))"))
    end
    sum(@inbounds(return rowvec[i]*vec[i]) for i = 1:length(vec))
end
@inline *(rowvec::RowVector, mat::AbstractMatrix) = transpose(mat.' * transpose(rowvec))
*(::RowVector, ::RowVector) = throw(DimensionMismatch("Cannot multiply two transposed vectors"))
@inline *(vec::AbstractVector, rowvec::RowVector) = vec .* rowvec
*(vec::AbstractVector, rowvec::AbstractVector) = throw(DimensionMismatch("Cannot multiply two vectors"))

# Transposed forms
A_mul_Bt(::RowVector, ::AbstractVector) = throw(DimensionMismatch("Cannot multiply two transposed vectors"))
@inline A_mul_Bt(rowvec::RowVector, mat::AbstractMatrix) = transpose(mat * transpose(rowvec))
@inline A_mul_Bt(rowvec1::RowVector, rowvec2::RowVector) = rowvec1*transpose(rowvec2)
A_mul_Bt(vec::AbstractVector, rowvec::RowVector) = throw(DimensionMismatch("Cannot multiply two vectors"))
@inline A_mul_Bt(vec1::AbstractVector, vec2::AbstractVector) = vec1 * transpose(vec2)
@inline A_mul_Bt(mat::AbstractMatrix, rowvec::RowVector) = mat * transpose(rowvec)

@inline At_mul_Bt(rowvec::RowVector, vec::AbstractVector) = transpose(rowvec) * transpose(vec)
@inline At_mul_Bt(vec::AbstractVector, mat::AbstractMatrix) = transpose(mat * vec)
At_mul_Bt(rowvec1::RowVector, rowvec2::RowVector) = throw(DimensionMismatch("Cannot multiply two vectors"))
@inline At_mul_Bt(vec::AbstractVector, rowvec::RowVector) = transpose(vec)*transpose(rowvec)
At_mul_Bt(vec::AbstractVector, rowvec::AbstractVector) = throw(DimensionMismatch(
    "Cannot multiply two transposed vectors"))
@inline At_mul_Bt(mat::AbstractMatrix, rowvec::RowVector) = mat.' * transpose(rowvec)

At_mul_B(::RowVector, ::AbstractVector) = throw(DimensionMismatch("Cannot multiply two vectors"))
@inline At_mul_B(vec::AbstractVector, mat::AbstractMatrix) = transpose(At_mul_B(mat,vec))
@inline At_mul_B(rowvec1::RowVector, rowvec2::RowVector) = transpose(rowvec1) * rowvec2
At_mul_B(vec::AbstractVector, rowvec::RowVector) = throw(DimensionMismatch(
    "Cannot multiply two transposed vectors"))
@inline At_mul_B(vec1::AbstractVector{T}, vec2::AbstractVector{T}) where {T<:Real} =
    reduce(+, map(At_mul_B, vec1, vec2)) # Seems to be overloaded...
@inline At_mul_B(vec1::AbstractVector, vec2::AbstractVector) = transpose(vec1) * vec2

# Conjugated forms
A_mul_Bc(::RowVector, ::AbstractVector) = throw(DimensionMismatch("Cannot multiply two transposed vectors"))
@inline A_mul_Bc(rowvec::RowVector, mat::AbstractMatrix) = adjoint(mat * adjoint(rowvec))
@inline A_mul_Bc(rowvec1::RowVector, rowvec2::RowVector) = rowvec1 * adjoint(rowvec2)
A_mul_Bc(vec::AbstractVector, rowvec::RowVector) = throw(DimensionMismatch("Cannot multiply two vectors"))
@inline A_mul_Bc(vec1::AbstractVector, vec2::AbstractVector) = vec1 * adjoint(vec2)
@inline A_mul_Bc(mat::AbstractMatrix, rowvec::RowVector) = mat * adjoint(rowvec)

@inline Ac_mul_Bc(rowvec::RowVector, vec::AbstractVector) = adjoint(rowvec) * adjoint(vec)
@inline Ac_mul_Bc(vec::AbstractVector, mat::AbstractMatrix) = adjoint(mat * vec)
Ac_mul_Bc(rowvec1::RowVector, rowvec2::RowVector) = throw(DimensionMismatch("Cannot multiply two vectors"))
@inline Ac_mul_Bc(vec::AbstractVector, rowvec::RowVector) = adjoint(vec)*adjoint(rowvec)
Ac_mul_Bc(vec::AbstractVector, rowvec::AbstractVector) = throw(DimensionMismatch("Cannot multiply two transposed vectors"))
@inline Ac_mul_Bc(mat::AbstractMatrix, rowvec::RowVector) = mat' * adjoint(rowvec)

Ac_mul_B(::RowVector, ::AbstractVector) = throw(DimensionMismatch("Cannot multiply two vectors"))
@inline Ac_mul_B(vec::AbstractVector, mat::AbstractMatrix) = adjoint(Ac_mul_B(mat,vec))
@inline Ac_mul_B(rowvec1::RowVector, rowvec2::RowVector) = adjoint(rowvec1) * rowvec2
Ac_mul_B(vec::AbstractVector, rowvec::RowVector) = throw(DimensionMismatch("Cannot multiply two transposed vectors"))
@inline Ac_mul_B(vec1::AbstractVector, vec2::AbstractVector) = adjoint(vec1)*vec2

# Pseudo-inverse
pinv(v::RowVector, tol::Real=0) = pinv(v', tol)'

# Left Division #

\(rowvec1::RowVector, rowvec2::RowVector) = pinv(rowvec1) * rowvec2
\(mat::AbstractMatrix, rowvec::RowVector) = throw(DimensionMismatch("Cannot left-divide transposed vector by matrix"))
At_ldiv_B(mat::AbstractMatrix, rowvec::RowVector) = throw(DimensionMismatch("Cannot left-divide transposed vector by matrix"))
Ac_ldiv_B(mat::AbstractMatrix, rowvec::RowVector) = throw(DimensionMismatch("Cannot left-divide transposed vector by matrix"))

# Right Division #

@inline /(rowvec::RowVector, mat::AbstractMatrix) = transpose(transpose(mat) \ transpose(rowvec))
@inline A_rdiv_Bt(rowvec::RowVector, mat::AbstractMatrix) = transpose(mat \ transpose(rowvec))
@inline A_rdiv_Bc(rowvec::RowVector, mat::AbstractMatrix) = adjoint(mat  \ adjoint(rowvec))
