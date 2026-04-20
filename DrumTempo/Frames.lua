-------------------------------------------------------------------------------
-- DrumTempo - Frames (v8.0 - Persistent Icon Caching)
-------------------------------------------------------------------------------
local addonName, addonTable = ...
local DrumTempo = DrumTempo or addonTable.Core 
local table_insert = table.insert

DrumTempo.frames = DrumTempo.frames or {}

-- Simple FontString creator using direct parenting
local function CreateFS(parent, size, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont("Fonts\\FRIZQT__.TTF", size or 10, "OUTLINE")
    fs:SetJustifyH(justify or "CENTER")
    fs:SetTextColor(1, 1, 1, 1)
    fs:SetShadowOffset(1, -1)
    return fs
end

function DrumTempo:CreateSingleFrame(framename)
    local Drum = {}
    local db = DrumTempo.db.profile
    
    -- 1. Main Button
    local btn = CreateFrame("Button", "PD_Frame_" .. framename, UIParent, "SecureActionButtonTemplate, BackdropTemplate")
    btn:SetSize(40, 40)
    btn:SetFrameStrata("MEDIUM")
    btn:SetClampedToScreen(true)
    btn:SetMovable(true)
    btn:SetScale(db.scale or 1)
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetAttribute("type", "item")

    btn.texture = btn:CreateTexture(nil, "ARTWORK")
    btn.texture:SetAllPoints()
    
    -- 2. Cooldown Frame
    btn.cd = CreateFrame("Cooldown", btn:GetName() .. "Cooldown", btn, "CooldownFrameTemplate")
    btn.cd:SetAllPoints()
    btn.cd:SetHideCountdownNumbers(true)

    -- 3. Text Elements
    btn.toptext = CreateFS(btn, db.topsize or 10, "CENTER")
    btn.toptext:SetPoint("BOTTOM", btn, "TOP", 0, 2)
    
    btn.centertext = CreateFS(btn, db.centersize or 15, "CENTER")
    btn.centertext:SetPoint("CENTER", btn, "CENTER", 0, 0)

    btn.bottomtext = CreateFS(btn, db.centersize or 14, "CENTER")
    btn.bottomtext:SetPoint("TOP", btn, "BOTTOM", 0, -2)
    btn.bottomtext:SetTextColor(1, 0.2, 0.2) -- Red for lockout timer

    btn.count = CreateFS(btn, db.countsize or 12, "RIGHT")
    btn.count:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    btn.count:SetTextColor(1, 1, 0)

    -- 4. Tooltip Logic
    btn:SetScript("OnEnter", function(self)
        local item = self:GetAttribute("item")
        if item then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(item)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- 5. Movement Anchor
    local anchor = CreateFrame("Frame", btn:GetName() .. "Anchor", btn, "BackdropTemplate")
    anchor:SetAllPoints(btn)
    anchor:SetFrameStrata("HIGH")
    anchor:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    anchor:SetBackdropColor(0, 1, 0, 0.4)
    anchor:Hide()

    anchor:EnableMouse(true)
    anchor:RegisterForDrag("LeftButton")
    anchor:SetScript("OnDragStart", function() btn:StartMoving() end)
    anchor:SetScript("OnDragStop", function() 
        btn:StopMovingOrSizing() 
        Drum:SavePos() 
    end)

    Drum.mainframe  = btn
    Drum.bottomtext = btn.bottomtext
    Drum.toptext    = btn.toptext

    function Drum:Lock()   anchor:Hide() end
    function Drum:Unlock() anchor:Show() end

    function Drum:SavePos()
        local point, _, relPoint, x, y = btn:GetPoint()
        local db = DrumTempo.db.profile
        db.x, db.y, db.point, db.relPoint = x, y, point, relPoint
    end

    function Drum:LoadPos()
        local db = DrumTempo.db.profile
        if db.x then
            btn:ClearAllPoints()
            btn:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
        else
            btn:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    end

    function Drum:SetItem(itemID)
        if InCombatLockdown() or not itemID then return end
        
        if not btn:GetScript("OnUpdate") then
            btn:SetAttribute("item", "item:" .. itemID)
        end

        local function RefreshIcon()
            local _, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(itemID)
            if itemTexture then
                btn.texture:SetTexture(itemTexture)
                return true
            end
            return false
        end

        -- If data is missing, request it and wait for the event
        if not RefreshIcon() then
            btn.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            
            -- Force a cache request by querying a hidden tooltip
            local scanner = _G["DrumTempoScanTooltip"] or CreateFrame("GameTooltip", "DrumTempoScanTooltip", nil, "GameTooltipTemplate")
            scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
            scanner:SetHyperlink("item:" .. itemID)

            -- Retry mechanism for high-latency or cold-cache logins
            local retries = 0
            local function AttemptRetry()
                if not RefreshIcon() and retries < 5 then
                    retries = retries + 1
                    C_Timer.After(1, AttemptRetry)
                end
            end
            AttemptRetry()

            btn:SetScript("OnEvent", function(self, event, id)
                if id == itemID and RefreshIcon() then
                    self:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
                end
            end)
            btn:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        end
    end

    function Drum:SetCooldown(drum) 
        btn.cd:SetCooldown(GetTime(), drum.duration or 30)
    end
    
    function Drum:SetLockout(duration)
        local startTime = GetTime()
        local lockoutDuration = duration or 120
        
        if btn.texture then btn.texture:SetDesaturated(true) end
        if not InCombatLockdown() then btn:SetAttribute("item", nil) end

        btn:SetScript("OnUpdate", function(self, elapsed)
            local timeLeft = (startTime + lockoutDuration) - GetTime()
            
            if timeLeft <= 0 then
                self:SetScript("OnUpdate", nil)
                btn.bottomtext:SetText("")
                btn.toptext:SetText("") 
                if btn.texture then btn.texture:SetDesaturated(false) end
                if not InCombatLockdown() then
                    btn:SetAttribute("item", "item:" .. DrumTempo.db.profile.drumwatched)
                end
            else
                local minutes = math.floor(timeLeft / 60)
                local seconds = math.floor(timeLeft % 60)
                btn.bottomtext:SetText(string.format("%d:%02d", minutes, seconds))
            end
        end)
    end
    
    function Drum:SetItemCount(count)
        local val = tonumber(count) or 0
        if val > 0 then btn.count:SetText(val); btn.count:Show() else btn.count:Hide() end
    end

    function Drum:SetTopText(txt) btn.toptext:SetText(txt or "") end

    return Drum
end

function DrumTempo:GetSingleFrame(framename)
    for _, f in pairs(self.frames) do
        if f.mainframe:GetName() == "PD_Frame_" .. framename then return f end
    end
    local frame = self:CreateSingleFrame(framename)
    table_insert(self.frames, frame)
    self:ResetFrame(frame)
    return frame
end

function DrumTempo:ResetFrame(Drum)
    Drum.mainframe:Show()
    Drum:SetItem(self.db.profile.drumwatched)
    Drum:LoadPos()
    if self.db.profile.locked then Drum:Lock() else Drum:Unlock() end
end

function DrumTempo:ReleaseFrame(frame)
    if frame and frame.mainframe then
        frame.mainframe:Hide()
        frame.mainframe:SetScript("OnUpdate", nil)
    end
end