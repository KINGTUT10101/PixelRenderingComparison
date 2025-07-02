local ffi = require ("ffi")
ffi.cdef ([[
    typedef struct { float r, g, b, a; } rgba_pixel;
]])
ffi.cdef ([[
    typedef struct { float r, g, b, a; } rgba_pixel;
]])

-- Declares / initializes the local variables
local particleData = {
    [1] = {
        color = {0, 0, 0, 1}
    }
}
local mapData = {
    grid = {},
    cgrid = {},
    width = 500,
    height = 250,
    tileSize = 1,
}
local renderingMode = "original"

local UINT8_PTR_TYPEOF = ffi.typeof('uint8_t*')
local FLOAT_PTR_TYPEOF = ffi.typeof('float*')
local SIZEOF_FLOAT     = ffi.sizeof('float')

-- Returns a LÖVE ByteData object, as well as its uint8_t FFI pointer.
-- The pointer is for modifying the contents.
-- Use makeFloatData() when it's for a GLSL uniform.
local function makeByteData(totalBytes)
    local data = love.data.newByteData(totalBytes)
    return data, UINT8_PTR_TYPEOF(data:getFFIPointer())
end

-- Create an RGBA8 image (4 bytes per pixel)
local pointerImage = love.graphics.newImage(love.image.newImageData(mapData.width, mapData.height, 'rgba8'))
local function plotImage()
    local width, height = mapData.width, mapData.height
    local BYTES_PER_PIXEL = 4 -- RGBA
    local data, ptr = makeByteData(width * height * BYTES_PER_PIXEL)

    local grid = mapData.grid
    for i = 1, width do
        local firstPart = grid[i]
        local columnIndex = i - 1
        for j = 1, height do
            local tileData = firstPart[j]
            local color = particleData[tileData.id].color
            local tint = tileData.tint
            local paint = tileData.paint

            -- Calculate pixel index (row-major order, 0-based)
            local pixelIndex = ((j - 1) * width + columnIndex) * BYTES_PER_PIXEL
            if paint ~= nil then
                ptr[pixelIndex + 0] = math.max(0, math.min(255, paint[1] * 255))
                ptr[pixelIndex + 1] = math.max(0, math.min(255, paint[2] * 255))
                ptr[pixelIndex + 2] = math.max(0, math.min(255, paint[3] * 255))
                ptr[pixelIndex + 3] = math.max(0, math.min(255, paint[4] * 255))
            elseif tint ~= nil then
                ptr[pixelIndex + 0] = math.max(0, math.min(255, (color[1] + tint[1]) * 255))
                ptr[pixelIndex + 1] = math.max(0, math.min(255, (color[2] + tint[2]) * 255))
                ptr[pixelIndex + 2] = math.max(0, math.min(255, (color[3] + tint[3]) * 255))
                ptr[pixelIndex + 3] = math.max(0, math.min(255, (color[4] + tint[4]) * 255))
            else
                ptr[pixelIndex + 0] = math.max(0, math.min(255, color[1] * 255))
                ptr[pixelIndex + 1] = math.max(0, math.min(255, color[2] * 255))
                ptr[pixelIndex + 2] = math.max(0, math.min(255, color[3] * 255))
                ptr[pixelIndex + 3] = math.max(0, math.min(255, color[4] * 255))
            end
        end
    end

    local imageData = love.image.newImageData(width, height, 'rgba8', data)
    pointerImage:replacePixels(imageData)
end

local tempImageData = love.image.newImageData (1, 1)
tempImageData:setPixel (0, 0, 1, 1, 1, 1)
local spritebatch = love.graphics.newSpriteBatch (love.graphics.newImage (tempImageData))

local setPixelImageData = love.image.newImageData (mapData.width + 1, mapData.height + 1)
local setPixelImage = love.graphics.newImage (setPixelImageData)

local setPixelThreadCode = love.filesystem.read ("setPixelThreadCode.lua")
local setPixelThread = love.thread.newThread (setPixelThreadCode)

local mapPixelImageData = love.image.newImageData (mapData.width, mapData.height)
local mapPixelImage = love.graphics.newImage (mapPixelImageData)
local pixelMapper = nil

local pixelShader = love.graphics.newShader ([[
    // extern vec4 testVal;
    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
    {
        vec4 texcolor = Texel(tex, texture_coords);
        number mapX = screen_coords.x + 1;
        number mapY = screen_coords.y + 1;

        if (screen_coords.x == 0) {
            //return vec4(0, 1, 0, 1);
        }

        if (texture_coords.x == 0) {
            return vec4(0, 0, 1, 1);
        }

        //return texcolor * color;
        //return vec4(1, 0, 0, (screen_coords.x + 1) / 500);
        return vec4(1, 0, 0, mapX / 500);
    }
]])

local colorDataArr

local testCData = ffi.new ("rgba_pixel", math.random (), math.random (), math.random (), 1)
local testCPointer = ffi.cast ("void*", testCData)
local cDataPassingThreadCode = love.filesystem.read ("cDataPassing.lua")
local cDataPassingThread = love.thread.newThread (cDataPassingThreadCode)

-- print (testCPointer)
-- cDataPassingThread:start (testCPointer)

-- while true do end

function love.load ()
	-- Fills the map grid with particle data
    for i = 1, mapData.width do
        mapData.grid[i] = {}
        mapData.cgrid[i] = {}
        for j = 1, mapData.height do
            mapData.grid[i][j] = {
                id = 1,
                tint = {math.random (), math.random (), math.random (), 1},
                paint = nil,
            }
            mapData.cgrid[i][j] = {
                id = 1,
                tint = ffi.new ("rgba_pixel", math.random (), math.random (), math.random (), 1),
                paint = nil,
            }

            -- print (mapData.cgrid[i][j].tint.r)
        end
    end

    local grid = mapData.grid
    pixelMapper = function (x, y)
        local tileData = grid[x + 1][y + 1]
        local color = particleData[tileData.id].color
        local tint = tileData.tint
        local paint = tileData.paint
    
        if paint ~= nil then
            return paint
        elseif tint ~= nil then
            return color[1] + tint[1], color[2] + tint[2], color[3] + tint[3], color[4] + tint[4]
        else
            return color
        end
    end

    colorDataArr = {}
        local grid = mapData.grid
        for i = 1, mapData.width do
            local firstPart = grid[i]
            for j = 1, mapData.height do
                local tileData = firstPart[j]
                local paint = tileData.paint
                colorDataArr[#colorDataArr + 1] = (paint == nil) and true or false -- true = tint, false = paint
                colorDataArr[#colorDataArr + 1] = (paint == nil) and tileData.tint or tileData.paint
            end
        end
end


function love.update (dt)
	
end


function love.draw ()
    -- Draws the particles
    -- Simulates the cost of the for loop without any actual rendering
    if renderingMode == "baseline" then
        local grid = mapData.grid
        local sum = 0
        for i = 1, mapData.width do
            local firstPart = grid[i]
            for j = 1, mapData.height do
                local tileData = firstPart[j]
                
                sum = sum + 1
            end
        end

    -- The current rendering modal from JASG that uses setColor and rectangle functions
    elseif renderingMode == "original" then
        local grid = mapData.grid
        local setColor = love.graphics.setColor
        local rectangle = love.graphics.rectangle
        for i = 1, mapData.width do
            local firstPart = grid[i]
            for j = 1, mapData.height do
                local tileData = firstPart[j]
                local color = particleData[tileData.id].color
                local tint = tileData.tint
                local paint = tileData.paint

                if paint ~= nil then
                    setColor (paint[1], paint[2], paint[3], paint[4])
                elseif tint ~= nil then
                    setColor (color[1] + tint[1], color[2] + tint[2], color[3] + tint[3], color[4] + tint[4])
                else
                    setColor (color[1], color[2], color[3], color[4])
                end

                rectangle ("fill", i, j, 1, 1)
            end
        end

    -- Adds sprites to a spritebatch so they get rendered all at once
    elseif renderingMode == "spritebatch" then
        spritebatch:clear()

        local grid = mapData.grid
        local setColor = spritebatch.setColor
        local add = spritebatch.add
        for i = 1, mapData.width do
            local firstPart = grid[i]
            for j = 1, mapData.height do
                local tileData = firstPart[j]
                local color = particleData[tileData.id].color
                local tint = tileData.tint
                local paint = tileData.paint

                if paint ~= nil then
                    setColor (spritebatch, paint[1], paint[2], paint[3], paint[4])
                elseif tint ~= nil then
                    setColor (spritebatch, color[1] + tint[1], color[2] + tint[2], color[3] + tint[3], color[4] + tint[4])
                else
                    setColor (spritebatch, color[1], color[2], color[3], color[4])
                end

                add (spritebatch, i, j)
            end
        end

        love.graphics.draw (spritebatch, 0, 0)

    -- Uses several threads to add sprites to the batches before rendering them all at once
    -- Each thread uses its own spritebatch to avoid issues with setColor
    elseif renderingMode == "ffi-color-tables" then
        local grid = mapData.cgrid
        local setColor = love.graphics.setColor
        local rectangle = love.graphics.rectangle
        for i = 1, mapData.width do
            local firstPart = grid[i]
            for j = 1, mapData.height do
                local tileData = firstPart[j]
                local color = particleData[tileData.id].color
                local tint = tileData.tint
                local paint = tileData.paint

                if paint ~= nil then
                    setColor (paint[1], paint[2], paint[3], paint[4])
                elseif tint ~= nil then
                    setColor (color[1] + tint.r, color[2] + tint.g, color[3] + tint.b, color[4] + tint.a)
                else
                    setColor (color[1], color[2], color[3], color[4])
                end

                rectangle ("fill", i, j, 1, 1)
            end
        end

    -- Uses a custom function to plot pixels on an image data, then converts and renders it
    elseif renderingMode == "ffi-bytedata-plotting" then
        plotImage (mapData.width, mapData.height)
        love.graphics.draw (pointerImage, 1, 1)

    -- Uses a custom function to map pixels on an imagedata, then converts and renders it
    elseif renderingMode == "setPixel" then
        local grid = mapData.grid
        local setPixel = setPixelImageData.setPixel
        local particleDataCache = particleData
        
        for i = 1, mapData.width do
            local firstPart = grid[i]
            for j = 1, mapData.height do
                local tileData = firstPart[j]
                local paint = tileData.paint

                if paint ~= nil then
                    setPixel (setPixelImageData, i, j, paint[1], paint[2], paint[3], paint[4])
                else
                    local tint = tileData.tint

                    if tint ~= nil then
                        local color = particleDataCache[tileData.id].color
                        setPixel (setPixelImageData, i, j, color[1] + tint[1], color[2] + tint[2], color[3] + tint[3], color[4] + tint[4])
                    else
                        local color = particleDataCache[tileData.id].color
                        setPixel (setPixelImageData, i, j, color[1], color[2], color[3], color[4])
                    end
                end
            end
        end

        setPixelImage:replacePixels (setPixelImageData)
        love.graphics.draw (setPixelImage, 0, 0)

    -- Splits the work of the setPixel mode over several threads
    elseif renderingMode == "setPixel-threaded" then
        setPixelThread:start (setPixelImageData, colorDataArr)
        -- setPixelThread:wait ()
        
        setPixelImage:replacePixels (setPixelImageData)
        love.graphics.draw (setPixelImage, 0, 0)

    elseif renderingMode == "setPixel-new" then


    -- Similar to setPixel mode but it uses a mapper function to generate color data rather than manually setting pixels
    elseif renderingMode == "mapPixel" then
        local grid = mapData.grid

        mapPixelImageData:mapPixel (pixelMapper)
        mapPixelImage:replacePixels (mapPixelImageData)
        love.graphics.draw (mapPixelImage, 1, 1)

    -- Uses the points function to draw singular pixels
    -- Remember that points are not affected by the current graphics scale!
    elseif renderingMode == "points" then
        local grid = mapData.grid
        local setColor = love.graphics.setColor
        local points = love.graphics.points
        for i = 1, mapData.width do
            local firstPart = grid[i]
            for j = 1, mapData.height do
                local tileData = firstPart[j]
                local color = particleData[tileData.id].color
                local tint = tileData.tint
                local paint = tileData.paint
    
                if paint ~= nil then
                    setColor (paint[1], paint[2], paint[3], paint[4])
                elseif tint ~= nil then
                    setColor (color[1] + tint[1], color[2] + tint[2], color[3] + tint[3], color[4] + tint[4])
                else
                    setColor (color[1], color[2], color[3], color[4])
                end
    
                points (0.5 + i, 0.5 + j)
            end
        end
        
    -- Uses a pixel (fragment) shader to render the particles, which requires copying color data to the GPU
    elseif renderingMode == "shader" then
        -- pixelShader:sendColor ("testVal", {math.random (), math.random (), math.random (), 1})
        love.graphics.setShader (pixelShader)
        love.graphics.rectangle ("fill", 1, 1, 500, 250)
        love.graphics.setShader ()
    end

    local stats = love.graphics.getStats ()

    -- Draws the map borders
    love.graphics.setColor (1, 0, 0, 1)
    love.graphics.line (0, 0, 501, 0)
    love.graphics.line (0, 251, 501, 251)
    love.graphics.line (501, 0, 501, 251)
    love.graphics.line (0, 0, 0, 251)

    -- Sets the color for text rendering
    love.graphics.setColor (1, 1, 1, 1)

    -- Shows the available rendering modes
    love.graphics.printf ("none - 1, baseline - 2, original - 3, spritebatch - 4, ffi-color-tables - 5, setPixel - 6, setPixel-threaded - 7, mapPixel - 8, points - 9, shader - 0", 10, 265, 500)

    -- Shows the mouse position
    local mouseX, mouseY = love.mouse.getPosition ()
    love.graphics.print ("Mouse X: " .. mouseX, 525, 15)
    love.graphics.print ("Mouse Y: " .. mouseY, 525, 30)

    -- Shows the rendering mode
    love.graphics.print ("Rendering Mode: " .. renderingMode, 525, 60)

    -- Shows the FPS
    love.graphics.print (love.timer.getFPS(), 750, 15)

    -- Shows the rendering stats
    love.graphics.print ("Drawcalls: " .. stats.drawcalls, 10, 320)
    love.graphics.print ("Canvas Switches: " .. stats.canvasswitches, 10, 350)
    love.graphics.print ("Texture Memory: " .. stats.texturememory, 10, 380)
    love.graphics.print ("Shader Switches: " .. stats.shaderswitches, 10, 410)
    love.graphics.print ("Drawcalls Batched: " .. stats.drawcallsbatched, 10, 440)
    love.graphics.print ("Images: " .. stats.images, 10, 470)
    love.graphics.print ("Canvases: " .. stats.canvases, 10, 500)
end


function love.keypressed (key)
	if key == "1" then
        renderingMode = "none"
    elseif key == "2" then
        renderingMode = "baseline"
    elseif key == "3" then
        renderingMode = "original"
    elseif key == "4" then
        renderingMode = "spritebatch"
    elseif key == "5" then
        if love.keyboard.isDown ("lshift") == true then
            renderingMode = "ffi-bytedata-plotting"
        else
            renderingMode = "ffi-color-tables"
        end
    elseif key == "6" then
        renderingMode = "setPixel"
    elseif key == "7" then
        if love.keyboard.isDown ("lshift") == true then
            renderingMode = "setPixel-new"
        else
            renderingMode = "setPixel-threaded"
        end
    elseif key == "8" then
        renderingMode = "mapPixel"
    elseif key == "9" then
        renderingMode = "points"
    elseif key == "0" then
        renderingMode = "shader"
    end
end