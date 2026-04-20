-------------------------------------------------------------------------------
-- DrumTempo - Main Addon File (v8.1 - Tinnitus Fix)
-------------------------------------------------------------------------------
local addonName, addonTable = ...
local DrumTempo = LibStub("AceAddon-3.0"):NewAddon("DrumTempo", 
    "AceEvent-3.0", 
    "AceConsole-3.0", 
    "AceTimer-3.0"
)

addonTable.Core = DrumTempo
_G["DrumTempo"] = DrumTempo 

DrumTempo.version = "8.1"
DrumTempo.Layouts = {}
DrumTempo.Layout  = nil
DrumTempo.frames  = DrumTempo.frames or {} 

-- ✅ NEW: Authoritative Tinnitus State
DrumTempo.hasTinnitus = false
DrumTempo.tinnitusEndTime = 0

-------------------------------------------------------------------------------
-- Database Defaults
-------------------------------------------------------------------------------
local DB_DEFAULTS = {
    profile = {
        layout        = "Default Drum",
        drumwatched   = 29529,
        locked        = true,
        scale         = 1,
        announceparty = true, 
        Hide          = false,
        topfont       = "Fonts\\FRIZQT__.TTF",
        centerfont    = "Fonts\\FRIZQT__.TTF",
        countfont     = "Fonts\\FRIZQT__.TTF",
        topsize       = 10,
        centersize    = 16,
        countsize     = 12,
    }
}

-------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------
function DrumTempo:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("DrumTempoDB", DB_DEFAULTS, true)
    
    if addonTable.DrumsData then
        self.Drums = addonTable.DrumsData
    end
    
    if addonTable.DefaultDrumLayout then
        self:RegisterLayout(addonTable.DefaultDrumLayout)
    end    
    
    if addonTable.MinimalDrumLayout then
        self:RegisterLayout(addonTable.MinimalDrumLayout)
    end    

    if self.SetupOptions then 
        self:SetupOptions() 
    end
end

function DrumTempo:OnEnable()
    self:SwitchLayout(self.db.profile.layout)
    
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "SetAlpha")

    -- ✅ NEW: Aura + Safety Polling
    self:RegisterEvent("UNIT_AURA")
    self:ScheduleRepeatingTimer(function()
        self:CheckTinnitus()
    end, 0.5)

    self:SetAlpha()
end

-------------------------------------------------------------------------------
-- ✅ NEW: AUTHORITATIVE TINNITUS CHECK
-------------------------------------------------------------------------------
function DrumTempo:CheckTinnitus()
    local name, _, _, _, duration, expirationTime = AuraUtil.FindAuraByName("Tinnitus", "player")

    if name and expirationTime then
        local remaining = expirationTime - GetTime()

        if not self.hasTinnitus or math.abs((self.tinnitusEndTime or 0) - expirationTime) > 0.3 then
            self.hasTinnitus = true
            self.tinnitusEndTime = expirationTime

            for _, frame in pairs(self.frames) do
                if frame.SetLockout then
                    frame:SetLockout(remaining)
                end
            end
        end
    else
        if self.hasTinnitus then
            self.hasTinnitus = false
            self.tinnitusEndTime = 0

            for _, frame in pairs(self.frames) do
                if frame.mainframe then
                    frame.mainframe:SetScript("OnUpdate", nil)

                    if frame.bottomtext then frame.bottomtext:SetText("") end
                    if frame.toptext then frame.toptext:SetText("") end

                    if frame.mainframe.texture then
                        frame.mainframe.texture:SetDesaturated(false)
                        frame.mainframe.texture:SetAlpha(1)
                    end

                    if not InCombatLockdown() then
                        frame:SetItem(self.db.profile.drumwatched)
                    end
                end
            end

            if self.Layout and self.Layout.UpdateCount then
                self.Layout:UpdateCount()
            end
        end
    end
end

function DrumTempo:UNIT_AURA(unit)
    if unit == "player" then
        self:CheckTinnitus()
    end
end

-------------------------------------------------------------------------------
-- Drum Detection & Lockout Logic
-------------------------------------------------------------------------------
function DrumTempo:COMBAT_LOG_EVENT_UNFILTERED()
    local _, subevent, _, _, sourceName, _, _, destGUID, _, _, _, spellId = CombatLogGetCurrentEventInfo()

    -- VISUAL: Drum Cast
    if subevent == "SPELL_CAST_SUCCESS" then
        local drum = self:GetDrumBySpellID(spellId)
        if drum then
            local name = self:Ambiguate(sourceName)
            
            if self.Layout and self.Layout.Drummed then
                self.Layout:Drummed(drum, name)
            end

            -- If YOU cast it
            if name == UnitName("player") then
                for _, frame in pairs(self.frames) do
                    if frame.SetLockout then 
                        frame:SetLockout(120) 
                    end
                end

                if self.db.profile.announceparty and GetNumGroupMembers() > 0 then
                    local itemlink = select(2, GetItemInfo(drum.item))
                    local channel = IsInRaid() and "RAID" or "PARTY"
                    SendChatMessage("++ " .. (itemlink or "Drums") .. " used!", channel)
                end
            end
        end
    end

    -- Keep original Tinnitus handling (harmless fallback)
    if destGUID == UnitGUID("player") and spellId == 29519 then
        if subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" then
            for _, frame in pairs(self.frames) do
                if frame.SetLockout then
                    frame:SetLockout(120) 
                end
            end
        elseif subevent == "SPELL_AURA_REMOVED" then
            for _, frame in pairs(self.frames) do
                if frame.mainframe then
                    frame.mainframe:SetScript("OnUpdate", nil)
                    if frame.bottomtext then frame.bottomtext:SetText("") end
                    if frame.toptext then frame.toptext:SetText("") end
                    if frame.mainframe.texture then 
                        frame.mainframe.texture:SetDesaturated(false) 
                    end
                    if not InCombatLockdown() then
                        frame:SetItem(self.db.profile.drumwatched)
                    end
                end
            end

            if self.Layout and self.Layout.UpdateCount then
                self.Layout:UpdateCount()
            end
        end
    end

    -- ✅ CRITICAL: Always verify actual state
    self:CheckTinnitus()
end

function DrumTempo:PLAYER_REGEN_ENABLED()
    for _, frame in pairs(self.frames) do
        if frame and frame.mainframe then
            if not frame.mainframe:GetScript("OnUpdate") then
                if not InCombatLockdown() then
                    frame:SetItem(self.db.profile.drumwatched)
                end
                if frame.mainframe.texture then
                    frame.mainframe.texture:SetDesaturated(false)
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------
function DrumTempo:GetDrumCount(itemID)
    return GetItemCount(itemID, false, true) or 0
end

function DrumTempo:GetDrumBySpellID(spellID)
    local data = self.Drums or addonTable.DrumsData
    if not data then return nil end
    for _, v in pairs(data) do
        if v.spell == spellID then return v end
    end
    return nil
end

function DrumTempo:GetDrumByItemID(itemID)
    local data = self.Drums or addonTable.DrumsData
    if not data then return nil end
    for _, v in pairs(data) do
        if v.item == itemID then return v end
    end
    return nil
end

function DrumTempo:Ambiguate(name)
    if not name then return "" end
    return (strsplit("-", name))
end

function DrumTempo:SetAlpha()
    if not self.Layout then return end
    if self.db.profile.Hide and GetNumGroupMembers() == 0 then
        self.Layout:HideFrame()
    else
        self.Layout:ShowFrame()
    end
end

-------------------------------------------------------------------------------
-- Layout API
-------------------------------------------------------------------------------
function DrumTempo:RegisterLayout(data)
    if not data or not data.name then return end
    self.Layouts[data.name] = data
end

function DrumTempo:SwitchLayout(name)
    if self.Layout and self.Layout.Unload then 
        self.Layout:Unload() 
    end

    self.Layout = self.Layouts[name] or self.Layouts["Default Drum"]

    if self.Layout and self.Layout.Load then 
        self.Layout:Load() 
    end
    self:SetAlpha()
end

function DrumTempo:ReleaseFrame(frame)
    if frame and frame.mainframe then
        frame.mainframe:Hide()
        frame.mainframe:SetScript("OnUpdate", nil)
    end
end