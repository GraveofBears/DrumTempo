-------------------------------------------------------------------------------
-- DrumTempo - Drum Data (v6.3)
-------------------------------------------------------------------------------
local addonName, addonTable = ...

-- Safety Check: Ensure the Core object exists in the namespace
-- If it's not there yet, we'll wait for DrumTempo.lua to populate it
local DrumTempo = addonTable.Core or LibStub("AceAddon-3.0"):GetAddon("DrumTempo", true)

local Drums = {
    battle = {
        item     = 29529,
        spell    = 35476,
        duration = 30,
        cooldown = 120,
        texture  = "Interface\\Icons\\INV_Misc_Drum_02",
    },
    war = {
        item     = 29528,
        spell    = 35475,
        duration = 30,
        cooldown = 120,
        texture  = "Interface\\Icons\\INV_Misc_Drum_03",
    },
    panic = {
        item     = 29532,
        spell    = 35474,
        duration = 2,
        cooldown = 120,
        texture  = "Interface\\Icons\\INV_Misc_Drum_06",
    },
    restoration = {
        item     = 29531,
        spell    = 35478,
        duration = 15,
        cooldown = 120,
        texture  = "Interface\\Icons\\INV_Misc_Drum_07",
    },
    speed = {
        item     = 29530,
        spell    = 35477,
        duration = 30,
        cooldown = 120,
        texture  = "Interface\\Icons\\INV_Misc_Drum_04",
    },
}

-- helper function to attach data once the core is ready
local function InitializeData(core)
    if not core then return end
    core.Drums = Drums
    
    function core:GetDrumByItemID(id)
        if not self.Drums then return nil end
        for _, v in pairs(self.Drums) do
            if v.item == id then return v end
        end
        return nil
    end
end

-- If the core is already loaded, initialize now. 
-- Otherwise, DrumTempo.lua will handle it when it starts.
if DrumTempo then
    InitializeData(DrumTempo)
else
    -- Fallback: inject the data table into the namespace so DrumTempo.lua can grab it
    addonTable.DrumsData = Drums
end