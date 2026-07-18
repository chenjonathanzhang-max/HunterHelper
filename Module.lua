-- Module.lua
-- Aspect + Trap + Pet 业务逻辑
local addonName, H = ...
if select(2, UnitClass("player")) ~= "HUNTER" then return end

-- ==========================================
-- ASPECT 模块
-- ==========================================
local aspectThrottle = 0
local ASPECT_THROTTLE_DELAY = 0.1

local function GetAspectState()
    for i = 1, 40 do
        local name = UnitAura("player", i, "HELPFUL")
        if not name then break end
        local base = H.StripRank(name)
        if base and H.SpellBaseNameToID[base] then
            local id = H.SpellBaseNameToID[base]
            for _, aspectId in ipairs(H.DB_DEFAULTS.ASPECTS) do
                local knownId = H.ResolveKnownSpellID(aspectId) or aspectId
                if id == knownId then return id end
            end
        end
    end
    return nil
end

function H.ApplyAspectState(spellID)
    local mod = H.AllModules.ASPECTS
    if not mod then return end

    if spellID then
        if not InCombatLockdown() then H.ApplySpellToButton(mod, spellID)
        else mod.selectedSpellID = spellID end
        mod.icon:SetTexture(H.GetSpellIcon(spellID))
        mod.icon:SetDesaturated(false)
        mod.icon:SetVertexColor(1, 1, 1)
        mod:SetAlpha(1)
        mod.activeBorder:SetShown(true)
        H.UpdateSubBorders(mod)
        H.lastSelectedAspectID = spellID
    else
        local fallback = (H.DB and H.DB.selected and H.DB.selected.ASPECTS) or H.DB_DEFAULTS.ASPECTS[1]
        if not InCombatLockdown() then H.ApplySpellToButton(mod, fallback)
        else mod.selectedSpellID = fallback end
        mod.icon:SetTexture(H.GetSpellIcon(fallback))
        mod.icon:SetDesaturated(true)
        mod.icon:SetVertexColor(0.6, 0.6, 0.6)
        mod:SetAlpha(0.7)
        mod.activeBorder:Hide()
        H.UpdateSubBorders(mod)
    end
end

function H.RefreshAspect()
    H.ApplyAspectState(GetAspectState())
end

function H:CreateAspectModule(parent, yOffset)
    local btn = H:CreateMainButton(parent, "ASPECTS", H.CONST.MAIN_BTN_SIZE)
    btn:SetPoint("TOP", parent, "TOP", 0, yOffset)

    btn:SetScript("PostClick", function()
        C_Timer.After(0.05, H.RefreshAspect)
    end)

    local flyout, bridge = H:CreateFlyout(btn)
    local count = 0
    btn.subButtons = {}

    for _, id in ipairs(H.DB_DEFAULTS.ASPECTS) do
        local knownID = H.ResolveKnownSpellID(id) or id
        if H.IsLearned(knownID) then
            count = count + 1
            local sub = H:CreateSubButton(flyout, btn, H.CONST.SUB_BTN_SIZE, knownID, false)

            sub:SetScript("PostClick", function(self)
                if self.spellID and H.DB and H.DB.selected then
                    H.DB.selected.ASPECTS = self.spellID
                end
                H.RefreshAspect()
            end)

            H.SecureHandlerWrapScript(sub, "OnClick", sub, "", [[
                local flyout = self:GetParent()
                local main = self:GetFrameRef("main")
                if main then
                    main:SetAttribute("type", "spell")
                    main:SetAttribute("spell", self:GetAttribute("spell"))
                    main:SetAttribute("selectedSpell", self:GetAttribute("spell"))
                    main:SetAttribute("selectedSpellID", self:GetAttribute("spellID"))
                end
                if flyout and not flyout:GetAttribute("in_combat") then flyout:Hide() end
            ]])

            sub:ClearAllPoints()
            sub:SetPoint("LEFT", flyout, "LEFT", (count - 1) * H.CONST.SUB_SPACING + H.CONST.SUB_PADDING, 0)
            sub:Show()
            btn.subButtons[count] = sub
        end
    end

    H.AllModules.ASPECTS = btn
    H:LayoutFlyout(flyout, count)
end

H:RegisterHandler("UNIT_AURA", function(unit)
    if unit == "player" then
        local now = GetTime()
        if now - aspectThrottle >= ASPECT_THROTTLE_DELAY then
            aspectThrottle = now
            H.RefreshAspect()
        end
    end
end)
H:RegisterHandler("PLAYER_REGEN_ENABLED", H.RefreshAspect)
H:RegisterHandler("PLAYER_LOGIN", H.RefreshAspect)
H:RegisterHandler("PLAYER_DEAD", function()
    C_Timer.After(1.0, H.RefreshAspect)
end)

-- ==========================================
-- TRAP 模块
-- ==========================================
function H.GetTrapState()
    local mod = H.AllModules.TRAPS
    if not mod or not mod.selectedSpellID then
        return { spellID = nil }
    end
    return { spellID = mod.selectedSpellID }
end

function H.ApplyTrapState(state)
    local mod = H.AllModules.TRAPS
    if not mod or not state then return end

    local spellID = state.spellID or (H.DB and H.DB.selected and H.DB.selected.TRAPS) or H.DB_DEFAULTS.TRAPS[1]
    if spellID and not InCombatLockdown() then H.ApplySpellToButton(mod, spellID) end

    if spellID then
        mod.icon:SetTexture(H.GetSpellIcon(spellID))
        local s, d = GetSpellCooldown(spellID)
        if s and d and d > 0 then
            mod.cd:SetCooldown(s, d)
            local isCooling = d > 1.6
            mod.icon:SetDesaturated(isCooling)
            mod.icon:SetVertexColor(isCooling and 0.6 or 1, isCooling and 0.6 or 1, isCooling and 0.6 or 1)
        else
            CooldownFrame_Clear(mod.cd)
            H.SetMainVisualAvailable(mod)
        end
    end
end

function H.RefreshTrap()
    H.ApplyTrapState(H.GetTrapState())
end

function H.RefreshTrapMainButton() H.RefreshTrap() end

function H.SetDefaultTrap(spellID, quiet)
    local mod = H.AllModules.TRAPS
    if not mod or not spellID then return false end
    local name = H.GetSpellName(spellID)
    if not name then return false end

    if InCombatLockdown() then
        H.pendingDefaultTrapID = spellID
        if not quiet then DEFAULT_CHAT_FRAME:AddMessage(H.L.TRAP_DEFAULT_DEFER .. name) end
        return false
    end

    H.pendingDefaultTrapID = nil
    if H.ApplySpellToButton(mod, spellID) then
        if H.DB and H.DB.selected then H.DB.selected.TRAPS = spellID end
        H.UpdateSubBorders(mod)
        H.RefreshTrap()
        if not quiet then DEFAULT_CHAT_FRAME:AddMessage(H.L.TRAP_DEFAULT_SET .. name) end
        return true
    end
    return false
end

function H:CreateTrapModule(parent, yOffset)
    local btn = H:CreateMainButton(parent, "TRAPS", H.CONST.MAIN_BTN_SIZE)
    btn:SetPoint("TOP", parent, "TOP", 0, yOffset)

    local flyout, bridge = H:CreateFlyout(btn)
    local count = 0
    btn.subButtons = {}

    for _, id in ipairs(H.DB_DEFAULTS.TRAPS) do
        local knownID = H.ResolveKnownSpellID(id) or id
        if H.IsLearned(knownID) then
            count = count + 1
            local sub = H:CreateSubButton(flyout, btn, H.CONST.SUB_BTN_SIZE, knownID, true)

            sub:SetAttribute("type1", "spell")
            sub:SetAttribute("spell1", H.GetSpellName(knownID))
            sub:SetAttribute("spellID1", knownID)
            sub:SetAttribute("type2", nil)
            sub:SetAttribute("spell2", nil)

            sub:SetScript("PostClick", function(self, mouseButton)
                local sid = self.spellID
                if not sid then return end
                if mouseButton == "RightButton" then H.SetDefaultTrap(sid) else H.RefreshTrap() end
            end)

            H.SecureHandlerWrapScript(sub, "OnClick", sub, "", [[
                local flyout = self:GetParent()
                local main = self:GetFrameRef("main")
                if main and not self:GetAttribute("trapButton") then
                    main:SetAttribute("type", "spell")
                    main:SetAttribute("spell", self:GetAttribute("spell"))
                    main:SetAttribute("selectedSpell", self:GetAttribute("spell"))
                    main:SetAttribute("selectedSpellID", self:GetAttribute("spellID"))
                end
                if flyout and not flyout:GetAttribute("in_combat") then flyout:Hide() end
            ]])

            sub:ClearAllPoints()
            sub:SetPoint("LEFT", flyout, "LEFT", (count - 1) * H.CONST.SUB_SPACING + H.CONST.SUB_PADDING, 0)
            sub:Show()
            btn.subButtons[count] = sub
        end
    end

    H.AllModules.TRAPS = btn
    H:LayoutFlyout(flyout, count)
end

H:RegisterHandler("SPELL_UPDATE_COOLDOWN", function() H.RefreshTrap(); H:RefreshAllCooldowns() end)
H:RegisterHandler("PLAYER_REGEN_ENABLED", function()
    if H.pendingDefaultTrapID then H.SetDefaultTrap(H.pendingDefaultTrapID) end
    H.RefreshTrap()
end)
H:RegisterHandler("SPELLS_CHANGED", function() H.BuildSpellCache(); H._securePending = true end)

-- ==========================================
-- PET 模块
-- ==========================================
local PET_REASON = { CALL = 1, REVIVE = 2, HEAL = 3, FEED = 4, DEFAULT = 5 }

-- ★ 终极防呆：宠物是否存在判定
-- 解决宠物因距离过远在战斗中"消失"时，UnitExists("pet") 返回 true 但实际不可用的问题
function H.IsPetActuallyExists()
    if UnitExists("pet") and not UnitIsDead("pet") then
        return true
    end
    
    if HasPetUI() then
        local actionType = GetPetActionInfo(1)
        if actionType == "spell" or actionType == "pet" then
            return true
        end
        return true
    end
    
    return false
end

function H.HasPetUIPresence()
    return HasPetUI()
end

-- ★ 文本缓存（防止倒计时文字闪烁）
local LastHealText = ""
local LastFeedText = ""

-- ★ 状态缓存（防止按钮状态频繁切换闪烁）
local CachedPetState = {
    stateName = nil,
    spellID = nil,
    visualEnabled = nil,
    reason = nil,
}

local function PetNeedsHeal()
    if not UnitExists("pet") or UnitIsDead("pet") then return false end
    local maxHealth = UnitHealthMax("pet") or 0
    return maxHealth > 0 and (UnitHealth("pet") or 0) < maxHealth
end

local function PetNeedsFeed()
    if not UnitExists("pet") or UnitIsDead("pet") or not GetPetHappiness then return false end
    return (GetPetHappiness() or 3) < 3
end

function H.GetPetState()
    -- 骑乘/飞行状态：不干扰
    if IsMounted() or UnitOnTaxi("player") then
        local defaultID = H.ResolveUsableSpellID((H.DB and H.DB.selected and H.DB.selected.PET) or H.PET_SPELL.MEND) or H.PET_SPELL.MEND
        return { spellID = defaultID, visualEnabled = true, reason = PET_REASON.DEFAULT, stateName = "MOUNTED" }
    end
    
    local petActuallyExists = H.IsPetActuallyExists()
    local unitExists = UnitExists("pet")
    local isDead = unitExists and UnitIsDead("pet")
    local inCombat = InCombatLockdown()
    
    -- ★ 将"显示复活"与"是否可施放"分开判断（解决空蓝时按钮消失的问题）
    local hasReviveSpell = GetSpellInfo(H.PET_SPELL.REVIVE) ~= nil
    local isPetDeadAtDistance = HasPetUI() and not unitExists and hasReviveSpell
    local canCastRevive = isPetDeadAtDistance and IsUsableSpell(H.PET_SPELL.REVIVE)
    
    -- 声明状态变量
    local state = nil
    
    -- 1. 完全无宠物 → 召唤（最高优先级）
    if not petActuallyExists and not HasPetUI() and not isPetDeadAtDistance then
        state = { spellID = H.PET_SPELL.CALL, visualEnabled = true, stateName = "CALL", reason = PET_REASON.CALL }
    end
    
    -- 1.5 ★ 宠物距离外死亡 → 复活（根据蓝量决定可用/灰色）
    if not state and isPetDeadAtDistance then
        state = { spellID = H.PET_SPELL.REVIVE, visualEnabled = canCastRevive, stateName = "REVIVE (DISTANCE)", reason = PET_REASON.REVIVE }
    end
    
    -- 2. 宠物死亡 → 复活
    if not state and isDead then
        state = { spellID = H.PET_SPELL.REVIVE, visualEnabled = IsUsableSpell(H.PET_SPELL.REVIVE), stateName = "REVIVE", reason = PET_REASON.REVIVE }
    end
    
    -- 3. 宠物因距离过远"消失"（战斗中）
    if not state and HasPetUI() and not unitExists and inCombat then
        state = { spellID = H.PET_SPELL.CALL, visualEnabled = false, stateName = "CALL (DISTANCE)", reason = PET_REASON.CALL }
    end
    
    -- 4. 宠物因距离过远"消失"（脱战后）
    if not state and HasPetUI() and not unitExists and not inCombat then
        state = { spellID = H.PET_SPELL.CALL, visualEnabled = true, stateName = "CALL (RECALL)", reason = PET_REASON.CALL }
    end
    
    -- 5. 战斗状态
    if not state and inCombat then
        local btn = H.AllModules.PET
        local currentID = (btn and btn.selectedSpellID) or H.PET_SPELL.MEND
        state = { spellID = currentID, visualEnabled = true, stateName = "COMBAT", reason = PET_REASON.DEFAULT }
    end

    -- 6. 手动覆盖
    if not state and H._petManualOverride and H._petManualSpellID then
        if not PetNeedsHeal() and not PetNeedsFeed() then
            state = { spellID = H._petManualSpellID, visualEnabled = true, stateName = "MANUAL", reason = PET_REASON.DEFAULT }
        else
            H._petManualOverride = false
            H._petManualSpellID = nil
        end
    end

    -- 7. 需要治疗
    if not state and PetNeedsHeal() then
        state = { spellID = H.PET_SPELL.MEND, visualEnabled = IsUsableSpell(H.PET_SPELL.MEND), forceIcon = H.PET_SPELL.MEND, reason = PET_REASON.HEAL, needTimer = true, healExpiration = H.petHealExpiration, stateName = "MEND" }
    end

    -- 8. 需要喂食
    if not state and PetNeedsFeed() then
        local foodID = H.DB and H.DB.PetFoodID
        if foodID and GetItemCount(foodID) > 0 then
            state = { spellID = H.PET_SPELL.FEED, visualEnabled = IsUsableSpell(H.PET_SPELL.FEED), reason = PET_REASON.FEED, needFeed = true, feedCount = GetItemCount(foodID), stateName = "FEED" }
        end
    end

    -- 9. 默认
    if not state then
        local defaultID = H.ResolveUsableSpellID((H.DB and H.DB.selected and H.DB.selected.PET) or H.PET_SPELL.MEND) or H.PET_SPELL.MEND
        state = { spellID = defaultID, visualEnabled = true, reason = PET_REASON.DEFAULT, stateName = "DEFAULT" }
    end
    
    -- ★ 状态缓存：只有状态发生变化时才更新 UI（防止闪烁）
    if CachedPetState.stateName ~= state.stateName or
       CachedPetState.spellID ~= state.spellID or
       CachedPetState.visualEnabled ~= state.visualEnabled then
        CachedPetState.stateName = state.stateName
        CachedPetState.spellID = state.spellID
        CachedPetState.visualEnabled = state.visualEnabled
        CachedPetState.reason = state.reason
        return state
    end
    
    -- 状态未变化，返回 state（但 ApplyPetState 会做文本缓存）
    return state
end

function H.ApplyPetState(state)
    local btn = H.AllModules.PET
    if not btn or not state then return end

    local isCombat = InCombatLockdown()
    local spellID

    if isCombat then
        spellID = btn:GetAttribute("selectedSpellID") or btn.selectedSpellID or state.spellID
        btn.selectedSpellID = spellID
        btn.icon:SetTexture(H.GetSpellIcon(spellID))
        H.SetMainVisualAvailable(btn)
        if H.COMBAT_UNSAFE_PET[spellID] then
            btn.icon:SetDesaturated(true)
            btn.icon:SetVertexColor(0.5, 0.5, 0.5)
            btn:SetAlpha(0.5)
        end
    else
        spellID = state.spellID
        local iconID = state.forceIcon or spellID
        if iconID then btn.icon:SetTexture(H.GetSpellIcon(iconID)) end
        H.ApplySpellToButton(btn, spellID)
        if state.visualEnabled then H.SetMainVisualAvailable(btn)
        else H.SetMainVisualUnavailable(btn, spellID) end
    end

    -- ★ 治疗计时（文本缓存，防止闪烁）
    if btn.text then
        if not isCombat and state.needTimer and state.healExpiration and state.healExpiration > GetTime() then
            local newText = H.FormatTime(state.healExpiration)
            if newText ~= LastHealText then
                btn.text:SetText(newText)
                LastHealText = newText
            end
            btn.text:Show()
        else
            btn.text:Hide()
            LastHealText = ""
        end
    end

    -- ★ 食物计数（文本缓存，防止闪烁）
    if btn.countText then
        if not isCombat and state.needFeed and H.DB and H.DB.PetFoodID then
            local newCount = tostring(GetItemCount(H.DB.PetFoodID))
            if newCount ~= LastFeedText then
                btn.countText:SetText(newCount)
                LastFeedText = newCount
            end
            btn.countText:Show()
        else
            btn.countText:Hide()
            LastFeedText = ""
        end
    end

    -- 子按钮：喂食图标和数量
    if btn.subButtons then
        for _, sub in ipairs(btn.subButtons) do
            if sub.spellID == H.PET_SPELL.FEED then
                local foodID = H.DB and H.DB.PetFoodID
                if foodID then
                    local count = GetItemCount(foodID)
                    sub.icon:SetTexture(select(10, GetItemInfo(foodID)) or H.GetSpellIcon(H.PET_SPELL.FEED))
                    if sub.countText then
                        sub.countText:SetText(tostring(count))
                        sub.countText:Show()
                    end
                else
                    sub.icon:SetTexture(H.GetSpellIcon(H.PET_SPELL.FEED))
                    if sub.countText then sub.countText:Hide() end
                end
            end
            
            -- ★ 喂养冷却动画（子按钮上显示 20 秒冷却）
            if sub.spellID == H.PET_SPELL.FEED then
                if H.feedCooldownActive and H.feedCooldownEnd > GetTime() then
                    local startTime = H.feedCooldownEnd - H.CONST.FEED_COOLDOWN
                    sub.cd:SetCooldown(startTime, H.CONST.FEED_COOLDOWN)
                else
                    CooldownFrame_Clear(sub.cd)
                end
            end

            local grayed = false
            if isCombat and H.COMBAT_UNSAFE_PET[sub.spellID] then
                grayed = true
            elseif sub.spellID == H.PET_SPELL.FEED then
                local foodID = H.DB and H.DB.PetFoodID
                if not foodID or GetItemCount(foodID) == 0 then grayed = true end
            end

            if grayed then
                sub.icon:SetDesaturated(true)
                sub.icon:SetVertexColor(0.5, 0.5, 0.5)
                sub:SetAlpha(0.5)
            else
                sub.icon:SetDesaturated(false)
                sub.icon:SetVertexColor(1, 1, 1)
                sub:SetAlpha(1)
            end
        end
    end

    H.UpdateSubBorders(btn)
end

function H.UpdatePetVisual()
    H.ApplyPetState(H.GetPetState())
end

function H.RefreshPet()
    H.UpdatePetHealAura()
    H.UpdatePetVisual()
end

function H:CreatePetModule(parent, yOffset)
    local btn = H:CreateMainButton(parent, "PET", H.CONST.MAIN_BTN_SIZE)
    btn:SetPoint("TOP", parent, "TOP", 0, yOffset)

    btn.countText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.countText:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    btn.countText:SetTextColor(1, 0.8, 0)
    btn.countText:SetFont(select(1, GameFontNormalSmall:GetFont()), 10, "OUTLINE")
    btn.countText:Hide()

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.text:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    btn.text:SetTextColor(1, 0.8, 0)
    btn.text:SetFont(select(1, GameFontNormalSmall:GetFont()), 12, "OUTLINE")
    btn.text:Hide()

    local flyout, bridge = H:CreateFlyout(btn)
    local count = 0
    btn.subButtons = {}

    for _, id in ipairs(H.DB_DEFAULTS.PET) do
        local knownID = H.ResolveKnownSpellID(id) or id
        if H.IsLearned(knownID) then
            count = count + 1
            local sub = H:CreateSubButton(flyout, btn, H.CONST.SUB_BTN_SIZE, knownID, false)

            if knownID == H.PET_SPELL.FEED then
                sub.countText = sub:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                sub.countText:SetPoint("BOTTOMRIGHT", sub, "BOTTOMRIGHT", -2, 2)
                sub.countText:SetTextColor(1, 0.8, 0)
                sub.countText:SetFont(select(1, GameFontNormalSmall:GetFont()), 10, "OUTLINE")
                sub.countText:Hide()

                sub:RegisterForDrag("LeftButton")
                sub:SetScript("OnReceiveDrag", function()
                    if InCombatLockdown() then return end
                    local t, id = GetCursorInfo()
                    if t == "item" and id then
                        H.DB.PetFoodID = id
                        ClearCursor()
                        H.RefreshPet()
                    end
                end)

                sub:SetScript("PreClick", function(self, button)
                    if InCombatLockdown() then return end
                    
                    -- ★ 冷却中阻止点击
                    if H.feedCooldownActive and GetTime() < H.feedCooldownEnd then
                        local remain = math.ceil(H.feedCooldownEnd - GetTime())
                        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[HunterHelper]|r 喂养冷却中，请等待 " .. remain .. " 秒")
                        return
                    end
                    
                    if button == "LeftButton" then
                        if not H.DB.PetFoodID or not UnitExists("pet") or UnitIsDead("pet") then
                            self.skipPostClick = true
                            return
                        end
                        self.skipPostClick = false
                        H.ApplySpellToButton(self, H.PET_SPELL.FEED)
                        self._isFeeding = true
                    elseif button == "RightButton" then
                        H.DB.PetFoodID = nil
                        self.skipPostClick = true
                        self:SetAttribute("type", nil)
                        H.RefreshPet()
                    end
                end)

                sub:SetScript("PostClick", function(self)
                    if self.skipPostClick then self.skipPostClick = false; return end
                    if InCombatLockdown() then return end
                    if self._isFeeding then
                        self._isFeeding = false
                        H._petManualOverride = true
                        H._petManualSpellID = H.PET_SPELL.FEED
                        H.ApplySpellToButton(btn, H.PET_SPELL.FEED)
                        H.feedCooldownActive = true
                        H.feedCooldownEnd = GetTime() + H.CONST.FEED_COOLDOWN
                        H.RefreshPet()
                    elseif self.spellID then
                        H.ApplySpellToButton(btn, self.spellID)
                        H.RefreshPet()
                    end
                end)

                H.SecureHandlerWrapScript(sub, "OnClick", sub, [[
                    local flyout = self:GetParent()
                    if flyout and flyout:GetAttribute("in_combat") then return true end
                ]], [[
                    local f = self:GetParent()
                    if f and not f:GetAttribute("in_combat") then f:Hide() end
                ]])
            else
                if H.COMBAT_UNSAFE_PET[knownID] then
                    sub:SetAttribute("combat_unsafe", true)
                end

                H.SecureHandlerWrapScript(sub, "OnClick", sub, [[
                    local flyout = self:GetParent()
                    if self:GetAttribute("combat_unsafe") and flyout and flyout:GetAttribute("in_combat") then
                        return true
                    end
                ]], [[
                    local flyout = self:GetParent()
                    local main = self:GetFrameRef("main")
                    if self:GetAttribute("combat_unsafe") and flyout and flyout:GetAttribute("in_combat") then
                        return
                    end
                    if main then
                        main:SetAttribute("type", "spell")
                        main:SetAttribute("spell", self:GetAttribute("spell"))
                        main:SetAttribute("selectedSpell", self:GetAttribute("spell"))
                        main:SetAttribute("selectedSpellID", self:GetAttribute("spellID"))
                    end
                    if flyout and not flyout:GetAttribute("in_combat") then flyout:Hide() end
                ]])

                sub:SetScript("PostClick", function(self)
                    if self.spellID then
                        if InCombatLockdown() and H.COMBAT_UNSAFE_PET[self.spellID] then return end
                        H._petManualOverride = true
                        H._petManualSpellID = self.spellID
                        if not InCombatLockdown() then
                            H.ApplySpellToButton(btn, self.spellID)
                        else
                            btn.selectedSpellID = self.spellID
                            btn.icon:SetTexture(H.GetResolvedIcon(btn, self.spellID))
                        end
                        H.UpdateSubBorders(btn)
                        H.RefreshPet()
                    end
                end)
            end

            sub:ClearAllPoints()
            sub:SetPoint("LEFT", flyout, "LEFT", (count - 1) * H.CONST.SUB_SPACING + H.CONST.SUB_PADDING, 0)
            sub:Show()
            btn.subButtons[count] = sub
        end
    end

    H.AllModules.PET = btn
    H:LayoutFlyout(flyout, count)
end

-- PET 事件注册
local function RefreshPetLater()
    C_Timer.After(0.05, H.RefreshPet)
end

H:RegisterHandler("UNIT_PET", function(u)
    if u == "player" then RefreshPetLater() end
end)
H:RegisterHandler("PET_STABLE_UPDATE", RefreshPetLater)
H:RegisterHandler("PET_STABLE_SHOW", RefreshPetLater)
H:RegisterHandler("PET_STABLE_CLOSED", RefreshPetLater)
H:RegisterHandler("PET_BAR_UPDATE", RefreshPetLater)

H:RegisterHandler("UNIT_AURA", function(u)
    if u == "pet" then H.UpdatePetHealAura(); H.UpdatePetVisual() end
end)
H:RegisterHandler("UNIT_HEALTH", function(u) if u == "pet" then H.UpdatePetVisual() end end)
H:RegisterHandler("UNIT_HEALTH_FREQUENT", function(u) if u == "pet" then H.UpdatePetVisual() end end)
H:RegisterHandler("UNIT_HAPPINESS", H.UpdatePetVisual)
H:RegisterHandler("BAG_UPDATE_DELAYED", H.UpdatePetVisual)
H:RegisterHandler("PLAYER_REGEN_DISABLED", H.UpdatePetVisual)

H:RegisterHandler("PLAYER_REGEN_ENABLED", H.RefreshPet)

-- PET 定时器
local nextPetHealTick = 0
local nextHappinessCheck = 0
H:RegisterTimerTask(function()
    local now = GetTime()
    local needFullRefresh = false

    if H.petHealExpiration and H.petHealExpiration > 0 then
        if H.petHealExpiration <= now then
            H.petHealExpiration = 0
            needFullRefresh = true
        elseif now >= nextPetHealTick then
            H.UpdatePetHealDuration()
            nextPetHealTick = now + 0.5  -- 降低频率，减少闪烁
        end
    end

    if H.feedCooldownActive and H.feedCooldownEnd > 0 and now >= H.feedCooldownEnd then
        H.feedCooldownActive = false
        H.feedCooldownEnd = 0
        needFullRefresh = true
    end

    -- 轮询宠物开心度（UNIT_HAPPINESS 事件在 TBC 2.5.5 不可靠）
    if now >= nextHappinessCheck then
        nextHappinessCheck = now + 2  -- 降低检查频率
        if UnitExists("pet") and not UnitIsDead("pet") and GetPetHappiness then
            local happiness = GetPetHappiness()
            if happiness and happiness ~= H._lastPetHappiness then
                H._lastPetHappiness = happiness
                needFullRefresh = true
            end
        else
            H._lastPetHappiness = nil
        end
    end

    if needFullRefresh then H.UpdatePetVisual() end
end)