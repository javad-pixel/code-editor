
# RGB Functions =>

"""

Convert 32bit pixel into UInt8[red, green, blue]
example:
julia> CxRGB(0x2e3440)
(0x2e, 0x34, 0x40)

"""
CxRGB(Cx::UInt32) =
    reinterpret(NTuple{4, UInt8}, Cx)[1:3] |> reverse

"""
Convert UInt8[red, green, blue] into 32bit pixel
example:
julia> toCx([0x2e, 0x34, 0x40])
0x2e3440

"""
function toCx(rgb)

    rgb = collect(rgb)
    reinterpret(UInt32, [reverse(rgb); 0x0] )[]
end


"""
Linear Color interpolation Function
( firstColor::UInt32, secondColor::UInt32, GrayScale::UInt8 )
G: 0 => returns the first color
G: 255 => returns the second color
G: 1:254 => calculates a color between C1 and C2
based on Linear Color Interpolation formula

example:
julia> linearCx(0x2e3440, 0xd8dee9, 0x88)

0x00888e9a

"""
function linearCx(C1::UInt32, C2::UInt32, G::UInt8)
    if     G == 0x00; C1
    elseif G == 0xff; C2
    else
        G = G // 0x00ff
        C = mapreduce(.*, .+, [G, 1-G], CxRGB.([C2, C1]) )
        toCx( trunc.(UInt8, C) )
    end
end

# Matrix Functions =>

cRange(wh, cord=(1,1)) = range.(cord, wh .+ cord .- 1)
draw2d(arr, val, cord=(1,1)) = setindex!(arr, val, cRange(size(val), cord)... )

function applyCx(bg, cx, bmap, pos)

    v = view(bg, cRange(size(bmap), pos)...)
    map!(v, v, bmap) do a, g
        linearCx(a, cx, g)
    end
end

function applyTexture(bg, tex, bmap, pos)

    v = view(bg, cRange(size(bmap), pos)...)
    map!(linearCx, v, v, tex, bmap)
end
