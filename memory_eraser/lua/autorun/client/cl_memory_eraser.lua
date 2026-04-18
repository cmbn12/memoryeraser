local surface, draw, math, net, timer = surface, draw, math, net, timer
local CurTime, LocalPlayer = CurTime, LocalPlayer
local DUR_HELMET, DUR_ERASE, DUR_DIZZY = 1.2, 12, 120
local MAX_SOUND_DURATION = 90 -- Лимит проигрывания звуков (1.5 минуты)

-- Хранилище таймеров
local activeTimers = {}
local function SafeTimer(name, delay, reps, func)
    timer.Remove("ME_"..name)
    timer.Create("ME_"..name, delay, reps, func)
    table.insert(activeTimers, "ME_"..name)
end
local function SafeSimple(delay, func)
    local id = "ME_Simple_"..CurTime()..math.random(1000)
    timer.Simple(delay, function() func() for i,v in ipairs(activeTimers) do if v==id then table.remove(activeTimers,i) break end end end)
    table.insert(activeTimers, id)
end
local function StopAllTimers() for _,n in ipairs(activeTimers) do timer.Remove(n) end activeTimers = {} end

local ME = {
    active = false,
    helmetClosing = false,
    helmetOpening = false,
    helmetOn = false,
    helmetStart = 0,
    isErasing = false,
    isFlashing = false,
    fadeStart = 0,
    dizzyEnd = 0,
    startTime = 0,
    soundCutoff = 0, -- Время, когда звуки должны замолчать
    logs = {},
    nextLog = 0,
    brainAlpha = 0,
    mats = {
        brain1 = Material("memory_eraser/brain_slide"),
        brain2 = Material("memory_eraser/brain_slide2"),
        static = Material("effects/combine_binocoverlay")
    },
    snd = { music = nil, loop = nil }
}

-- СПИСОК ФОНОВЫХ ЗВУКОВ
local postEraseSounds = {
    "npc/combine_soldier/vo/prison_soldier_bunker1.wav",
    "npc/combine_soldier/vo/prison_soldier_bunker3.wav",
    "npc/overwatch/cityvoice/f_anticitizenreport_spkr.wav",
    "npc/overwatch/radiovoice/allunitsbeginwhitnesssterilization.wav",
    "npc/stalker/breathing3.wav",
    "npc/overwatch/cityvoice/f_anticitizenreport_spkr.wav",
    "ambient/voices/playground_memory.wav",
    "ambient/levels/streetwar/city_scream3.wav",
    "ambient/levels/citadel/strange_talk"..math.random(1,11)..".wav",
    "ambient/voices/citizen_beaten3.wav",
    "doors/door_chainlink_close1.wav",
    "npc/overwatch/radiovoice/youarechargedwithterminal.wav",
    "npc/zombie/zombie_voice_idle14.wav",
    "vo/Breencast/br_welcome02.wav",
    "vo/Breencast/br_collaboration02.wav",
    "vo/Breencast/br_welcome07.wav",
    "vo/Breencast/br_instinct21.wav",
    "vo/Breencast/br_instinct22.wav",
    "vo/Breencast/br_instinct23.wav",
    "vo/Breencast/br_collaboration08.wav",
    "vo/Breencast/br_collaboration05.wav"
}

-- Функция для проигрывания уникальных звуков
local function PlayUniqueSequence(availableSounds)
    -- ПРОВЕРКА: Если процедура окончена, звуки кончились ИЛИ прошло 1.5 минуты — выходим
    if not ME.active or #availableSounds == 0 or CurTime() >= ME.soundCutoff then 
        return 
    end

    local idx = math.random(#availableSounds)
    local snd = availableSounds[idx]
    table.remove(availableSounds, idx)

    LocalPlayer():EmitSound(snd, 35, math.random(65, 105), 0.4)

    -- Интервал между звуками (от 5 до 10 секунд)
    SafeSimple(math.random(5, 10), function()
        PlayUniqueSequence(availableSounds)
    end)
end

local combineLogs = {
    "> ИНИЦИАЛИЗАЦИЯ...", "> ПОДКЛЮЧЕНИЕ...", "> СКАНИРОВАНИЕ...",
    "> АНАЛИЗ ДАННЫХ...", "> ВЫЯВЛЕНЫ ПАТТЕРНЫ...", "> ОЧИСТКА...",
    "> УДАЛЕНИЕ НЕЙРОНОВ...", "> ПЕРЕЗАПИСЬ НЕЙРОНОВ...", "> СИНХРОНИЗАЦИЯ...",
    "> ПРОВЕРКА...", "> СТАБИЛИЗАЦИЯ...", "> ЗАВЕРШЕНИЕ..."
}

local scrW, scrH = ScrW(), ScrH()
hook.Add("OnScreenSizeChanged", "ME_Res", function() scrW, scrH = ScrW(), ScrH() end)
surface.CreateFont("gtasa", {font="gtasa Bold", size=22, weight=800, antialias=false})

local function ResetClientState()
if stopMusic and ME.snd.music and ME.snd.music:IsPlaying() then 
        ME.snd.music:Stop() 
        ME.snd.music = nil
    end
    if ME.snd.loop and ME.snd.loop:IsPlaying() then 
        ME.snd.loop:Stop() 
        ME.snd.loop = nil
    end
    StopAllTimers()
    table.Empty(ME.logs)
    ME.active, ME.helmetClosing, ME.helmetOpening, ME.helmetOn, ME.isErasing, ME.isFlashing = false, false, false, false, false, false
    ME.helmetStart, ME.fadeStart, ME.dizzyEnd, ME.startTime, ME.nextLog, ME.brainAlpha, ME.soundCutoff = 0,0,0,0,0,0,0
end

hook.Add("PlayerDeath", "ME_Reset", ResetClientState)
hook.Add("PlayerSpawn", "ME_Reset", ResetClientState)
hook.Add("PlayerDisconnected", "ME_Reset", ResetClientState)
net.Receive("ME_ResetClient", ResetClientState)

net.Receive("Combine_StartSterilization", function()
    ResetClientState()
    ME.active, ME.helmetClosing, ME.helmetStart = true, true, CurTime()
    surface.PlaySound("doors/door_metal_thin_move1.wav")
    SafeSimple(1.2, function() if ME.active then surface.PlaySound("memory_eraser/breath.wav") end end)
    
    SafeSimple(4.5, function()
        if not ME.active then return end
        ME.helmetClosing, ME.helmetOn, ME.isErasing, ME.startTime = false, true, true, CurTime()
        local ply = LocalPlayer()
        
        SafeTimer("Heartbeat_"..ply:EntIndex(), 0.9, 0, function()
            if not ME.active or not ME.isErasing then timer.Remove("ME_Heartbeat_"..ply:EntIndex()) return end
            surface.PlaySound("memory_eraser/heartbeat.wav")
            timer.Adjust("ME_Heartbeat_"..ply:EntIndex(), math.Remap(math.Clamp((CurTime()-ME.startTime)/DUR_ERASE,0,1),0,1,0.9,0.25))
        end)

        ME.snd.loop = CreateSound(ply, "memory_eraser/memory.wav")
        ME.snd.loop:PlayEx(0.5, 100)

        -- Устанавливаем время отключения звуков (текущее время + 1.5 минуты)
        ME.soundCutoff = CurTime() + MAX_SOUND_DURATION
        
        -- Запускаем цепочку уникальных звуков (вместо старой строки SafeSimple)
        local currentSessionSounds = table.Copy(postEraseSounds)
        SafeSimple(2, function() 
            PlayUniqueSequence(currentSessionSounds)
        end)
    end)
    
    SafeSimple(4.5 + DUR_ERASE, function()
        if not ME.active then return end
        if ME.snd.loop then ME.snd.loop:Stop() end
        ME.isErasing, ME.helmetOn, ME.isFlashing = false, false, true
        surface.PlaySound("ambient/energy/whiteflash.wav")
        
        ME.snd.music = CreateSound(LocalPlayer(), "memory_eraser/passivemusic.ogg")
        ME.snd.music:PlayEx(0.7, 100)

        SafeSimple(1.5, function()
            if not ME.active then return end
            ME.isFlashing, ME.helmetOpening, ME.helmetStart = false, true, CurTime()
            ME.fadeStart, ME.dizzyEnd = CurTime(), CurTime() + DUR_DIZZY
            surface.PlaySound("doors/door_metal_thin_open1.wav")
            surface.PlaySound("memory_eraser/breath.wav")
            SafeSimple(DUR_HELMET, function() ME.helmetOpening = false end)
            SafeSimple(DUR_DIZZY, function() ME.active = false end)
        end)
    end)
end)

hook.Add("HUDPaint", "ME_HUD", function()
    if not ME.active then return end
    local ct = CurTime()

    if ME.helmetClosing or ME.helmetOpening then
        local p = math.Clamp((ct - ME.helmetStart) / DUR_HELMET, 0, 1)
        if ME.helmetOpening then p = 1 - p end
        local h = scrH * 0.5 * p
        surface.SetDrawColor(0,0,0,255)
        surface.DrawRect(0,0,scrW,h)
        surface.DrawRect(0,scrH-h,scrW,h)
    end

    if ME.isErasing or ME.helmetOn then
        surface.SetDrawColor(0,0,0,255)
        surface.DrawRect(0,0,scrW,scrH)

        if ME.isErasing then
            local prog = math.Clamp((ct - ME.startTime) / DUR_ERASE, 0, 1)
            ME.brainAlpha = math.Approach(ME.brainAlpha, 100 + prog*155, 2)

            surface.SetMaterial((math.floor(ct*12)%2==0) and ME.mats.brain1 or ME.mats.brain2)
            surface.SetDrawColor(255,255,255, ME.brainAlpha)
            surface.DrawTexturedRect(0,0,scrW,scrH)

            surface.SetMaterial(ME.mats.static)
            surface.SetDrawColor(0,150,255, 20 + math.sin(ct*20)*10)
            surface.DrawTexturedRect(0,0,scrW,scrH)

            surface.SetDrawColor(255,255,255, prog*180)
            surface.DrawRect(0,0,scrW,scrH)

            if ct > ME.nextLog and #ME.logs < #combineLogs then
                table.insert(ME.logs, combineLogs[#ME.logs+1])
                ME.nextLog = ct + (DUR_ERASE / #combineLogs)
                surface.PlaySound("ambient/levels/prison/radio_random"..math.random(1,15)..".wav")
            end
            for i, text in ipairs(ME.logs) do
                draw.SimpleText(text, "gtasa", 40, scrH*0.2 + i*22, Color(0,180,255,200))
            end

            draw.SimpleText("СТЕРИЛИЗАЦИЯ: "..math.floor(prog*100).."%", "gtasa", scrW/2, scrH*0.82, Color(0,180,255,200), 1)
            surface.SetDrawColor(0,80,150,100)
            surface.DrawOutlinedRect(scrW/2-150, scrH*0.85, 300, 10)
            surface.SetDrawColor(0,180,255,200)
            surface.DrawRect(scrW/2-150, scrH*0.85, 300*prog, 10)
        end
    end

    if ME.isFlashing then
        surface.SetDrawColor(255,255,255,255)
        surface.DrawRect(0,0,scrW,scrH)
    elseif ME.fadeStart > 0 and ct < ME.fadeStart + 2 then
        surface.SetDrawColor(255,255,255, (1 - (ct-ME.fadeStart)*0.5)*255)
        surface.DrawRect(0,0,scrW,scrH)
    end
end)

hook.Add("RenderScreenspaceEffects", "ME_FX", function()
    if ME.active and ME.dizzyEnd > 0 and CurTime() < ME.dizzyEnd then
        DrawMotionBlur(0.1, 0.8 * math.Clamp((ME.dizzyEnd-CurTime())/DUR_DIZZY,0,1), 0.02)
    end
end)

hook.Add("CalcView", "ME_View", function(ply, pos, ang, fov)
    if ME.active and ME.dizzyEnd > 0 and CurTime() < ME.dizzyEnd then
        local s = math.Clamp((ME.dizzyEnd-CurTime())/DUR_DIZZY,0,1)
        local t = CurTime()
        return {origin=pos, angles=ang+Angle(math.sin(t*2)*5*s, 0, math.cos(t)*3*s), fov=fov}
    end
end)