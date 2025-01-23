
module ftmod

using FreeType

function ftInit(fontfilepath, faceindex = Int32(0))

    library = Ref{Ptr{Nothing}}()
    @ccall (:libfreetype).FT_Init_FreeType(library::Ptr{Nothing})::Cint

    face = Ref{Ptr{FT_FaceRec_}}()

    @ccall (:libfreetype).FT_New_Face(
            library[]::Ptr{Nothing}, fontfilepath::Ptr{UInt8},
            faceindex::Int64, face::Ptr{Ptr{FT_FaceRec_}})::Int32

    (library=library[], face=face[])
end
ftDoneLibrary(library) = @ccall (:libfreetype).FT_Done_FreeType(library::Ptr{Nothing})::Int32
ftDoneFace(face) = @ccall (:libfreetype).FT_Done_Face(face::Ptr{Nothing})::Int32

function setPixelSize!(face, h, w=0) # width and height [0: auto]
    @ccall (:libfreetype).FT_Set_Pixel_Sizes(
            face::Ptr{Nothing}, w::UInt32, h::UInt32)::Int32

    global glyps = Dict{UInt16, Any}()

    flod = unsafe_load(face)
    yScale = unsafe_load(flod.size).metrics.y_scale// 1<<22 # (2^16)// 64

    round.(Int, [flod.height, flod.ascender] .* yScale, RoundUp)
end
getCharIndex(face, charcode) =
        @ccall (:libfreetype).FT_Get_Char_Index(
            face::Ptr{Nothing}, charcode::UInt64)::UInt32

function loadGlyph!(face, index, loadFlags = 0)

    @ccall (:libfreetype).FT_Load_Glyph(
            face::Ptr{Nothing}, index::UInt32, loadFlags::Int32)::Int32
    unsafe_load(face).glyph
end
# renderMode::UInt32 => 0: NORMAL | 1: LIGHT | 2: MONO
#                       3: LCD    | 4: LCD_V | 5: MAX
function renderGlyph(face, index, renderMode = 0)
    slot = loadGlyph!(face, index)

    @ccall (:libfreetype).FT_Render_Glyph(slot::Ptr{Nothing}, renderMode::UInt32)::Int32

    glyph = unsafe_load(slot)

    anchor = (glyph.bitmap_left, -glyph.bitmap_top) 
    xAdvance = round(Int, glyph.advance.x//64, RoundUp) 
    
    (; buffer, width, rows) = glyph.bitmap

    (unsafe_wrap(Array, buffer, (width, rows)) |> copy, anchor, xAdvance)
end

# Cache renderGlyph's output...
function getGlyph(face, c, renderMode = 0)
    i = (c isa Char) ? getCharIndex(face, c) : c

    get!(glyps, i) do
        renderGlyph(face, i, renderMode)
    end
end
# KernMode::UInt32 => DEFAULT : 0 | UNFITTED : 1 | UNSCALED : 2
function getKerning(face, lGlyph, rGlyph, kernMode = 0)
    kerning = fill(Int64(0), 2)
    @ccall (:libfreetype).FT_Get_Kerning(face::Ptr{Nothing},
            lGlyph::UInt32, rGlyph::UInt32, kernMode::UInt32, kerning::Ptr{Nothing})::Int32
    kerning # Int64[x, y] ::FT_Vector 
end

export ftInit, ftDoneFace, ftDoneLibrary, setPixelSize!,
        getCharIndex, loadGlyph!, renderGlyph, getGlyph,
        getKerning
end

using .ftmod
