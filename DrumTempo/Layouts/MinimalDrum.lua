-------------------------------------------------------------------------------
-- DrumTempo - Minimal Drum Layout (v1.2)
-------------------------------------------------------------------------------
local addonName, addonTable = ...
local DrumTempo = addonTable.Core or LibStub("AceAddon-3.0"):GetAddon("DrumTempo", true)

local Layout = { 
    name = "Minimal Drum", 
    frame = nil 
}

-- Utility for safe library access (using AutoCast shine for the "Ready" flash)
local function GetLCG()
    return LibStub("LibCustomGlow-1.0", true)
end

-------------------------------------------------------------------------------
-- Visual Logic
-------------------------------------------------------------------------------
function Layout:Drummed(drum, drummer)
    if not drum or not self.frame then return end
    
    -- 1. Start the visual swipe
    self.frame:SetCooldown(drum)
    
    -- 2. Force grey state immediately upon use
    if self.frame.mainframe.texture then
        self.frame.mainframe.texture:SetDesaturated(true)
    end
    
    self:UpdateCount()
end

function Layout:UpdateCount()
    -- SAFETY GATE: If the frame or the cooldown object doesn't exist yet, stop here.
    if not self.frame or not self.frame.mainframe or not self.frame.mainframe.cooldown then 
        return 
    end
    
    if not DrumTempo.db then return end
    
    local itemID = DrumTempo.db.profile.drumwatched
    local count = DrumTempo:GetDrumCount(itemID)
    
    -- Update the item count text (bottom right)
    self.frame:SetItemCount(count)

    -- Color/Grey Logic
    local isLockout = self.frame.mainframe.cooldown:GetCooldownDuration() > 0
    
    -- If we have drums AND the cooldown swipe is gone, show color
    if count > 0 and not isLockout then
        -- If it was grey and just turned to color, trigger a brief flash
        if self.frame.mainframe.texture:IsDesaturated() then
            local LCG = GetLCG()
            if LCG then
                -- Just a quick flash/shine to alert the user
                LCG.AutoCastGlow_Start(self.frame.mainframe, {1, 1, 1, 1})
                C_Timer.After(0.8, function() 
                    if self.frame and self.frame.mainframe then
                        LCG.AutoCastGlow_Stop(self.frame.mainframe) 
                    end
                end)
            end
        end
        self.frame.mainframe.texture:SetDesaturated(false)
    else
        -- Stay grey if out of drums or in lockout
        self.frame.mainframe.texture:SetDesaturated(true)
    end
end

-------------------------------------------------------------------------------
-- Layout Management
-------------------------------------------------------------------------------
function Layout:Load()
    -- Get the frame using the unique ID
    self.frame = DrumTempo:GetSingleFrame("MinimalDrum")
    
    if self.frame then
        -- Force Minimalist Style: Hide text elements
        self.frame.toptext:Hide()
        self.frame.bottomtext:Hide()

        -- Small delay to let item cache and Frame objects fully initialize
        C_Timer.After(0.5, function()
            if self.frame and self.frame.mainframe then
                self.frame:SetItem(DrumTempo.db.profile.drumwatched)
                self.frame:LoadPos()
                self.frame.mainframe:Show()
                
                -- CRITICAL FIX: Only hook the cooldown if it actually exists
                if self.frame.mainframe.cooldown then
                    self.frame.mainframe.cooldown:SetScript("OnCooldownDone", function()
                        self:UpdateCount()
                    end)
                end

                self:UpdateCount()
            end
        end)
        
        self.frame.mainframe:RegisterEvent("BAG_UPDATE")
        self.frame.mainframe:SetScript("OnEvent", function() self:UpdateCount() end)
    end
end

function Layout:Unload()
    if self.frame then
        local LCG = GetLCG()
        if LCG then LCG.AutoCastGlow_Stop(self.frame.mainframe) end

        if self.frame.mainframe then
            self.frame.mainframe:UnregisterEvent("BAG_UPDATE")
            self.frame.mainframe:SetScript("OnEvent", nil)
            self.frame.mainframe.cooldown:SetScript("OnCooldownDone", nil)
        end

        -- Restore text visibility for other layouts
        self.frame.toptext:Show()
        self.frame.bottomtext:Show()
        
        DrumTempo:ReleaseFrame(self.frame)
        self.frame = nil
    end
end

function Layout:ShowFrame()
    if self.frame and self.frame.mainframe then 
        self.frame.mainframe:Show() 
    end
end

function Layout:HideFrame()
    if self.frame and self.frame.mainframe then 
        self.frame.mainframe:Hide() 
    end
end

-------------------------------------------------------------------------------
-- Register with Core
-------------------------------------------------------------------------------
if DrumTempo and DrumTempo.RegisterLayout then
    DrumTempo:RegisterLayout(Layout)
else
    addonTable.MinimalDrumLayout = Layout
end