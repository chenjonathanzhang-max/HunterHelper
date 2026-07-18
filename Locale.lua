local addonName, H = ...
if select(2, UnitClass("player")) ~= "HUNTER" then return end

if addonName == "HunterHelper" and not _G.HunterHelper then
    _G.HunterHelper = H
end

local locale = GetLocale()
H.L = {}

if locale == "zhCN" then
    H.L = {
        NO_DRAG = "战斗中无法移动框架",
        AUTO_EXPAND_ON = "战斗自动展开：开启",
        AUTO_EXPAND_OFF = "战斗自动展开：关闭",
        AUTO_EXPAND_DEFER = "战斗中已保存设置，脱战后生效",
        TRAP_LEFT_CLICK = "左键：施放陷阱",
        TRAP_RIGHT_CLICK = "右键：设为默认陷阱",
        TRAP_DEFAULT_SET = "默认陷阱已设置：",
        TRAP_DEFAULT_DEFER = "战斗中已记录默认陷阱，脱战后生效：",
        UPDATE_FOUND = "发现新版本 (v%d)！为了获得最佳体验，请前往CurseForge更新。",
        CURRENT_VERSION_MSG = "当前 HunterHelper 版本：v%d",
        MANUAL_CHECK = "输入 /hh version 检查更新。",
        FEED_SET = "已设为默认食物：",
        FEED_CLEARED = "已清除默认食物",
        FEED_PROMPT = "左键：拖动背包食物至此绑定\n右键：清除默认食物",
        RESET_DONE = "所有设置已重置为默认值",
        HELP_VERSION = "显示当前版本号",
        HELP_AUTO = "切换战斗中自动展开",
        HELP_FOOD = "查看或设置宠物食物",
        HELP_RESET = "重置所有设置",
    }
elseif locale == "zhTW" then
    H.L = {
        NO_DRAG = "戰鬥中無法移動框架",
        AUTO_EXPAND_ON = "戰鬥自動展開：開啟",
        AUTO_EXPAND_OFF = "戰鬥自動展開：關閉",
        AUTO_EXPAND_DEFER = "戰鬥中已保存設定，脫戰後生效",
        TRAP_LEFT_CLICK = "左鍵：施放陷阱",
        TRAP_RIGHT_CLICK = "右鍵：設為預設陷阱",
        TRAP_DEFAULT_SET = "預設陷阱已設定：",
        TRAP_DEFAULT_DEFER = "戰鬥中已記錄預設陷阱，脫戰後生效：",
        UPDATE_FOUND = "發現新版本 (v%d)！為了獲得最佳體驗，請前往CurseForge更新。",
        CURRENT_VERSION_MSG = "目前 HunterHelper 版本：v%d",
        MANUAL_CHECK = "輸入 /hh version 檢查更新。",
        FEED_SET = "已設為預設食物：",
        FEED_CLEARED = "已清除預設食物",
        FEED_PROMPT = "左鍵：拖動背包食物至此綁定\n右鍵：清除預設食物",
        RESET_DONE = "所有設定已重置為預設值",
        HELP_VERSION = "顯示目前版本號",
        HELP_AUTO = "切換戰鬥中自動展開",
        HELP_FOOD = "查看或設定寵物食物",
        HELP_RESET = "重置所有設定",
    }
else
    H.L = {
        NO_DRAG = "Cannot move in combat",
        AUTO_EXPAND_ON = "Auto-expand in combat: ON",
        AUTO_EXPAND_OFF = "Auto-expand in combat: OFF",
        AUTO_EXPAND_DEFER = "Saved in combat; will apply after combat",
        TRAP_LEFT_CLICK = "Left-click: Cast trap",
        TRAP_RIGHT_CLICK = "Right-click: Set default trap",
        TRAP_DEFAULT_SET = "Default trap set: ",
        TRAP_DEFAULT_DEFER = "Default trap saved in combat; applies after combat: ",
        UPDATE_FOUND = "New version (v%d) available! Please update from CurseForge.",
        CURRENT_VERSION_MSG = "Current HunterHelper version: v%d",
        MANUAL_CHECK = "Type /hh version to check for updates.",
        FEED_SET = "Default food set: ",
        FEED_CLEARED = "Default food cleared",
        FEED_PROMPT = "Left-click: Drag food here to bind\nRight-click: Clear default food",
        RESET_DONE = "All settings reset to defaults",
        HELP_VERSION = "Display current version",
        HELP_AUTO = "Toggle auto-expand in combat",
        HELP_FOOD = "View or set pet food",
        HELP_RESET = "Reset all settings",
    }
end