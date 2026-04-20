-------------------------------------------------------------------------------
-- DrumTempo - Default Drum Layout (v8.1)
-------------------------------------------------------------------------------
local addonName, addonTable = ...

local DrumTempo = addonTable.Core or LibStub("AceAddon-3.0"):GetAddon("DrumTempo", true)

local Layout = { 
    name = "Default Drum", 
    frame = nil 
}

-------------------------------------------------------------------------------
-- Visual Logic
-------------------------------------------------------------------------------
function Layout:Drummed(drum, drummer)
    if not drum or not self.frame or not self.frame.mainframe then return end
    
    -- Start visual cooldown
    self.frame:SetCooldown(drum)
    
    -- Show drummer name
    local name = DrumTempo:Ambiguate(drummer)
    self.frame:SetTopText(name)

    -- ✅ NEW: If already debuffed, force lockout to sync visuals
    if DrumTempo.hasTinnitus and DrumTempo.tinnitusEndTime then
        local remaining = DrumTempo.tinnitusEndTime - GetTime()
        if remaining > 0 then
            self.frame:SetLockout(remaining)
        end
    end

    self:UpdateCount()
end

function Layout:UpdateCount()
    -- SAFETY GATE: Prevent errors if frame objects aren't initialized yet
    if not self.frame or not self.frame.mainframe then return end
    if not DrumTempo.db then return end
    
    -- Pull the current drum ID directly from the profile to ensure correct count
    local itemID = DrumTempo.db.profile.drumwatched
    local count = DrumTempo:GetDrumCount(itemID)
    
    self.frame:SetItemCount(count)
end

-------------------------------------------------------------------------------
-- Layout Management
-------------------------------------------------------------------------------
function Layout:Load()
    -- Get the unique frame for this layout
    self.frame = DrumTempo:GetSingleFrame("DefaultDrum")
    
    if self.frame then
        -- Ensure text elements are visible (in case we switched from Minimal)
        if self.frame.toptext then self.frame.toptext:Show() end
        if self.frame.bottomtext then self.frame.bottomtext:Show() end

        -- Delay the initial item setup by 0.5 seconds to allow cache to warm up
        C_Timer.After(0.5, function()
            if self.frame and self.frame.mainframe then
                self:UpdateCount()
                self.frame:SetItem(DrumTempo.db.profile.drumwatched)
                self.frame:LoadPos()
                self.frame.mainframe:Show()
            end
        end)
        
        self.frame.mainframe:RegisterEvent("BAG_UPDATE")
        self.frame.mainframe:SetScript("OnEvent", function() self:UpdateCount() end)
    end
end

function Layout:Unload()
    if self.frame then
        -- Safely unregister and clear scripts
        if self.frame.mainframe then
            self.frame.mainframe:UnregisterEvent("BAG_UPDATE")
            self.frame.mainframe:SetScript("OnEvent", nil)
            
            -- Clear cooldown scripts if they were added
            if self.frame.mainframe.cooldown then
                self.frame.mainframe.cooldown:SetScript("OnCooldownDone", nil)
            end
        end

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
    -- Fallback for early loading if Core isn't initialized yet
    addonTable.DefaultDrumLayout = Layout
end