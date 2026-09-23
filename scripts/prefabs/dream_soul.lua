-- ============================================================
-- 梦之魂 (dream_soul)
-- 吃下后永久叠加强化：生命 / 精神 / 饥饿上限 + 伤害倍率
-- ============================================================
local GLOBAL = _G
local assets =
{
    Asset("ATLAS", "images/inventoryimages/dream_soul.xml"),
    Asset("IMAGE", "images/inventoryimages/dream_soul.tex"),
    -- 以后做好自己的动画后，取消下面这行注释，并把 BUILD 换成自己的 build 名
    Asset("ANIM", "anim/dream_soul.zip"),
}

-- 物品外观：暂时复用原版"噩梦燃料"的动画 build（游戏自带，不需要额外资源）
local BUILD = "dream_soul"
local BUILD_IDLE_ANIM = "idle"

-- ========== 每层叠加的属性增量（可自由调整） ==========
local SOUL_HEALTH = 0.010    -- 每层 +1% 生命上限
local SOUL_SANITY = 0.010    -- 每层 +1% 精神上限
local SOUL_HUNGER = 0.010    -- 每层 +1% 饥饿上限
local SOUL_DAMAGE = 0.010    -- 每层 +1% 伤害倍率

-- 吃掉后是否消失：true = 吃一个少一个（可堆叠时只少 1 个）；false = 可以无限吃
local CONSUMED_ON_EAT = true

-- 可堆叠数量（跟随游戏的"小物品"上限；getModConfigData 之类的堆叠 mod 改写后也能取到）
local STACK_SIZE = TUNING.STACK_SIZE_SMALLITEM

-- 创建 soul_data 时锁定基准值（此刻还没吃过梦之魂，组件是真实基础状态）
-- 不依赖"首次应用时的当前值"：若在其他 mod/角色特性已强化后才首次应用，
-- 会把别人的加成也固化进基准，造成双重强化。
local function InitSoulData(owner)
    if owner.soul_data ~= nil then
        return owner.soul_data
    end
    local sd = { layers = 0 }
    local health = owner.components.health
    if health ~= nil then sd.base_health = health.maxhealth end
    local sanity = owner.components.sanity
    if sanity ~= nil then sd.base_sanity = sanity.max end
    local hunger = owner.components.hunger
    if hunger ~= nil then sd.base_hunger = hunger.max end
    local combat = owner.components.combat
    if combat ~= nil then sd.base_combat = combat.damagemultiplier end
    owner.soul_data = sd

    return sd
end

-- 根据 owner.soul_data.layers 重新应用全部加成
-- 幂等设计：重复调用结果一致（读档/复活后会被多次调用）
-- 必须从"基础值"重新计算，不能从当前值继续叠——否则读档后组件已被存档恢复，
-- 再用当前值叠加一次会造成双重加成。
local function ApplySoulLayers(owner)
    local soul_data = owner.soul_data
    if soul_data == nil or soul_data.layers == nil or soul_data.layers <= 0 then
        return
    end
    local layers = soul_data.layers

    -- 在修改上限之前，先记录当前的属性值
    local old_health = owner.components.health.currenthealth
    local old_sanity = owner.components.sanity.current
    local old_hunger = owner.components.hunger.current


    -- 提升属性上限

    -- 旧档迁移（方案 B）：老版本存档只有 layers、没有 base_* 字段，
    -- 用"当前值 ÷ (1+增量)^layers"反推真实基准，避免把已强化的当前值当基准。
    -- 前提：假设旧档的当前上限全部来自本 mod 的层数加成。
    -- 反推结果写入 soul_data 后会被 OnSave 持久化，下次读档即有 base，迁移只发生一次。
    if soul_data.base_health == nil then
        local h = owner.components.health
        if h ~= nil then soul_data.base_health = h.maxhealth / ((1 + SOUL_HEALTH) ^ layers) end
    end
    if soul_data.base_sanity == nil then
        local s = owner.components.sanity
        if s ~= nil then soul_data.base_sanity = s.max / ((1 + SOUL_SANITY) ^ layers) end
    end
    if soul_data.base_hunger == nil then
        local hg = owner.components.hunger
        if hg ~= nil then soul_data.base_hunger = hg.max / ((1 + SOUL_HUNGER) ^ layers) end
    end
    if soul_data.base_combat == nil then
        local c = owner.components.combat
        if c ~= nil then soul_data.base_combat = c.damagemultiplier / ((1 + SOUL_DAMAGE) ^ layers) end
    end

    -- 基准值在 InitSoulData 创建或上方迁移时已就位；这里只做防御性判断，不在此快照
    local health = owner.components.health
    if health ~= nil and soul_data.base_health ~= nil then
        local max = soul_data.base_health
        for _ = 1, layers do
            max = max * (1 + SOUL_HEALTH)
        end
        health:SetMaxHealth(max)
    end

    local sanity = owner.components.sanity
    if sanity ~= nil and soul_data.base_sanity ~= nil then
        local max = soul_data.base_sanity
        for _ = 1, layers do
            max = max * (1 + SOUL_SANITY)
        end
        sanity:SetMax(max)
    end

    local hunger = owner.components.hunger
    if hunger ~= nil and soul_data.base_hunger ~= nil then
        local max = soul_data.base_hunger
        for _ = 1, layers do
            max = max * (1 + SOUL_HUNGER)
        end
        hunger:SetMax(max)
    end

    local combat = owner.components.combat
    if combat ~= nil and soul_data.base_combat ~= nil then
        combat.damagemultiplier = soul_data.base_combat * (1 + SOUL_DAMAGE) ^ layers
    end

    -- 恢复当前属性
    if health ~= nil then
        health.currenthealth = old_health  -- 不再调用 SetVal
    end
    if sanity ~= nil then
        sanity.current = old_sanity  -- 不再调用 SetVal
    end
    if hunger ~= nil then
        hunger.current = old_hunger  -- 不再调用 SetVal
    end

    
end

-- 叠加一层梦之魂 buff
local function AddSoulLayer(owner)
    local sd = InitSoulData(owner)
    sd.layers = sd.layers + 1
    local layers = sd.layers

    ApplySoulLayers(owner)

    -- 飘字提示（Talker 会把这句话同步给所有客户端）
    if owner.components.talker ~= nil then
        owner.components.talker:Say("梦之魂第" .. layers .. "层！基础属性全属性增强！")
    end
end

-- 暴露给 modmain：读档/复活后需要重新应用加成
GLOBAL.blacksouls_apply_soul_layers = ApplySoulLayers

-- 吃下梦之魂时的回调
local function OnEaten(inst, eater)
    if eater == nil or not eater:HasTag("player") then
        return
    end

    AddSoulLayer(eater)

    -- ★ 这里绝对不要写 inst:Remove()！
    -- 消耗是由原版 edible.lua 的 HandleEatRemove() 在 OnEaten 之后处理的：
    --   可堆叠 -> components.stackable:Get():Remove()  只吃掉 1 个
    --   否则   -> inst:Remove()
    -- 早期版本在这里 Remove()，会把一整叠梦之魂全部吃掉。
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    -- 掉落/物理（背包物品必需）
    MakeInventoryPhysics(inst)

    -- 动画
    inst.AnimState:SetBank(BUILD)
    inst.AnimState:SetBuild(BUILD)
    inst.AnimState:PlayAnimation(BUILD_IDLE_ANIM, true)

    -- 实体静态部分到此结束
    inst.entity:SetPristine()

    -- 物品标签（影响客户端渲染，必须在 SetPristine 之前）
    inst:AddTag("nosteal")

    -- ★★★ 客户端判断 ★★★
    if not TheWorld.ismastersim then
        return inst
    end

    -- 物品描述
    inst:AddComponent("inspectable")

    -- 物品栏组件（背包物品必需）
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "dream_soul"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/dream_soul.xml"

    -- 可堆叠(读档后掉落非可堆叠组件的问题)
    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = STACK_SIZE
    

    -- 食用组件（核心）——注意：游戏里没有 "consumable" 组件，有这个就够了
    inst:AddComponent("edible")
    inst.components.edible.foodtype = FOODTYPE.GENERIC
    inst.components.edible.healthvalue = 0       -- 吃下不回血
    inst.components.edible.sanityvalue = 0       -- 吃下不回精神
    inst.components.edible.hungervalue = 0       -- 吃下不回饥饿
    inst.components.edible.oneaten = OnEaten     -- 吃下时触发

    if not CONSUMED_ON_EAT then
        -- 不消耗：把原版"吃掉就移除"的行为改成什么都不做
        inst.components.edible.handleremovefn = function() end
    end

    -- 吃东西时的音效（原版存在的事件）纯服务器端
    inst.eatensound = "dontstarve/characters/wortox/soul/spawn"
    

    return inst
end

return Prefab("dream_soul", fn, assets)
