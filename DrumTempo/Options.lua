-------------------------------------------------------------------------------
-- DrumTempo - Options (v8.4)
-------------------------------------------------------------------------------
local addonName, addonTable = ...
local DrumTempo = addonTable.Core or LibStub("AceAddon-3.0"):GetAddon("DrumTempo")
local SharedMedia = LibStub("LibSharedMedia-3.0", true)
local L = setmetatable({}, { __index = function(t, k) return k end })

-------------------------------------------------------------------------------
-- SharedMedia Helpers
-------------------------------------------------------------------------------
local function getFontValues()
    -- Always start with the system default to avoid empty menus
    local t = { ["Fonts\\FRIZQT__.TTF"] = "Friz Quadrata (Default)" }
    if SharedMedia then
        local mediaList = SharedMedia:List("font")
        for _, name in ipairs(mediaList) do 
            t[name] = name 
        end
    end
    return t
end

-------------------------------------------------------------------------------
-- Build Font Group
-------------------------------------------------------------------------------
local function makeFontGroup(displayName, order, fieldKey, sizeKey, yOffsetKey, frameKey)
    return {
        type = "group",
        name = L[displayName],
        order = order,
        inline = true,
        args = {
            fontsize = {
                type = "range",
                name = L["Size"],
                order = 1,
                min = 8, max = 40, step = 1,
                get = function() return DrumTempo.db.profile[sizeKey] or 10 end,
                set = function(_, value)
                    DrumTempo.db.profile[sizeKey] = value
                    for _, v in pairs(DrumTempo.frames) do
                        local targetMap = { 
                            ["NbItemtext"] = "count", 
                            ["centertext"] = "bottomtext",
                            ["toptext"]    = "toptext" 
                        }
                        local target = targetMap[frameKey] or frameKey
                        local fontString = v[target] or (v.mainframe and v.mainframe[target])
                        
                        if fontString and fontString.SetFont then
                            local fontPath, _, flags = fontString:GetFont()
                            fontString:SetFont(fontPath, value, flags or "OUTLINE")
                        end
                    end
                end,
            },
            yoffset = {
                type = "range",
                name = L["Vertical Offset"],
                order = 2,
                min = -100, max = 100, step = 1,
                get = function() return DrumTempo.db.profile[yOffsetKey] or 0 end,
                set = function(_, value)
                    DrumTempo.db.profile[yOffsetKey] = value
                    for _, v in pairs(DrumTempo.frames) do
                        local targetMap = { 
                            ["NbItemtext"] = "count", 
                            ["centertext"] = "bottomtext",
                            ["toptext"]    = "toptext" 
                        }
                        local target = targetMap[frameKey] or frameKey
                        local fontString = v[target] or (v.mainframe and v.mainframe[target])
                        
                        if fontString then
                            local point, relativeTo, relativePoint, xOfs, _ = fontString:GetPoint()
                            fontString:SetPoint(point, relativeTo, relativePoint, xOfs, value)
                        end
                    end
                end,
            },
            fonttype = {
                type = "select",
                name = L["Type"],
                order = 3,
                values = getFontValues,
                get = function() return DrumTempo.db.profile[fieldKey] or "Fonts\\FRIZQT__.TTF" end,
                set = function(_, value)
                    local fontPath = (SharedMedia and SharedMedia:Fetch("font", value)) or "Fonts\\FRIZQT__.TTF"
                    DrumTempo.db.profile[fieldKey] = value
                    
                    for _, v in pairs(DrumTempo.frames) do
                        local targetMap = { 
                            ["NbItemtext"] = "count", 
                            ["centertext"] = "bottomtext",
                            ["toptext"]    = "toptext" 
                        }
                        local target = targetMap[frameKey] or frameKey
                        local fontString = v[target] or (v.mainframe and v.mainframe[target])
                        
                        if fontString and fontString.SetFont then
                            local _, size, flags = fontString:GetFont()
                            fontString:SetFont(fontPath, size, flags or "OUTLINE")
                        end
                    end
                end,
            },
        },
    }
end

-------------------------------------------------------------------------------
-- Main Options Table
-------------------------------------------------------------------------------
DrumTempo.options = {
    type = "group",
    name = "DrumTempo",
    handler = DrumTempo,
    childGroups = "tab", -- This forces General, Appearance, and Profiles into Tabs
    args = {
        general = {
            type = "group",
            name = L["General Settings"],
            order = 1,
            args = {
                lock = {
                    type = "toggle",
                    name = L["Lock Drums"],
                    order = 1,
                    get = function() return DrumTempo.db.profile.locked end,
                    set = function(_, value)
                        if InCombatLockdown() then return end
                        DrumTempo.db.profile.locked = value
                        for _, frame in pairs(DrumTempo.frames) do
                            if value then frame:Lock() else frame:Unlock() end
                        end
                    end,
                },
                announce = {
                    type = "toggle",
                    name = L["Announce in Party"],
                    order = 2,
                    get = function() return DrumTempo.db.profile.announceparty end,
                    set = function(_, value) DrumTempo.db.profile.announceparty = value end,
                },
                hidegrouped = {
                    type = "toggle",
                    name = L["Hide When Solo"],
                    order = 3,
                    get = function() return DrumTempo.db.profile.Hide end,
                    set = function(_, value) 
                        DrumTempo.db.profile.Hide = value 
                        DrumTempo:SetAlpha()
                    end,
                },
                layout = {
                    type = "select",
                    name = L["Layout Choice"],
                    order = 4,
                    values = function()
                        local t = {}
                        for k, v in pairs(DrumTempo.Layouts) do t[k] = k end
                        return t
                    end,
                    get = function() return DrumTempo.db.profile.layout end,
                    set = function(_, v) 
                        DrumTempo.db.profile.layout = v
                        DrumTempo:SwitchLayout(v) 
                    end,
                },
                drumwatched = {
                    type = "select",
                    name = L["Drums to Watch"],
                    order = 5,
                    values = function()
                        local t = {}
                        if DrumTempo.Drums then
                            for _, v in pairs(DrumTempo.Drums) do
                                local name = GetItemInfo(v.item) or ("Item: " .. v.item)
                                t[v.item] = name
                            end
                        end
                        return t
                    end,
                    get = function() return DrumTempo.db.profile.drumwatched end,
                    set = function(_, val)
                        if InCombatLockdown() then return end
                        DrumTempo.db.profile.drumwatched = val
                        for _, vf in pairs(DrumTempo.frames) do 
                            vf:SetItem(val) 
                        end
                        if DrumTempo.Layout and DrumTempo.Layout.UpdateCount then
                            DrumTempo.Layout:UpdateCount()
                        end
                    end,
                },
            },
        },
        appearance = {
            type = "group",
            name = L["Appearance"],
            order = 2,
            args = {
                scale = {
                    type = "range",
                    name = L["Icon Scale"],
                    order = 1,
                    min = 0.5, max = 3.0, step = 0.1,
                    get = function() return DrumTempo.db.profile.scale or 1 end,
                    set = function(_, value)
                        DrumTempo.db.profile.scale = value
                        for _, v in pairs(DrumTempo.frames) do
                            if v.mainframe then v.mainframe:SetScale(value) end
                        end
                    end,
                },
                fontHeader = {
                    type = "header",
                    name = L["Font & Positioning"],
                    order = 2,
                },
                toptext    = makeFontGroup("Drummer Name", 3, "topfont",    "topsize",    "topY",    "toptext"),
                centertext = makeFontGroup("Debuff Timer", 4, "centerfont", "centersize", "centerY", "centertext"),
                counttext  = makeFontGroup("Charges Count", 5, "countfont",  "countsize",  "countY",  "NbItemtext"),
            },
        },
    },
}

function DrumTempo:SetupOptions()
    -- Inject Profile options as a tab
    self.options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
    self.options.args.profiles.name = L["Profiles"]
    self.options.args.profiles.order = 3

    -- Register the main table
    LibStub("AceConfig-3.0"):RegisterOptionsTable("DrumTempo", self.options)
    
    -- Register only the main category to keep the sidebar clean
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("DrumTempo", "DrumTempo")

    self:RegisterChatCommand("drumtempo", "OpenOptions")
    self:RegisterChatCommand("dt", "OpenOptions")
end

function DrumTempo:OpenOptions()
    if Settings and Settings.OpenToCategory then
        Settings.OpenToCategory("DrumTempo")
    else
        InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
    end
end