local prefab_id = "cape"
local assets_id = "redhat"
local BUILD_NAME = "swap_yukinoa_redhat"
local BUILDNAME = "yukinoa_redhat"

local assets =
{
    Asset("ANIM", "anim/" .. assets_id .. ".zip"),
    Asset("ANIM", "anim/swap_" .. assets_id .. ".zip"),
    Asset("ATLAS", "images/inventoryimages/" .. assets_id .. ".xml"),
}

local prefabs =
{
    prefab_id,
}

---onequipfn
---@param inst ent
---@param owner ent
---@param from_ground boolean
local function onequip(inst, owner, from_ground)
    owner.AnimState:OverrideSymbol("swap_body", BUILD_NAME, BUILD_NAME)
end

---onunequipfn
---@param inst ent
---@param owner ent
local function onunequip(inst, owner)
    owner.AnimState:ClearOverrideSymbol("swap_body")
end

-- local function OnCharged(inst)
--     if inst.components.armor then
--         inst.components.armor:SetAbsorption(0.85)
--     end
-- end

-- local function OnDischarged(inst)
--     if inst.components.armor then
--         inst.components.armor:SetAbsorption(0.95)
--     end
-- end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()
    inst.entity:AddSoundEmitter()
    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank(BUILDNAME)
    inst.AnimState:SetBuild(BUILDNAME)
    inst.AnimState:PlayAnimation("idle", true)

    MakeInventoryFloatable(inst, "med", nil, 0.75)

    inst.entity:SetPristine()

    inst:AddTag("nosteal")
    inst:AddTag("cape")

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = assets_id
    inst.components.inventoryitem.atlasname = "images/inventoryimages/" .. assets_id .. ".xml"

    inst:AddComponent("equippable")
    inst.components.equippable.equipslot = EQUIPSLOTS.BODY  -- 确认槽位是否支持
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)

    inst:AddComponent("armor")
    inst.components.armor:InitIndestructible(0.85)
    inst.components.armor:SetOnFinished(function() end)

    --- 保暖属性设置
    inst:AddComponent("insulator")
    inst.components.insulator:SetInsulation(240)
    inst.components.insulator:SetWinter()

    -- inst:AddComponent("rechargeable")
    -- inst.components.rechargeable:SetChargeTime(2400)
    -- inst.components.rechargeable:SetOnChargedFn(OnCharged)
    -- inst.components.rechargeable:SetOnDischargedFn(OnDischarged)
    -- inst.components.rechargeable:SetCharge(2400, true)

    return inst
end

return Prefab("common/inventory/" .. prefab_id, fn, assets, prefabs)