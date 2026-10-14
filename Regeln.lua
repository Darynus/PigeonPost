-- Regeln: welche Gegenstände in den nächsten Brief kommen.
-- Nie dabei: seelengebundene, gesperrte und Gegenstände von der Liste "Nie senden".
-- Questgegenstände und Taschen haben keine Kategorie und kommen deshalb nie mit.
local ADDON, ns = ...

local Regeln = {}
ns.Regeln = Regeln

local K = ns.KLASSE

function Regeln.MaxAnhaenge()
  return ATTACHMENTS_MAX_SEND or 12
end

local function sofortInfo()
  return (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
end

local function volleInfo()
  return (C_Item and C_Item.GetItemInfo) or GetItemInfo
end

-- Gegenstandsdaten ändern sich nie: einmal vollständig gelesen, bleiben sie im Speicher
local cache = {}

-- Daten zu einem Gegenstand. Klasse und Unterklasse kommen sofort aus den Spieldaten,
-- Name und Stapelgröße brauchen den Zwischenspeicher des Spiels und können anfangs fehlen.
function Regeln.Daten(itemID)
  if cache[itemID] then return cache[itemID] end
  local d = {}
  local sofort = sofortInfo()
  if sofort then
    local _, _, _, _, icon, klasse, unterklasse = sofort(itemID)
    d.icon, d.klasse, d.unterklasse = icon, klasse, unterklasse
  end
  local voll = volleInfo()
  if voll then
    local name, _, qualitaet, _, _, _, _, stapel, _, icon, _, klasse, unterklasse = voll(itemID)
    d.name, d.qualitaet, d.stapel = name, qualitaet, stapel
    d.icon = d.icon or icon
    d.klasse = d.klasse or klasse
    d.unterklasse = d.unterklasse or unterklasse
  end
  if d.name and d.stapel then
    cache[itemID] = d
  elseif C_Item and C_Item.RequestLoadItemDataByID then
    pcall(C_Item.RequestLoadItemDataByID, itemID)
  end
  return d
end

local function nachListe(itemID, d)
  local kategorie = ns.BEKANNT[itemID]
  if not kategorie then return nil end
  if d.klasse == K.HANDELSWAREN or d.klasse == K.EDELSTEIN then return kategorie end
  if d.klasse == K.VERBRAUCH and ns.KATEGORIE[kategorie].auchVerbrauch then return kategorie end
end

local function nachKlasse(d)
  if d.klasse == K.HANDELSWAREN then
    for _, k in ipairs(ns.KATEGORIEN) do
      if k.unterklasse and k.unterklasse == d.unterklasse then return k.schluessel end
    end
  elseif (d.klasse == K.WAFFE or d.klasse == K.RUESTUNG) and d.qualitaet == ns.QUALITAET_GRUEN then
    return "gruen"
  end
end

-- Kategorie eines Gegenstands. Die feste Liste hat Vorrang vor der Unterklasse.
-- Rückgabe: Kategorie, über Liste erkannt, über Klasse erkannt
function Regeln.Kategorie(itemID, d)
  local liste, klasse = nachListe(itemID, d), nachKlasse(d)
  return liste or klasse, liste ~= nil, klasse ~= nil
end

-- Mitschreiben, welche Handelswaren Pigeon Post gesehen hat und wie es sie einordnet.
-- So sehen wir nach dem Spielen, ob in Forever etwas fehlt.
local function merken(g)
  if not (ns.db and (g.klasse == K.HANDELSWAREN or g.klasse == K.EDELSTEIN)) then return end
  local alt = ns.db.gesehen[g.itemID]
  if alt and alt.kategorie == (g.kategorie or "keine") and alt.name then return end
  ns.db.gesehen[g.itemID] = {
    name = g.name, klasse = g.klasse, unterklasse = g.unterklasse,
    kategorie = g.kategorie or "keine", liste = g.viaListe, unter = g.viaKlasse,
  }
end

-- Alle Gegenstände in den Taschen mit Kategorie
function Regeln.Taschen()
  local liste = {}
  if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return liste end
  -- Mit Reagenzientasche, falls Forever sie hat (Retail: Taschen-Index 5)
  for tasche = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 do
    for platz = 1, C_Container.GetContainerNumSlots(tasche) or 0 do
      local info = C_Container.GetContainerItemInfo(tasche, platz)
      if info and info.itemID then
        local d = Regeln.Daten(info.itemID)
        local g = {
          tasche = tasche, platz = platz, itemID = info.itemID,
          anzahl = info.stackCount or 1, gebunden = info.isBound, gesperrt = info.isLocked,
          name = d.name, icon = info.iconFileID or d.icon, qualitaet = info.quality or d.qualitaet,
          stapel = d.stapel, klasse = d.klasse, unterklasse = d.unterklasse,
        }
        g.kategorie, g.viaListe, g.viaKlasse = Regeln.Kategorie(info.itemID, { klasse = g.klasse, unterklasse = g.unterklasse, qualitaet = g.qualitaet })
        merken(g)
        table.insert(liste, g)
      end
    end
  end
  return liste
end

-- Regel für einen Empfänger, beim ersten Mal mit den Standardwerten angelegt
function Regeln.Fuer(guid)
  local r = guid and ns.db.regeln[guid]
  if not r then
    r = { kategorien = {}, stapel = "voll" }
    for _, k in ipairs(ns.KATEGORIEN) do r.kategorien[k.schluessel] = k.standard end
    if guid then ns.db.regeln[guid] = r end
  end
  return r
end

-- Schlüssel für einen Taschenplatz mit Gegenstand, für "aus diesem Brief nehmen"
function Regeln.Platz(g)
  return g.tasche .. ":" .. g.platz .. ":" .. g.itemID
end

-- Darf dieser Gegenstand überhaupt in einen Brief? Nie gebunden, nie von der Liste "Nie senden".
function Regeln.Sendbar(g)
  return not g.gebunden and not ns.db.nie[g.itemID]
end

-- Passt der Stapel zur Einstellung? "voll": nur volle Stapel, "alles": auch Reste
function Regeln.StapelPasst(g, stapel)
  return stapel == "alles" or (g.stapel ~= nil and g.anzahl >= g.stapel)
end

-- Feste Reihenfolge im Brief: Kategorie, dann ID, dann große Stapel zuerst. Gegenstände ohne
-- Kategorie (nur über eine Gegenstandsregel) kommen ans Ende.
function Regeln.Sortieren(liste)
  table.sort(liste, function(a, b)
    local ka = a.kategorie and ns.KATEGORIE[a.kategorie].nr or 99
    local kb = b.kategorie and ns.KATEGORIE[b.kategorie].nr or 99
    if ka ~= kb then return ka < kb end
    if a.itemID ~= b.itemID then return a.itemID < b.itemID end
    if a.anzahl ~= b.anzahl then return a.anzahl > b.anzahl end
    if a.tasche ~= b.tasche then return a.tasche < b.tasche end
    return a.platz < b.platz
  end)
  return liste
end

-- Alle Gegenstände, die nach der Regel mitdürfen, in fester Reihenfolge.
-- Dazu je Kategorie die Menge in den Taschen, für die Anzeige, und die Menge, die nur wegen
-- "nur volle Stapel" liegen bleibt.
-- ausgelassen: Plätze, die der Spieler für diesen Besuch am Briefkasten herausgenommen hat.
function Regeln.Auswahl(regel, ausgelassen)
  local liste, menge, reste = {}, {}, 0
  for _, g in ipairs(Regeln.Taschen()) do
    if g.kategorie and Regeln.Sendbar(g) then
      menge[g.kategorie] = (menge[g.kategorie] or 0) + g.anzahl
      if regel.kategorien[g.kategorie] and not g.gesperrt and not (ausgelassen and ausgelassen[Regeln.Platz(g)]) then
        if Regeln.StapelPasst(g, regel.stapel) then table.insert(liste, g) else reste = reste + 1 end
      end
    end
  end
  return Regeln.Sortieren(liste), menge, reste
end

-- Sind zwei Briefe gleich: gleiche Gegenstände, gleiche Mengen, gleiche Taschenplätze?
function Regeln.GleicherBrief(a, b)
  if not a or not b or #a ~= #b then return false end
  for i = 1, #a do
    local x, y = a[i], b[i]
    if x.itemID ~= y.itemID or x.anzahl ~= y.anzahl or x.tasche ~= y.tasche or x.platz ~= y.platz then
      return false
    end
  end
  return true
end

-- Der nächste Brief: höchstens 12 Anhänge. Dazu alle passenden Gegenstände und die Mengen.
function Regeln.NaechsterBrief(regel, ausgelassen)
  local alle, menge, reste = Regeln.Auswahl(regel, ausgelassen)
  local brief = {}
  for i = 1, math.min(#alle, Regeln.MaxAnhaenge()) do brief[i] = alle[i] end
  return brief, alle, menge, reste
end

-- Katalog: geht alle Gegenstands-IDs der Spieldaten durch und hält fest, wie Pigeon Post
-- Handelswaren und Edelsteine einordnet. Nur auf Befehl, nur im Client, keine Serveranfragen.
-- Verteilt auf viele Bilder, damit das Spiel nicht ruckelt.
local KATALOG_BIS = 250000
local KATALOG_SCHRITT = 2500

function Regeln.KatalogStarten(fortschritt, fertig)
  local sofort = sofortInfo()
  if not sofort or not (C_Timer and C_Timer.After) then return false, ns.L.CATALOG_MISSING_API end
  if Regeln.katalogLaeuft then return false, ns.L.CATALOG_RUNNING end
  Regeln.katalogLaeuft = true

  local k = {
    zeit = ns.jetzt(), bis = KATALOG_BIS,
    kategorien = {},    -- Kategorie -> Liste der IDs
    nurListe = {},      -- erkannt nur über die feste Liste: Unterklasse in Forever anders
    nurKlasse = {},     -- erkannt nur über die Unterklasse: neu in Forever oder Liste unvollständig
    widerspruch = {},   -- Liste und Unterklasse sagen Verschiedenes
    unterklassen = {},  -- Handelswaren je Unterklasse, Anzahl
    fehlen = {},        -- IDs aus der festen Liste, die es in Forever nicht gibt
  }
  local id = 1

  local function schritt()
    local ende = math.min(id + KATALOG_SCHRITT - 1, KATALOG_BIS)
    for i = id, ende do
      local gefunden, _, _, _, _, klasse, unterklasse = sofort(i)
      if gefunden and (klasse == K.HANDELSWAREN or klasse == K.EDELSTEIN) then
        local d = { klasse = klasse, unterklasse = unterklasse }
        local kategorie, viaListe, viaKlasse = Regeln.Kategorie(i, d)
        if klasse == K.HANDELSWAREN then
          local u = tostring(unterklasse)
          k.unterklassen[u] = (k.unterklassen[u] or 0) + 1
        end
        if kategorie then
          k.kategorien[kategorie] = k.kategorien[kategorie] or {}
          table.insert(k.kategorien[kategorie], i)
          if viaListe and not viaKlasse then table.insert(k.nurListe, i .. ":" .. tostring(unterklasse)) end
          if viaKlasse and not viaListe then table.insert(k.nurKlasse, i) end
          if viaListe and viaKlasse and nachKlasse(d) ~= ns.BEKANNT[i] then table.insert(k.widerspruch, i) end
        end
      end
    end
    id = ende + 1
    if id <= KATALOG_BIS then
      if fortschritt then fortschritt(id - 1, KATALOG_BIS) end
      C_Timer.After(0, schritt)
      return
    end
    for bekannt in pairs(ns.BEKANNT) do
      if not sofort(bekannt) then table.insert(k.fehlen, bekannt) end
    end
    table.sort(k.fehlen)
    ns.db.katalog = k
    Regeln.katalogLaeuft = false
    if fertig then fertig(k) end
  end

  schritt()
  return true
end
