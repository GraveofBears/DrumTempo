-------------------------------------------------------------------------------
-- DrumTempo - Minimal Drum Layout (v1.5)
-------------------------------------------------------------------------------
local addonName, addonTable = ...
local DrumTempo = addonTable.Core or LibStub("AceAddon-3.0"):GetAddon("DrumTempo", true)

local Layout = { 
    name = "Minimal Drum", 
    frame = nil 
}

local function GetLCG()
    return LibStub("LibCustomGlow-1.0", true)
end

-------------------------------------------------------------------------------
-- Visual Logic
-------------------------------------------------------------------------------
function Layout:Drummed(drum, drummer)
    if not drum or not self.frame or not self.frame.mainframe then return end
    self.frame:SetCooldown(drum)
    
    if self.frame.mainframe.texture then
        self.frame.mainframe.texture:SetDesaturated(true)
    end
    
    self:UpdateCount()
end

function Layout:UpdateCount()
    if not self.frame or not self.frame.mainframe then return end
    if not DrumTempo.db then return end
    
    local itemID = DrumTempo.db.profile.drumwatched
    local count = DrumTempo:GetDrumCount(itemID)
    
    -- Update the count
    self.frame:SetItemCount(count)

    -- FORCE VISIBILITY: Ensure the count text is actually shown
    -- We check the frame AND the mainframe in case it's nested
    local countText = self.frame.count or (self.frame.mainframe and self.frame.mainframe.count)
    if countText then 
        countText:Show() 
    end

    -- Color/Grey Logic
    local isLockout = false
    if self.frame.mainframe.cooldown then
        isLockout = self.frame.mainframe.cooldown:GetCooldownDuration() > 0
    end
    
    if count > 0 and not isLockout then
        if self.frame.mainframe.texture:IsDesaturated() then
            local LCG = GetLCG()
            if LCG then
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
        self.frame.mainframe.texture:SetDesaturated(true)
    end
end

-------------------------------------------------------------------------------
-- Layout Management
-------------------------------------------------------------------------------
function Layout:Load()
    self.frame = DrumTempo:GetSingleFrame("MinimalDrum")
    
    if self.frame then
        -- Hide the fluff
        if self.frame.toptext then self.frame.toptext:Hide() end
        if self.frame.bottomtext then self.frame.bottomtext:Hide() end

        C_Timer.After(0.5, function()
            if self.frame and self.frame.mainframe then
                self.frame:SetItem(DrumTempo.db.profile.drumwatched)
                self.frame:LoadPos()
                self.frame.mainframe:Show()
                
                -- Ensure count is visible after SetItem potentially hides things
                local countText = self.frame.count or self.frame.mainframe.count
                if countText then countText:Show() end

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
        if LCG and self.frame.mainframe then 
            LCG.AutoCastGlow_Stop(self.frame.mainframe) 
        end

        if self.frame.mainframe then
            self.frame.mainframe:UnregisterEvent("BAG_UPDATE")
            self.frame.mainframe:SetScript("OnEvent", nil)
            if self.frame.mainframe.cooldown then
                self.frame.mainframe.cooldown:SetScript("OnCooldownDone", nil)
            end
        end

        -- Restore for Default view
        if self.frame.toptext then self.frame.toptext:Show() end
        if self.frame.bottomtext then self.frame.bottomtext:Show() end
        local countText = self.frame.count or (self.frame.mainframe and self.frame.mainframe.count)
        if countText then countText:Show() end
        
        DrumTempo:ReleaseFrame(self.frame)
        self.frame = nil
    end
end

function Layout:ShowFrame()
    if self.frame and self.frame.mainframe then self.frame.mainframe:Show() end
end

function Layout:HideFrame()
    if self.frame and self.frame.mainframe then self.frame.mainframe:Hide() end
end

if DrumTempo and DrumTempo.RegisterLayout then
    DrumTempo:RegisterLayout(Layout)
else
    addonTable.MinimalDrumLayout = Layout
end