-- Hauptfenster: Chars, Verteilen, Gegenstandsregeln, Einstellungen, Nie senden, Verlauf, Prüfen, Hilfe.
-- Öffnen mit /pigeon, über den Minikarten-Knopf oder im Optionen-Menü.
-- Aussehen wie die Fenster des Spiels, wie bei Campfire Buddy (Patrick, 16. Okt): Porträtrahmen
-- mit Titelleiste, versenkte Innenfläche, Reiter unten, rote Knöpfe, Haken und Auswahlknöpfe aus
-- dem Client. Fehlt eine dieser Vorlagen, baut das Fenster sich wie früher flach selbst.
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F, rgba = S.F, S.rgba

local W = { seiten = {} }
ns.Fenster = W

-- Maße: werden in W:Bauen je nach Aufbau gesetzt (echt oder flach)
local BREITE, HOEHE = 640, 480
local SEITE = 150
local X = SEITE + 16                  -- linker Rand des Inhalts
local B = BREITE - X - 16             -- Breite des Inhalts
local OBEN = -60                      -- erste Zeile unter dem Kopf
local UNTEN = 16

local REITER = {
  { schluessel = "chars", text = L.TAB_CHARACTERS },
  { schluessel = "verteilen", text = L.TAB_DISTRIBUTE },
  { schluessel = "items", text = L.TAB_ITEM_RULES },
  { schluessel = "einstellungen", text = L.TAB_SETTINGS },
  { schluessel = "nie", text = L.TAB_NEVER },
  { schluessel = "protokoll", text = L.TAB_HISTORY },
  { schluessel = "pruefen", text = L.TAB_CHECK },
  { schluessel = "hilfe", text = L.TAB_HELP },
}

local function seite(schluessel)
  local f = CreateFrame("Frame", nil, W.rahmen)
  f:SetPoint("TOPLEFT", X, OBEN)
  f:SetSize(B, HOEHE + OBEN - UNTEN)
  -- Über der versenkten Fläche des echten Fensters
  if W.echt then f:SetFrameLevel((W.rahmen:GetFrameLevel() or 1) + 4) end
  f:Hide()
  W.seiten[schluessel] = f
  return f
end

local function datum(zeit)
  return zeit and date("%Y-%m-%d %H:%M", zeit) or "?"
end

-- Seite: Chars -----------------------------------------------------------------

local function bauenChars()
  local f = seite("chars")
  local LISTE_B = 214
  S.ueberschrift(f, L.YOUR_CHARACTERS):SetPoint("TOPLEFT", 0, 0)

  f.liste = S.liste(f, LISTE_B, 324, 36, function(liste)
    local z = S.zeile(liste)
    z.name = S.schrift(z, "GameFontHighlight")
    z.name:SetPoint("TOPLEFT", 8, -4)
    z.info = S.schrift(z, "GameFontHighlightSmall", F.leise)
    z.info:SetPoint("TOPLEFT", 8, -20)
    z.info:SetWidth(LISTE_B - 40)
    z.info:SetJustifyH("LEFT")
    z.info:SetWordWrap(false)
    z.stern = S.stern(z, 14)
    z.stern:SetPoint("RIGHT", -8, 0)
    z.punkt = z:CreateTexture(nil, "ARTWORK")
    z.punkt:SetSize(6, 6)
    z.punkt:SetPoint("RIGHT", -12, 0)
    z:SetScript("OnClick", function(self)
      S.klick()
      f.auswahl = self.eintrag.guid
      f.entfernenBereit = false
      W:Aktualisieren()
    end)
    return z
  end)
  f.liste:SetPoint("TOPLEFT", 0, -16)

  local hinweis = S.absatz(f, LISTE_B, F.leise)
  hinweis:SetPoint("TOPLEFT", 0, -348)
  hinweis:SetText(L.CHARS_HINT)

  -- Rechts: Details zum gewählten Char
  local d = CreateFrame("Frame", nil, f)
  f.details = d
  local DX, DB = LISTE_B + 18, B - LISTE_B - 18
  d:SetPoint("TOPLEFT", DX, 0)
  d:SetSize(DB, 400)
  d.stern = S.stern(d, 18)
  d.stern:SetPoint("TOPLEFT", 0, -1)
  d.name = S.schrift(d, "GameFontNormalLarge", F.text)
  d.name:SetPoint("TOPLEFT", 0, 0)
  d.zeilen = S.absatz(d, DB, F.leise)
  d.zeilen:SetPoint("TOPLEFT", 0, -24)
  -- Alles darunter hängt am Text darüber, damit lange Zeilen nichts überdecken
  d.status = S.absatz(d, DB, F.erfolg)
  d.status:SetPoint("TOPLEFT", d.zeilen, "BOTTOMLEFT", 0, -8)

  d.empfaengt = S.ueberschrift(d, L.RECEIVES)
  d.empfaengt:SetPoint("TOPLEFT", d.status, "BOTTOMLEFT", 0, -12)
  d.haken = {}
  for i, k in ipairs(ns.KATEGORIEN) do
    local h = S.haken(d, (DB - 6) / 2, k.kurz, k.hilfe, function(knopf, an)
      if ns.Versand:Beschaeftigt() or not f.auswahl then return end
      ns.Regeln.Fuer(f.auswahl).kategorien[knopf.schluessel] = an
      W:Aktualisieren()
      ns.Oberflaeche:Aktualisieren()
    end)
    h.schluessel = k.schluessel
    local spalte, reihe = (i - 1) % 2, math.floor((i - 1) / 2)
    h:SetPoint("TOPLEFT", d.empfaengt, "BOTTOMLEFT", spalte * ((DB + 6) / 2), -4 - reihe * 20)
    d.haken[i] = h
  end
  d.stapel = S.segmente(d, DB, {
    { wert = "voll", text = L.STACKS_FULL, hilfe = L.STACKS_FULL_HELP },
    { wert = "alles", text = L.STACKS_ALL, hilfe = L.STACKS_ALL_HELP },
  }, function(wert)
    if ns.Versand:Beschaeftigt() or not f.auswahl then return end
    ns.Regeln.Fuer(f.auswahl).stapel = wert
    W:Aktualisieren()
    ns.Oberflaeche:Aktualisieren()
  end)
  d.stapel:SetPoint("TOPLEFT", d.empfaengt, "BOTTOMLEFT", 0, -90)

  d.favorit = S.textKnopf(d, L.SET_FAVORITE, DB, function()
    ns.Register:Favorit(f.auswahl)
    W:Aktualisieren()
    ns.Oberflaeche:Aktualisieren()
  end)
  d.favorit:SetPoint("TOPLEFT", d.stapel, "BOTTOMLEFT", 0, -18)
  S.tooltip(d.favorit, L.FAVORITE, L.FAVORITE_HELP)

  -- Entfernen in zwei Schritten, damit niemand aus Versehen einen Char löscht
  d.entfernen = S.textKnopf(d, L.REMOVE, DB, function()
    if not f.entfernenBereit then
      f.entfernenBereit = true
      return W:Aktualisieren()
    end
    local name = ns.Register:Entfernen(f.auswahl)
    if name then ns.melde(string.format(L.MSG_REMOVED, name)) end
    f.auswahl, f.entfernenBereit = nil, false
    W:Aktualisieren()
    ns.Oberflaeche:Aktualisieren()
  end)
  d.entfernen:SetPoint("TOPLEFT", d.favorit, "BOTTOMLEFT", 0, -6)
  S.tooltip(d.entfernen, L.REMOVE, L.REMOVE_HELP)

  function f:Aktualisieren()
    local alle = ns.Register:Alle()
    local favorit = ns.Register:Favorit()
    if not (self.auswahl and ns.db.chars[self.auswahl]) then
      self.auswahl = alle[1] and alle[1].guid
    end
    self.liste:Setzen(alle, function(z, c)
      z.name:SetText(ns.Register:Anzeigename(c))
      z.name:SetTextColor(rgba(S.klassenFarbe(c.klasse)))
      z.info:SetText(string.format(L.LEVEL_CLASS, c.stufe or "?", c.klasseName or "") .. " · " .. (c.realm or "?"))
      z.stern:SetShown(c.guid == favorit)
      local kann = ns.Register:IstEmpfaenger(c.guid)
      z.punkt:SetColorTexture(rgba(kann and F.erfolg or F.rand))
      z.punkt:SetShown(c.guid ~= favorit)
      z.wahl:SetShown(c.guid == self.auswahl)
    end, L.CHARS_EMPTY)

    local c = self.auswahl and ns.db.chars[self.auswahl]
    d:SetShown(c ~= nil)
    if not c then return end
    local istFavorit = c.guid == favorit
    d.stern:SetShown(istFavorit)
    d.name:SetPoint("TOPLEFT", istFavorit and 24 or 0, 0)
    d.name:SetText(ns.Register:Anzeigename(c))
    d.name:SetTextColor(rgba(S.klassenFarbe(c.klasse)))
    local berufe = {}
    for _, b in ipairs(c.berufe or {}) do table.insert(berufe, b.name .. " " .. (b.wert or 0)) end
    d.zeilen:SetText(table.concat({
      string.format(L.LEVEL_CLASS, c.stufe or "?", c.klasseName or ""),
      L.REALM .. ": " .. (c.realm or "?") .. "   " .. L.FACTION .. ": " .. (c.fraktion or "?"),
      L.MAIL_ADDRESS .. ": " .. (ns.Register:Adresse(c) or L.ADDRESS_UNKNOWN),
      L.PROFESSIONS .. ": " .. (#berufe > 0 and table.concat(berufe, ", ") or L.NONE_KNOWN),
      L.LAST_SEEN .. ": " .. datum(c.zuletzt),
    }, "\n"))
    local grund = ns.Register:Grund(c.guid)
    d.status:SetText(grund or L.CAN_RECEIVE)
    d.status:SetTextColor(rgba(grund and F.hinweis or F.erfolg))

    -- Regeln gibt es nur für mögliche Empfänger
    local regelSichtbar = grund == nil
    d.empfaengt:SetShown(regelSichtbar)
    d.stapel:SetShown(regelSichtbar)
    for _, h in ipairs(d.haken) do h:SetShown(regelSichtbar) end
    if regelSichtbar then
      local regel = ns.Regeln.Fuer(c.guid)
      for _, h in ipairs(d.haken) do h:Setzen(regel.kategorien[h.schluessel]) end
      d.stapel:Setzen(regel.stapel)
    end

    d.favorit.text:SetText(istFavorit and L.UNSET_FAVORITE or L.SET_FAVORITE)
    d.favorit:Aktiv(c.guid ~= UnitGUID("player"))
    local selbst = c.guid == UnitGUID("player")
    d.entfernen:Aktiv(not selbst)
    d.entfernen.text:SetText(selbst and L.REMOVE_SELF or (self.entfernenBereit and L.REMOVE_CONFIRM or L.REMOVE))
    d.entfernen.randFarbe = self.entfernenBereit and F.fehler or nil
    S.randFarbe(d.entfernen, self.entfernenBereit and F.fehler or F.rand)
  end
end

-- Ziele für Aufklapplisten: "wie alles andere" (nur Kategorien), "bleibt", dann alle Chars
local V = ns.Verteilen
local function zielEintraege(mitRest)
  local t = {}
  if mitRest then table.insert(t, { wert = V.REST, text = L.TARGET_REST, farbe = F.leise }) end
  table.insert(t, { wert = V.BLEIBT, text = L.TARGET_KEEP, farbe = F.leise })
  for _, c in ipairs(ns.Register:Alle()) do
    table.insert(t, { wert = c.guid, text = ns.Register:Anzeigename(c), farbe = S.klassenFarbe(c.klasse),
      info = string.format(L.LEVEL_SHORT, c.stufe or 0) })
  end
  return t
end

local function zielFarbe(ziel)
  if ziel == nil or ziel == V.REST or ziel == V.BLEIBT then return F.leise end
  local c = ns.db.chars[ziel]
  return c and S.klassenFarbe(c.klasse) or F.hinweis
end

local function geaendert()
  W:Aktualisieren()
  if ns.Oberflaeche then ns.Oberflaeche:Aktualisieren() end
end

-- Seite: Verteilen ------------------------------------------------------------------

local function bauenVerteilen()
  local f = seite("verteilen")
  S.ueberschrift(f, L.PROFILES):SetPoint("TOPLEFT", 0, 0)
  f.profile = {}
  for i = 1, V.MAX_PROFILE do
    local b = S.textKnopf(f, "", 84, function()
      if ns.Versand:Beschaeftigt() then return end
      f.loeschenBereit = false
      V.Waehlen(i)
      geaendert()
    end)
    b:SetPoint("TOPLEFT", (i - 1) * 88, -16)
    b.text:SetWidth(76)
    b.text:SetWordWrap(false)
    f.profile[i] = b
  end
  f.neu = S.textKnopf(f, "+", 30, function()
    f.loeschenBereit = false
    if V.Hinzufuegen() then geaendert() end
  end)
  S.tooltip(f.neu, L.NEW_PROFILE, L.NEW_PROFILE_HELP)

  f.name = S.eingabe(f, 200, 24, function(text)
    text = string.gsub(text, "|", "")
    if text ~= "" then V.Aktiv().name = text end
    geaendert()
  end)
  f.name:SetPoint("TOPLEFT", 0, -46)
  S.tooltip(f.name, L.PROFILE_NAME, L.PROFILE_NAME_HELP)
  f.loeschen = S.textKnopf(f, L.DELETE_PROFILE, 120, function()
    if not f.loeschenBereit then
      f.loeschenBereit = true
      return W:Aktualisieren()
    end
    f.loeschenBereit = false
    V.Loeschen(V.AktivNr())
    geaendert()
  end)
  f.loeschen:SetPoint("LEFT", f.name, "RIGHT", 8, 0)

  S.ueberschrift(f, L.ROUTES):SetPoint("TOPLEFT", 0, -80)
  f.ziele = {}
  local zeilen = {}
  for _, k in ipairs(ns.KATEGORIEN) do table.insert(zeilen, { schluessel = k.schluessel, text = k.name, hilfe = k.hilfe }) end
  table.insert(zeilen, { schluessel = "rest", text = L.EVERYTHING_ELSE, hilfe = L.EVERYTHING_ELSE_HELP })
  for i, z in ipairs(zeilen) do
    local y = -96 - (i - 1) * 25
    local name = S.schrift(f, "GameFontHighlight", z.schluessel == "rest" and F.akzent or F.text)
    name:SetPoint("TOPLEFT", 0, y - 4)
    name:SetText(z.text)
    local a = S.auswahl(f, 280, function() return zielEintraege(z.schluessel ~= "rest") end, function(wert)
      local p = V.Aktiv()
      if z.schluessel == "rest" then
        p.rest = (wert ~= V.BLEIBT) and wert or nil
      else
        p.kategorien[z.schluessel] = (wert ~= V.REST) and wert or nil
      end
      geaendert()
    end)
    a:SetPoint("TOPLEFT", 170, y)
    a.schluessel = z.schluessel
    S.tooltip(a, z.text, z.hilfe)
    f.ziele[i] = a
  end

  S.ueberschrift(f, L.STACKS):SetPoint("TOPLEFT", 0, -300)
  f.stapel = S.segmente(f, 300, {
    { wert = "voll", text = L.STACKS_FULL, hilfe = L.STACKS_FULL_HELP },
    { wert = "alles", text = L.STACKS_ALL, hilfe = L.STACKS_ALL_HELP },
  }, function(wert)
    V.Aktiv().stapel = wert
    geaendert()
  end)
  f.stapel:SetPoint("TOPLEFT", 0, -316)
  local hilfe = S.absatz(f, B, F.leise)
  hilfe:SetPoint("TOPLEFT", 0, -346)
  hilfe:SetText(L.DISTRIBUTE_HELP)

  function f:Aktualisieren()
    local profile = V.Profile()
    local aktiv, nr = V.Aktiv(), V.AktivNr()
    for i, b in ipairs(self.profile) do
      local p = profile[i]
      b:SetShown(p ~= nil)
      if p then
        b.text:SetText(p.name)
        b.randFarbe = i == nr and F.akzent or nil
        S.randFarbe(b, i == nr and F.akzent or F.rand)
        b.text:SetTextColor(rgba(i == nr and F.akzent or F.text))
      end
    end
    self.neu:SetShown(#profile < V.MAX_PROFILE)
    self.neu:ClearAllPoints()
    self.neu:SetPoint("TOPLEFT", #profile * 88, -16)
    if not (self.name.HasFocus and self.name:HasFocus()) then self.name:SetText(aktiv.name) end
    self.loeschen:Aktiv(#profile > 1)
    self.loeschen.text:SetText(self.loeschenBereit and L.DELETE_CONFIRM or L.DELETE_PROFILE)
    for _, a in ipairs(self.ziele) do
      local ziel
      if a.schluessel == "rest" then ziel = aktiv.rest or V.BLEIBT else ziel = aktiv.kategorien[a.schluessel] end
      a:Setzen(V.ZielText(ziel), zielFarbe(ziel))
    end
    self.stapel:Setzen(aktiv.stapel)
  end
end

-- Seite: Gegenstandsregeln --------------------------------------------------------------

local function bauenItems()
  local f = seite("items")
  f.titel = S.ueberschrift(f, "")
  f.titel:SetPoint("TOPLEFT", 0, 0)

  -- Ablage: Gegenstand aus den Taschen hierher ziehen (oder mit ihm am Mauszeiger klicken)
  local ablage = S.kasten(f, "Button", F.flaeche, F.akzent)
  f.ablage = ablage
  ablage:SetSize(40, 40)
  ablage:SetPoint("TOPLEFT", 0, -18)
  ablage.plus = S.schrift(ablage, "GameFontNormalLarge", F.akzent)
  ablage.plus:SetPoint("CENTER")
  ablage.plus:SetText("+")
  local function ablegen()
    if not GetCursorInfo then return end
    local art, itemID = GetCursorInfo()
    if art ~= "item" or type(itemID) ~= "number" then return end
    ClearCursor()
    local p = V.Aktiv()
    if not p.items[itemID] then
      local ziel = p.rest or ns.Register:Favorit()
      if not (ziel and ns.db.chars[ziel]) then ziel = V.BLEIBT end
      p.items[itemID] = ziel
    end
    geaendert()
  end
  ablage:SetScript("OnReceiveDrag", ablegen)
  ablage:SetScript("OnClick", ablegen)
  S.tooltip(ablage, L.ADD_ITEM_RULE, L.ADD_ITEM_RULE_HELP)
  local text = S.absatz(f, B - 52, F.leise)
  text:SetPoint("TOPLEFT", 52, -20)
  text:SetText(L.ITEM_RULES_HELP)

  f.liste = S.liste(f, B, 30 * 9, 30, function(liste)
    local z = S.zeile(liste)
    z.icon = z:CreateTexture(nil, "ARTWORK")
    z.icon:SetSize(22, 22)
    z.icon:SetPoint("LEFT", 6, 0)
    z.name = S.schrift(z, "GameFontHighlight")
    z.name:SetPoint("LEFT", z.icon, "RIGHT", 8, 0)
    z.name:SetWidth(B - 260)
    z.name:SetJustifyH("LEFT")
    z.name:SetWordWrap(false)
    z.ziel = S.auswahl(z, 190, function() return zielEintraege(false) end, function(wert)
      V.Aktiv().items[z.eintrag.id] = wert
      geaendert()
    end)
    z.ziel:SetPoint("RIGHT", -30, 0)
    z.weg = S.zeichenKnopf(z, "x", function()
      V.Aktiv().items[z.eintrag.id] = nil
      geaendert()
    end)
    z.weg:SetPoint("RIGHT", -4, 0)
    S.tooltip(z.weg, L.REMOVE_RULE, nil)
    return z
  end)
  f.liste:SetPoint("TOPLEFT", 0, -70)

  function f:Aktualisieren()
    local p = V.Aktiv()
    self.titel:SetText(string.format(L.ITEM_RULES_FOR, p.name))
    local daten = {}
    for id, ziel in pairs(p.items) do
      local d = ns.Regeln.Daten(id)
      table.insert(daten, { id = id, ziel = ziel, name = d.name or ("ID " .. id), icon = d.icon })
    end
    table.sort(daten, function(a, b) return a.name < b.name end)
    self.liste:Setzen(daten, function(z, e)
      z.icon:SetTexture(e.icon)
      z.name:SetText(e.name)
      z.ziel:Setzen(V.ZielText(e.ziel), zielFarbe(e.ziel))
    end, L.ITEM_RULES_EMPTY)
  end
end

-- Seite: Einstellungen ----------------------------------------------------------

local function bauenEinstellungen()
  local f = seite("einstellungen")
  S.ueberschrift(f, L.DISPLAY):SetPoint("TOPLEFT", 0, 0)
  local schalter = {
    { feld = "autoOeffnen", text = L.OPT_AUTO_OPEN, hilfe = L.OPT_AUTO_OPEN_HELP },
    { feld = "minimapZeigen", text = L.OPT_MINIMAP, hilfe = L.OPT_MINIMAP_HELP,
      danach = function() if ns.Minimap then ns.Minimap:Sichtbarkeit() end end },
    { feld = "tooltip", text = L.OPT_TOOLTIP, hilfe = L.OPT_TOOLTIP_HELP },
  }
  f.schalter = {}
  for i, s in ipairs(schalter) do
    local h = S.haken(f, B, s.text, s.hilfe, function(_, an)
      ns.db[s.feld] = an
      if s.danach then s.danach() end
      W:Aktualisieren()
    end)
    h.feld = s.feld
    h:SetPoint("TOPLEFT", 0, -16 - (i - 1) * 22)
    f.schalter[i] = h
  end

  S.ueberschrift(f, L.SAFETY):SetPoint("TOPLEFT", 0, -102)
  local sicher = S.absatz(f, B, F.text)
  sicher:SetPoint("TOPLEFT", 0, -118)
  sicher:SetText(L.SAFETY_TEXT)

  function f:Aktualisieren()
    for _, h in ipairs(self.schalter) do h:Setzen(ns.db[h.feld]) end
  end
end

-- Seite: Nie senden --------------------------------------------------------------

local function bauenNie()
  local f = seite("nie")
  S.ueberschrift(f, L.NEVER_TITLE):SetPoint("TOPLEFT", 0, 0)

  -- Ablage wie bei den Item rules: Gegenstand aus den Taschen hierher ziehen
  local ablage = S.kasten(f, "Button", F.flaeche, F.akzent)
  f.ablage = ablage
  ablage:SetSize(40, 40)
  ablage:SetPoint("TOPLEFT", 0, -18)
  ablage.plus = S.schrift(ablage, "GameFontNormalLarge", F.akzent)
  ablage.plus:SetPoint("CENTER")
  ablage.plus:SetText("+")
  local function ablegen()
    if not GetCursorInfo then return end
    local art, itemID = GetCursorInfo()
    if art ~= "item" or type(itemID) ~= "number" then return end
    ClearCursor()
    local d = ns.Regeln.Daten(itemID)
    ns.db.nie[itemID] = d.name or tostring(itemID)
    ns.melde(string.format(L.MSG_NEVER, d.name or itemID))
    W:Aktualisieren()
    ns.Oberflaeche:Aktualisieren()
  end
  ablage:SetScript("OnReceiveDrag", ablegen)
  ablage:SetScript("OnClick", ablegen)
  S.tooltip(ablage, L.ADD_NEVER, L.ADD_NEVER_HELP)
  local ablageText = S.absatz(f, B - 52, F.leise)
  ablageText:SetPoint("TOPLEFT", 52, -20)
  ablageText:SetText(L.NEVER_DROP_HELP)

  f.liste = S.liste(f, B, 30 * 9, 30, function(liste)
    local z = S.zeile(liste)
    z.icon = z:CreateTexture(nil, "ARTWORK")
    z.icon:SetSize(22, 22)
    z.icon:SetPoint("LEFT", 6, 0)
    z.name = S.schrift(z, "GameFontHighlight")
    z.name:SetPoint("LEFT", z.icon, "RIGHT", 8, 0)
    z.id = S.schrift(z, "GameFontHighlightSmall", F.leise)
    z.id:SetPoint("LEFT", z.name, "RIGHT", 8, 0)
    z.weg = S.textKnopf(z, L.ALLOW_AGAIN, 96, function(knopf)
      ns.db.nie[knopf:GetParent().eintrag.id] = nil
      W:Aktualisieren()
      ns.Oberflaeche:Aktualisieren()
    end)
    z.weg:SetPoint("RIGHT", -8, 0)
    return z
  end)
  f.liste:SetPoint("TOPLEFT", 0, -66)
  f.hinweis = S.absatz(f, B - 130, F.leise)
  f.hinweis:SetPoint("TOPLEFT", 0, -350)
  f.hinweis:SetText(L.NEVER_HINT)
  f.leeren = S.textKnopf(f, L.CLEAR_LIST, 120, function()
    ns.db.nie = {}
    W:Aktualisieren()
    ns.Oberflaeche:Aktualisieren()
  end)
  f.leeren:SetPoint("TOPRIGHT", 0, -348)

  function f:Aktualisieren()
    local daten = {}
    for id, name in pairs(ns.db.nie) do table.insert(daten, { id = id, name = name }) end
    table.sort(daten, function(a, b) return tostring(a.name) < tostring(b.name) end)
    self.liste:Setzen(daten, function(z, e)
      local d = ns.Regeln.Daten(e.id)
      z.icon:SetTexture(d.icon)
      z.name:SetText(d.name or e.name)
      z.id:SetText("ID " .. e.id)
    end, L.NEVER_EMPTY)
    self.leeren:Aktiv(#daten > 0)
  end
end

-- Seite: Verlauf -------------------------------------------------------------------

local ERGEBNIS = {
  gesendet = { L.RESULT_SENT, F.erfolg },
  probelauf = { L.RESULT_TEST, F.leise },
  fehlgeschlagen = { L.RESULT_FAILED, F.fehler },
  unklar = { L.RESULT_UNCLEAR, F.hinweis },
}

local function bauenProtokoll()
  local f = seite("protokoll")
  S.ueberschrift(f, L.HISTORY_TITLE):SetPoint("TOPLEFT", 0, 0)
  f.liste = S.liste(f, B, 380, 36, function(liste)
    local z = S.zeile(liste)
    z.titel = S.schrift(z, "GameFontHighlight")
    z.titel:SetPoint("TOPLEFT", 8, -4)
    z.info = S.schrift(z, "GameFontHighlightSmall", F.leise)
    z.info:SetPoint("TOPLEFT", 8, -20)
    z.ergebnis = S.schrift(z, "GameFontHighlightSmall")
    z.ergebnis:SetPoint("RIGHT", -10, 0)
    S.tooltip(z, function(self) return self.eintrag and self.eintrag.titel end, function(self)
      local e = self.eintrag
      if not e then return end
      local teile = {}
      for _, g in ipairs(e.inhalt or {}) do table.insert(teile, (g.name or ("ID " .. g.id)) .. " x" .. g.anzahl) end
      if e.adresse then table.insert(teile, 1, L.MAIL_ADDRESS .. ": " .. e.adresse) end
      if e.fehler then table.insert(teile, L.SERVER_SAID .. ": " .. e.fehler) end
      return table.concat(teile, "\n")
    end)
    return z
  end)
  f.liste:SetPoint("TOPLEFT", 0, -16)

  function f:Aktualisieren()
    local daten = {}
    for i = #ns.db.protokoll, 1, -1 do
      local e = ns.db.protokoll[i]
      e.titel = string.format(L.FROM_TO, e.von or "?", e.an or "?")
      table.insert(daten, e)
    end
    self.liste:Setzen(daten, function(z, e)
      z.titel:SetText(e.titel)
      z.info:SetText(e.zeit .. " · " .. ns.anhaenge(#(e.inhalt or {})))
      local erg = ERGEBNIS[e.ergebnis] or { e.ergebnis, F.leise }
      z.ergebnis:SetText(erg[1])
      z.ergebnis:SetTextColor(rgba(erg[2]))
    end, L.HISTORY_EMPTY)
  end
end

-- Seite: Prüfen ----------------------------------------------------------------------

local function bauenPruefen()
  local f = seite("pruefen")
  S.ueberschrift(f, L.CHECK_TITLE):SetPoint("TOPLEFT", 0, 0)
  local text = S.absatz(f, B, F.leise)
  text:SetPoint("TOPLEFT", 0, -16)
  text:SetText(L.CHECK_TEXT)

  f.taschen = S.textKnopf(f, L.SCAN_BAGS, 140, function() f:Taschen() end)
  f.taschen:SetPoint("TOPLEFT", 0, -64)
  f.katalog = S.textKnopf(f, L.CHECK_ALL, 170, function() f:Katalog() end)
  f.katalog:SetPoint("LEFT", f.taschen, "RIGHT", 8, 0)
  S.tooltip(f.katalog, L.CHECK_ALL, L.CHECK_ALL_HELP)
  f.status = S.absatz(f, B, F.leise)
  f.status:SetPoint("TOPLEFT", 0, -94)

  f.liste = S.liste(f, B, 252, 28, function(liste)
    local z = S.zeile(liste)
    z.icon = z:CreateTexture(nil, "ARTWORK")
    z.icon:SetSize(20, 20)
    z.icon:SetPoint("LEFT", 6, 0)
    z.name = S.schrift(z, "GameFontHighlight")
    z.name:SetPoint("LEFT", z.icon, "RIGHT", 8, 0)
    z.kategorie = S.schrift(z, "GameFontHighlightSmall")
    z.kategorie:SetPoint("RIGHT", -10, 0)
    return z
  end)
  f.liste:SetPoint("TOPLEFT", 0, -134)
  f.daten = {}

  function f:Taschen()
    local daten = {}
    for _, g in ipairs(ns.Regeln.Taschen()) do
      if g.klasse == ns.KLASSE.HANDELSWAREN or g.klasse == ns.KLASSE.EDELSTEIN or g.kategorie then
        table.insert(daten, g)
      end
    end
    self.daten = daten
    local ohne = 0
    for _, g in ipairs(daten) do if not g.kategorie then ohne = ohne + 1 end end
    self.status:SetText(string.format(L.SCAN_RESULT, #daten, ohne))
    self:Aktualisieren()
  end

  function f:Katalog()
    local ok, grund = ns.Regeln.KatalogStarten(function(bis, gesamt)
      f.status:SetText(string.format(L.CATALOG_PROGRESS, math.floor(bis / gesamt * 100)))
    end, function(k)
      local teile = {}
      for _, kat in ipairs(ns.KATEGORIEN) do
        if k.kategorien[kat.schluessel] then table.insert(teile, kat.name .. " " .. #k.kategorien[kat.schluessel]) end
      end
      f.status:SetText(table.concat(teile, ", ") .. "\n" ..
        string.format(L.CATALOG_DONE, #k.nurListe, #k.nurKlasse, #k.widerspruch, #k.fehlen))
    end)
    if not ok then self.status:SetText(grund) end
  end

  function f:Aktualisieren()
    self.liste:Setzen(self.daten, function(z, g)
      z.icon:SetTexture(g.icon)
      z.name:SetText(g.name or ("ID " .. g.itemID))
      if g.kategorie then
        z.kategorie:SetText(ns.KATEGORIE[g.kategorie].name)
        z.kategorie:SetTextColor(rgba(F.akzent))
      else
        z.kategorie:SetText(string.format(L.NOT_SORTED, tostring(g.klasse), tostring(g.unterklasse)))
        z.kategorie:SetTextColor(rgba(F.leise))
      end
    end, L.CHECK_EMPTY)
  end
end

-- Seite: Hilfe -------------------------------------------------------------------------

local function bauenHilfe()
  local f = seite("hilfe")
  local y = 0
  for _, abschnitt in ipairs({
    { L.HELP_START_TITLE, L.HELP_START },
    { L.HELP_SPLIT_TITLE, L.HELP_SPLIT },
    { L.HELP_SENDING_TITLE, L.HELP_SENDING },
    { L.HELP_COMMANDS_TITLE, L.HELP_COMMANDS },
  }) do
    S.ueberschrift(f, abschnitt[1]):SetPoint("TOPLEFT", 0, y)
    local t = S.absatz(f, B, F.text)
    t:SetPoint("TOPLEFT", 0, y - 16)
    t:SetText(abschnitt[2])
    y = y - 16 - (t:GetStringHeight() or 60) - 18
  end
  function f:Aktualisieren() end
end

-- Rahmen ---------------------------------------------------------------------------------

-- Echter Aufbau: Porträtrahmen des Spiels, darin die versenkte Fläche, unten die Reiter
local function bauenEcht(r)
  BREITE, HOEHE = 740, 500
  X, OBEN, UNTEN = 16, -72, 18
  B = BREITE - X - 18
  r:SetSize(BREITE, HOEHE)
  pcall(r.SetTitle, r, L.ADDON_NAME)
  if r.SetPortraitToAsset then pcall(r.SetPortraitToAsset, r, S.ICON) end
  local unter = S.schrift(r, "GameFontHighlightSmall")
  unter:SetPoint("TOPLEFT", 66, -36)
  unter:SetText(L.SUBTITLE)
  local version = S.schrift(r, "GameFontDisableSmall")
  version:SetPoint("TOPRIGHT", -14, -36)
  version:SetText("by Darynus   v" .. ns.VERSION)
  local innen = S.vorlage("Frame", r, "InsetFrameTemplate")
  if innen then
    innen:SetFrameLevel((r:GetFrameLevel() or 1) + 1)
    innen:SetPoint("TOPLEFT", 4, -60)
    innen:SetPoint("BOTTOMRIGHT", -6, 4)
  end
  -- Reiter unten am Fenster. Die neue Vorlage (mit LeftActive) steht mit Abstand nebeneinander,
  -- die alte überlappt wie im Charakterfenster.
  r.Tabs = {}
  local vorher
  for i, t in ipairs(REITER) do
    local tab = S.vorlage("Button", r, "PanelTabButtonTemplate", "PigeonPostFrameTab" .. i)
    if tab then
      tab:SetText(t.text)
    else
      tab = S.textKnopf(r, t.text, 84, function() end)
    end
    if tab.SetID then tab:SetID(i) end
    if vorher then
      if tab.LeftActive then tab:SetPoint("TOPLEFT", vorher, "TOPRIGHT", 3, 0) else tab:SetPoint("LEFT", vorher, "RIGHT", -15, 0) end
    else
      tab:SetPoint("TOPLEFT", r, "BOTTOMLEFT", 12, 2)
    end
    if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, tab, 0) end
    tab.schluessel = t.schluessel
    tab:SetScript("OnClick", function()
      if PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_TAB) end
      W:Zeigen(t.schluessel)
    end)
    r.Tabs[i] = tab
    vorher = tab
  end
  if PanelTemplates_SetNumTabs then pcall(PanelTemplates_SetNumTabs, r, #REITER) end
  W.reiter = r.Tabs
end

-- Flacher Aufbau wie früher: Kopfzeile, Reiter links
local function bauenFlach(r)
  r:SetSize(BREITE, HOEHE)
  S.schatten(r)
  S.kopf(r, L.SUBTITLE)

  local version = S.schrift(r, "GameFontHighlightSmall", F.leise)
  version:SetPoint("TOPRIGHT", -40, -18)
  version:SetText("v" .. ns.VERSION)
  local zu = S.zeichenKnopf(r, "x", function() r:Hide() end)
  zu:SetPoint("TOPRIGHT", -8, -11)

  -- Seitenleiste mit Reitern
  local leiste = r:CreateTexture(nil, "BORDER")
  leiste:SetPoint("TOPLEFT", 1, -46)
  leiste:SetPoint("BOTTOMLEFT", 1, 1)
  leiste:SetWidth(SEITE)
  leiste:SetColorTexture(rgba(F.seite))
  W.reiter = {}
  for i, t in ipairs(REITER) do
    local b = S.zeile(r)
    b:SetSize(SEITE, 30)
    b:SetPoint("TOPLEFT", 1, -54 - (i - 1) * 32)
    b.text = S.schrift(b, "GameFontHighlight", F.leise)
    b.text:SetPoint("LEFT", 16, 0)
    b.text:SetText(t.text)
    b.schluessel = t.schluessel
    b:SetScript("OnClick", function() S.klick() W:Zeigen(t.schluessel) end)
    W.reiter[i] = b
  end
end

function W:Bauen()
  local r = S.vorlage("Frame", UIParent, "PortraitFrameTemplate", "PigeonPostFrame")
  self.echt = r ~= nil and r.SetTitle ~= nil
  if not self.echt then r = S.kasten(UIParent, "Frame", F.grund, F.rand, "PigeonPostFrame") end
  self.rahmen = r
  local pos = ns.db.fenster
  if pos and pos.punkt then r:SetPoint(pos.punkt, UIParent, pos.punkt, pos.x, pos.y) else r:SetPoint("CENTER") end
  r:SetFrameStrata("HIGH")
  r:SetToplevel(true)
  r:SetClampedToScreen(true)
  r:EnableMouse(true)
  r:SetMovable(true)
  r:RegisterForDrag("LeftButton")
  r:SetScript("OnDragStart", function(self) self:StartMoving() end)
  r:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local punkt, _, _, x, y = self:GetPoint()
    ns.db.fenster = { punkt = punkt, x = x, y = y }
  end)
  if UISpecialFrames then table.insert(UISpecialFrames, "PigeonPostFrame") end
  if self.echt then bauenEcht(r) else bauenFlach(r) end

  bauenChars()
  bauenVerteilen()
  bauenItems()
  bauenEinstellungen()
  bauenNie()
  bauenProtokoll()
  bauenPruefen()
  bauenHilfe()
  r:Hide()
end

function W:Zeigen(schluessel)
  if not ns.db then return end
  if not self.rahmen then self:Bauen() end
  self.aktiv = schluessel or self.aktiv or "chars"
  for k, f in pairs(self.seiten) do f:SetShown(k == self.aktiv) end
  for i, b in ipairs(self.reiter) do
    local an = b.schluessel == self.aktiv
    if self.echt then
      if an and PanelTemplates_SetTab then pcall(PanelTemplates_SetTab, self.rahmen, i) end
    else
      b.wahl:SetShown(an)
      b.text:SetTextColor(rgba(an and F.text or F.leise))
    end
  end
  self.rahmen:Show()
  self:Aktualisieren()
end

function W:Umschalten()
  if self.rahmen and self.rahmen:IsShown() then self.rahmen:Hide() else self:Zeigen() end
end

function W:Aktualisieren()
  if not (self.rahmen and self.rahmen:IsShown()) then return end
  local f = self.seiten[self.aktiv]
  if f and f.Aktualisieren then f:Aktualisieren() end
end
