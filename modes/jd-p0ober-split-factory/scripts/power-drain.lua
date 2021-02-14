local PowerDrain = {}
local EventScheduler = require("utility/event-scheduler")
local Interfaces = require("utility/interfaces")

local TargetLowPowerRatio = 0.7

PowerDrain.CreateGlobals = function()
    global.powerDrain = global.powerDrain or {}
    global.powerDrain.forcesDraining = global.powerDrain.forcesDraining or {}
    --[[
        [id] = {
            id = force index.
            playersTriggeringDrain = table of LuaPlayer that are triggering the drain. key'd by player index.
            drainEntity = entity thats doing the drain.
            readerEntity = entity thats being the constant teleporter power user and read for electric health.
        }
    ]]
end

PowerDrain.OnLoad = function()
    Interfaces.RegisterInterface("PowerDrain.StartCycle", PowerDrain.StartCycle)
    Interfaces.RegisterInterface("PowerDrain.StopCycle", PowerDrain.StopCycle)
    EventScheduler.RegisterScheduledEventType("PowerDrain.OnTick", PowerDrain.OnTick)
end

PowerDrain.StartCycle = function(player)
    if 1 == 1 then
        PowerDrain.StartNewPowerDrainCycle(player)
    end
    -- TODO: should check if one already exists and add to it if so.
end

PowerDrain.StopCycle = function()
end

PowerDrain.StartNewPowerDrainCycle = function(player)
    local drainEntity = player.surface.create_entity {name = "jd_plays-jd_p0ober_split_factory-power_drain-sink", position = {0, 0}, force = player.force}
    drainEntity.destructible = false
    local readerEntity = player.surface.create_entity {name = "jd_plays-jd_p0ober_split_factory-power_drain-reader", position = {0, 2}, force = player.force}
    readerEntity.destructible = false
    readerEntity.power_usage = 500000 / 60
    readerEntity.electric_buffer_size = 500000 / 60
    local powerDrainEntry = {
        id = player.force.index,
        playersTriggeringDrain = {[player.index] = player},
        drainEntity = drainEntity,
        readerEntity = readerEntity
    }
    global.powerDrain.forcesDraining[powerDrainEntry.id] = powerDrainEntry
    EventScheduler.ScheduleEvent(game.tick + 1, "PowerDrain.OnTick", powerDrainEntry.id)
end

PowerDrain.OnTick = function(event)
    local powerDrainEntry = global.powerDrain.forcesDraining[event.instanceId]
    local drainEntity, readerEntity = powerDrainEntry.drainEntity, powerDrainEntry.readerEntity

    if drainEntity.power_usage > 0 then
        local drainDirection
        if readerEntity.energy / readerEntity.electric_buffer_size > TargetLowPowerRatio then
            drainDirection = 1
        else
            drainDirection = -1
        end
        drainEntity.power_usage = drainEntity.power_usage + ((drainEntity.power_usage / 5 / 60) * drainDirection) -- Change up/down to move towards target power usage each tick. Move in 20% increments and keep it jumping up and down on power usage so its a bit random.
    else
        drainEntity.power_usage = (10000000 / 60) -- 10MW starting
    end
    drainEntity.electric_buffer_size = drainEntity.power_usage

    EventScheduler.ScheduleEvent(game.tick + 1, "PowerDrain.OnTick", powerDrainEntry.id)
end

return PowerDrain
