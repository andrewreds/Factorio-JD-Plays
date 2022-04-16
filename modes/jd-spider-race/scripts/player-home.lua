local PlayerHome = {}
local Events = require("utility/events")
local Utils = require("utility/utils")
local Logging = require("utility/logging")
local Interfaces = require("utility/interfaces")

local SpawnYOffset = 20

PlayerHome.CreateGlobals = function()
    global.playerHome = global.playerHome or {}

    global.playerHome.teams = global.playerHome.teams or {}
    --[[
        [id] = {
            id = string team of either "north" or "south".
            spawnPosition = position of this team's spawn.
            playerIds = table of the player ids who have joined this team.
            playerNames = table of player names who will join this team on first connect.
            otherTeam = ref to the other teams global object.
        }
    ]]
    global.playerHome.playerIdToTeam = global.playerHome.playerIdToTeam or {}

end

PlayerHome.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_player_respawned, "PlayerHome.OnPlayerSpawn", PlayerHome.OnPlayerSpawn)
    Events.RegisterHandlerEvent(defines.events.on_player_created, "PlayerHome.OnPlayerCreated", PlayerHome.OnPlayerCreated)
    Events.RegisterHandlerEvent(defines.events.on_marked_for_deconstruction, "PlayerHome.OnMarkedForDeconstruction", PlayerHome.OnMarkedForDeconstruction)
    Events.RegisterHandlerEvent(defines.events.on_built_entity, "PlayerHome.OnBuiltEntity", PlayerHome.OnBuiltEntity)
    Events.RegisterHandlerEvent(defines.events.on_entity_damaged, "PlayerHome.OnEntityDamaged", PlayerHome.OnEntityDamaged, {
        -- Don't give us biter damage events
        -- Worms are "turrents". So this filter doesn't include them :(
        {filter = "type", type = "unit", invert = true},
        {filter = "type", type = "unit-spawner", invert = true, mode = "and"},
    })

end

PlayerHome.OnStartup = function()
    Utils.DisableIntroMessage()

    if global.playerHome.teams["north"] == nil then
        PlayerHome.CreateTeam("north", global.divider.dividerMiddleYPos - SpawnYOffset)
        PlayerHome.CreateTeam("south", global.divider.dividerMiddleYPos + SpawnYOffset)
        global.playerHome.teams["north"].otherTeam = global.playerHome.teams["south"]
        global.playerHome.teams["south"].otherTeam = global.playerHome.teams["north"]
    end
end

PlayerHome.OnEntityDamaged = function(event)
    -- Undo any damage done to the opposing team

    local event_force = event.force
    local event_entity = event.entity

    if event_force == nil or event_entity == nil then
        -- should never happen. Defensive coding
        return false
    end

    local from_force_name = event_force.name
    local to_force_name = event_entity.force.name

    -- We could generically loop over all forces, but lets squeeze any
    -- performance we can out of this code
    if (from_force_name == "north" and to_force_name == "south") or
            (from_force_name == "south" and to_force_name == "north") then

        -- undo the damage done
        event_entity.health = event_entity.health + event.final_damage_amount

        return true
    end

    return false
end


PlayerHome.CreateTeam = function(teamId, spawnYPos)
    local team = {
        id = teamId,
        spawnPosition = {x = 0, y = spawnYPos},
        playerIds = {},
        playerNames = {}
    }

    local force = game.create_force(teamId)
    local enemy_force = game.create_force(teamId.."_enemy")

    -- Don't auto target other forces
    for other_force_name, _ in pairs(global.playerHome.teams) do
        other_force = game.forces[other_force_name]
        other_enemy_force = game.forces[other_force_name.."_enemy"]

        force.set_cease_fire(other_force, true)
        force.set_cease_fire(other_enemy_force, true)
        enemy_force.set_cease_fire(other_force, true)
        enemy_force.set_cease_fire(other_enemy_force, true)
    end

    global.playerHome.teams[teamId] = team
end

PlayerHome.AddPlayerNameToTeam = function(playerName, team)
    team.playerNames[playerName] = playerName
end

PlayerHome.OnPlayerCreated = function(event)
    local player = game.get_player(event.player_index)

    if player.controller_type == defines.controllers.cutscene then
        -- So we have a player character to teleport.
        player.exit_cutscene()
    end
    -- Check if player is on the named list.
    local team
    for _, teamToCheck in pairs(global.playerHome.teams) do
        if teamToCheck.playerNames[player.name] ~= nil then
            team = teamToCheck
            break
        end
    end
    -- If player isn't named give them a random team.
    if team == nil then
        local teamNames = Utils.TableKeyToArray(global.playerHome.teams)
        team = global.playerHome.teams[teamNames[math.random(1, 2)]]
        PlayerHome.AddPlayerNameToTeam(player.name, team)
        game.print("Player '" .. player.name .. "' isn't set on a team, so added to the '" .. team.id .. "' randomly")
    end
    --Record the player ID to the team, rather than relying on names.
    team.playerIds[player.index] = player
    global.playerHome.playerIdToTeam[player.index] = team

    player.force = game.forces[team.id]
    PlayerHome.OnPlayerSpawn(event)
end

PlayerHome.OnPlayerSpawn = function(event)
    local player = game.get_player(event.player_index)
    local team = global.playerHome.playerIdToTeam[player.index]
    local targetPos, surface = team.spawnPosition, player.surface

    local foundPos = surface.find_non_colliding_position("character", targetPos, 0, 0.2)
    if foundPos == nil then
        Logging.LogPrint("ERROR: no position found for player '" .. player.name .. "' near '" .. Logging.PositionToString(targetPos) .. "' on surface '" .. surface.name .. "'")
        return
    end
    local teleported = player.teleport(foundPos, surface)
    if teleported ~= true then
        Logging.LogPrint("ERROR: teleport failed for player '" .. player.name .. "' to '" .. Logging.PositionToString(foundPos) .. "' on surface '" .. surface.name .. "'")
        return
    end
end

PlayerHome.OnMarkedForDeconstruction = function(event)
    -- stop deconstruction from the wrong side of the wall

    local player = game.get_player(event.player_index)

    if player == nil then
        return
    end

    local team = global.playerHome.playerIdToTeam[player.index]
    if team == nil then
        return
    end

    if event.entity.position.y < 0 then
        if team.id == "south" then
            event.entity.cancel_deconstruction(player.force, player)
        end
    elseif team.id == "north" then
        event.entity.cancel_deconstruction(player.force, player)
    end
end


PlayerHome.OnBuiltEntity = function(event)
    -- stop building on the wrong side
    local player = game.get_player(event.player_index)
    local team = global.playerHome.playerIdToTeam[player.index]
    if team == nil then
        return
    end

    if event.created_entity.position.y < 0 then
        if team.id == "south" then
            event.created_entity.destroy()
         end
    elseif team.id == "north" then
        event.created_entity.destroy()
    end
end


-- TOOD: Do we want on_player_dropped_item?




return PlayerHome
