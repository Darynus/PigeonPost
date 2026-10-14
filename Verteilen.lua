-- Verteilen: Profile, die Gegenstände auf mehrere eigene Chars aufteilen.
-- Beispiel "Crafters": Kräuter an den Alchemisten, Bergbau an den Schmied, Stoff an den
-- Schneider, alles andere an den Bankchar. Beispiel "Bank": alles an den Bankchar.
--
-- Vorrang, damit sich nichts aufhebt:
--   1. "Nie senden" und gebundene Gegenstände: bleiben immer
--   2. Gegenstandsregel des Profils: dieser Gegenstand an diesen Char (oder bleibt)
--   3. Ziel der Kategorie: ein Char, "bleibt" oder "wie alles andere"
--   4. Ziel für alles andere (meist der Bankchar), oder es bleibt
-- Ist das Ziel der Char, mit dem man spielt, bleibt der Gegenstand in den Taschen.
--
-- Der Plan wird immer frisch aus den Taschen gerechnet, es gibt keine gespeicherte
-- Warteschlange. Gesendet wird wie immer: ein Klick, ein Brief, Empfänger nur aus dem Register.
local ADDON, ns = ...
local L = ns.L

local V = {}
ns.Verteilen = V

V.BLEIBT = "keep"   -- Ziel: bleibt in den Taschen
V.REST = "rest"     -- Ziel einer Kategorie: wie alles andere
V.MAX_PROFILE = 5

-- Neues Profil. Kategorien, die beim Einzelbrief standardmäßig an sind (Kräuter, Bergbau),
-- folgen "alles andere", die übrigen bleiben, bis man sie bewusst einstellt.
function V.Neu(name)
  local p = { name = name, kategorien = {}, items = {}, rest = nil, stapel = "voll", bekannt = {} }
  for _, k in ipairs(ns.KATEGORIEN) do
    if not k.standard then p.kategorien[k.schluessel] = V.BLEIBT end
    p.bekannt[k.schluessel] = true
  end
  return p
end

-- Kommt eine Kategorie neu dazu (0.5.1: Cooking), steht sie in alten Profilen auf "bleibt".
-- Sonst ginge sie still an "alles andere", ohne dass der Spieler das je gewählt hat.
local ALTE = { kraeuter = true, bergbau = true, stoff = true, leder = true, verzauberung = true, gruen = true }
local function nachziehen(p)
  p.bekannt = p.bekannt or {}
  if next(p.bekannt) == nil then for k in pairs(ALTE) do p.bekannt[k] = true end end
  for _, k in ipairs(ns.KATEGORIEN) do
    if not p.bekannt[k.schluessel] then
      if p.kategorien[k.schluessel] == nil then p.kategorien[k.schluessel] = V.BLEIBT end
      p.bekannt[k.schluessel] = true
    end
  end
end

local function daten()
  local v = ns.db.verteilung
  if #v.profile == 0 then
    local p = V.Neu(string.format(L.PROFILE_N, 1))
    p.rest = ns.db.favorit
    table.insert(v.profile, p)
  end
  if not v.profile[v.profil] then v.profil = 1 end
  for _, p in ipairs(v.profile) do nachziehen(p) end
  return v
end

function V.Profile() return daten().profile end
function V.Aktiv() local v = daten() return v.profile[v.profil] end
function V.AktivNr() return daten().profil end
function V.An() return ns.db and ns.db.verteilung.an == true end

function V.Waehlen(nr)
  local v = daten()
  if v.profile[nr] then v.profil = nr end
end

function V.Hinzufuegen()
  local v = daten()
  if #v.profile >= V.MAX_PROFILE then return nil end
  local p = V.Neu(string.format(L.PROFILE_N, #v.profile + 1))
  p.rest = V.Aktiv().rest
  table.insert(v.profile, p)
  v.profil = #v.profile
  return p
end

function V.Loeschen(nr)
  local v = daten()
  if #v.profile <= 1 or not v.profile[nr] then return false end
  table.remove(v.profile, nr)
  if v.profil > #v.profile then v.profil = #v.profile end
  return true
end

-- Ein Char wurde aus dem Register genommen: Ziele auf ihn werden zu "bleibt". Sonst ginge z. B.
-- Stoff still an den Bankchar, obwohl der Spieler das nie gewählt hat.
function V.CharEntfernt(guid)
  for _, p in ipairs(ns.db.verteilung.profile) do
    for k, ziel in pairs(p.kategorien) do if ziel == guid then p.kategorien[k] = V.BLEIBT end end
    for id, ziel in pairs(p.items) do if ziel == guid then p.items[id] = V.BLEIBT end end
    if p.rest == guid then p.rest = nil end
  end
end

-- Ziel eines Gegenstands nach dem Profil: GUID oder nil (bleibt in den Taschen)
function V.Ziel(profil, g)
  local regel = profil.items[g.itemID]
  if regel then
    if regel == V.BLEIBT then return nil end
    return regel
  end
  if not g.kategorie then return nil end
  local ziel = profil.kategorien[g.kategorie]
  if ziel == V.BLEIBT then return nil end
  if ziel == nil or ziel == V.REST then return profil.rest end
  return ziel
end

-- Der Plan für dieses Profil, gerechnet aus den Taschen.
-- Rückgabe:
--   briefe: { { guid, char, brief = { Gegenstände, höchstens 12 } }, ... } in Sendereihenfolge
--   empfaenger: { { guid, char, anzahl, briefe }, ... } für die Übersicht
--   ungueltig: { [guid] = true } Ziele, die von diesem Char aus keine Post bekommen können
--   reste: Anzahl Stapel, die nur wegen "nur volle Stapel" liegen bleiben
function V.Plan(profil, ausgelassen)
  local ich = UnitGUID("player")
  local je, ungueltig, reste = {}, {}, 0
  for _, g in ipairs(ns.Regeln.Taschen()) do
    if ns.Regeln.Sendbar(g) and not g.gesperrt and not (ausgelassen and ausgelassen[ns.Regeln.Platz(g)]) then
      local ziel = V.Ziel(profil, g)
      if ziel and ziel ~= ich then
        if not ns.Register:IstEmpfaenger(ziel) then
          ungueltig[ziel] = true
        elseif ns.Regeln.StapelPasst(g, profil.stapel) then
          je[ziel] = je[ziel] or {}
          table.insert(je[ziel], g)
        else
          reste = reste + 1
        end
      end
    end
  end
  local briefe, empfaenger = {}, {}
  local max = ns.Regeln.MaxAnhaenge()
  -- Reihenfolge wie in der Empfängerliste: Favorit zuerst, dann nach Stufe
  for _, c in ipairs(ns.Register:Empfaenger()) do
    local liste = je[c.guid]
    if liste then
      ns.Regeln.Sortieren(liste)
      local n = math.ceil(#liste / max)
      table.insert(empfaenger, { guid = c.guid, char = c, anzahl = #liste, briefe = n })
      for b = 1, n do
        local brief = {}
        for i = (b - 1) * max + 1, math.min(b * max, #liste) do table.insert(brief, liste[i]) end
        table.insert(briefe, { guid = c.guid, char = c, brief = brief })
      end
    end
  end
  return briefe, empfaenger, ungueltig, reste
end

-- Der nächste Brief des Plans, aber nur, wenn er noch an denselben Empfänger geht.
-- Für den Vergleich mit der Vorschau direkt vor dem Packen.
function V.NaechsterBriefAn(guid, ausgelassen)
  local briefe = V.Plan(V.Aktiv(), ausgelassen)
  local b = briefe[1]
  if b and b.guid == guid then return b.brief end
  return {}
end

-- Ziel als Text für die Anzeige
function V.ZielText(ziel)
  if ziel == nil or ziel == V.REST then return L.TARGET_REST end
  if ziel == V.BLEIBT then return L.TARGET_KEEP end
  local c = ns.db.chars[ziel]
  return c and ns.Register:Anzeigename(c) or L.TARGET_UNKNOWN
end

-- Kurzbeschreibung eines Profils: "Herbs to Ann, Mining to Bob, rest to Bank"
function V.Beschreibung(profil)
  local teile = {}
  for _, k in ipairs(ns.KATEGORIEN) do
    local ziel = profil.kategorien[k.schluessel]
    if ziel and ziel ~= V.REST and ziel ~= V.BLEIBT then
      table.insert(teile, string.format(L.ROUTE_SHORT, k.kurz, ns.vorname(V.ZielText(ziel))))
    end
  end
  local items = 0
  for _ in pairs(profil.items) do items = items + 1 end
  if items > 0 then table.insert(teile, string.format(L.ITEM_RULES_N, items)) end
  if profil.rest then table.insert(teile, string.format(L.REST_SHORT, ns.vorname(V.ZielText(profil.rest)))) end
  if #teile == 0 then return L.PROFILE_EMPTY end
  return table.concat(teile, ", ")
end
