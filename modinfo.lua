name = "道具包 - BlackSouls"
description = "来自BlackSouls的遗失物品 v1.3.1"
author = "MashKanber"
-- 1.2: 修复 stackable 客户端崩溃（stackable.lua:4 attempt to index field 'stackable'）、
--      修复吃堆叠只消耗 1 个、修复开局赠送重复刷物品
version = "1.3.1"

icon_atlas = "blacksouls.xml"
icon = "blacksouls.tex"

api_version = 10

dst_compatible = true
client_only_mod = false
-- 本 mod 新增了 prefab、配方和图标，客户端必须一起加载，
-- 否则联机时客户端不认识梦之魂（图标空白、配方不显示）
all_clients_require_mod = true

priority = 0
