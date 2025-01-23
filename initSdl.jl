module initsdl

using SimpleDirectMediaLayer.LibSDL2

function sdlRend(win, renderFn)
    surf = SDL_GetWindowSurface(win) |> unsafe_load
    
    dims = (surf.w, surf.h)
    pixels = Ptr{UInt32}(surf.pixels)

    renderFn( unsafe_wrap(Array, pixels, dims) ) 
    
    SDL_UpdateWindowSurface(win)
end

qLoop() = global eLoop = false
function sdlEventLoop(eventFn)

    evt = Ref{SDL_Event}()
    global eLoop = true

    while eLoop

        SDL_WaitEvent(evt)

        eventFn(evt[])
    end

    SDL_Quit()
end

# mouseButton=> 1: Left | 2: Middle | 3: Right | 4: Back | 5: Forward
mouseButtons = ["LeftBtn", "Middle", "RightBtn", "Back", "Forward"]

# 0: None | 1: Shown | ...
winEvents = ["Shown", "Hidden", "Exposed", "Moved", "Resized", 
"SizeChanged", "Minimized", "Maximized", "Restored", "winEnter", 
"Leave", "FocusGained", "FocusLost", "Close", 
"TakeFocus", "HitTest", "IccprofChanged", "DisplayChanged"] 

fnKeys = Array{Union{String, Char}}(
            ['A':'Z'; '0':'9'; collect("-=[]\\;'`,./")] )

append!(fnKeys,
[ String.(split("Enter escape backSpace tab space CapsLK", ' '));
  [ "F$i" for i in 1:12 ];
  String.(split(
"ScrLK Pause Ins Home PgUP Del End PgDn Right Left Down Up NumLK KpDiv KpMul KpMinus KpPlus Enter Application LCtrl LShift LAlt RCtrl RShift RAlt", ' '))] )

function keyEvent(sc)

        if sc in 4:29    ;     (sc-  3) # 'A':'Z'
    elseif sc in 30:38   ; 27+ (sc- 29) # '1':'9'
    elseif sc in 89:97   ; 27+ (sc- 88) # '1':'9'
    elseif sc in [39, 98]; 27           # '0'
    elseif sc in 45:49   ; 36+ (sc- 44) # "-=[]\\"
    elseif sc in 51:56   ; 41+ (sc- 50) # ";'`,./"
    elseif sc == 99      ; 46           # '.'

    elseif sc in 40:44  ; 47+     (sc- 39)  # rebts
    elseif sc in 57:69  ; 47+  5+ (sc- 56)  # capsFx
    elseif sc in 71:88  ; 47+ 18+ (sc- 70)  # rlup
    elseif sc == 101    ; 47+ 37            # "Application"
    elseif sc in 224:226; 47+ 37+ (sc- 223) # LCSA
    elseif sc in 228:230; 47+ 40+ (sc- 227) # RCSA
    else; 0
    end
end

noop(i=missing, j=missing) = missing
onWinEvent    = Array{Function}(undef, length(winEvents))
onKeyClick    = Array{Function}(undef, length(fnKeys), 2)
onMouseClick  = Array{Function}(undef, length(mouseButtons), 2)
onMouseMotion = Ref{Function}(noop)
onKeyboardEvent = Ref{Function}(noop)

function applyEvent(e, fn=noop, Release=false)

    if e == "onMouseMotion"
        onMouseMotion[] = fn

    elseif e == "onKeyboardEvent"
        onKeyboardEvent[] = fn

    elseif e in mouseButtons
        onMouseClick[ findfirst(==(e), mouseButtons), Release+ 1 ] = fn

    elseif e in winEvents
        onWinEvent[ findfirst(==(e), winEvents) ] = fn

    else
        onKeyClick[ findfirst(==(e), fnKeys), Release+ 1 ] = fn

    end
end
function clearEvents()

    fill!.([onWinEvent, onKeyClick, onMouseClick], noop)
    setindex!.([onMouseMotion, onKeyboardEvent], noop)
end

function launchUI(eventsGen, wh, launchFrame)

    win = SDL_CreateWindow("sdlExample", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
        wh..., SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE)
 # | SDL_WINDOW_BORDERLESS

    winMods = (
    setTitle=t-> SDL_SetWindowTitle(win, t),
    setPos= xy-> SDL_SetWindowPosition(win, Int32.(xy)...),
    setSize=wh-> SDL_SetWindowSize(win, Int32.(wh)...),
    getPos=()->( x = Ref{Int32}(0); y = Ref{Int32}(0);
                 SDL_GetWindowPosition(win, x, y); (x[], y[]) ),
    getSize=()->( w = Ref{Int32}(0); h = Ref{Int32}(0);
                 SDL_GetWindowSize(win, w, h); (w[], h[]) ),
    setResizeable=b->SDL_SetWindowResizable(win, SDL_bool(UInt32(b))) )


    sdlRend(win, launchFrame)

    clearEvents()
    eventsGen(winMods, f->sdlRend(win, f), applyEvent, clearEvents, qLoop)

    sdlEventLoop() do ev

        ty = ev.type
        if ty == 0x200  #SDL_WINDOWEVENT
            (; event, data1, data2) = ev.window
            onWinEvent[event]( (data1, data2) )

        elseif ty in [0x300, 0x301]  #SDL_KEYDOWN  SDL_KEYUP
            keyInd = UInt32(ev.key.keysym.scancode) |> keyEvent
            if keyInd != 0
                onKeyboardEvent[]( fnKeys[ keyInd ], (ty == 0x301) )
                onKeyClick[keyInd, (ty == 0x301 ? 2 : 1)]()
            end

        elseif ty == 0x400  #SDL_MOUSEMOTION
            (; x, y) = ev.motion
            onMouseMotion[]( (x, y) )

        elseif ty in [0x401, 0x402]  #SDL_MOUSEBUTTONDOWN  SDL_MOUSEBUTTONUP
            (; button, x, y) = ev.button
            onMouseClick[button, (ty == 0x402 ? 2 : 1)]( (x, y) )
        end
    end
end

export launchUI, SDL_GetModState

end

using .initsdl
