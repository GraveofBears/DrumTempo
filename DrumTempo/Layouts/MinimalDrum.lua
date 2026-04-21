-------------------------------------------------------------------------------
-- DrumTempo - Minimal Drum Layout (v2.4)
-------------------------------------------------------------------------------
local addonName, addonTable = ...
local DrumTempo = addonTable.Core or LibStub("AceAddon-3.0"):GetAddon("DrumTempo", true)

local Layout = { 
    name = "Minimal Drum", 
    frame = nil,
    lastState = nil,
    isPulsing = false,
    clickLockout = 0 
}

local TINNITUS_ID = 29519 

local function GetLCG()
    return LibStub("LibCustomGlow-1.0", true)
end

-- Softer "Shine" Effect for "Ready to Use"
local function TriggerReadyShine(frame)
    local LCG = GetLCG()
    if not LCG or not frame then return end
    
    -- Stop all existing glows first
    LCG.PixelGlow_Stop(frame)
    LCG.AutoCastGlow_Stop(frame)
    
    -- ButtonGlow is the Blizzard-style "Proc" shine. 
    -- It has a very natural fade-out.
    LCG.ButtonGlow_Start(frame)
    
    C_Timer.After(2.5, function() 
        if frame then LCG.ButtonGlow_Stop(frame) end
    end)
end

-------------------------------------------------------------------------------
-- Visual Logic
-------------------------------------------------------------------------------
function Layout:GetDebuffRemaining()
    for i = 1, 40 do
        local name, _, _, _, duration, expirationTime, _, _, _, spellId = UnitDebuff("player", i)
        if not name then break end
        
        if spellId == TINNITUS_ID or name == "Tinnitus" then
            local rem = expirationTime - GetTime()
            return rem > 0 and rem or 0
        end
    end
    return 0
end

function Layout:Drummed(drum, drummer)
    if not drum or not self.frame or not self.frame.mainframe then return end
    -- Start the 30s visual cooldown swipe
    self.frame:SetCooldown(drum)
    
    -- Stop any "ready" glows immediately
    local LCG = GetLCG()
    if LCG then
        LCG.ButtonGlow_Stop(self.frame.mainframe)
        LCG.PixelGlow_Stop(self.frame.mainframe)
        LCG.AutoCastGlow_Stop(self.frame.mainframe)
    end

    -- Set a brief click lockout so we can't double-fire before Tinnitus lands
    self.clickLockout = GetTime() + 2
    self.lastState = "lockout"
    self.isPulsing = false
    
    -- Grey out immediately; UpdateCount's OnUpdate loop will manage the full lockout
    -- from here via GetDebuffRemaining(), so we do NOT call frame:SetLockout() here.
    if self.frame.mainframe.texture then
        self.frame.mainframe.texture:SetDesaturated(true)
    end

    -- Disable clicking without touching the OnUpdate loop
    if not InCombatLockdown() then
        self.frame.mainframe:SetAttribute("item", nil)
    end
    
    C_Timer.After(0.1, function() self:UpdateCount() end)
end

function Layout:UpdateCount()
    if not self.frame or not self.frame.mainframe then return end
    if not DrumTempo.db then return end
    
    local itemID = DrumTempo.db.profile.drumwatched
    local count = DrumTempo:GetDrumCount(itemID)
    self.frame:SetItemCount(count)

    local debuffRemaining = self:GetDebuffRemaining()
    
    local currentlyReady = (count > 0 and debuffRemaining <= 0 and GetTime() > self.clickLockout)
    local currentState = currentlyReady and "ready" or "lockout"
    local texture = self.frame.mainframe.texture

    -- 1. THE 5-SECOND PULSE (Softer White Warning)
    if debuffRemaining > 0 and debuffRemaining <= 5 then
        if not self.isPulsing then
            self.isPulsing = true
            local LCG = GetLCG()
            if LCG then LCG.AutoCastGlow_Start(self.frame.mainframe, {1, 1, 1, 0.5}) end
        end
    elseif self.isPulsing then
        self.isPulsing = false
        local LCG = GetLCG()
        if LCG then LCG.AutoCastGlow_Stop(self.frame.mainframe) end
    end

    -- 2. THE READY SHINE (Swapped from Sparkle)
    if currentState == "ready" and self.lastState == "lockout" then
        TriggerReadyShine(self.frame.mainframe)
    end
    
    self.lastState = currentState

    -- 3. APPLY VISUAL STATE
    if texture then
        texture:SetDesaturated(not currentlyReady)
    end
    
    -- Restore or clear the item attribute so the button is only clickable when ready
    if not InCombatLockdown() then
        if currentlyReady then
            local itemID = DrumTempo.db.profile.drumwatched
            if self.frame.mainframe:GetAttribute("item") == nil then
                self.frame.mainframe:SetAttribute("item", "item:" .. itemID)
            end
        else
            self.frame.mainframe:SetAttribute("item", nil)
        end
    end
end

-------------------------------------------------------------------------------
-- Layout Management
-------------------------------------------------------------------------------
function Layout:Load()
    self.frame = DrumTempo:GetSingleFrame("MinimalDrum")
    
    if self.frame then
        -- Tell Frames.lua not to overwrite our OnUpdate with its own lockout script
        self.frame.selfManagesLockout = true

        if self.frame.toptext then self.frame.toptext:Hide() end
        if self.frame.bottomtext then self.frame.bottomtext:Hide() end

        C_Timer.After(0.5, function()
            if self.frame and self.frame.mainframe then
                self.frame:SetItem(DrumTempo.db.profile.drumwatched)
                self.frame:LoadPos()
                
                if not InCombatLockdown() then
                    self.frame.mainframe:Show()
                end

                self.frame.mainframe:SetScript("OnUpdate", function(s, elapsed)
                    s.timer = (s.timer or 0) + elapsed
                    if s.timer > 0.1 then 
                        self:UpdateCount()
                        s.timer = 0
                    end
                end)

                self:UpdateCount()
            end
        end)
        
        self.frame.mainframe:RegisterEvent("UNIT_AURA")
        self.frame.mainframe:RegisterEvent("BAG_UPDATE")
        self.frame.mainframe:SetScript("OnEvent", function(s, event, unit)
            if event == "BAG_UPDATE" or unit == "player" then 
                self:UpdateCount() 
            end
        end)
    end
end

function Layout:Unload()
    if self.frame then
        -- Re-enable standard lockout handling for other layouts
        self.frame.selfManagesLockout = false
        local LCG = GetLCG()
        if LCG and self.frame.mainframe then 
            LCG.ButtonGlow_Stop(self.frame.mainframe)
            LCG.AutoCastGlow_Stop(self.frame.mainframe) 
        end

        if self.frame.mainframe then
            self.frame.mainframe:SetScript("OnUpdate", nil)
            self.frame.mainframe:UnregisterEvent("UNIT_AURA")
            self.frame.mainframe:UnregisterEvent("BAG_UPDATE")
            self.frame.mainframe:SetScript("OnEvent", nil)
        end

        if self.frame.toptext then self.frame.toptext:Show() end
        if self.frame.bottomtext then self.frame.bottomtext:Show() end
        
        DrumTempo:ReleaseFrame(self.frame)
        self.frame = nil
        self.lastState = nil
        self.isPulsing = false
    end
end

function Layout:ShowFrame()
    if self.frame and self.frame.mainframe and not InCombatLockdown() then 
        self.frame.mainframe:Show() 
    end
end

function Layout:HideFrame()
    if self.frame and self.frame.mainframe and not InCombatLockdown() then 
        self.frame.mainframe:Hide() 
    end
end

if DrumTempo and DrumTempo.RegisterLayout then
    DrumTempo:RegisterLayout(Layout)
else
    addonTable.MinimalDrumLayout = Layout
end