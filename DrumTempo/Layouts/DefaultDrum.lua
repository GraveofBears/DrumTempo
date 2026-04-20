-------------------------------------------------------------------------------
-- DrumTempo - Default Drum Layout (v8.0)
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
    if not drum or not self.frame then return end
    
    -- 1. Start the 30s visual cooldown clock (the sweeping overlay)
    self.frame:SetCooldown(drum)
    
    -- 2. Display Drummer Name on Top
    local name = DrumTempo:Ambiguate(drummer)
    self.frame:SetTopText(name)

    -- Note: Name clearing is handled by Frames.lua (lockout end) 
    -- or DrumTempo.lua (debuff removal).
    
    self:UpdateCount()
end

function Layout:UpdateCount()
    if not self.frame or not DrumTempo.db then return end
    
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
        self.frame.toptext:Show()
        self.frame.bottomtext:Show()

        -- Delay the initial item setup by 0.5 seconds to allow cache to warm up
        C_Timer.After(0.5, function()
            if self.frame then
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
        if self.frame.mainframe then
            self.frame.mainframe:UnregisterEvent("BAG_UPDATE")
            self.frame.mainframe:SetScript("OnEvent", nil)
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
    -- THIS IS THE MISSING LINK:
    addonTable.DefaultDrumLayout = Layout
end