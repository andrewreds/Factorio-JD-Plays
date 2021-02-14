if settings.startup["jdplays_mode"].value ~= "jd_p0ober_split_factory" then
    return
end

local refElectricEnergyInterface = data.raw["electric-energy-interface"]["electric-energy-interface"]

data:extend(
    {
        {
            type = "electric-energy-interface",
            name = "jd_plays-jd_p0ober_split_factory-power_drain-sink",
            picture = refElectricEnergyInterface.picture,
            energy_source = {
                type = "electric",
                usage_priority = "primary-input"
            }
        },
        {
            type = "electric-energy-interface",
            name = "jd_plays-jd_p0ober_split_factory-power_drain-reader",
            picture = refElectricEnergyInterface.picture,
            energy_source = {
                type = "electric",
                usage_priority = "secondary-input"
            }
        }
    }
)
