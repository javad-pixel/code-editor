# 2D Array Functions 
cRange(wh, cord=(1,1)) = range.(cord, wh .+ cord .- 1)
draw2d(arr, val, cord=(1,1)) = setindex!(arr, val, cRange(size(val), cord)... )

# RGB Functions 
CxRGB(Cx::UInt32) = # inputExample -> 0x2e3440 , 0xrrggbb
    reinterpret(NTuple{4, UInt8}, Cx)[1:3] |> reverse
function toCx(rgb) # inputExample -> UInt8[39, 41, 54] , (0xrr, 0xgg, 0xbb)

    rgb = collect(rgb)
    reinterpret(UInt32, [reverse(rgb); 0x0] )[]
end
function linearCx(C1, C2, G::UInt8) # inputExample -> ( backGround::Cx, textColor::Cx, GrayScale::UInt8 )
    if     G == 0x00; C1
    elseif G == 0xff; C2
    else
        G = G // 0x00ff
        C = mapreduce(.*, .+, [G, 1-G], CxRGB.([C2, C1]) )
        toCx( trunc.(UInt8, C) )
    end
end

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
