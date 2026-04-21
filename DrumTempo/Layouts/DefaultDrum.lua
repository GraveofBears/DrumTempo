-------------------------------------------------------------------------------
-- DrumTempo - Default Drum Layout (v8.2)
-------------------------------------------------------------------------------
local addonName, addonTable = ...

local DrumTempo = addonTable.Core or LibStub("AceAddon-3.0"):GetAddon("DrumTempo", true)

local Layout = {
    name      = "Default Drum",
    frame     = nil,
    lastState = nil,   -- tracks "ready" vs "lockout" for glow trigger
    isPulsing = false, -- tracks whether the 5s warning pulse is active
}

local TINNITUS_ID = 29519

-------------------------------------------------------------------------------
-- LibCustomGlow helper (optional dependency, same pattern as MinimalDrum)
-------------------------------------------------------------------------------
local function GetLCG()
    return LibStub("LibCustomGlow-1.0", true)
end

local function TriggerReadyShine(frame)
    local LCG = GetLCG()
    if not LCG or not frame then return end
    LCG.PixelGlow_Stop(frame)
    LCG.AutoCastGlow_Stop(frame)
    LCG.ButtonGlow_Start(frame)
    C_Timer.After(2.5, function()
        if frame then LCG.ButtonGlow_Stop(frame) end
    end)
end

-------------------------------------------------------------------------------
-- Debuff helpers
-------------------------------------------------------------------------------
local function GetTinnitusRemaining()
    for i = 1, 40 do
        local name, _, _, _, _, expirationTime, _, _, _, spellId = UnitDebuff("player", i)
        if not name then break end
        if spellId == TINNITUS_ID or name == "Tinnitus" then
            local rem = expirationTime - GetTime()
            return rem > 0 and rem or 0
        end
    end
    return 0
end

-------------------------------------------------------------------------------
-- Visibility helpers (called from Options setters and on layout load)
-------------------------------------------------------------------------------
function Layout:ApplyVisibility()
    if not self.frame then return end
    local db = DrumTempo.db.profile

    -- Drummer name (toptext)
    if self.frame.toptext then
        if db.showDrummerName then self.frame.toptext:Show()
        else                       self.frame.toptext:Hide(); self.frame.toptext:SetText("") end
    end

    -- Debuff timer (bottomtext)
    if self.frame.bottomtext then
        if db.showDebuffTimer then self.frame.bottomtext:Show()
        else                       self.frame.bottomtext:Hide(); self.frame.bottomtext:SetText("") end
    end

    -- Charge count widget lives on mainframe
    if self.frame.mainframe and self.frame.mainframe.count then
        if db.showChargeCount then self.frame.mainframe.count:Show()
        else                       self.frame.mainframe.count:Hide() end
    end
end

-------------------------------------------------------------------------------
-- Debuff countdown (OnUpdate loop writing to bottomtext)
-------------------------------------------------------------------------------
function Layout:StartDebuffTimer()
    if not self.frame or not self.frame.mainframe then return end
    local btn = self.frame.mainframe

    btn:SetScript("OnUpdate", function(self, elapsed)
        self.timer = (self.timer or 0) + elapsed
        if self.timer < 0.1 then return end
        self.timer = 0

        local rem = GetTinnitusRemaining()
        local LCG = GetLCG()

        -- 5-second warning pulse
        if rem > 0 and rem <= 5 then
            if not Layout.isPulsing then
                Layout.isPulsing = true
                if LCG then LCG.AutoCastGlow_Start(btn, {1, 1, 1, 0.5}) end
            end
        elseif Layout.isPulsing then
            Layout.isPulsing = false
            if LCG then LCG.AutoCastGlow_Stop(btn) end
        end

        if rem > 0 then
            -- Keep icon grey while debuff is active
            if btn.texture then btn.texture:SetDesaturated(true) end
            -- Only write text when the layer is shown
            if DrumTempo.db.profile.showDebuffTimer then
                local minutes = math.floor(rem / 60)
                local seconds = math.floor(rem % 60)
                btn.bottomtext:SetText(string.format("%d:%02d", minutes, seconds))
            end
        else
            -- Debuff expired — restore color, clean up, fire ready glow
            btn:SetScript("OnUpdate", nil)
            btn.bottomtext:SetText("")
            Layout.isPulsing = false
            if LCG then LCG.AutoCastGlow_Stop(btn) end

            -- Restore color now that debuff is gone
            if btn.texture then btn.texture:SetDesaturated(false) end

            if DrumTempo.db.profile.showReadyGlow and Layout.lastState == "lockout" then
                TriggerReadyShine(btn)
            end
            Layout.lastState = "ready"

            Layout:UpdateCount()
        end
    end)
end

-------------------------------------------------------------------------------
-- Visual Logic
-------------------------------------------------------------------------------
function Layout:Drummed(drum, drummer)
    if not drum or not self.frame or not self.frame.mainframe then return end

    -- 1. 30s visual cooldown swipe
    self.frame:SetCooldown(drum)

    -- 2. Drummer name (respects visibility toggle)
    if DrumTempo.db.profile.showDrummerName then
        local name = DrumTempo:Ambiguate(drummer)
        self.frame:SetTopText(name)
    end

    -- 3. Stop any existing ready glow immediately
    local LCG = GetLCG()
    if LCG and self.frame.mainframe then
        LCG.ButtonGlow_Stop(self.frame.mainframe)
        LCG.AutoCastGlow_Stop(self.frame.mainframe)
    end

    -- 4. Grey out immediately so the icon reflects lockout state right away
    if self.frame.mainframe.texture then
        self.frame.mainframe.texture:SetDesaturated(true)
    end

    self.lastState = "lockout"
    self.isPulsing = false

    -- 5. Start red debuff countdown (short delay so Tinnitus has time to land)
    C_Timer.After(0.3, function()
        if self.frame and self.frame.mainframe then
            self:StartDebuffTimer()
        end
    end)

    self:UpdateCount()
end

function Layout:UpdateCount()
    if not self.frame or not self.frame.mainframe then return end
    if not DrumTempo.db then return end

    local itemID = DrumTempo.db.profile.drumwatched
    local count  = DrumTempo:GetDrumCount(itemID)

    -- Passing 0 causes SetItemCount to hide the label naturally
    self.frame:SetItemCount(DrumTempo.db.profile.showChargeCount and count or 0)
end

-------------------------------------------------------------------------------
-- Layout Management
-------------------------------------------------------------------------------
function Layout:Load()
    self.frame = DrumTempo:GetSingleFrame("DefaultDrum")

    if self.frame then
        -- Tell Frames.lua not to overwrite our OnUpdate with its own lockout script
        self.frame.selfManagesLockout = true

        -- Apply saved visibility toggles before showing anything
        self:ApplyVisibility()

        C_Timer.After(0.5, function()
            if self.frame and self.frame.mainframe then
                self:UpdateCount()
                self.frame:SetItem(DrumTempo.db.profile.drumwatched)
                self.frame:LoadPos()
                self.frame.mainframe:Show()

                -- Resume timer if we reloaded mid-debuff
                if GetTinnitusRemaining() > 0 then
                    self.lastState = "lockout"
                    self:StartDebuffTimer()
                else
                    self.lastState = "ready"
                end
            end
        end)

        self.frame.mainframe:RegisterEvent("BAG_UPDATE")
        self.frame.mainframe:RegisterEvent("UNIT_AURA")
        self.frame.mainframe:SetScript("OnEvent", function(s, event, unit)
            if event == "BAG_UPDATE" then
                self:UpdateCount()
            elseif event == "UNIT_AURA" and unit == "player" then
                self:UpdateCount()
                local rem = GetTinnitusRemaining()
                if rem > 0 and not s:GetScript("OnUpdate") then
                    self.lastState = "lockout"
                    self:StartDebuffTimer()
                end
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
            self.frame.mainframe:UnregisterEvent("BAG_UPDATE")
            self.frame.mainframe:UnregisterEvent("UNIT_AURA")
            self.frame.mainframe:SetScript("OnEvent", nil)
            if self.frame.mainframe.cooldown then
                self.frame.mainframe.cooldown:SetScript("OnCooldownDone", nil)
            end
        end

        DrumTempo:ReleaseFrame(self.frame)
        self.frame     = nil
        self.lastState = nil
        self.isPulsing = false
    end
end

function Layout:ShowFrame()
    if self.frame and self.frame.mainframe then self.frame.mainframe:Show() end
end

function Layout:HideFrame()
    if self.frame and self.frame.mainframe then self.frame.mainframe:Hide() end
end

-------------------------------------------------------------------------------
-- Register with Core
-------------------------------------------------------------------------------
if DrumTempo and DrumTempo.RegisterLayout then
    DrumTempo:RegisterLayout(Layout)
else
    addonTable.DefaultDrumLayout = Layout
end