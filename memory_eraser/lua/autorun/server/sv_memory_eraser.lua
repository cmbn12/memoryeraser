if SERVER then
    util.AddNetworkString("Combine_StartSterilization")
    util.AddNetworkString("ME_ResetClient")

    local files = {
        "materials/memory_eraser/brain_slide.vmt", "materials/memory_eraser/brain_slide.vtf",
        "materials/memory_eraser/brain_slide2.vmt", "materials/memory_eraser/brain_slide2.vtf",
        "sound/memory_eraser/heartbeat.wav", "sound/memory_eraser/breath.wav", "sound/memory_eraser/alarm.wav",
        "sound/memory_eraser/memory.mp3", "sound/memory_eraser/passivemusic.ogg",
        "resource/fonts/cpmonorusbold.ttf"
    }
    for _, f in ipairs(files) do resource.AddFile(f) end
end

local ME_CFG = {
    DUR_TOTAL = 37, DUR_PROCESS = 12, DUR_START = 4.5, DUR_UNFREEZE = 18, DUR_SLOW = 120,
    SOUNDS = {
        LOOP = "ambient/machines/combine_terminal_loop1.wav", END = "buttons/combine_button7.wav",
        LOCKED = "buttons/combine_button_locked.wav", START = "buttons/combine_button3.wav",
        IDLES = {"ambient/machines/combine_terminal_idle1.wav","ambient/machines/combine_terminal_idle2.wav","ambient/machines/combine_terminal_idle3.wav","ambient/machines/combine_terminal_idle4.wav"}
    }
}

local function ResetPlayerStatus(ply)
    if not IsValid(ply) then return end
    ply.ME_IsProcessing = false
    ply.ME_SlowUntil = nil
    
    ply:Freeze(false)
    
    if ply.ME_OldJumpPower then
        ply:SetJumpPower(ply.ME_OldJumpPower)
        ply.ME_OldJumpPower = nil
    else
        ply:SetJumpPower(200)
    end

    ply:StopSound(ME_CFG.SOUNDS.LOOP)
    local tIdx = ply:EntIndex()
    timer.Remove("ME_Ambient_"..tIdx) timer.Remove("ME_Finalize_"..tIdx) timer.Remove("ME_Unlock_"..tIdx)
    net.Start("ME_ResetClient") net.Send(ply)
end

hook.Add("PlayerSpawn", "ME_ResetOnSpawn", ResetPlayerStatus)
hook.Add("PlayerDeath", "ME_CleanupOnDeath", ResetPlayerStatus)
hook.Add("PlayerDisconnected", "ME_CleanupOnDisconnect", ResetPlayerStatus)

hook.Add("SetupMove", "ME_Slowdown", function(ply, mv, cmd)
    if ply.ME_SlowUntil and CurTime() < ply.ME_SlowUntil then
        local currentWalk = ply:GetWalkSpeed()
        local currentRun = ply:GetRunSpeed()

        local targetSpeed = (mv:KeyDown(IN_SPEED) and currentRun or currentWalk) * 0.2

        mv:SetMaxSpeed(targetSpeed)
        mv:SetMaxClientSpeed(targetSpeed)

        if bit.band(mv:GetButtons(), IN_JUMP) ~= 0 then
            mv:SetButtons(bit.band(mv:GetButtons(), bit.bnot(IN_JUMP)))
        end
    elseif ply.ME_SlowUntil and CurTime() >= ply.ME_SlowUntil then
        ResetPlayerStatus(ply)
    end
end)

function StartMemoryEraser(victim, activator, terminal)
    if not IsValid(victim) or not victim:IsPlayer() then return end
    local curT = CurTime()
    
    if victim.ME_IsProcessing then
        if IsValid(activator) then activator:ChatPrint("Субъект уже в процессе.") activator:EmitSound(ME_CFG.SOUNDS.LOCKED) end
        return
    end

    victim.ME_IsProcessing = true
    victim:Freeze(true)

    local src = IsValid(terminal) and terminal or victim
    src:EmitSound(ME_CFG.SOUNDS.LOOP, 75, 100, 0.5)
    
    local idx = victim:EntIndex()
    timer.Create("ME_Ambient_"..idx, 2.5, 5, function()
        if IsValid(src) and IsValid(victim) and victim.ME_IsProcessing then 
            src:EmitSound(table.Random(ME_CFG.SOUNDS.IDLES),70,100,0.4) 
        end
    end)

    timer.Create("ME_Finalize_"..idx, ME_CFG.DUR_START+ME_CFG.DUR_PROCESS, 1, function()
        if IsValid(src) then src:StopSound(ME_CFG.SOUNDS.LOOP) src:EmitSound(ME_CFG.SOUNDS.END,80,100,0.7) end
    end)

    net.Start("Combine_StartSterilization") net.Send(victim)
    victim:ChatPrint("Капсула заблокировалась...")

    timer.Simple(ME_CFG.DUR_UNFREEZE, function()
        if not IsValid(victim) then return end
        victim:Freeze(false) 
        if victim:InVehicle() then victim:ExitVehicle() end

        victim.ME_OldJumpPower = victim:GetJumpPower()
        victim:SetJumpPower(0)

        victim.ME_SlowUntil = CurTime() + ME_CFG.DUR_SLOW
        victim:ChatPrint("Вы чувствуете тошноту и звон в ушах...")
        
        timer.Simple(2, function() if IsValid(victim) then victim:ChatPrint("Где я?.. Почему я здесь?") end end)
    end)

    timer.Create("ME_Unlock_"..idx, ME_CFG.DUR_TOTAL, 1, function() 
        if IsValid(victim) then victim.ME_IsProcessing = false end 
    end)

    if IsValid(activator) and activator ~= victim then 
        activator:ChatPrint("Стерилизация "..victim:Nick().." активирована.") 
        activator:EmitSound(ME_CFG.SOUNDS.START) 
    end
end

hook.Add("PlayerSay", "Combine_EraseCommand", function(ply, txt)
    if txt:lower() == "/erase" then
        local tr = ply:GetEyeTrace()
        local target = IsValid(tr.Entity) and tr.Entity:IsPlayer() and tr.Entity or ply
        StartMemoryEraser(target, ply)
        return ""
    end
end)

concommand.Add("me_reset_status", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    local target = args[1] and player.GetByID(tonumber(args[1])) or ply
    if IsValid(target) then
        ResetPlayerStatus(target)
        if IsValid(ply) then ply:ChatPrint("Статус для "..target:Nick().." сброшен.") end
    end
end)