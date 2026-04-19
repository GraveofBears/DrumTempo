-------------------------------------------------------------------------------
-- DrumTempo - Main Addon File (v7.1 - Name Persistence Sync)
-------------------------------------------------------------------------------
local addonName, addonTable = ...
local DrumTempo = LibStub("AceAddon-3.0"):NewAddon("DrumTempo", 
    "AceEvent-3.0", 
    "AceConsole-3.0", 
    "AceTimer-3.0"
)

addonTable.Core = DrumTempo
_G["DrumTempo"] = DrumTempo 

DrumTempo.version = "7.1"
DrumTempo.Layouts = {}
DrumTempo.Layout  = nil
DrumTempo.frames  = DrumTempo.frames or {} 

-------------------------------------------------------------------------------
-- Database Defaults
-------------------------------------------------------------------------------
local DB_DEFAULTS = {
    profile = {
        layout        = "Simple Drum",
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
    
    if addonTable.SimpleDrumLayout then
        self:RegisterLayout(addonTable.SimpleDrumLayout)
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
    
    self:SetAlpha()
end

-------------------------------------------------------------------------------
-- Drum Detection & Lockout Logic
-------------------------------------------------------------------------------
function DrumTempo:COMBAT_LOG_EVENT_UNFILTERED()
    local _, subevent, _, _, sourceName, _, _, destGUID, _, _, _, spellId = CombatLogGetCurrentEventInfo()

    -- 1. VISUAL: Drum Cast Success
    if subevent == "SPELL_CAST_SUCCESS" then
        local drum = self:GetDrumBySpellID(spellId)
        if drum then
            local name = self:Ambiguate(sourceName)
            
            -- Update layout (Buff duration visual)
            if self.Layout and self.Layout.Drummed then
                self.Layout:Drummed(drum, name)
            end

            -- If YOU cast it, trigger the 120s timer logic
            if name == UnitName("player") then
                for _, frame in pairs(self.frames) do
                    if frame.SetLockout then 
                        frame:SetLockout(120) 
                    end
                end

                -- Party Announcement
                if self.db.profile.announceparty and GetNumGroupMembers() > 0 then
                    local itemlink = select(2, GetItemInfo(drum.item))
                    local channel = IsInRaid() and "RAID" or "PARTY"
                    SendChatMessage("++ " .. (itemlink or "Drums") .. " used!", channel)
                end
            end
        end
    end

    -- 2. LOCKOUT: Tinnitus (SpellID: 29519)
    if destGUID == UnitGUID("player") and spellId == 29519 then
        if subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" then
            for _, frame in pairs(self.frames) do
                if frame.SetLockout then
                    frame:SetLockout(120) 
                end
            end
        elseif subevent == "SPELL_AURA_REMOVED" then
            -- Tinnitus gone: Clear timers AND names
            for _, frame in pairs(self.frames) do
                if frame.mainframe then
                    frame.mainframe:SetScript("OnUpdate", nil)
                    
                    if frame.bottomtext then frame.bottomtext:SetText("") end
                    if frame.toptext then frame.toptext:SetText("") end -- Fix: Clear name now
                    
                    if frame.mainframe.texture then 
                        frame.mainframe.texture:SetDesaturated(false) 
                    end
                    
                    if not InCombatLockdown() then
                        frame:SetItem(self.db.profile.drumwatched)
                    end
                end
            end
        end
    end
end

function DrumTempo:PLAYER_REGEN_ENABLED()
    -- Recovery check
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
    for _, v in pairs(data) do
        if v.spell == spellID then return v end
    end
    return nil
end

function DrumTempo:GetDrumByItemID(itemID)
    local data = self.Drums or addonTable.DrumsData
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
    self.Layout = self.Layouts[name] or self.Layouts["Simple Drum"]
    if self.Layout and self.Layout.Load then 
        self.Layout:Load() 
    end
end

function DrumTempo:ReleaseFrame(frame)
    if frame and frame.mainframe then
        frame.mainframe:Hide()
        frame.mainframe:SetScript("OnUpdate", nil)
    end
end