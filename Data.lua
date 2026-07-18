-- Data.lua
-- 所有常量、默认值、工具函数
local addonName, H = ...
if select(2, UnitClass("player")) ~= "HUNTER" then return end
if addonName == "HunterHelper" and not _G.HunterHelper then _G.HunterHelper = H end

-- ==========================================
-- 常量
-- ==========================================
H.CURRENT_VERSION = 305
H.COMM_PREFIX = "HH_VER_CHK"

H.CONST = {
    MAIN_BTN_SIZE = 38,
    MAIN_SPACING = 42,
    SUB_BTN_SIZE = 32,
    SUB_SPACING = 34,
    SUB_PADDING = 5,
    FLYOUT_HEIGHT = 40,
    MIN_WIDTH = 10,
    FEED_COOLDOWN = 20,
}

H.DB_DEFAULTS = {
    ASPECTS = {27044, 13163, 34074, 5118, 13159, 27045, 13161},
    TRAPS   = {14311, 13809, 27025, 27023, 34600},
    PET     = {883, 982, 27046, 6991, 1515, 2641, 14327, 1002, 1462, 5149},
}
H.PET_SPELL = { CALL = 883, REVIVE = 982, MEND = 27046, FEED = 6991, DISMISS = 2641, TRAINING = 5149 }
H.COMBAT_UNSAFE_PET = {
    [H.PET_SPELL.CALL] = true,
    [H.PET_SPELL.DISMISS] = true,
    [H.PET_SPELL.TRAINING] = true,
    [H.PET_SPELL.FEED] = true,
}

H.SpellCache = {}
H.SpellBaseNameToID = {}
H.TrapBaseNames = {}
H.AllModules = {}

-- ==========================================
-- 全局状态
-- ==========================================
H.trapLocked = false
H.trapLockedSpellID = nil
H.feedCooldownActive = false
H.feedCooldownEnd = 0
H.petHealExpiration = 0
H.pendingDefaultTrapID = nil
H.lastSelectedAspectID = nil
H._aspectScheduled = false
H._petManualOverride = false
H._petManualSpellID = nil
H._lastVersionBroadcast = 0
H._securePending = false
H._lastPetHappiness = nil
H._timerTasks = {}

-- ==========================================
-- 工具函数
-- ==========================================
local rankCache = {}

function H.StripRank(name)
    if not name then return nil end
    if rankCache[name] then return rankCache[name] end
    local pos = name:find("(", 1, true) or name:find("（", 1, true)
    local result = (pos and pos > 1) and name:sub(1, pos - 1):gsub("%s+$", "") or name
    rankCache[name] = result
    return result
end

function H.GetSpellData(spellID)
    if H.SpellCache[spellID] then
        return H.SpellCache[spellID].icon, H.SpellCache[spellID].name, H.SpellCache[spellID].base
    end
    local name = GetSpellInfo(spellID)
    if not name then return nil, nil, nil end
    local base = H.StripRank(name)
    local icon = select(3, GetSpellInfo(spellID)) or "Interface\\Icons\\INV_Misc_QuestionMark"
    H.SpellCache[spellID] = { icon = icon, name = name, base = base }
    return icon, name, base
end

function H.GetSpellIcon(spellID) return select(1, H.GetSpellData(spellID)) end
function H.GetSpellName(spellID) return select(2, H.GetSpellData(spellID)) end
function H.GetSpellBase(spellID) return select(3, H.GetSpellData(spellID)) end

function H.GetResolvedIcon(btn, spellID)
    if spellID == H.PET_SPELL.FEED then
        if btn and btn.category == "PET" then return H.GetSpellIcon(spellID) end
        if H.DB and H.DB.PetFoodID then
            local icon = select(10, GetItemInfo(H.DB.PetFoodID))
            if icon then return icon end
        end
    end
    return H.GetSpellIcon(spellID)
end

function H.BuildSpellCache()
    wipe(H.SpellCache)
    wipe(H.SpellBaseNameToID)
    wipe(H.TrapBaseNames)

    -- ★ 预加载核心技能
    H.GetSpellData(H.PET_SPELL.MEND)
    H.GetSpellData(H.PET_SPELL.FEED)
    H.GetSpellData(H.PET_SPELL.CALL)
    H.GetSpellData(H.PET_SPELL.REVIVE)

    if not GetNumSpellTabs then return end
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, numSpells = GetSpellTabInfo(tab)
        if offset and numSpells then
            for i = offset + 1, offset + numSpells do
                local spellName = GetSpellBookItemName(i, "spell")
                if spellName then
                    local base = H.StripRank(spellName)
                    local _, spellID = GetSpellBookItemInfo(i, "spell")
                    if type(spellID) == "number" then
                        local old = H.SpellBaseNameToID[base]
                        H.SpellBaseNameToID[base] = old and math.max(old, spellID) or spellID
                    end
                end
            end
        end
    end

    for _, id in ipairs(H.DB_DEFAULTS.TRAPS) do
        local base = H.GetSpellBase(id)
        if base then H.TrapBaseNames[base] = true end
    end
end

function H.IsLearned(id) return H.SpellBaseNameToID[H.GetSpellBase(id)] ~= nil end
function H.ResolveKnownSpellID(id) return H.SpellBaseNameToID[H.GetSpellBase(id)] or id end
function H.ResolveUsableSpellID(id)
    if not id then return nil end
    return H.ResolveKnownSpellID(id) or id
end

function H.FormatTime(expiration)
    if not expiration or expiration == 0 then return "" end
    local remain = expiration - GetTime()
    if remain <= 0 then return "" end
    local mins, secs = math.floor(remain / 60), math.floor(remain % 60)
    if mins > 0 then return string.format("%dm%02d", mins, secs) else return string.format("%ds", secs) end
end

-- ==========================================
-- 宠物工具
-- ==========================================
function H.IsPetAlive()
    if not UnitExists("pet") then return false end
    return (UnitHealth("pet") or 0) > 0
end

function H.UpdatePetHealAura()
    H.petHealExpiration = 0
    if not UnitExists("pet") then return end
    local healName = H.GetSpellBase(H.PET_SPELL.MEND)
    if not healName then return end
    for i = 1, 40 do
        local name, icon, count, dispelType, duration, expirationTime, source = UnitAura("pet", i, "HELPFUL")
        if not name then break end
        if source == "player" and H.StripRank(name) == healName then
            H.petHealExpiration = expirationTime or 0
            break
        end
    end
end

function H.UpdatePetHealDuration()
    local mod = H.AllModules and H.AllModules.PET
    if not mod or not mod.text then return end
    if H.petHealExpiration and H.petHealExpiration > GetTime() then
        mod.text:SetText(H.FormatTime(H.petHealExpiration))
        mod.text:Show()
    else
        mod.text:Hide()
    end
end

-- ==========================================
-- 视觉工具
-- ==========================================
function H.SetMainVisualAvailable(btn)
    if not btn or not btn.icon then return end
    btn.icon:SetDesaturated(false)
    btn.icon:SetVertexColor(1, 1, 1)
    btn:SetAlpha(1)
end

function H.SetMainVisualUnavailable(btn, spellID)
    if not btn or not btn.icon then return end
    if spellID then
        btn.icon:SetTexture(H.GetResolvedIcon(btn, spellID))
        btn.selectedSpellID = spellID
    end
    btn.icon:SetDesaturated(true)
    btn.icon:SetVertexColor(0.6, 0.6, 0.6)
    btn:SetAlpha(0.7)
    if btn.activeBorder then btn.activeBorder:Hide() end
end

function H.UpdateSubBorders(btn)
    if not btn or not btn.subButtons then return end
    for _, sub in ipairs(btn.subButtons) do
        if sub.activeBorder then
            sub.activeBorder:SetShown(sub.spellID == btn.selectedSpellID)
        end
    end
end

-- ==========================================
-- Secure 按钮管理
-- ==========================================
function H.ApplySpellToButton(btn, spellID)
    if not btn or not spellID then return false end
    local name = H.GetSpellName(spellID)
    if not name then return false end

    btn.selectedSpellID = spellID

    if btn.icon then
        btn.icon:SetTexture(H.GetResolvedIcon(btn, spellID))
    end

    if InCombatLockdown() then
        H._securePending = true
        return true
    end

    if spellID == H.PET_SPELL.FEED and H.DB and H.DB.PetFoodID and GetItemCount(H.DB.PetFoodID) > 0 then
        btn:SetAttribute("type", "macro")
        btn:SetAttribute("macrotext", "/cast " .. name .. "\n/use item:" .. H.DB.PetFoodID)
    else
        btn:SetAttribute("type", "spell")
        btn:SetAttribute("spell", name)
    end

    btn:SetAttribute("spellID", spellID)
    btn:SetAttribute("selectedSpell", name)
    btn:SetAttribute("selectedSpellID", spellID)
    return true
end

function H.ReapplySecureAttributes()
    if InCombatLockdown() then return end
    for _, cat in ipairs({"ASPECTS", "TRAPS", "PET"}) do
        local mod = H.AllModules[cat]
        if mod and mod.selectedSpellID then
            H.ApplySpellToButton(mod, mod.selectedSpellID)
        end
    end
end

-- ==========================================
-- 应用保存的选择
-- ==========================================
function H.ApplySavedSelections()
    if not H.DB or not H.DB.selected then return end
    for _, cat in ipairs({"ASPECTS", "TRAPS", "PET"}) do
        if H.DB.selected[cat] and H.AllModules[cat] then
            local id = H.ResolveUsableSpellID(H.DB.selected[cat])
            if id then
                H.ApplySpellToButton(H.AllModules[cat], id)
                H.UpdateSubBorders(H.AllModules[cat])
            end
        end
    end
end

-- ==========================================
-- 版本检查
-- ==========================================
function H.SendVersionCheck()
    local now = GetTime()
    if now - (H._lastVersionBroadcast or 0) < 30 then return end
    H._lastVersionBroadcast = now
    local channel = nil
    if IsInRaid() then channel = "RAID"
    elseif IsInGroup() then channel = "PARTY"
    elseif IsInGuild() then channel = "GUILD" end
    if channel then
        local SendMessage = C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
        if SendMessage then
            SendMessage(H.COMM_PREFIX, tostring(H.CURRENT_VERSION), channel)
        end
    end
end