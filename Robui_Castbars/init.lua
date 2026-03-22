local ADDON_NAME, ns = ...

_G[ADDON_NAME] = ns

ns.name = ADDON_NAME
ns.R = _G.Robui
ns.CB = ns.CB or {}

local CB = ns.CB

CB.bars = CB.bars or {}
CB.isUnlocked = false
CB.SettingsPanel = nil