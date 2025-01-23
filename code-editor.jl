
include("2Dlib.jl")
include("colorPalletes.jl")
include("freetypeLib.jl")
include("gui_functions.jl")

fontfilepath = "./fonts/FiraCode-Bold.ttf"

library, face = ftInit(fontfilepath)

ftpoint = Ref(12)
fHeight, ascender = setPixelSize!(face, ftpoint[])

using JuliaSyntaxHighlighting: _hl_annotations, parseall, GreenNode
highlightCode(str) = _hl_annotations(str, parseall(GreenNode, str))

vimTheme = Dict(
[ ( Symbol("julia_rainbow_$(pbc)_$i") => cx ) for pbc in ["paren", "bracket", "curly"] for (i, cx) in zip(1:6, [aurora; frost[1]]) ]...,
    :julia_funcall => snowStorm[1],
    :julia_number  => frost[4],
    :julia_comment => aurora[4], 
    # :julia_macro => ,
    # :julia_symbol => ,
    # :julia_singleton_identifier => ,
    # :julia_type => ,
    # :julia_typedec => ,
    :julia_char => aurora[2],
    :julia_char_delim => aurora[2],
    :julia_string => frost[1],
    :julia_string_delim => frost[1],
    # :julia_cmdstring => ,
    # :julia_regex => ,
    # :julia_backslash_literal => ,
    # :julia_bool => ,
    # :julia_broadcast => ,
    # :julia_builtin => ,
    :julia_operator => aurora[5],
    # :julia_comparator => ,
    # :julia_assignment => ,
    :julia_keyword => aurora[5],
    # :julia_parentheses => ,
    # :julia_unpaired_parentheses => ,
    :julia_error => 0xcc313d)

codeStr = read("./initSdl.jl", String)

appState = Dict(
    :codeCont => collect.( split(codeStr, '\n') ),
    :scroll  => 0,
    :vimView => missing,
    :vimCur  => [[1, 1], ],
)

cs = [polarNight[2], frost[3], frost[2], frost[4]]
# cs = getproperty.([mocha], [:Base, :Text, :Sky, :Lavender])

function launchFrame(surf2d)
    
    fill!(surf2d, polarNight[1]) # cs[1])

    lLengths = [0; accumulate(+, length.(appState[:codeCont][1:end-1]) .+ 1 ) ]
    styles = map(highlightCode(join(String.( appState[:codeCont] ), '\n'))) do (r, (_, anno))

        l = findlast(<(r[1]), lLengths)
        (l, r .- lLengths[l] .+ 7, get(vimTheme, anno, frost[3]) )
    end

    lines = getindex.(appState[:vimCur], 1)
    
    appState[:vimCur] = appState[:vimCur][end:end]

    wim = vimdow(Broadcast.broadcasted((String ∘ vcat), appState[:codeCont], ' '), cs, appState[:vimCur][end])
    append!(wim[4], styles)
    appState[:vimView] = applyText(wim..., appState[:vimView], ismissing(appState[:vimView]) ? missing : lines )

    vimHeight = min(size(appState[:vimView], 2), div(size(surf2d, 2) - 40, fHeight)*fHeight)

    appState[:scroll] = begin 
        distances = ((lines[end].+[-1, 0]) .* fHeight .* [1, -1]) .+ [0, vimHeight] .+ (appState[:scroll] .* [-1, 1])
        dd = div(vimHeight, 7*fHeight) * fHeight
        s = [-1, 1] .* max.(dd .- distances, 0)

        clamp(appState[:scroll] + sum(s), 0, size(appState[:vimView], 2)- vimHeight) # maxscroll
    end
    
    vimV = appState[:vimView][:, appState[:scroll] .+ (1:vimHeight)]
    vimVPos = [10, 20]

    applyCx(surf2d, frost[3], roundedRect(size(vimV) .+ 2, 6), vimVPos .- 1 )
    applyTexture(surf2d, vimV, roundedRect(size(vimV), 5), vimVPos)

end

include("initSdl.jl")

# vimModes => :normalMode | :insertMode | :visualMode
cVimMode = Ref(:normalMode)

upPt = n-> begin
    global fHeight, ascender = setPixelSize!(face, (ftpoint[] += n))
    appState[:vimView] = missing
end
upCur = up-> begin
    upState = appState[:vimCur][end] .+ up
    upState[1] = clamp(upState[1], 1, length( appState[:codeCont] ))
    upState[2] = clamp(upState[2], 1, length( appState[:codeCont][upState[1]] )+1)
    push!(appState[:vimCur], upState)
end


windowSize = 80 .* (21, 9)
launchUI(windowSize, launchFrame) do winMods, render, applyEvent, clearEvents, quit
    (; setResizeable) = winMods

    fn = ()->render(launchFrame)

    evs = [
    ("SizeChanged", wh-> fn() ),
    ('Q', quit, true),

    ("onKeyboardEvent", (key, Release)->begin 

        Release && return;

        # LSHIFT: 1 | RSHIFT:  2 | LCTRL:   64 | RCTRL:    128
        # LALT: 256 | RALT:  512 | LGUI:  1024 | RGUI:    2048
        # NUM: 4096 | CAPS: 8192 | MODE: 16384 | SCROLL: 32768
        # CTRL: 192 | SHIFT:   3 | ALT:    768 | GUI:     3072
        kmod = SDL_GetModState()
        # kmod -= sum( kmod .& [3072, 16384, 32768] )

        cased = xor( (kmod .& [2^13, 3] .> 0)... )
        line, curx = appState[:vimCur][end]
        insChar = (ind, chr)-> insert!(appState[:codeCont][line], ind, chr)
        insLines = (ind, n)-> begin
            appState[:vimView] = hcat( appState[:vimView][:,1:((ind-1) * fHeight)],
            fill(UInt32(0), size(appState[:vimView], 1), fHeight*n),
            appState[:vimView][:,((ind-1)* fHeight+ 1):end])
        end


        if (cVimMode[] == :normalMode)
            if key == 'O'
                insert!(appState[:codeCont], line+(cased ? 0 : 1 ), Char[])
                !(cased) && upCur([1 , 0])
                insLines(line, 1)
                cVimMode[] = :insertMode

            elseif key == 'D'
                if curx > length( appState[:codeCont][line] )

                    append!(appState[:codeCont][line], appState[:codeCont][line+1])
                    deleteat!(appState[:codeCont], line+1)
                    appState[:vimView] = hcat( appState[:vimView][:,1:(line * fHeight)],
                    appState[:vimView][:,((line+1)* fHeight+ 1):end])
                else
                    deleteat!(appState[:codeCont][line], curx)
                end

            elseif !(cased)

                if key isa Char

                    curu = [[0, -1], [0,  1], [1,  0], [-1, 0]]
                    (key in "HLJK") && upCur(  curu[ findfirst(==(key), "HLJK") ] )
                    (key in ",."  ) && upPt( [-1,1][ findfirst(==(key), ",."  ) ] )
                end
                # ('S', ()->(appState[:scroll] += fHeight ))
                # ('W', ()->(appState[:scroll] -= fHeight ))
                key == 'I' && (cVimMode[] = :insertMode)
            end

        elseif cVimMode[] == :insertMode

            if key == "escape"
                cVimMode[] = :normalMode

            elseif key == "space"
                insChar(curx, ' ')
                upCur([0,  1])

            elseif key == "tab"
                insChar.(curx, collect("    "))
                upCur([0,  4])

            elseif key == "backSpace"
                if curx > 1
                    deleteat!(appState[:codeCont][line], curx-1)
                    upCur([0, -1])
                else
                    upCur([-1, length(appState[:codeCont][line-1])+1])
                    append!(appState[:codeCont][line-1], appState[:codeCont][line])
                    deleteat!(appState[:codeCont], line)
                    appState[:vimView] = hcat( appState[:vimView][:,1:((line-1) * fHeight)],
                    appState[:vimView][:,(line* fHeight+ 1):end])
                end

            elseif (key isa Char) && key in 'A':'Z'
                insChar(curx, (cased ? key : lowercase(key)) )
                upCur([0,  1])

            elseif ( ind = findfirst(==(key), ['1':'9'; '0'; collect("-=[]\\;'`,./")]); !isnothing(ind) )

                insChar(curx, (kmod & 3 > 0) ? string("!@#\$%^&*()", "_+{}|:\"~<>?")[ ind ] : key )
                upCur([0,  1])
            end
        # elseif (cVimMode[] == :visualMode)

        end

        fn()

    end)]

    splat(applyEvent).(evs)
end
