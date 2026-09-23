PrefabFiles = {
    "dream_soul",
    "cape",
}

-- Assets = {
--     -- dream_soul 的资源
--     Asset("IMAGE", "images/inventoryimages/dream_soul.tex"),
--     Asset("ATLAS", "images/inventoryimages/dream_soul.xml"),
--     Asset("ANIM", "anim/blacksouls_soul.zip"),  -- 物品栏/地面动画

--     -- cape 的资源（根据你的预制体脚本补充）
--     Asset("IMAGE", "images/inventoryimages/redhat.tex"),
--     Asset("ATLAS", "images/inventoryimages/redhat.xml"),
--     Asset("ANIM", "anim/redhat.zip"),          -- 地面/物品栏动画
--     Asset("ANIM", "anim/swap_redhat.zip"),     -- 装备时的替换动画
-- }

-- ========== 中文文本 ==========
-- 直接写在 modmain 顶层：客户端加载 mod 时也会执行，名称/描述才显示得出来
GLOBAL.STRINGS.NAMES.DREAM_SOUL = "梦之魂"
GLOBAL.STRINGS.CHARACTERS.GENERIC.DESCRIBE.DREAM_SOUL = "来自BlackSouls的神秘灵魂，使用后可无限增强自身属性。"

GLOBAL.STRINGS.NAMES.CAPE = "红之披风"
GLOBAL.STRINGS.CHARACTERS.GENERIC.DESCRIBE.CAPE = "在斩下你的头颅之前，我是不会死的..."
-- 检查（按空格/V）时的台词（可选）
-- GLOBAL.STRINGS.CHARACTERS.WILSON.DESCRIBE.CAPE = "温暖的...棉袄..."

-- ========== 制作配方 ==========
local Ingredient = GLOBAL.Ingredient
local TECH = GLOBAL.TECH

-- 注意：AddRecipe2 的真实签名是 (name, ingredients, tech, config, filters)，
-- 没有 tab 参数，第 3 个参数是科技，第 4 个才是配置表。
-- （旧写法把 RECIPETABS.MAGIC 传给了 tech，导致 recipes.level 里混进字符串
--   "MAGIC"，游戏加载 blueprint 预制物时报
--   blueprint.lua:68: attempt to compare number with string）
local dream_soul_recipe = AddRecipe2(
    "dream_soul",
    {
        Ingredient("nightmarefuel", 1),          -- 噩梦燃料 ×1
    },
    TECH.NONE,                                   -- 无需科技台，开局就能做
    {
        atlas = "images/inventoryimages/dream_soul.xml",  -- 配方图标图集
        image = "dream_soul.tex",                         -- 配方图标
        nounlock = true,                                  -- 不需要解锁
    },
    { "MODS" }                                   -- 放进"模组"制作筛选页
)

GLOBAL.STRINGS.RECIPE_DESC.DREAM_SOUL = "来自神秘箱庭的灵魂..."

local cape_recipe = AddRecipe2(
    "cape",
    {
        Ingredient("voidcloth", 6),
        Ingredient("beefalowool", 10),
        Ingredient("manrabbit_tail", 10),
        Ingredient("opalpreciousgem", 3),
    },
    TECH.NONE,
    {
        atlas = "images/inventoryimages/redhat.xml",
        image = "redhat.tex",
        nounlock = true,
    },
    {"MODS"}
)
GLOBAL.STRINGS.RECIPE_DESC.CAPE = "一件温暖的红棉袄..."


RegisterInventoryItemAtlas("images/inventoryimages/redhat.xml", "redhat.tex")
RegisterInventoryItemAtlas("images/inventoryimages/dream_soul.xml", "dream_soul.tex")

-- ========== 梦之魂层数持久化：读档/复活后重新应用加成 ==========
AddPlayerPostInit(function(inst)
    -- 只处理主机端（客户端不参与存档，也没有 health/combat 等逻辑组件）
    if GLOBAL.TheWorld == nil or not GLOBAL.TheWorld.ismastersim then
        return
    end

    -- 存档：把 soul_data 写进玩家存档
    local old_save = inst.OnSave
    inst.OnSave = function(inst_, data, ...)
        local refs = old_save ~= nil and old_save(inst_, data, ...) or nil
        if data ~= nil then
            data.soul_data = inst_.soul_data or nil
        end
        return refs
    end

    -- 读档：恢复 soul_data 并重新应用加成
    local old_load = inst.OnLoad
    inst.OnLoad = function(inst_, data, ...)
        if old_load ~= nil then
            old_load(inst_, data, ...)
        end
        if data ~= nil and data.soul_data ~= nil then
            inst_.soul_data = data.soul_data
        end
        if type(GLOBAL.blacksouls_apply_soul_layers) == "function" then
            GLOBAL.blacksouls_apply_soul_layers(inst_)
        end
    end

    -- 死亡/复活：新角色实体走 OnNewSpawn，同样恢复并重新应用
    local old_newspawn = inst.OnNewSpawn
    inst.OnNewSpawn = function(inst_, data, ...)
        if old_newspawn ~= nil then
            old_newspawn(inst_, data, ...)
        end
        if data ~= nil and data.soul_data ~= nil then
            inst_.soul_data = data.soul_data
        end
        if type(GLOBAL.blacksouls_apply_soul_layers) == "function" then
            GLOBAL.blacksouls_apply_soul_layers(inst_)
        end
    end
end)
