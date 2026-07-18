# HunterHelper（猎人助手）

Lightweight, high-performance Hunter aspect and spell manager for World of Warcraft.

## 简介

HunterHelper 是一个轻量、高效的猎人守护（Aspect）与法术管理器，适用于 **TBC Classic / Wrath Classic（客户端接口 20506）** 周年服。

- 作者：Jonathan Zhang
- 版本：3.0
- 本地化：简体中文（zhCN）、繁体中文（zhTW）、英文

## 功能

- 猎人守护（Aspect）管理
- 宠物状态管理
- 陷阱锁定管理
- 事件驱动的高效处理器（UNIT_AURA 等多处理器派发）

## 安装

1. 将本仓库克隆 / 解压到 WoW 的 `Interface/AddOns/` 目录，使路径形如：
   ```
   World of Warcraft/_anniversary_/Interface/AddOns/HunterHelper/
   ```
2. 确保文件夹内包含：`Core.lua`、`Data.lua`、`HunterHelper.toc`、`Locale.lua`、`Module.lua`。
3. 进入游戏，在角色选择界面点击 **AddOns**，勾选 **HunterHelper**（如提示过期，一并勾选“加载过期插件”）。
4. 输入 `/reload` 重载界面即可生效。

## 文件结构

| 文件                | 说明                                   |
|---------------------|----------------------------------------|
| `HunterHelper.toc`  | 插件元数据与加载清单                   |
| `Core.lua`          | 核心框架、事件注册与派发               |
| `Data.lua`          | 配置默认值、守护 / 宠物数据            |
| `Module.lua`        | 主要逻辑模块                           |
| `Locale.lua`        | 多语言文本（zhCN / zhTW / enUS）       |

## 配置

插件的运行配置保存在 `HunterHelperDB`（WoW SavedVariables）中。
