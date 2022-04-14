local Divider = {}
local Events = require("utility/events")

Divider.CreateGlobals = function()
    global.divider = global.divider or {}
    -- The divider must all be within 1 chunk
    global.divider.dividerStartYPos = global.divider.dividerStartYPos or -18 -- X pos in world of divide tiles start.
    global.divider.dividerEndYPos = global.divider.dividerEndYPos or -17 -- X pos in world of divide tiles end.
    global.divider.dividerMiddleYPos = global.divider.dividerMiddleYPos or -17 -- X Pos of divide entity.
    global.divider.chunkYPos = global.divider.chunkYPos or -1 -- Chunk X pos when looking for chunks generated.
end

Divider.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_chunk_generated, "Divider.OnChunkGenerated", Divider.OnChunkGenerated)
    Events.RegisterHandlerEvent(defines.events.on_player_built_tile, "Divider.OnTilePlaced", Divider.OnTilePlaced)
    Events.RegisterHandlerEvent(defines.events.on_robot_built_tile, "Divider.OnTilePlaced", Divider.OnTilePlaced)
end

Divider.OnChunkGenerated = function(event)
    -- This requires both tiles and entity to all be in the same chunk. So not centered down chunk border.
    if event.position.y ~= global.divider.chunkYPos then
        return
    end

    -- Place the blocking land tiles down. Ignore water tiles as catch when landfill is placed.
    -- Check beyond this chunk in the next 3 partially generated chunks (map gen weirdness) and fill them with our blocking tiles. Stops biters pathing around the top/bottom of the partially generated map.
    local surface, landTilesToReplace = event.surface, {}
    local yMin, yMax
    if event.area.left_top.x >= 0 then
        xMin = event.area.left_top.x
        xMax = event.area.left_top.x + 31 + 96
    else
        xMin = event.area.left_top.x - 96
        xMax = event.area.left_top.x + 31
    end
    for y = global.divider.dividerStartYPos, global.divider.dividerEndYPos do
        for x = xMin, xMax do
            local existingTileName = surface.get_tile(x, y).name
            if existingTileName ~= "water" and existingTileName ~= "deepwater" and existingTileName ~= "jd_plays-jd_spider_race-divider_tile_land" then
                table.insert(landTilesToReplace, {name = "jd_plays-jd_spider_race-divider_tile_land", position = {x = x, y = y}})
            end
        end
    end
    surface.set_tiles(landTilesToReplace, true, true, false, false)

    -- Place the blocking entities in the center of the 2 tiles.
    for x = event.area.left_top.x, event.area.left_top.x + 31 do
        local dividerEntity = surface.create_entity {name = "jd_plays-jd_spider_race-divider_entity", position = {x = x + 0.5, y = global.divider.dividerMiddleYPos}, create_build_effect_smoke = false, raise_built = false}
        dividerEntity.destructible = false
        local dividerEntitySpider = surface.create_entity {name = "jd_plays-jd_spider_race-divider_entity_spider_block", position = {x = x + 0.5, y = global.divider.dividerMiddleYPos}, create_build_effect_smoke = false, raise_built = false}
        dividerEntitySpider.destructible = false
    end

    -- Place the beam effect. Overlap by a tile as we have overlaped all the graphics bits of the beam prototype.
    surface.create_entity {name = "jd_plays-jd_spider_race-divider_beam", position = {0, 0}, target_position = {x = event.area.left_top.x - 1, y = global.divider.dividerMiddleYPos}, source_position = {x = event.area.left_top.x + 33, y = global.divider.dividerMiddleYPos}}
end

Divider.OnTilePlaced = function(event)
    if event.tile.name ~= "landfill" then
        return
    end
    local surface, landTilesToReplace = game.surfaces[event.surface_index], {}
    for _, tileReplaced in pairs(event.tiles) do
        if tileReplaced.position.x >= global.divider.dividerStartXPos and tileReplaced.position.x <= global.divider.dividerEndXPos then
            table.insert(landTilesToReplace, {name = "jd_plays-jd_spider_race-divider_tile_land", position = tileReplaced.position})
        end
    end
    if #landTilesToReplace > 0 then
        surface.set_tiles(landTilesToReplace, true, true, false, false)
    end
end

return Divider
