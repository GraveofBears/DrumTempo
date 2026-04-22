-------------------------------------------------------------------------------
-- DrumTempo - Main Addon File (v8.0)
-------------------------------------------------------------------------------
local addonName, addonTable = ...
local DrumTempo = LibStub("AceAddon-3.0"):NewAddon("DrumTempo", 
    "AceEvent-3.0", 
    "AceConsole-3.0", 
    "AceTimer-3.0"
)

addonTable.Core = DrumTempo
_G["DrumTempo"] = DrumTempo 

DrumTempo.version = "8.0"
DrumTempo.Layouts = {}
DrumTempo.Layout  = nil
DrumTempo.frames  = DrumTempo.frames or {} 

-------------------------------------------------------------------------------
-- Database Defaults
-------------------------------------------------------------------------------
local DB_DEFAULTS = {
    profile = {
        layout        = "Default Drum",
        drumwatched   = 29529, -- Greater Drums of Battle
        locked        = true,
        scale         = 1,
        announceparty = true,  -- party announcement (default on)
        announceraid  = false, -- raid announcement (default off)
        Hide          = false,
        topfont       = "Fonts\\FRIZQT__.TTF",
        centerfont    = "Fonts\\FRIZQT__.TTF",
        countfont     = "Fonts\\FRIZQT__.TTF",
        topsize       = 10,
        centersize    = 16,
        countsize     = 12,
        -- DefaultDrum visibility toggles
        showDrummerName = true,
        showDebuffTimer = true,
        showChargeCount = true,
        showReadyGlow   = true,
    }
}

-------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------
function DrumTempo:OnInitialize()
    -- Initialize Database
    self.db = LibStub("AceDB-3.0"):New("DrumTempoDB", DB_DEFAULTS, true)
    
    -- Load Drum Data from DrumData.lua
    if addonTable.DrumsData then
        self.Drums = addonTable.DrumsData
    end

    -- Migration: ensure new profile keys exist for players who logged in before
    -- these defaults were added (AceDB only applies defaults to missing saved vars
    -- on a completely fresh profile, not to existing ones).
    local p = self.db.profile
    if p.showDrummerName == nil then p.showDrummerName = true end
    if p.showDebuffTimer == nil then p.showDebuffTimer = true end
    if p.showChargeCount == nil then p.showChargeCount = true end
    if p.showReadyGlow   == nil then p.showReadyGlow   = true end
    if p.announceraid    == nil then p.announceraid    = false end
    
    -- Register Layouts that loaded before the Core
    if addonTable.DefaultDrumLayout then
        self:RegisterLayout(addonTable.DefaultDrumLayout)
    end    
    
    if addonTable.MinimalDrumLayout then
        self:RegisterLayout(addonTable.MinimalDrumLayout)
    end    

    -- Initialize Options
    if self.SetupOptions then 
        self:SetupOptions() 
    end
end

function DrumTempo:OnEnable()
    -- Apply the saved or default layout
    self:SwitchLayout(self.db.profile.layout)
    
    -- Register Game Events
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

    -- 1. VISUAL: Drum Cast Success (Any player in group)
    if subevent == "SPELL_CAST_SUCCESS" then
        local drum = self:GetDrumBySpellID(spellId)
        if drum then
            local name = self:Ambiguate(sourceName)
            
            -- Update layout visuals and drummer name display for everyone
            if self.Layout and self.Layout.Drummed then
                self.Layout:Drummed(drum, name)
            end

            -- Party/Raid Announcement (only when YOU cast)
            if name == UnitName("player") then
                local itemlink = select(2, GetItemInfo(drum.item))
                local msg = "++ " .. (itemlink or "Drums") .. " used!"
                if IsInRaid() then
                    if self.db.profile.announceraid  then SendChatMessage(msg, "RAID")  end
                    if self.db.profile.announceparty then SendChatMessage(msg, "PARTY") end
                elseif GetNumGroupMembers() > 0 then
                    if self.db.profile.announceparty then SendChatMessage(msg, "PARTY") end
                end
            end
        end
    end

    -- 2. LOCKOUT: Tinnitus applied to YOU (SpellID: 29519)
    -- This fires whether YOU drummed or SOMEONE ELSE drummed.
    -- This is the single source of truth for the lockout state.
    if destGUID == UnitGUID("player") and spellId == 29519 then
        if subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" then
            for _, frame in pairs(self.frames) do
                if frame.SetLockout then
                    frame:SetLockout(120)
                end
            end
        elseif subevent == "SPELL_AURA_REMOVED" then
            -- Tinnitus gone: Clear timers, names, and desaturation
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
            
            -- Refresh Layout Glow/Visuals immediately after lockout
            if self.Layout and self.Layout.UpdateCount then
                self.Layout:UpdateCount()
            end
        end
    end
end

function DrumTempo:PLAYER_REGEN_ENABLED()
    -- Out of combat recovery: ensure icons are restored if they were stuck
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
    -- Hide frame if user has "Hide when Solo" enabled
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

    -- Change the fallback to "Default Drum"
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