-- Pigeon Post: Post an die eigenen Chars, sicher und mit einem Klick pro Brief.
-- Grundregeln, die nie gebrochen werden:
--   1. Empfänger nur aus dem eigenen Register. Ein Char kommt nur hinein, wenn man sich mit ihm einloggt.
--   2. Kein Gold, keine Nachnahme. SetSendMailMoney und SetSendMailCOD kommen im Code nicht vor.
--   3. Ein Klick, höchstens ein Brief.
--   4. Die Leiste zeigt vorher genau den Brief, der rausgeht. Vor dem allerersten Brief fragt
--      Pigeon Post einmal nach.
local ADDON, ns = ...
local L = ns.L

ns.FARBE = "|cff4f9bff"
ns.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")) or "0.2.0"

function ns.melde(text)
  DEFAULT_CHAT_FRAME:AddMessage(ns.FARBE .. "Pigeon Post:|r " .. tostring(text))
end

function ns.jetzt()
  return date("%Y-%m-%d %H:%M:%S")
end

-- Prüft, ob eine Funktion existiert, z. B. ns.api("C_Item.GetItemInfoInstant")
function ns.api(pfad)
  local t = _G
  for teil in string.gmatch(pfad, "[^%.]+") do
    if type(t) ~= "table" then return nil end
    t = t[teil]
  end
  return t
end

-- Vorname aus "Vor Nach"
function ns.vorname(name)
  return name and string.match(name, "^([^%s%-]+)") or name
end

-- "1 item", "3 items"
function ns.anhaenge(n)
  return n == 1 and L.ONE_ITEM or string.format(L.N_ITEMS, n)
end

-- Kupfer als kurzer Text: 1g 2s 30c
function ns.geld(kupfer)
  kupfer = math.floor(kupfer or 0)
  local g, s, k = math.floor(kupfer / 10000), math.floor(kupfer / 100) % 100, kupfer % 100
  local teile = {}
  if g > 0 then table.insert(teile, g .. L.GOLD_SUFFIX) end
  if s > 0 then table.insert(teile, s .. L.SILVER_SUFFIX) end
  if k > 0 or #teile == 0 then table.insert(teile, k .. L.COPPER_SUFFIX) end
  return table.concat(teile, " ")
end

-- Läuft das Spiel als WoW Forever? Dort sind nur Vor- und Nachname zusammen eindeutig.
function ns.istForever()
  local projekt = WOW_PROJECT_CAMELOT or 18
  return WOW_PROJECT_ID == projekt
end

local STANDARD = {
  chars = {},          -- Register: GUID -> Char
  regeln = {},         -- je Empfänger-GUID: was mitkommt und ob nur volle Stapel
  gewaehlt = {},       -- je Absender-GUID: zuletzt gewählter Empfänger
  nie = {},            -- itemID -> Name, wird nie gesendet
  protokoll = {},      -- die letzten 200 Briefe
  gesehen = {},        -- itemID -> wie Pigeon Post diese Handelsware eingeordnet hat
  -- katalog: Ergebnis von /pigeon katalog, entsteht erst beim ersten Lauf
  sendenBestaetigt = false, -- die Frage vor dem allerersten Brief ist beantwortet
  eingeklappt = false,
  autoOeffnen = true,  -- Leiste beim Öffnen des Briefkastens zeigen
  minimapZeigen = true,
  minimapWinkel = 210,
  tooltip = true,      -- Kategorie im Gegenstands-Tooltip
  -- Verteilen: Profile mit Zielen je Kategorie und je Gegenstand, siehe Verteilen.lua
  verteilung = { an = false, profil = 1, profile = {} },
  -- favorit: GUID des Lieblingsempfängers, auf jedem Char vorausgewählt
  -- fenster: Position des Hauptfensters
}

local function ergaenzen(ziel, vorlage)
  for k, v in pairs(vorlage) do
    if type(v) == "table" then
      if type(ziel[k]) ~= "table" then ziel[k] = {} end
      ergaenzen(ziel[k], v)
    elseif ziel[k] == nil then
      ziel[k] = v
    end
  end
end

-- Ereignisse: mehrere Empfänger pro Ereignis, unbekannte Ereignisse werden still ignoriert
local frame = CreateFrame("Frame")
local empfaenger = {}

function ns.Ereignis(name, funktion)
  if not empfaenger[name] then
    local ok = pcall(frame.RegisterEvent, frame, name)
    if not ok then return false end
    empfaenger[name] = {}
  end
  table.insert(empfaenger[name], funktion)
  return true
end

frame:SetScript("OnEvent", function(_, ereignis, ...)
  local liste = empfaenger[ereignis]
  if not liste then return end
  for _, f in ipairs(liste) do
    local ok, fehler = pcall(f, ...)
    if not ok then ns.melde(string.format(L.ERR_EVENT, ereignis, tostring(fehler))) end
  end
end)

ns.Ereignis("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  PigeonPostDB = PigeonPostDB or {}
  ergaenzen(PigeonPostDB, STANDARD)
  PigeonPostDB.modus = nil   -- bis 0.5.0: Test, Attach, Send. Jetzt sendet jeder Klick einen Brief.
  ns.db = PigeonPostDB
end)
