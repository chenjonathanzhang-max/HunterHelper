-- Core.lua
-- 事件框架、UI 创建、初始化调度、Secure 处理器
local addonName, H = ...
if select(2, UnitClass("player")) ~= "HUNTER" then return end

if addonName == "HunterHelper" and not _G.HunterHelper then
    _G.HunterHelper = H
end

H.MainFrame = nil
H.TimerDriver = nil

-- ==========================================
-- 事件框架
-- ==========================================
H.eventFrame = CreateFrame("Frame")
local handlers = {}

function H:RegisterHandler(event, handler)
    if not handlers[event] then
        handlers[event] = {}
        H.eventFrame:RegisterEvent(event)
    end
    for _, h in ipairs(handlers[event]) do
        if h == handler then return end
    end
    table.insert(handlers[event], handler)
end

H.eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        H.DB = _G.HunterHelperDB or { selected = {}, pos = {"CENTER", "UIParent", "CENTER", 0, 0}, autoExpandInCombat = true }
        _G.HunterHelperDB = H.DB
        if H.DB.autoExpandInCombat == nil then H.DB.autoExpandInCombat = true end
        if H.DB.lastUpdateAlert == nil then H.DB.lastUpdateAlert = 0 end
    elseif event == "PLAYER_LOGIN" then
        -- ★ 防御性初始化
        if not H.DB then
            H.DB = _G.HunterHelperDB or { selected = {}, pos = {"CENTER", "UIParent", "CENTER", 0, 0}, autoExpandInCombat = true }
            _G.HunterHelperDB = H.DB
            if H.DB.autoExpandInCombat == nil then H.DB.autoExpandInCombat = true end
            if H.DB.lastUpdateAlert == nil then H.DB.lastUpdateAlert = 0 end
        end
        H.BuildSpellCache()
        H:CreateMainFrame()
        H:InitModules()
        H.MainFrame:Show()
    end

    if handlers[event] then
        for _, handler in ipairs(handlers[event]) do
            xpcall(handler, geterrorhandler(), ...)
        end
    end
end)

-- ==========================================
-- Timer
-- ==========================================
H.TimerDriver = CreateFrame("Frame")
H.TimerDriver:Hide()

function H:RegisterTimerTask(task)
    table.insert(H._timerTasks, task)
    H.TimerDriver:Show()
end

H.TimerDriver:SetScript("OnUpdate", function(self, elapsed)
    for _, task in ipairs(H._timerTasks or {}) do
        task(elapsed)
    end
    if H._aspectScheduled then
        H._aspectScheduled = false
        if H.RefreshAspect then H.RefreshAspect() end
    end
end)

-- ==========================================
-- UI 创建
-- ==========================================
function H:CreateMainFrame()
    H.MainFrame = CreateFrame("Frame", "HunterHelper_MainFrame", UIParent)
    H.MainFrame:SetSize(H.CONST.MAIN_BTN_SIZE, 130)
    H.MainFrame:SetMovable(true)
    H.MainFrame:EnableMouse(true)
    H.MainFrame:SetClampedToScreen(true)

    local p = H.DB.pos
    if p and #p >= 4 then
        H.MainFrame:SetPoint(p[1], UIParent, p[3], p[4], p[5] or 0)
    else
        H.MainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    local dragBar = CreateFrame("Frame", nil, H.MainFrame)
    dragBar:SetSize(H.CONST.MAIN_BTN_SIZE, 8)
    dragBar:SetPoint("TOP", H.MainFrame, "TOP", 0, 8)
    dragBar:EnableMouse(true)
    dragBar:RegisterForDrag("LeftButton")
    dragBar:SetAlpha(0)

    local dragTex = dragBar:CreateTexture(nil, "BACKGROUND")
    dragTex:SetAllPoints()
    dragTex:SetColorTexture(1, 1, 1, 0.5)

    H.MainFrame:SetScript("OnEnter", function() dragBar:SetAlpha(1) end)
    H.MainFrame:SetScript("OnLeave", function()
        if not dragBar:IsMouseOver() then dragBar:SetAlpha(0) end
    end)
    dragBar:SetScript("OnEnter", function() dragBar:SetAlpha(1) end)
    dragBar:SetScript("OnLeave", function()
        if not H.MainFrame:IsMouseOver() then dragBar:SetAlpha(0) end
    end)
    dragBar:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        H.MainFrame:StartMoving()
        H._dragging = true
    end)
    dragBar:SetScript("OnDragStop", function()
        H.MainFrame:StopMovingOrSizing()
        H._dragging = false
        if not InCombatLockdown() then
            local pt, _, rel, x, y = H.MainFrame:GetPoint()
            H.DB.pos = {pt, "UIParent", rel, x, y}
        end
    end)
end

function H:InitModules()
    H:CreateAspectModule(H.MainFrame, 0)
    H:CreateTrapModule(H.MainFrame, -H.CONST.MAIN_SPACING)
    H:CreatePetModule(H.MainFrame, -H.CONST.MAIN_SPACING * 2)
    H.ApplySavedSelections()
    H:RefreshAll()
end

function H:RefreshAll()
    if H.RefreshAspect then H.RefreshAspect() end
    if H.RefreshTrap then H.RefreshTrap() end
    if H.RefreshPet then H.RefreshPet() end
    H:RefreshAllCooldowns()
end

function H:RefreshAllCooldowns()
    for _, cat in ipairs({"ASPECTS", "TRAPS", "PET"}) do
        local mod = H.AllModules[cat]
        if mod then
            if mod.selectedSpellID then
                local s, d = GetSpellCooldown(mod.selectedSpellID)
                if s and d then mod.cd:SetCooldown(s, d) end
            end
            if mod.subButtons then
                for _, sub in ipairs(mod.subButtons) do
                    if sub.spellID then
                        local s, d = GetSpellCooldown(sub.spellID)
                        if s and d then sub.cd:SetCooldown(s, d) end
                    end
                end
            end
        end
    end
end

H:RegisterHandler("PLAYER_ENTERING_WORLD", function()
    if not InCombatLockdown() then H.SendVersionCheck() end
end)
H:RegisterHandler("GROUP_JOINED", function()
    if not InCombatLockdown() then H.SendVersionCheck() end
end)
H:RegisterHandler("RAID_ROSTER_UPDATE", function()
    if not InCombatLockdown() then H.SendVersionCheck() end
end)

H:RegisterHandler("PLAYER_REGEN_ENABLED", function()
    if H.ReapplySecureAttributes then H.ReapplySecureAttributes() end
    H._securePending = false
    H:RefreshAll()
end)

-- 拖拽途中进入战斗：立即结束拖拽，避免主框架在战斗中一直黏着光标
H:RegisterHandler("PLAYER_REGEN_DISABLED", function()
    if H._dragging then
        H.MainFrame:StopMovingOrSizing()
        H._dragging = false
    end
end)

H:RegisterHandler("CHAT_MSG_ADDON", function(prefix, text, channel, sender)
    if prefix == H.COMM_PREFIX and sender and sender ~= UnitName("player") then
        local remoteVer = tonumber(text)
        if remoteVer and remoteVer > H.CURRENT_VERSION then
            if not H.DB.lastUpdateAlert or H.DB.lastUpdateAlert < remoteVer then
                H.DB.lastUpdateAlert = remoteVer
                DEFAULT_CHAT_FRAME:AddMessage(
                    "|cffffff00[HunterHelper] " ..
                    string.format(H.L.UPDATE_FOUND, remoteVer) .. "|r"
                )
            end
        end
    end
end)

local RegisterPrefix = C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix or RegisterAddonMessagePrefix
if RegisterPrefix then RegisterPrefix(H.COMM_PREFIX) end

-- ==========================================
-- Secure 安全施法处理器
-- ==========================================
local function ApplyButtonStyling(btn, size)
    btn:SetHighlightTexture("Interface\\Buttons\\CheckButtonHilight")
    local hl = btn:GetHighlightTexture()
    hl:SetBlendMode("ADD")
    hl:SetAllPoints(btn)

    btn.activeBorder = btn:CreateTexture(nil, "OVERLAY")
    btn.activeBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    btn.activeBorder:SetBlendMode("ADD")
    btn.activeBorder:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.activeBorder:SetSize(size * 1.85, size * 1.85)
    btn.activeBorder:SetVertexColor(1, 0.8, 0)
    btn.activeBorder:Hide()
end

function H:CreateMainButton(parent, category, size)
    local btn = CreateFrame("Button", "HH_" .. category, parent,
        "SecureActionButtonTemplate, SecureHandlerEnterLeaveTemplate")
    btn:SetSize(size, size)
    btn:RegisterForClicks("AnyDown")
    btn.category = category
    btn.selectedSpellID = nil
    btn.subButtons = {}

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints()

    btn.cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cd:SetAllPoints()

    ApplyButtonStyling(btn, size)

    return btn
end

function H:CreateFlyout(btn)
    local flyout = CreateFrame("Frame", nil, btn, "SecureHandlerEnterLeaveTemplate, SecureHandlerStateTemplate")
    flyout:SetFrameStrata("LOW")
    flyout:SetPoint("LEFT", btn, "RIGHT", -6, 0)
    flyout:SetSize(100, 40)
    flyout:EnableMouse(true)
    flyout:Hide()

    flyout.bg = flyout:CreateTexture(nil, "BACKGROUND")
    flyout.bg:SetAllPoints()
    flyout.bg:SetColorTexture(0, 0, 0, 0)

    local bridge = CreateFrame("Frame", nil, btn, "SecureHandlerEnterLeaveTemplate")
    bridge:SetFrameStrata("LOW")
    bridge:SetPoint("LEFT", btn, "RIGHT", -8, 0)
    bridge:SetSize(48, 40)
    bridge:EnableMouse(true)
    bridge:SetAlpha(0)

    btn.flyout = flyout
    btn.bridge = bridge

    btn:SetFrameRef("flyout", flyout)
    btn:SetFrameRef("bridge", bridge)
    flyout:SetFrameRef("main", btn)
    flyout:SetFrameRef("bridge", bridge)
    bridge:SetFrameRef("main", btn)
    bridge:SetFrameRef("flyout", flyout)

    RegisterStateDriver(flyout, "combat", "[combat] combat; nocombat")
    flyout:SetAttribute("_onstate-combat", [[
        if newstate == "combat" then
            self:SetAttribute("in_combat", true)
            if self:GetAttribute("auto_expand") then self:Show() end
        else
            self:SetAttribute("in_combat", false)
            local main, b = self:GetFrameRef("main"), self:GetFrameRef("bridge")
            if not self:IsUnderMouse(true) and (not main or not main:IsUnderMouse(true)) and (not b or not b:IsUnderMouse(true)) then
                self:Hide()
            end
        end
    ]])
    flyout:SetAttribute("auto_expand", (H.DB and H.DB.autoExpandInCombat) and 1 or nil)

    btn:SetAttribute("_onenter", [[ self:GetFrameRef("flyout"):Show() ]])
    bridge:SetAttribute("_onenter", [[ self:GetFrameRef("flyout"):Show() ]])
    btn:SetAttribute("_onleave", [[
        local f, b = self:GetFrameRef("flyout"), self:GetFrameRef("bridge")
        if f and f:GetAttribute("in_combat") and f:GetAttribute("auto_expand") then return end
        if f and not f:IsUnderMouse(true) and (not b or not b:IsUnderMouse(true)) then f:Hide() end
    ]])
    flyout:SetAttribute("_onleave", [[
        if self:GetAttribute("in_combat") and self:GetAttribute("auto_expand") then return end
        local main, b = self:GetFrameRef("main"), self:GetFrameRef("bridge")
        if not self:IsUnderMouse(true) and (not main or not main:IsUnderMouse(true)) and (not b or not b:IsUnderMouse(true)) then self:Hide() end
    ]])
    bridge:SetAttribute("_onleave", [[
        local main, f = self:GetFrameRef("main"), self:GetFrameRef("flyout")
        if f and f:GetAttribute("in_combat") and f:GetAttribute("auto_expand") then return end
        if not self:IsUnderMouse(true) and (not main or not main:IsUnderMouse(true)) and (not f or not f:IsUnderMouse(true)) then f:Hide() end
    ]])

    return flyout, bridge
end

function H:CreateSubButton(flyout, mainBtn, size, spellID, isTrap)
    local sub = CreateFrame("Button", nil, flyout, "SecureActionButtonTemplate, SecureHandlerBaseTemplate")
    sub:SetSize(size, size)

    if isTrap then
        sub:RegisterForClicks("LeftButtonDown", "RightButtonDown")
    else
        sub:RegisterForClicks("AnyDown")
    end

    sub.icon = sub:CreateTexture(nil, "ARTWORK")
    sub.icon:SetAllPoints()
    sub.icon:SetTexture(H.GetResolvedIcon(sub, spellID))

    sub.cd = CreateFrame("Cooldown", nil, sub, "CooldownFrameTemplate")
    sub.cd:SetAllPoints()

    ApplyButtonStyling(sub, size)

    sub.mainButton = mainBtn
    sub:SetFrameRef("main", mainBtn)
    sub.spellID = spellID

    local spellName = H.GetSpellName(spellID)
    sub:SetAttribute("spellID", spellID)

    if isTrap then
        sub:SetAttribute("trapButton", true)
        sub:SetAttribute("type1", "spell")
        sub:SetAttribute("spell1", spellName)
        sub:SetAttribute("spellID1", spellID)
    else
        sub:SetAttribute("type", "spell")
        sub:SetAttribute("spell", spellName)
    end

    sub:SetScript("OnEnter", function()
        GameTooltip:SetOwner(sub, "ANCHOR_RIGHT")
        if sub.spellID then GameTooltip:SetSpellByID(sub.spellID) end
        GameTooltip:Show()
    end)
    sub:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return sub
end

function H:LayoutFlyout(flyout, count)
    local width = math.max(count * H.CONST.SUB_SPACING + H.CONST.SUB_PADDING * 2, H.CONST.MIN_WIDTH)
    flyout:SetWidth(width)
    flyout:SetHeight(H.CONST.FLYOUT_HEIGHT)
end

function H.SecureHandlerWrapScript(btn, event, ...)
    SecureHandlerWrapScript(btn, event, ...)
end

-- ==========================================
-- 斜杠命令
-- ==========================================
SLASH_HH1 = "/hh"
SlashCmdList["HH"] = function(msg)
    local cmd = strsplit(" ", msg)
    cmd = cmd:lower()

    if cmd == "version" or cmd == "v" then
        DEFAULT_CHAT_FRAME:AddMessage(string.format(H.L.CURRENT_VERSION_MSG, H.CURRENT_VERSION))

    elseif cmd == "auto" or cmd == "toggle" then
        if not H.DB then
            DEFAULT_CHAT_FRAME:AddMessage(H.L.MANUAL_CHECK)
            return
        end
        H.DB.autoExpandInCombat = not H.DB.autoExpandInCombat
        _G.HunterHelperDB = H.DB

        local val = H.DB.autoExpandInCombat and 1 or nil
        for _, mod in pairs(H.AllModules) do
            if mod.flyout then
                mod.flyout:SetAttribute("auto_expand", val)
            end
        end

        DEFAULT_CHAT_FRAME:AddMessage(
            H.DB.autoExpandInCombat and H.L.AUTO_EXPAND_ON or H.L.AUTO_EXPAND_OFF
        )

    elseif cmd == "food" or cmd == "f" then
        local foodID = H.DB and H.DB.PetFoodID
        if foodID then
            local name = GetItemInfo(foodID)
            DEFAULT_CHAT_FRAME:AddMessage(H.L.FEED_SET .. (name or foodID))
        else
            DEFAULT_CHAT_FRAME:AddMessage(H.L.FEED_CLEARED)
        end

    elseif cmd == "reset" then
        if not H.DB then
            DEFAULT_CHAT_FRAME:AddMessage(H.L.MANUAL_CHECK)
            return
        end
        H.DB = { selected = {}, pos = {"CENTER", "UIParent", "CENTER", 0, 0}, autoExpandInCombat = true, PetFoodID = nil }
        _G.HunterHelperDB = H.DB
        if H.RefreshAll then H:RefreshAll() end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[HunterHelper]|r " .. H.L.RESET_DONE)

    else
        -- 帮助信息
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[HunterHelper]|r " .. H.L.MANUAL_CHECK)
        DEFAULT_CHAT_FRAME:AddMessage("  /hh version   - " .. H.L.HELP_VERSION)
        DEFAULT_CHAT_FRAME:AddMessage("  /hh auto      - " .. H.L.HELP_AUTO)
        DEFAULT_CHAT_FRAME:AddMessage("  /hh food      - " .. H.L.HELP_FOOD)
        DEFAULT_CHAT_FRAME:AddMessage("  /hh reset     - " .. H.L.HELP_RESET)
    end
end
