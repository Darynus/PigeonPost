-- Register: alle Chars dieses Accounts. Ein Char kommt nur hinein, wenn man sich mit ihm
-- einloggt. Es gibt bewusst keine Funktion, die einen Char per Hand oder per Nachricht
-- hinzufügt. Deshalb können fremde Chars nie Empfänger sein.
local ADDON, ns = ...
local L = ns.L

local Register = {}
ns.Register = Register

-- Berufe. Direkt beim Login liefert GetProfessions in Forever noch nichts (Beta, 13. Okt),
-- deshalb erst nach SKILL_LINES_CHANGED oder ein paar Sekunden nach dem Login lesen.
local function berufe()
  local liste = {}
  if not (GetProfessions and GetProfessionInfo) then return liste end
  -- GetProfessions kann Lücken liefern (kein Hauptberuf, aber Kochkunst), deshalb 1 bis 5 einzeln
  local ok, a, b, c, d, e = pcall(GetProfessions)
  if not ok then return liste end
  local indizes = { a, b, c, d, e }
  for i = 1, 5 do
    if indizes[i] then
      local name, _, wert, maximum = GetProfessionInfo(indizes[i])
      if name then table.insert(liste, { name = name, wert = wert, max = maximum }) end
    end
  end
  return liste
end

-- Hat dieses Spiel Vor- und Nachnamen (WoW Forever: Namen sind pro Region eindeutig, nur der
-- volle Name, nicht der Vorname)?
function ns.Nachnamen()
  return RegionalUniqueNamesEnabled ~= nil and RegionalUniqueNamesEnabled() == true
end

-- Vorname, Nachname und der volle Name in der Schreibweise, die das Spiel selbst liefert
local function namen()
  local vor, nach
  if UnitNameUnmodified then vor, nach = UnitNameUnmodified("player") end
  vor = vor or UnitName("player")
  if nach == "" then nach = nil end
  local voll = GetUnitName and GetUnitName("player", true)
  if not voll or voll == "" or voll == vor then
    voll = nach and (vor .. " " .. nach) or vor
  end
  return vor, nach, voll
end

-- leerErlaubt: Eine leere Berufsliste darf bekannte Berufe ersetzen (nach SKILL_LINES_CHANGED,
-- dann hat der Char wirklich alles verlernt). Direkt nach dem Login nicht, da fehlen die Daten noch.
function Register:Aktualisieren(mitBerufen, leerErlaubt)
  local guid = UnitGUID("player")
  if not guid or not ns.db then return end
  local c = ns.db.chars[guid] or {}
  ns.db.chars[guid] = c
  c.guid = guid
  c.name, c.nachname, c.voll = namen()
  c.realm = GetRealmName()
  c.fraktion = UnitFactionGroup("player")
  c.klasse = select(2, UnitClass("player"))
  c.klasseName = UnitClass("player")
  c.stufe = UnitLevel("player")
  c.zuletzt = time()
  if mitBerufen then
    local liste = berufe()
    -- Eine leere Liste überschreibt keine bekannten Berufe: meist sind die Daten nur noch nicht da
    if #liste > 0 or leerErlaubt or not c.berufe then c.berufe = liste end
  end
end

-- Die Adresse für den Brief. In Forever nur mit Nachnamen, sonst könnte ein fremder Char
-- mit gleichem Vornamen den Brief bekommen. Fehlt der Nachname: nil, kein Brief.
function Register:Adresse(c)
  if not c or not c.name or c.name == "" then return nil end
  -- In Forever immer mit Nachnamen, auch wenn die Prüffunktion fehlt
  if ns.Nachnamen() or ns.istForever() then
    if c.nachname and c.voll then return c.voll end
    return nil
  end
  return c.voll or c.name
end

-- Name für die Anzeige: voller Name, falls bekannt
function Register:Anzeigename(c)
  return c and (c.voll or c.name) or "?"
end

-- Darf dieser Char jetzt Post bekommen? Gleicher Server, gleiche Fraktion, nicht man selbst,
-- und eine eindeutige Adresse ist bekannt.
function Register:IstEmpfaenger(guid)
  if not guid or not ns.db then return false end
  local c = ns.db.chars[guid]
  return c ~= nil
    and guid ~= UnitGUID("player")
    and self:Adresse(c) ~= nil
    and c.realm == GetRealmName()
    and c.fraktion == UnitFactionGroup("player")
end

-- Warum kann ein Char keine Post bekommen? nil, wenn er kann.
function Register:Grund(guid)
  local c = ns.db.chars[guid]
  if not c then return L.REASON_UNKNOWN end
  if guid == UnitGUID("player") then return L.REASON_SELF end
  if c.realm ~= GetRealmName() then return L.REASON_REALM end
  if c.fraktion ~= UnitFactionGroup("player") then return L.REASON_FACTION end
  if not self:Adresse(c) then return L.REASON_NO_SURNAME end
  return nil
end

local function sortieren(liste)
  local favorit = ns.db.favorit
  table.sort(liste, function(x, y)
    if (x.guid == favorit) ~= (y.guid == favorit) then return x.guid == favorit end
    if (x.stufe or 0) ~= (y.stufe or 0) then return (x.stufe or 0) > (y.stufe or 0) end
    return (x.name or "") < (y.name or "")
  end)
  return liste
end

-- Alle gültigen Empfänger: Favorit zuerst, dann höchste Stufe
function Register:Empfaenger()
  local liste = {}
  for guid, c in pairs(ns.db.chars) do
    if self:IstEmpfaenger(guid) then table.insert(liste, c) end
  end
  return sortieren(liste)
end

-- Alle Chars im Register, gleiche Sortierung
function Register:Alle()
  local liste = {}
  for _, c in pairs(ns.db.chars) do table.insert(liste, c) end
  return sortieren(liste)
end

-- Der Favorit ist auf jedem Char beim Einloggen vorausgewählt (meist der Bankchar)
function Register:Favorit(guid)
  if guid == nil then return ns.db.favorit end
  ns.db.favorit = (ns.db.favorit ~= guid) and guid or nil
  return ns.db.favorit
end

function Register:Entfernen(guid)
  local c = ns.db.chars[guid]
  if not c or guid == UnitGUID("player") then return nil end
  ns.db.chars[guid] = nil
  ns.db.regeln[guid] = nil
  if ns.db.favorit == guid then ns.db.favorit = nil end
  for absender, empfaenger in pairs(ns.db.gewaehlt) do
    if empfaenger == guid then ns.db.gewaehlt[absender] = nil end
  end
  if ns.Verteilen then ns.Verteilen.CharEntfernt(guid) end
  return self:Anzeigename(c)
end

-- Char per Name finden: voller Name zuerst, sonst Vorname, wenn er eindeutig ist
function Register:NachName(name)
  name = string.lower(name or "")
  local treffer, anzahl
  for guid, c in pairs(ns.db.chars) do
    if c.voll and string.lower(c.voll) == name then return guid, c end
  end
  anzahl = 0
  for guid, c in pairs(ns.db.chars) do
    if c.name and string.lower(c.name) == name then treffer, anzahl = guid, anzahl + 1 end
  end
  if anzahl == 1 then return treffer, ns.db.chars[treffer] end
end

-- Tage seit dem letzten Login, nil wenn unbekannt
function Register:TageWeg(c)
  if not (c and c.zuletzt) or c.guid == UnitGUID("player") then return nil end
  return math.floor((time() - c.zuletzt) / 86400)
end

-- Kurzbeschreibung: "Level 12 Druid · Herbalism 75". Wer lange nicht da war, bekommt einen
-- Hinweis: Gelöschte Chars bleiben sonst unbemerkt Empfänger.
function Register:Beschreibung(c, ohneBerufe)
  local teile = { string.format(L.LEVEL_CLASS, c.stufe or "?", c.klasseName or "") }
  local tage = self:TageWeg(c)
  if tage and tage >= 14 then table.insert(teile, string.format(L.DAYS_AWAY, tage)) end
  if not ohneBerufe then
    for _, b in ipairs(c.berufe or {}) do
      table.insert(teile, b.name .. " " .. (b.wert or 0))
    end
  end
  return table.concat(teile, " · ")
end

ns.Ereignis("PLAYER_LOGIN", function()
  Register.loginZeit = time()
  Register:Aktualisieren(false)
  if C_Timer and C_Timer.After then
    C_Timer.After(5, function() Register:Aktualisieren(true) end)
  end
end)
ns.Ereignis("PLAYER_LEVEL_UP", function() Register:Aktualisieren(false) end)
-- Leere Liste nur ernst nehmen, wenn der Login schon eine Weile her ist
ns.Ereignis("SKILL_LINES_CHANGED", function()
  Register:Aktualisieren(true, time() - (Register.loginZeit or 0) > 10)
end)
ns.Ereignis("PLAYER_LOGOUT", function() Register:Aktualisieren(false) end)
