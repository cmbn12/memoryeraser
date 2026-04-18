AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/props_combine/combine_interface001.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    local victim = nil
    local radius = 250
    local found = ents.FindInSphere(self:GetPos(), radius)

    for _, ent in ipairs(found) do
        if IsValid(ent) and ent:GetClass() == "prop_vehicle_prisoner_pod" then
            local driver = ent:GetDriver()
            if IsValid(driver) and driver:IsPlayer() then
                victim = driver
                break
            end
        end
    end

    if IsValid(victim) then
        if _G.StartMemoryEraser then
            _G.StartMemoryEraser(victim, activator, self)
        else
            activator:ChatPrint("Система очистки памяти не загружена")
        end
    else
        activator:ChatPrint("Капсула пуста или не обнаружена.")
        self:EmitSound("buttons/combine_button_locked.wav")
    end
end