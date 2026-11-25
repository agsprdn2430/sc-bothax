--[PNB v7 | rebuild B'INTERNAL + menu ImGui | docs: https://github.com/BotHax/binternal]
--[Jalankan script SAAT SUDAH DI DALAM world, atur di menu, lalu tekan START]
--[Nilai di bawah hanya default awal, semuanya bisa diubah lewat menu]
--[Gerak: TelePath murni (paket posisi + OnSetPos per hop kecil), TANPA FindPath]

-------------------------------------------------
-- CONFIG (default awal)
-------------------------------------------------
--[Background ID of Magplant][ID background yang ada di belakang Magplant]
BackgroundID = 12840

--[Urutan ambil Magplant]
--[true  = pola Z: baris paling atas dulu, tiap baris dari kiri ke kanan, lalu turun]
--[false = urutan lama: dari kanan ke kiri, bawah ke atas]
MagOrderZ = true

--[Posisi PnB]
--[UseCustomPNB = true -> karakter PnB di tile CustomPNBX, CustomPNBY]
--[UseCustomPNB = false + GetPosPNB = true -> pakai posisi karakter saat START]
UseCustomPNB = true
CustomPNBX = 53
CustomPNBY = 194
GetPosPNB = false

--[Posisi Telephone (untuk convert DL/BGL)]
UseCustomTEL = false
CustomTELX = 0
CustomTELY = 0
GetPosTEL = false

--[Cheat Option]
AutoBuff = false
AutoRemote = false
NoGemsDrop = true
IgnoreOther = false
AntiLag = false
MirrorPNB = true
AutoBuyCheats = true

--[Consumable]
ConsumeArroz = false
ConsumeSongpyeon = false
ConsumeClover = false

--[Auto Convert via Telephone][gems -> DL, DL -> BGL]
ConvertDLBGL = false
ConvertDL = false
--[Gems >= angka ini -> convert ke DL]
MaxGems = 200000
--[DL >= angka ini -> convert ke BGL]
ConvertDLAt = 100

--[Webhook][butuh MakeRequest & os]
WebhookPNB = true
WebhookUrl = "https://discord.com/api/webhooks/1532060254970445845/A1-9I43FIVQ-_T6-qRG9QVZU8gRaUAkEE38oXkO4-SRNjUnfOFfFBYxBbMdRfOIoUhkb"
DiscordID = "460068402631933989"
--[Menit antar laporan]
DelayWebhook = 5
--[Kirim notif saat reconnect]
ReconnectWebhook = true

--[Anti-Speedhack][ms per tile, naikkan ke 100-140 kalau masih rubberband]
AntiSpeedMsPerTile = 50
AntiSpeedMaxStep = 2
DelayStepPath = 100

-------------------------------------------------
-- STATE
-------------------------------------------------
Running = false
BotAlive = false
Status = "Idle"
LogLines = {}

function PLog(msg)
  LogToConsole(msg)
  local clean = tostring(msg):gsub("`.", "")
  table.insert(LogLines, clean)
  while #LogLines > 8 do
    table.remove(LogLines, 1)
  end
end

-------------------------------------------------
-- HELPER
-------------------------------------------------
function InWorld()
  return GetWorld() ~= nil
end

function inv(id)
  if not id then
    return 0
  end
  return GetItemCount(id) or 0
end

function obj(id)
  local total = 0
  for _, object in pairs(GetObjectList()) do
    if object.id == id then
      total = total + object.amount
    end
  end
  return total
end

function GetMag(a, b)
  local found = {}
  local y1, y2, ys = b, 0, -1
  local x1, x2, xs = a, 0, -1
  if MagOrderZ then
    y1, y2, ys = 0, b, 1
    x1, x2, xs = 0, a, 1
  end
  for y = y1, y2, ys do
    for x = x1, x2, xs do
      local t = GetTile(x, y)
      if t and t.fg == 5638 and t.bg == BackgroundID then
        table.insert(found, {x = x, y = y})
      end
    end
  end
  return found
end

function FindTPLeft(x, y)
  SendPacketRaw(false, {
    state = 48,
    x = x * 32,
    y = y * 32,
    px = x,
    py = y
  })
end

local function B01(v)
  return v and 1 or 0
end

function CheatTurnOff()
  local ign = B01(IgnoreOther)
  SendPacket(2, "action|dialog_return\ndialog_name|cheats\ncheck_autofarm|0\ncheck_bfg|0\ncheck_gems|1\n\ncheck_lonely|" .. ign .. "\ncheck_ignoreo|" .. ign .. "\ncheck_ignoref|" .. ign)
end

function CheatTurnOn()
  local ign = B01(IgnoreOther)
  SendPacket(2, "action|dialog_return\ndialog_name|cheats\ncheck_autofarm|1\ncheck_bfg|1\ncheck_autobuff|" .. B01(AutoBuff) .. "\ncheck_autoremote|" .. B01(AutoRemote) .. "\ncheck_gems|" .. B01(NoGemsDrop) .. "\ncheck_lonely|" .. ign .. "\ncheck_ignoreo|" .. ign .. "\ncheck_ignoref|" .. ign)
end

function ApplyAntiLag(on)
  for _, n in ipairs({"name", "particle", "shadow", "world", "object", "player"}) do
    pcall(ChangeValue, "[C] No render " .. n, on and true or false)
  end
end

function SendWebhook(url, data)
  if not url or url == "" then
    return
  end
  MakeRequest(url, "POST", {
    ["Content-Type"] = "application/json"
  }, data)
end

function FNum(num)
  num = tonumber(num) or 0
  if num >= 1.0E9 then
    return string.format("%.2fB", num / 1.0E9)
  elseif num >= 1000000.0 then
    return string.format("%.1fM", num / 1000000.0)
  elseif num >= 1000.0 then
    return string.format("%.0fK", num / 1000.0)
  else
    return tostring(num)
  end
end

function FTime(sec)
  local days = math.floor(sec / 86400)
  local hours = math.floor(sec % 86400 / 3600)
  local minutes = math.floor(sec % 3600 / 60)
  local seconds = math.floor(sec % 60)
  if days > 0 then
    return string.format("%s day %s hour %s minute %s second", days, hours, minutes, seconds)
  elseif hours > 0 then
    return string.format("%s hour %s minute %s second", hours, minutes, seconds)
  elseif minutes > 0 then
    return string.format("%s minute %s second", minutes, seconds)
  end
  return string.format("%s second", seconds)
end

-------------------------------------------------
-- GERAK: TelePath murni (tanpa FindPath / CheckPath)
-------------------------------------------------
local function sign(v)
  return (v > 0 and 1) or (v < 0 and -1) or 0
end

local function CurTile()
  local pl = GetLocal()
  if pl and pl.pos then
    return math.floor(pl.pos.x / 32), math.floor(pl.pos.y / 32)
  end
end

function GoPath(t, s, v, x, y)
  if not InWorld() then
    return
  end
  SendPacketRaw(false, {type = t, state = s, value = v, px = x, py = y, x = x * 32, y = y * 32})
  if t == nil then
    local pl = GetLocal()
    if pl then
      SendVariantList({[0] = "OnSetPos", [1] = {x = x * 32, y = y * 32}}, pl.netid)
    end
  end
end

function gOgOPath(x, y)
  GoPath(3, 1, 0, x, y)
  GoPath(nil, nil, nil, x, y)
end

local function MoveHop(cx, cy, nx, ny)
  local dist = math.abs(nx - cx) + math.abs(ny - cy)
  gOgOPath(nx, ny)
  Sleep(math.floor(math.max(dist, 1) * AntiSpeedMsPerTile))
end

local function WaitReach(nx, ny)
  for _ = 1, 5 do
    if not InWorld() then
      return false
    end
    Sleep(DelayStepPath + math.floor((GetPing() or 0) / 2))
    local px, py = CurTile()
    if px == nx and py == ny then
      return true
    end
  end
  return false
end

function TelePath(tx, ty)
  if not InWorld() then
    return false
  end
  tx, ty = math.floor(tx), math.floor(ty)
  local cx, cy = CurTile()
  if not cx then
    return false
  end
  if cx == tx and cy == ty then
    return true
  end
  local steps, no_progress = 0, 0
  while (cx ~= tx or cy ~= ty) and InWorld() and Running and steps < 1000 do
    steps = steps + 1
    local dx, dy = tx - cx, ty - cy
    local nx, ny = cx, cy
    if math.abs(dx) >= math.abs(dy) then
      nx = cx + sign(dx) * math.min(AntiSpeedMaxStep, math.abs(dx))
    else
      ny = cy + sign(dy) * math.min(AntiSpeedMaxStep, math.abs(dy))
    end
    MoveHop(cx, cy, nx, ny)
    if WaitReach(nx, ny) then
      cx, cy = nx, ny
      no_progress = 0
    else
      local done = false
      if nx ~= cx and cy ~= ty then
        local alt_ny = cy + sign(ty - cy) * math.min(AntiSpeedMaxStep, math.abs(ty - cy))
        MoveHop(cx, cy, cx, alt_ny)
        if WaitReach(cx, alt_ny) then
          cy = alt_ny
          done = true
        end
      end
      if done then
        no_progress = 0
      else
        no_progress = no_progress + 1
        PLog(string.format("`e[PNB] TelePath tidak maju %d (ke %d,%d)", no_progress, tx, ty))
        local px, py = CurTile()
        if px then
          cx, cy = px, py
        end
      end
    end
    if no_progress >= 3 then
      PLog("`4[PNB] TelePath macet, lanjut tanpa sampai tujuan")
      return false
    end
    Sleep(10)
  end
  local px, py = CurTile()
  return px == tx and py == ty
end

-------------------------------------------------
-- CONVERT / WEBHOOK / CONSUME
-------------------------------------------------
function AutoConvert()
  if not ConvertDLBGL or not TelX or not TelY then
    return
  end
  local tx, ty = math.floor(TelX), math.floor(TelY)
  local gems = GetGems() or 0
  local dl = inv(1796)
  local bgl = inv(7188)

  local function Tel(button)
    SendPacket(2, "action|dialog_return\ndialog_name|telephone\nnum|53785|\nx|" .. tx .. "|\ny|" .. ty .. "|\nbuttonClicked|" .. button)
  end

  if dl >= ConvertDLAt then
    PLog("`9[PNB] Convert: DL " .. dl .. " >= " .. ConvertDLAt .. " -> BGL")
    Tel("bglconvert")
    Sleep(1500)
  elseif gems >= MaxGems then
    PLog("`9[PNB] Convert: Gems " .. gems .. " >= " .. MaxGems .. " -> DL")
    Tel("dlconvert")
    Sleep(1500)
  elseif bgl >= 100 then
    PLog("`9[PNB] Convert: BGL " .. bgl .. " >= 100 -> Black Gem Lock")
    SendPacket(2, "action|dialog_return\ndialog_name|info_box\nbuttonClicked|make_bgl")
    Sleep(1500)
  end
end

function SendInfoPNB()
  if not os or not WebhookUrl or WebhookUrl == "" then
    return
  end
  local pg = obj(16668)
  local bg = obj(16916)
  local ig = obj(17470)
  local payload = {
    embeds = {
      {
        title = "<a:verify1:1194823074810445935> PNB LOG",
        fields = {
          {name = "<:npc:1471371280786788405> Account", value = tostring(Nick), inline = false},
          {name = "<:mgp:1194831769858494464> Information", value = tostring(WorldName), inline = false},
          {name = "<:magplant:1380675170603237428> Magplant", value = tostring(Now) .. " / " .. tostring(#Mag), inline = false},
          {name = "<:antidote:1412039873950519348> Consumables", value = inv(1056) .. " <:songpyeon:1412036404292223108> " .. inv(528) .. " <:clover:1412036362735190048> " .. inv(4604) .. " <:arroz:1412036332640800859>", inline = false},
          {name = "<:Worldlock:977344300004294666> Total Locks", value = inv(11550) .. " <:ireng:1344481043864092672> " .. inv(7188) .. " <:bgl:1344293284201369620> " .. inv(1796) .. " <:dl:1370773297930702989>", inline = false},
          {name = "<:gems:1378917469082751067> Current Gems", value = FNum(GetGems()), inline = false},
          {name = "<:gems:1378917469082751067> Gems Drop", value = FNum(bg) .. " <:bgems:1412036304715120791> " .. FNum(pg) .. " <:pgems:1412036250927628369> " .. FNum(ig).. " <:gems:1194831751193825281>", inline = false},
          {name = "<a:rg:1197369816403685396> Uptime", value = FTime(os.time() - StartTime), inline = false}
        },
        footer = {text = "Script Made By DRsc (Today At " .. os.date("%H:%M") .. ")"},
        thumbnail = {url = "https://cdn.discordapp.com/attachments/1526090658996289579/1574834350929748191/b393eccb-4ca4-4fd0-a2f5-13772fd26b2c.png?ex=6b071648&is=6b05c4c8&hm=1b0f7340d22fc4566f135599e40701f28933765283c436cd5ea18c787c37cec7&"}
      }
    }
  }
  SendWebhook(WebhookUrl, json.stringify(payload))
end

function CheckTime()
  if not os or not WebhookPNB then
    return
  end
  local now = os.time()
  if now - (LastTime or 0) >= DelayWebhook * 60 and InWorld() and HasRemote then
    SendInfoPNB()
    Sleep(1000)
    LastTime = now
  end
end

function AutoConsume(id)
  SendPacketRaw(false, {
    type = 3,
    value = id,
    px = pnbX,
    py = pnbY,
    x = pnbX * 32,
    y = pnbY * 32
  })
  Sleep(500)
end

-------------------------------------------------
-- LOGIKA UTAMA PNB
-------------------------------------------------
function AutoPNB()
  if not Running then
    return false
  end
  if not Mag or #Mag == 0 then
    return false
  end
  if not Now or Now < 1 then
    Now = 1
  end
  if Now > #Mag then
    Now = 1
  end
  if Ghost then
    Ghost = false
    Sleep(500)
    SendPacket(2, "action|input\n|text|/ghost")
    if IgnoreOther then
      RequestJoinWorld(WorldName)
      Sleep(2000)
    end
  end
  if Ghost then
    return
  end
  if BlockSB and InWorld() then
    BlockSB = false
    Sleep(500)
    SendPacket(2, "action|input\n|text|/radio")
  end
  if AllMagEmpty then
    if WebhookPNB then
      SendWebhook(WebhookUrl, json.stringify({content = "<@" .. DiscordID .. "> ALL Magplants Are Empty!"}))
    end
    AllMagEmpty = false
  end
  if reconnect then
    reconnect = false
    if ReconnectPending then
      ReconnectPending = false
      SendWebhook(WebhookUrl, json.stringify({content = "<@" .. DiscordID .. "> " .. Nick .. " Is Reconnecting!"}))
    end
    Sleep(2000)
    if not InWorld() then
      RequestJoinWorld(WorldName)
      Sleep(7000)
    else
      return
    end
  elseif arroz and ConsumeArroz and HasRemote and not AutoBuff then
    TelePath(pnbX, pnbY)
    Sleep(2000)
    AutoConsume(4604)
    return true
  elseif clover and ConsumeSongpyeon and HasRemote and not AutoBuff then
    TelePath(pnbX, pnbY)
    Sleep(2000)
    AutoConsume(1056)
    return true
  elseif clover and ConsumeClover and HasRemote and not AutoBuff then
    TelePath(pnbX, pnbY)
    Sleep(2000)
    AutoConsume(528)
    return true
  elseif cheat and AutoBuyCheats then
    SendPacket(2, "action|dialog_return\ndialog_name|buycheat\ndialog_name|cheats\nbuttonClicked|1\n")
    Sleep(5000)
    MagW = false
    HasRemote = false
    CheatOff = true
    Sleep(2000)
    return true
  end
  if CheatOff and not HasRemote then
    Sleep(500)
    CheatOff = false
    CheatTurnOff()
    PLog(("`9[PNB] `1Stop PnB! Last Magplant On #%d"):format(Now))
    Now = (Now == #Mag) and 1 or (Now + 1)
    CheatStopped = true
  end
  if HasRemote then
    if pnbX and pnbY then
      if not Taking then
        local loc = GetLocal()
        if loc and loc.pos then
          local lx = math.floor(loc.pos.x / 32)
          local ly = math.floor(loc.pos.y / 32)
          if lx ~= pnbX or ly ~= pnbY then
            CheatTurnOff()
            TelePath(pnbX, pnbY)
            PendingCheatOn = true
            CheatOn = false
          else
            if PendingCheatOn then
              local loc2 = GetLocal()
              if loc2 and loc2.pos then
                local lx2 = math.floor(loc2.pos.x / 32)
                local ly2 = math.floor(loc2.pos.y / 32)
                if lx2 == pnbX and ly2 == pnbY then
                  PendingCheatOn = false
                  CheatOn = true
                  PLog("`9[PNB] `1Sampai di posisi PnB: CheatOn.")
                  if MirrorPNB then
                    ChangeValue("[C] Ghost mode", true)
                    FindTPLeft(pnbX, pnbY)
                  end
                  Sleep(2000)
                else
                  return
                end
              else
                return
              end
            end
            if CheatOn then
              CheatOn = false
              CheatTurnOn()
              PLog(string.format("`9[PNB] `1Start PnB! Posisi X : `2%d, `1Y : `2%d", pnbX, pnbY))
            end
            AutoConvert()
            if MagEmpty then
              CheatOff = true
            end
            Sleep(2000)
          end
        end
        CheckTime()
      end
      return true
    elseif not InWorld() then
      return
    end
  else
    local m = Mag[Now]
    if m and m.x and m.y then
      if CheatStopped then
        Sleep(500)
        TelePath(m.x, m.y - 1)
        local cur = Mag[Now]
        SendPacketRaw(false, {type = 3, value = 32, px = cur.x, py = cur.y, x = cur.x * 32, y = cur.y * 32})
        Sleep(500)
        SendPacket(2, "action|dialog_return\ndialog_name|magplant_edit\nx|" .. cur.x .. "|\ny|" .. cur.y .. "|\nbuttonClicked|getRemote\n")
        return true
      else
        Sleep(500)
      end
    elseif not m then
      Now = (Now == #Mag) and 1 or (Now + 1)
      PLog("`9[PNB] `1AutoPNB: Magplant sekarang hilang, lanjut ke berikutnya.")
      local nextm = Mag[Now]
      if nextm and nextm.x and nextm.y then
        TelePath(nextm.x, nextm.y - 1)
        return true
      end
    end
  end
  return false
end

--[Hook 'call' (OnVariant): function(var, netid, delay)]
local function OnVariant(var, netid, delay)
  if not Running then
    return false
  end
  local ev = var[0]
  local v1 = var[1]
  local v2 = var[2]
  if not InWorld() then
    reconnect = true
    if WebhookPNB and ReconnectWebhook then
      ReconnectPending = true
    end
  elseif ev == "OnSDBroadcast" then
    SendPacket(2, "action|input\n|text|/radio")
  elseif type(v1) == "string" and v1:find("backpack slots.") then
    Ghost = not v1:find("Ghost in the shell")
    arroz = not v1:find("Breaking Gems")
    clover = not v1:find("Lucky!")
    cheat = not v1:find("Cheater")
    return true
  elseif ev == "OnConsoleMessage" and type(v1) == "string" then
    if v1:find("Radio enabled,") then
      BlockSB = true
    end
    if v1:find("World Locked") then
      MagW = false
      HasRemote = false
      if not v1:find(WorldName, 1, true) then
        Ghost = true
        RequestJoinWorld(WorldName)
      end
    end
    if v1:find("Your luck has worn off.") then
      clover = true
    end
    if v1:find("Your stomach's rumbling.") then
      arroz = true
    end
    if v1:find("boringness.") then
      cheat = true
    end
    if v1:find("You're luckier than before!") then
      clover = false
    end
    if v1:find("chance of a gem") then
      arroz = false
    end
    if v1:find("cheater!") then
      cheat = false
    end
  end
  if not MagW and not Ghost then
    MagW = true
  end
  if ev == "OnTalkBubble" and type(v2) == "string" then
    if v2:find("You received a MAGPLANT 5000 Remote") then
      HasRemote = true
      PendingCheatOn = true
      Taking = false
      MagEmpty = false
    elseif v2:find("The MAGPLANT 5000 is empty") then
      CheatOff = true
      HasRemote = false
      MagW = false
      CheatStopped = false
      Taking = true
      MagEmpty = true
      if WebhookPNB and Now == #Mag then
        AllMagEmpty = true
      end
    end
  end
  return false
end

-------------------------------------------------
-- INIT + BOT THREAD
-------------------------------------------------
function Init()
  if not GetWorld() or not GetLocal() then
    error("Masuk ke world dulu, baru tekan START")
  end
  pcall(ChangeValue, "[C] Modfly", true)
  ApplyAntiLag(AntiLag)
  WorldName = GetWorld().name or "Unknown"
  Nick = GetLocal().name:gsub("`(%S)", ""):match("%S+") or "Player"
  local lp = GetLocal()
  local curX, curY = math.floor(lp.pos.x / 32), math.floor(lp.pos.y / 32)
  pnbX, pnbY, TelX, TelY = nil, nil, nil, nil
  if GetPosPNB then
    pnbX, pnbY = curX, curY
  end
  if GetPosTEL then
    TelX, TelY = curX, curY
  end
  if UseCustomTEL then
    TelX, TelY = CustomTELX, CustomTELY
  end
  if UseCustomPNB then
    pnbX, pnbY = CustomPNBX, CustomPNBY
  end
  if not pnbX or not pnbY then
    pnbX, pnbY = curX, curY
  end
  if not os then
    WebhookPNB = false
  end
  StartTime = os and os.time() or 0
  LastTime = 0
  Now = 1
  BlockSB = true
  reconnect = false
  ReconnectPending = false
  HasRemote = false
  CheatStopped = true
  CheatOff = false
  CheatOn = false
  Ghost = false
  MagW = false
  Taking = false
  PendingCheatOn = false
  MagEmpty = false
  AllMagEmpty = false
  arroz, clover, cheat = nil, nil, nil
  local w = GetWorld()
  if w and w.width and w.width > 0 and w.height and w.height > 0 then
    Mag = GetMag(w.width - 1, w.height - 1)
  elseif GetTile(209, 0) then
    Mag = GetMag(209, 209)
  elseif GetTile(199, 0) then
    Mag = GetMag(199, 199)
  elseif GetTile(149, 0) then
    Mag = GetMag(149, 149)
  elseif GetTile(99, 0) then
    Mag = GetMag(99, 59)
  elseif GetTile(29, 0) then
    Mag = GetMag(29, 29)
  end
  Mag = Mag or {}
  PLog("`9[PNB] Magplant ditemukan: " .. #Mag .. " | urutan: " .. (MagOrderZ and "Z (atas->bawah, kiri->kanan)" or "lama") .. " | PnB tile: " .. tostring(pnbX) .. "," .. tostring(pnbY))
end

local function BotMain()
  BotAlive = true
  Running = true
  Status = "Inisialisasi..."
  local ok, err = pcall(Init)
  if not ok then
    PLog("`4[PNB] Init gagal: " .. tostring(err))
    Status = "Init gagal"
    Running = false
    BotAlive = false
    return
  end
  if #Mag == 0 then
    PLog("`7Please Set Magplant Background (cek Background ID)")
    Status = "Magplant tidak ketemu"
    Running = false
    BotAlive = false
    return
  end
  Status = "Berjalan"
  PLog("`8Please Wait A Moment...")
  Sleep(1000)
  if AutoBuyCheats then
    SendPacket(2, "action|dialog_return\ndialog_name|buycheat\ndialog_name|cheats\nbuttonClicked|1\n")
    Sleep(1000)
  end
  RemoveHook("pnb_variant")
  AddHook("call", "pnb_variant", OnVariant)
  Sleep(1000)
  if BlockSB then
    BlockSB = false
    Sleep(500)
    SendPacket(2, "action|input\n|text|/radio")
    Sleep(1000)
  end
  CheatTurnOff()
  PLog("`9[PNB] `1PnB On Progress...")
  Sleep(1000)
  while Running do
    Sleep(500)
    local ok2, e2 = pcall(AutoPNB)
    if not ok2 then
      PLog("`4[PNB] error: " .. tostring(e2))
      Sleep(2000)
    end
  end
  RemoveHook("pnb_variant")
  if InWorld() then
    CheatTurnOff()
  end
  if Status == "Menghentikan..." then
    Status = "Dihentikan"
  end
  BotAlive = false
end

-------------------------------------------------
-- MENU IMGUI
-------------------------------------------------
local function CB(label, v)
  local changed, nv = ImGui.Checkbox(label, v and true or false)
  if changed then
    return nv
  end
  return v
end

local function IN(label, v, step)
  ImGui.SetNextItemWidth(150)
  local changed, nv = ImGui.InputInt(label, math.floor(v or 0), step or 1, (step or 1) * 10)
  if changed then
    return nv
  end
  return v
end

local function TX(label, v)
  ImGui.SetNextItemWidth(230)
  local changed, nv = ImGui.InputText(label, tostring(v or ""), 0)
  if changed then
    return nv
  end
  return v
end

local function UIRender(delta)
  ImGui.SetNextWindowPos(ImVec2(30, 60), ImGui.Cond.FirstUseEver)
  ImGui.SetNextWindowSize(ImVec2(390, 540), ImGui.Cond.FirstUseEver)
  local visible = ImGui.Begin("PNB B'INTERNAL")
  if visible then
    --[Status]
    local color = Running and ImVec4(0.3, 1, 0.3, 1) or ImVec4(1, 0.65, 0.2, 1)
    ImGui.TextColored(color, "Status: " .. tostring(Status))
    ImGui.Text("World: " .. tostring(WorldName or "-") .. ((not WorldName or InWorld()) and "" or "  (di luar world)"))
    if Running then
      local mode = (reconnect and "Reconnect") or (HasRemote and "PnB") or "Ambil Magplant"
      ImGui.Text("Mode: " .. mode)
      ImGui.Text("Magplant: " .. tostring(Now or 0) .. "/" .. tostring(Mag and #Mag or 0) .. "   PnB: " .. tostring(pnbX) .. "," .. tostring(pnbY))
      ImGui.Text("Gems: " .. FNum(GetGems()) .. "   DL: " .. tostring(inv(1796)) .. "   BGL: " .. tostring(inv(7188)))
      ImGui.Text("Ping: " .. tostring(GetPing() or 0))
      if os and StartTime and StartTime > 0 then
        ImGui.Text("Uptime: " .. FTime(os.time() - StartTime))
      end
    end
    --[Start / Stop]
    if not Running then
      ImGui.BeginDisabled(BotAlive)
      if ImGui.Button("START", ImVec2(120, 38)) then
        BotAlive = true
        Running = true
        RunThread(BotMain)
      end
      ImGui.EndDisabled()
    else
      if ImGui.Button("STOP", ImVec2(120, 38)) then
        Running = false
        Status = "Menghentikan..."
      end
    end
    ImGui.Separator()
    --[Tabs]
    if ImGui.BeginTabBar("pnb_tabs") then
      if ImGui.BeginTabItem("PNB") then
        ImGui.BeginDisabled(Running)
        BackgroundID = IN("Background ID Magplant", BackgroundID)
        MagOrderZ = CB("Urutan Magplant pola Z", MagOrderZ)
        ImGui.Separator()
        GetPosPNB = CB("PnB di posisi saat START", GetPosPNB)
        UseCustomPNB = CB("Pakai posisi PnB custom", UseCustomPNB)
        CustomPNBX = IN("PnB X", CustomPNBX)
        CustomPNBY = IN("PnB Y", CustomPNBY)
        ImGui.Separator()
        GetPosTEL = CB("Telephone di posisi saat START", GetPosTEL)
        UseCustomTEL = CB("Pakai posisi Telephone custom", UseCustomTEL)
        CustomTELX = IN("Telephone X", CustomTELX)
        CustomTELY = IN("Telephone Y", CustomTELY)
        ImGui.EndDisabled()
        ImGui.TextDisabled("Dikunci saat bot jalan")
        ImGui.EndTabItem()
      end
      if ImGui.BeginTabItem("Cheat") then
        AutoBuff = CB("Auto Buff", AutoBuff)
        AutoRemote = CB("Auto Remote", AutoRemote)
        NoGemsDrop = CB("No Gems Drop", NoGemsDrop)
        IgnoreOther = CB("Ignore Other", IgnoreOther)
        MirrorPNB = CB("Mirror PnB", MirrorPNB)
        AutoBuyCheats = CB("Auto Buy Cheats", AutoBuyCheats)
        local al = CB("Anti Lag", AntiLag)
        if al ~= AntiLag then
          AntiLag = al
          if Running then
            ApplyAntiLag(al)
          end
        end
        ImGui.Separator()
        ImGui.Text("Consumable")
        ConsumeArroz = CB("Arroz", ConsumeArroz)
        ConsumeSongpyeon = CB("Songpyeon", ConsumeSongpyeon)
        ConsumeClover = CB("Clover", ConsumeClover)
        ImGui.TextDisabled("Consumable hanya jalan kalau Auto Buff mati")
        ImGui.EndTabItem()
      end
      if ImGui.BeginTabItem("Convert") then
        ConvertDLBGL = CB("Auto convert via Telephone", ConvertDLBGL)
        ConvertDL = CB("Convert DL", ConvertDL)
        MaxGems = IN("Gems >= (-> DL)", MaxGems, 10000)
        ConvertDLAt = IN("DL >= (-> BGL)", ConvertDLAt, 10)
        ImGui.EndTabItem()
      end
      if ImGui.BeginTabItem("Speed") then
        AntiSpeedMsPerTile = math.max(10, IN("ms per tile", AntiSpeedMsPerTile, 10))
        AntiSpeedMaxStep = math.max(1, IN("Max tile per hop", AntiSpeedMaxStep))
        DelayStepPath = math.max(10, IN("Delay cek posisi (ms)", DelayStepPath, 10))
        ImGui.TextWrapped("Kena kick / rubberband: naikkan ms per tile (100-140) dan turunkan max tile per hop ke 1.")
        ImGui.EndTabItem()
      end
      if ImGui.BeginTabItem("Webhook") then
        WebhookPNB = CB("Aktifkan webhook", WebhookPNB)
        WebhookUrl = TX("URL", WebhookUrl)
        DiscordID = TX("Discord ID", DiscordID)
        DelayWebhook = math.max(1, IN("Menit antar laporan", DelayWebhook))
        ReconnectWebhook = CB("Notif saat reconnect", ReconnectWebhook)
        ImGui.BeginDisabled(not (BotAlive and os and WebhookPNB))
        if ImGui.Button("Tes kirim laporan", ImVec2(160, 0)) then
          RunThread(SendInfoPNB)
        end
        ImGui.EndDisabled()
        if not os then
          ImGui.TextDisabled("API os tidak tersedia, webhook nonaktif")
        end
        ImGui.EndTabItem()
      end
      ImGui.EndTabBar()
    end
    ImGui.Separator()
    ImGui.Text("Log")
    for _, line in ipairs(LogLines) do
      ImGui.TextWrapped(line)
    end
  end
  ImGui.End()
end

RemoveHook("pnb_ui")
AddHook("draw", "pnb_ui", UIRender)
PLog("`2[PNB] Menu ImGui siap, atur lalu tekan START")
