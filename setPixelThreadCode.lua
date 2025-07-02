-- require ("love.graphics")
require ("love.image")

local setPixelImageData, colorDataArr, particleData = ...

-- while true do
--     -- Waits for a signal from the main thread to start working
--     channel:demand ()
-- end

-- local grid = mapData.grid
-- local setPixel = setPixelImageData.setPixel
-- for i = 1, mapData.width do
--     local firstPart = grid[i]
--     for j = 1, mapData.height do
--         local tileData = firstPart[j]
--         local color = particleData[tileData.id].color
--         local tint = tileData.tint
--         local paint = tileData.paint

--         if paint ~= nil then
--             setPixel (setPixelImageData, i, j, paint[1], paint[2], paint[3], paint[4])
--         elseif tint ~= nil then
--             setPixel (setPixelImageData, i, j, color[1] + tint[1], color[2] + tint[2], color[3] + tint[3], color[4] + tint[4])
--         else
--             setPixel (setPixelImageData, i, j, color[1], color[2], color[3], color[4])
--         end
--     end
-- end