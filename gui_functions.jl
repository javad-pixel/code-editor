
function strAdvance(face, str)

    advance = ( getGlyph(face, c)[3] for c in str )

    UInt16[0; accumulate(+, advance)]
end
function renderLine(str, defBg, defCx, st=[], wid=missing)

    advanc = strAdvance(face, str)

    w = 2+ advanc[end]

    ov = fill(defBg, coalesce(wid, w + div(w, 50) ), fHeight)

    for (rng, _, bg) in Iterators.filter(s-> length(s) > 2, st),
        r in rng

        vrng = range( ( advanc[[0, 1] .+ r] .+ (1, 0) .+ 1)...)
        fill!(view(ov, vrng, 1:fHeight), bg)
    end

    fgc = Base.Generator(eachindex(str)) do i

        cx = findlast(st) do (rng, c, _...)
            (i in rng) & !ismissing(c)
        end
        isnothing(cx) ? defCx : st[ cx ][2]
    end

    linePos = (1, ascender) .+ 1

    glyphs = ( getGlyph(face, c)[1:2] for c in str )

    for ( cx, (bmap, anchor), gOffset ) in zip(fgc, glyphs, ( (x, 0) for x in advanc ))

        applyCx(ov, cx, bmap, anchor .+ gOffset .+ linePos)
    end

    ov
end
function applyText(content, defBg, defCx, styles=[], ov=missing, selLines=missing)
    
    if ismissing(ov)

        w = 2+ maximum(content) do str
            strAdvance(face, str)[end]
        end
        ov = fill(defBg, w + div(w, 50), length(content)*fHeight )
    end

    for line in coalesce(selLines, eachindex(content))

        str = content[line]
        advanc = strAdvance(face, str)

        hrng = ((-1, 0) .+ line) .* fHeight .+ (1, 0)
        fillLine = (vrng, cb)-> fill!(view(ov, vrng, range(hrng...)), cb)

        !ismissing(selLines) && fillLine(axes(ov, 1), defBg)

        st = [ s for (lrng, s...) in styles if line in lrng ]

        for (rng, _, bg) in Iterators.filter(s-> length(s) > 2, st),
            r in rng

            fillLine(range( ( advanc[[0, 1] .+ r] .+ (1, 0) .+ 1)...), bg)
        end

        fgc = Base.Generator(eachindex(str)) do i

            cx = findlast(st) do (rng, c, _...)
                (i in rng) & !ismissing(c)
            end
            isnothing(cx) ? defCx : st[ cx ][2]
        end

        linePos = (1, ascender+ (line-1)*fHeight) .+ 1

        glyphs = ( getGlyph(face, c)[1:2] for c in str )

        for ( cx, (bmap, anchor), gOffset ) in zip(fgc, glyphs, ( (x, 0) for x in advanc ))

            applyCx(ov, cx, bmap, anchor .+ gOffset .+ linePos)
        end
    end

    ov
end

function vimdow(content, cs, cur, sel=[], indes=missing)

    content = map( coalesce(indes, eachindex(content)), content) do i, c
        rpad(lpad(string(i), 5), 7) * c
    end

    styles = Any[(eachindex(content), 1:7, cs[4]);
    [(l, i .+ 7, cs[1], cs[2]) for (l, i) in sel];
    ((cur .+ [0, 7])..., cs[1], cs[3]) ]

    ( content, cs[1:2]..., styles )
end

function bitmapGenerator(func, rng, heig=missing)

    ls = map(rng) do ind

        map( ind* 16 .+ (0:15) ) do x
            ( pixs, g ) = func(x)
            ( pixs, ceil(UInt8, g * 16) )
        end
    end    

    maxH = maximum(ls) do l
        maximum(l) do (pixs, g)
            (pixs + ( g>0 ? 1 : 0 ))
        end
    end
    mapfoldl(hcat, ls) do l

        col = fill( UInt16(0), coalesce(heig, maxH) )
        for (pixs, g) in l

            col[1:pixs] .+= 16
            if pixs < length(col)
                col[pixs+1] += g
            end
        end

        [ UInt8( clamp(p, 0x0, 0xff) ) for p in col ]
    end
end

function quartCircle(r)

    bitmapGenerator(0:(r-1), r) do l

        g, pixs = modf( sqrt( r^2 - (l//16)^2 ) )
        (trunc(Int, pixs), g)
    end
end
function circle(r)
    c = quartCircle(r)
    [reverse(c) reverse(c, dims=1)[:, 2:end] ; reverse(c, dims=2)[2:end, :] c[2:end, 2:end]]
end
function roundedRect(wh, r)

    rec = fill(0xff, wh...)
    c = quartCircle(r)
    x, y = size(rec) .- size(c)
    for i in 1:4

        i==1 && (p = (0, 0); v = reverse(c))
        i==2 && (p = (x, 0); v = reverse(c, dims=2))
        i==3 && (p = (0, y); v = reverse(c, dims=1))
        i==4 && (p = (x, y); v = c)

        rec[ cRange(size(v), p .+ 1)... ] = v
        # setindex!(rec, v, cRange(size(v), p .+ 1)...)
    end
    rec
end

