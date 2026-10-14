-- Oberfläche: Leiste rechts neben dem Postfenster.
-- Zwei Arten: "One character" (ein Empfänger, Kategorien zum Anhaken) und "Distribute"
-- (ein Profil verteilt auf mehrere Chars, siehe Verteilen.lua). In beiden gilt: ein Klick, ein Brief.
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F, rgba = S.F, S.rgba

local O = {}
ns.Oberflaeche = O

local BREITE, HOEHE, RAND = 250, 466, 10
local INNEN = BREITE - 2 * RAND
local SLOT, LUECKE = 35, 4
local ZEILE = 34
local LISTE_MAX = 10     -- sichtbare Zeilen der Empfängerliste, der Rest mit dem Mausrad
local PLAN_ZEILEN = 4

local ARTEN = {
  { wert = "einzeln", text = L.KIND_ONE, hilfe = L.KIND_ONE_HELP },
  { wert = "verteilen", text = L.KIND_SPLIT, hilfe = L.KIND_SPLIT_HELP },
}

local function ich() return UnitGUID("player") end
local function beschaeftigt() return ns.Versand:Beschaeftigt() end
local function verteilen() return ns.Verteilen.An() end

-- Allererster Brief: einmal nachfragen. "Yes" ist dann selbst der Klick für genau diesen Brief.
local function ersterBrief()
  if ns.db.sendenBestaetigt or not (StaticPopup_Show and StaticPopupDialogs) then return true end
  StaticPopupDialogs.PIGEONPOST_SENDEN = StaticPopupDialogs.PIGEONPOST_SENDEN or {
    text = L.CONFIRM_FIRST_SEND,
    button1 = L.YES,
    button2 = L.NO,
    OnAccept = function()
      ns.db.sendenBestaetigt = true
      O:Klick()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  }
  StaticPopup_Show("PIGEONPOST_SENDEN")
  return false
end

-- Einzelbrief oder Verteilen umschalten
function ns.ArtWaehlen(wert)
  if beschaeftigt() then return O:Aktualisieren() end
  ns.db.verteilung.an = wert == "verteilen"
  if O.liste then O.liste:Hide() end
  O.ausgelassen = {}
  O:Status("", "hinweis")
  O:Aktualisieren()
  if ns.Fenster then ns.Fenster:Aktualisieren() end
end

-- Ein Feld der Vorschau, wie ein Anhang im Postfenster
local function slot(parent, i)
  local s = S.kasten(parent, "Button", F.flaeche, F.rand)
  s:SetSize(SLOT, SLOT)
  local reihe, spalte = math.floor((i - 1) / 6), (i - 1) % 6
  s:SetPoint("TOPLEFT", spalte * (SLOT + LUECKE), -reihe * (SLOT + LUECKE))
  s.icon = s:CreateTexture(nil, "ARTWORK")
  s.icon:SetPoint("TOPLEFT", 2, -2)
  s.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  s.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  s.zahl = s:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  s.zahl:SetPoint("BOTTOMRIGHT", -2, 2)
  s:RegisterForClicks("RightButtonUp")
  s:HookScript("OnEnter", function(self)
    local g = self.gegenstand
    if not g then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if not pcall(GameTooltip.SetBagItem, GameTooltip, g.tasche, g.platz) then GameTooltip:SetText(g.name or "?") end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.RIGHTCLICK_REMOVE, F.leise[1], F.leise[2], F.leise[3])
    GameTooltip:AddLine(L.SHIFT_RIGHTCLICK_NEVER, F.leise[1], F.leise[2], F.leise[3])
    GameTooltip:Show()
  end)
  s:HookScript("OnLeave", function() GameTooltip:Hide() end)
  -- Rechtsklick: nur aus diesem Brief nehmen. Umschalt+Rechtsklick: nie wieder senden.
  s:SetScript("OnClick", function(self, taste)
    if taste ~= "RightButton" or not self.gegenstand then return end
    if IsShiftKeyDown and IsShiftKeyDown() then O:NieSenden(self.gegenstand) else O:Auslassen(self.gegenstand) end
    GameTooltip:Hide()
  end)
  function s:Zeigen(g)
    self.gegenstand = g
    if g then
      self.icon:SetTexture(g.icon)
      self.icon:Show()
      self.zahl:SetText(g.anzahl > 1 and tostring(g.anzahl) or "")
      S.randFarbe(self, S.qualitaetsFarbe(g.qualitaet))
    else
      self.icon:Hide()
      self.zahl:SetText("")
      S.randFarbe(self, F.rand)
    end
  end
  return s
end

-- Großes Wahlfeld mit Name und Info, wie ein Aufklappfeld (Empfänger, Profil)
local function wahlFeld(parent, y, beiKlick)
  local w = S.kasten(parent, "Button", F.flaeche, F.rand)
  w:SetSize(INNEN, 36)
  w:SetPoint("TOPLEFT", RAND, y)
  w.stern = S.stern(w, 14)
  w.stern:SetPoint("TOPLEFT", 7, -6)
  w.name = S.schrift(w, "GameFontHighlight", F.text)
  w.name:SetPoint("TOPLEFT", 8, -5)
  w.name:SetWidth(INNEN - 40)
  w.name:SetJustifyH("LEFT")
  w.name:SetWordWrap(false)
  w.info = S.schrift(w, "GameFontHighlightSmall", F.leise)
  w.info:SetPoint("TOPLEFT", 8, -21)
  w.info:SetWidth(INNEN - 34)
  w.info:SetJustifyH("LEFT")
  w.info:SetWordWrap(false)
  w.pfeil = S.winkel(w, F.leise)
  w.pfeil:SetPoint("RIGHT", -10, 0)
  w:HookScript("OnEnter", function(self) S.randFarbe(self, F.akzent) self.pfeil:Farbe(F.akzent) end)
  w:HookScript("OnLeave", function(self) S.randFarbe(self, F.rand) self.pfeil:Farbe(F.leise) end)
  w:SetScript("OnClick", function(self) S.klick() beiKlick(self) end)
  -- Lange Beschreibungen (Profil mit vielen Zielen) sind abgeschnitten: im Tooltip ganz
  S.tooltip(w, function(self) return self.name:GetText() end, function(self) return self.info:GetText() end)
  return w
end

-- Aufbau ----------------------------------------------------------------------

local function bauenEinzeln(p)
  local e = CreateFrame("Frame", nil, p)
  O.einzeln = e
  e:SetAllPoints()
  S.ueberschrift(e, L.RECIPIENT):SetPoint("TOPLEFT", RAND, -80)
  O.wahl = wahlFeld(e, -94, function()
    if #ns.Register:Empfaenger() == 0 then return ns.Fenster:Zeigen("chars") end
    if O.liste:IsShown() then O.liste:Hide() else O:ListeZeigen() end
  end)

  -- Auswahlliste, liegt über allem anderen. Mehr als 10 Chars: Mausrad.
  local liste = S.kasten(p, "Frame", F.grund, F.akzent)
  O.liste = liste
  liste:SetFrameStrata("DIALOG")
  liste:SetWidth(INNEN)
  liste:SetPoint("TOPLEFT", O.wahl, "BOTTOMLEFT", 0, -2)
  liste:SetClampedToScreen(true)
  liste:EnableMouseWheel(true)
  liste:SetScript("OnMouseWheel", function(self, delta)
    local hoechster = math.max(0, #(self.chars or {}) - LISTE_MAX)
    self.versatz = math.min(math.max((self.versatz or 0) - delta, 0), hoechster)
    O:ListeFuellen()
  end)
  liste:Hide()
  liste.fuss = CreateFrame("Button", nil, liste)
  liste.fuss:SetSize(INNEN - 2, 22)
  liste.fuss.text = S.schrift(liste.fuss, "GameFontHighlightSmall", F.leise)
  liste.fuss.text:SetPoint("LEFT", 8, 0)
  liste.fuss.text:SetText(L.MISSING_CHAR)
  liste.fuss:HookScript("OnEnter", function(self) self.text:SetTextColor(rgba(F.akzent)) end)
  liste.fuss:HookScript("OnLeave", function(self) self.text:SetTextColor(rgba(F.leise)) end)
  liste.fuss:SetScript("OnClick", function() liste:Hide() ns.Fenster:Zeigen("chars") end)
  O.zeilen = {}

  S.ueberschrift(e, L.SEND_THESE):SetPoint("TOPLEFT", RAND, -140)
  O.haken = {}
  for i, k in ipairs(ns.KATEGORIEN) do
    local h = S.haken(e, (INNEN - 6) / 2, k.kurz, k.hilfe, function(knopf, an)
      if beschaeftigt() or not O.regel then return O:Aktualisieren() end
      O.regel.kategorien[knopf.schluessel] = an
      O:Aktualisieren()
    end)
    h.schluessel = k.schluessel
    local spalte, reihe = (i - 1) % 2, math.floor((i - 1) / 2)
    h:SetPoint("TOPLEFT", RAND + spalte * ((INNEN + 6) / 2), -154 - reihe * 20)
    O.haken[i] = h
  end
end

local function bauenVerteilen(p)
  local v = CreateFrame("Frame", nil, p)
  O.verteilen = v
  v:SetAllPoints()
  S.ueberschrift(v, L.PROFILE):SetPoint("TOPLEFT", RAND, -80)
  O.profil = wahlFeld(v, -94, function(feld)
    local eintraege = {}
    local aktiv = ns.Verteilen.AktivNr()
    for i, pr in ipairs(ns.Verteilen.Profile()) do
      table.insert(eintraege, { wert = i, text = pr.name, farbe = i == aktiv and F.akzent or F.text })
    end
    table.insert(eintraege, { wert = "bearbeiten", text = L.EDIT_DISTRIBUTION, farbe = F.leise })
    S.aufklappen(feld, INNEN, eintraege, function(wert)
      if wert == "bearbeiten" then return ns.Fenster:Zeigen("verteilen") end
      if beschaeftigt() then return end
      ns.Verteilen.Waehlen(wert)
      O.ausgelassen = {}
      O:Aktualisieren()
      if ns.Fenster then ns.Fenster:Aktualisieren() end
    end)
  end)

  S.ueberschrift(v, L.LETTERS):SetPoint("TOPLEFT", RAND, -140)
  O.planAnzahl = S.schrift(v, "GameFontHighlightSmall", F.leise)
  O.planAnzahl:SetPoint("TOPRIGHT", -RAND, -140)
  O.planZeilen = {}
  for i = 1, PLAN_ZEILEN do
    local z = CreateFrame("Frame", nil, v)
    z:SetSize(INNEN, 20)
    z:SetPoint("TOPLEFT", RAND, -154 - (i - 1) * 20)
    z.name = S.schrift(z, "GameFontHighlightSmall", F.text)
    z.name:SetPoint("LEFT", 0, 0)
    z.name:SetWidth(INNEN - 96)
    z.name:SetJustifyH("LEFT")
    z.name:SetWordWrap(false)
    z.info = S.schrift(z, "GameFontHighlightSmall", F.leise)
    z.info:SetPoint("RIGHT", 0, 0)
    O.planZeilen[i] = z
  end
  O.planLeer = S.absatz(v, INNEN, F.leise)
  O.planLeer:SetPoint("TOPLEFT", RAND, -156)
end

function O:Bauen()
  local p = S.kasten(MailFrame, "Frame", F.grund, F.rand)
  self.panel = p
  p:SetSize(BREITE, HOEHE)
  p:EnableMouse(true)
  S.schatten(p)
  S.kopf(p, L.SUBTITLE_SHORT)

  local zu = S.zeichenKnopf(p, "«", function() ns.db.eingeklappt = true O:Sichtbarkeit() end)
  zu:SetPoint("TOPRIGHT", -6, -12)
  S.tooltip(zu, L.COLLAPSE, L.COLLAPSE_HELP)
  local optionen = S.textKnopf(p, L.OPTIONS, 60, function() ns.Fenster:Zeigen("einstellungen") end)
  optionen:SetHeight(20)
  optionen:SetPoint("TOPRIGHT", -32, -13)
  S.tooltip(optionen, L.OPTIONS, L.OPTIONS_HELP)

  -- Einzelbrief oder Verteilen
  self.art = S.segmente(p, INNEN, ARTEN, ns.ArtWaehlen)
  self.art:SetPoint("TOPLEFT", RAND, -52)

  bauenEinzeln(p)
  bauenVerteilen(p)

  -- Nur volle Stapel: im Einzelbrief für den Empfänger, beim Verteilen für das Profil
  self.stapel = S.haken(p, INNEN, L.STACKS_FULL, L.STACKS_FULL_HELP, function(_, an)
    if beschaeftigt() then return O:Aktualisieren() end
    local wert = an and "voll" or "alles"
    if verteilen() then
      ns.Verteilen.Aktiv().stapel = wert
    elseif O.regel then
      O.regel.stapel = wert
    end
    O:Aktualisieren()
    if ns.Fenster then ns.Fenster:Aktualisieren() end
  end)
  self.stapel:SetPoint("TOPLEFT", RAND, -242)

  -- Vorschau
  self.vorschauTitel = S.ueberschrift(p, L.NEXT_LETTER)
  self.vorschauTitel:SetPoint("TOPLEFT", RAND, -272)
  self.vorschauTitel:SetWidth(INNEN - 50)
  self.vorschauTitel:SetJustifyH("LEFT")
  self.vorschauTitel:SetWordWrap(false)
  self.anzahl = S.schrift(p, "GameFontHighlightSmall", F.leise)
  self.anzahl:SetPoint("TOPRIGHT", -RAND, -272)
  local raster = CreateFrame("Frame", nil, p)
  raster:SetSize(INNEN, 2 * SLOT + LUECKE)
  raster:SetPoint("TOPLEFT", RAND, -286)
  self.slots = {}
  for i = 1, 12 do self.slots[i] = slot(raster, i) end
  -- Infozeile darf zweizeilig sein, damit das Porto nicht abgeschnitten wird
  self.info = S.absatz(p, INNEN, F.leise)
  self.info:SetPoint("TOPLEFT", RAND, -366)
  -- Herausgenommene Gegenstände zurück in den Brief
  self.zurueck = S.textKnopf(p, "", 62, function()
    O.ausgelassen = {}
    O:Aktualisieren()
  end)
  self.zurueck:SetHeight(16)
  self.zurueck:SetPoint("TOPRIGHT", -RAND, -363)
  S.tooltip(self.zurueck, L.PUT_BACK, L.PUT_BACK_HELP)

  -- Knopf und Meldung
  self.knopf = S.knopf(p, INNEN, 30)
  self.knopf:SetPoint("TOPLEFT", RAND, -398)
  self.knopf:SetScript("OnClick", function() O:Klick() end)
  self.meldung = S.absatz(p, INNEN, F.leise)
  self.meldung:SetPoint("TOPLEFT", RAND, -434)
  self.meldung:SetJustifyH("CENTER")

  -- Eingeklappt: kleiner Knopf mit Icon am Postfenster
  local lasche = S.kasten(MailFrame, "Button", F.grund, F.rand)
  self.lasche = lasche
  lasche:SetSize(36, 36)
  local laschenIcon = lasche:CreateTexture(nil, "ARTWORK")
  laschenIcon:SetPoint("TOPLEFT", 4, -4)
  laschenIcon:SetPoint("BOTTOMRIGHT", -4, 4)
  laschenIcon:SetTexture(S.ICON)
  lasche:HookScript("OnEnter", function(self) S.randFarbe(self, F.akzent) end)
  lasche:HookScript("OnLeave", function(self) S.randFarbe(self, F.rand) end)
  lasche:SetScript("OnClick", function()
    S.klick()
    ns.db.eingeklappt = false
    O.sitzungZu = false
    O:Sichtbarkeit()
  end)
  S.tooltip(lasche, L.ADDON_NAME, function() return O.laschenHilfe or L.EXPAND_HELP end)

  -- Jedes Mal, wenn die Leiste sichtbar wird, neu rechnen. Forever meldet MAIL_SHOW, bevor das
  -- Postfenster sichtbar ist (Beta, 14. Okt); sonst bliebe die Vorschau vom letzten Besuch stehen.
  p:SetScript("OnShow", function() O:Aktualisieren() end)

  -- Briefkasten zu oder Leiste versteckt: Liste schließen, halb gepackten Brief abbrechen
  p:SetScript("OnHide", function()
    O.liste:Hide()
    if not (MailFrame and MailFrame:IsShown()) then ns.Versand:BriefkastenZu() end
  end)
  MailFrame:HookScript("OnHide", function() O.sitzung = false end)

  -- Ein geöffneter Brief erscheint rechts neben dem Posteingang. Dann rückt die Leiste daneben.
  if OpenMailFrame and OpenMailFrame.HookScript then
    OpenMailFrame:HookScript("OnShow", function() O:Anker() end)
    OpenMailFrame:HookScript("OnHide", function() O:Anker() end)
  end
  self:Anker()
end

function O:Anker()
  if not self.panel then return end
  local neben = MailFrame
  if OpenMailFrame and OpenMailFrame:IsShown() then neben = OpenMailFrame end
  self.panel:ClearAllPoints()
  self.panel:SetPoint("TOPLEFT", neben, "TOPRIGHT", 4, 0)
  self.lasche:ClearAllPoints()
  self.lasche:SetPoint("TOPLEFT", neben, "TOPRIGHT", 4, -40)
end

-- Empfängerliste ----------------------------------------------------------------

function O:ListeZeigen()
  local chars = ns.Register:Empfaenger()
  if #chars == 0 or beschaeftigt() then return end
  self.liste.chars, self.liste.versatz = chars, 0
  local sichtbar = math.min(#chars, LISTE_MAX)
  for i = 1, sichtbar do
    local z = self.zeilen[i]
    if not z then
      z = S.zeile(self.liste)
      z:SetSize(INNEN - 2, ZEILE)
      z:SetPoint("TOPLEFT", 1, -1 - (i - 1) * ZEILE)
      z.name = S.schrift(z, "GameFontHighlight")
      z.name:SetPoint("TOPLEFT", 8, -4)
      z.info = S.schrift(z, "GameFontHighlightSmall", F.leise)
      z.info:SetPoint("TOPLEFT", z.name, "BOTTOMLEFT", 0, -3)
      z.info:SetWidth(INNEN - 44)
      z.info:SetJustifyH("LEFT")
      z.info:SetWordWrap(false)
      -- Stern rechts: Favorit an oder aus, ohne den Char zu wählen
      z.favorit = CreateFrame("Button", nil, z)
      z.favorit:SetSize(22, 22)
      z.favorit:SetPoint("RIGHT", -6, 0)
      z.favorit.stern = S.stern(z.favorit, 16)
      z.favorit.stern:SetPoint("CENTER")
      z.favorit:SetScript("OnClick", function(self)
        S.klick()
        ns.Register:Favorit(self:GetParent().char.guid)
        O:ListeFuellen()
        O:Aktualisieren()
      end)
      S.tooltip(z.favorit, L.FAVORITE, L.FAVORITE_HELP)
      z:SetScript("OnClick", function(self)
        S.klick()
        O.wahlGuid = self.char.guid
        ns.db.gewaehlt[ich()] = self.char.guid
        O.liste:Hide()
        O:Status("", "hinweis")
        O:Aktualisieren()
      end)
      self.zeilen[i] = z
    end
  end
  for i = sichtbar + 1, #self.zeilen do self.zeilen[i]:Hide() end
  self.liste.fuss:SetPoint("TOPLEFT", 1, -1 - sichtbar * ZEILE)
  self.liste:SetHeight(sichtbar * ZEILE + 24)
  self:ListeFuellen()
  self.liste:Show()
end

function O:ListeFuellen()
  local chars, versatz = self.liste.chars or {}, self.liste.versatz or 0
  local favorit = ns.Register:Favorit()
  for i = 1, math.min(#chars, LISTE_MAX) do
    local z, c = self.zeilen[i], chars[i + versatz]
    if z and c then
      z.char = c
      z.name:SetText(ns.Register:Anzeigename(c))
      z.name:SetTextColor(rgba(S.klassenFarbe(c.klasse)))
      z.info:SetText(ns.Register:Beschreibung(c))
      z.favorit.stern:SetDesaturated(c.guid ~= favorit)
      z.favorit.stern:SetAlpha(c.guid == favorit and 1 or 0.35)
      z:Show()
    end
  end
end

-- Anzeige ---------------------------------------------------------------------

function O:Sichtbarkeit()
  if not self.panel then return end
  local zu = ns.db.eingeklappt or self.sitzungZu
  self.panel:SetShown(not zu)
  self.lasche:SetShown(zu and true or false)
  self:Aktualisieren()
end

function O:Status(text, art)
  self.statusText, self.statusArt = text, art
  if not self.meldung then return end
  self.meldung:SetText(text or "")
  self.meldung:SetTextColor(rgba(F[art] or F.leise))
end

-- Empfänger dieser Sitzung: zuerst die Wahl in dieser Sitzung, dann der Favorit,
-- dann der zuletzt auf diesem Char gewählte, sonst der erste gültige
function O:EmpfaengerGuid()
  local R = ns.Register
  if R:IstEmpfaenger(self.wahlGuid) then return self.wahlGuid end
  if R:IstEmpfaenger(R:Favorit()) then return R:Favorit() end
  local zuletzt = ns.db.gewaehlt[ich()]
  if R:IstEmpfaenger(zuletzt) then return zuletzt end
  local chars = R:Empfaenger()
  return chars[1] and chars[1].guid
end

-- Einzelbrief: Empfänger, Kategorien, nächster Brief
local function anzeigenEinzeln(self)
  local guid = self:EmpfaengerGuid()
  local empf = guid and ns.db.chars[guid]
  self.empfaenger = empf
  self.regel = guid and ns.Regeln.Fuer(guid) or nil

  local w = self.wahl
  if empf then
    local favorit = guid == ns.Register:Favorit()
    w.stern:SetShown(favorit)
    w.name:SetPoint("TOPLEFT", favorit and 24 or 8, -5)
    w.name:SetText(ns.Register:Anzeigename(empf))
    w.name:SetTextColor(rgba(S.klassenFarbe(empf.klasse)))
    w.info:SetText(ns.Register:Beschreibung(empf))
  else
    w.stern:Hide()
    w.name:SetPoint("TOPLEFT", 8, -5)
    w.name:SetText(L.NO_CHARS)
    w.name:SetTextColor(rgba(F.hinweis))
    w.info:SetText(L.NO_CHARS_HINT)
  end

  local brief, alle, menge, reste
  if self.regel then
    brief, alle, menge, reste = ns.Regeln.NaechsterBrief(self.regel, self.ausgelassen)
  else
    brief, alle, menge, reste = {}, {}, {}, 0
  end
  for _, h in ipairs(self.haken) do
    h:Setzen(self.regel and self.regel.kategorien[h.schluessel])
    h.menge:SetText(menge[h.schluessel] and tostring(menge[h.schluessel]) or "")
  end
  self.stapel:Setzen(not self.regel or self.regel.stapel ~= "alles")
  return brief, #alle, empf and 1 or 0, reste, math.ceil(#alle / ns.Regeln.MaxAnhaenge())
end

-- Verteilen: Profil, Briefe je Empfänger, nächster Brief des Plans
local function anzeigenVerteilen(self)
  local profil = ns.Verteilen.Aktiv()
  self.profil.stern:Hide()
  self.profil.name:SetText(profil.name)
  self.profil.name:SetTextColor(rgba(F.akzent))
  self.profil.info:SetText(ns.Verteilen.Beschreibung(profil))
  self.stapel:Setzen(profil.stapel ~= "alles")

  local briefe, empfaenger, ungueltig, reste = ns.Verteilen.Plan(profil, self.ausgelassen)
  local zeilen = {}
  for _, e in ipairs(empfaenger) do
    table.insert(zeilen, { text = ns.Register:Anzeigename(e.char), farbe = S.klassenFarbe(e.char.klasse),
      info = ns.anhaenge(e.anzahl) .. "  ·  " .. (e.briefe == 1 and L.ONE_LETTER or string.format(L.N_LETTERS, e.briefe)) })
  end
  for guid in pairs(ungueltig) do
    local c = ns.db.chars[guid]
    table.insert(zeilen, { text = c and ns.Register:Anzeigename(c) or L.TARGET_UNKNOWN, farbe = F.hinweis,
      info = L.CANT_RECEIVE_HERE })
  end
  if #zeilen > PLAN_ZEILEN then
    local mehr = #zeilen - PLAN_ZEILEN + 1
    zeilen[PLAN_ZEILEN] = { text = string.format(L.MORE_RECIPIENTS, mehr), farbe = F.leise, info = "" }
  end
  for i, z in ipairs(self.planZeilen) do
    local e = zeilen[i]
    z:SetShown(e ~= nil)
    if e then
      z.name:SetText(e.text)
      z.name:SetTextColor(rgba(e.farbe))
      z.info:SetText(e.info)
    end
  end
  self.planLeer:SetText(#zeilen == 0 and L.PLAN_EMPTY or "")
  self.planAnzahl:SetText(#briefe > 0 and (#briefe == 1 and L.ONE_LETTER or string.format(L.N_LETTERS, #briefe)) or "")

  local erster = briefe[1]
  self.empfaenger = erster and erster.char or nil
  local alle = 0
  for _, e in ipairs(empfaenger) do alle = alle + e.anzahl end
  return erster and erster.brief or {}, alle, #empfaenger, reste, #briefe
end

function O:Aktualisieren()
  if not (self.panel and self.panel:IsVisible()) then return end
  local v = ns.Versand
  local split = verteilen()
  self.art:Setzen(split and "verteilen" or "einzeln")
  self.einzeln:SetShown(not split)
  self.verteilen:SetShown(split)

  local brief, alle, empfaengerZahl, reste, briefe
  if split then
    brief, alle, empfaengerZahl, reste, briefe = anzeigenVerteilen(self)
  else
    brief, alle, empfaengerZahl, reste, briefe = anzeigenEinzeln(self)
  end
  -- Während Pigeon Post packt oder sendet, zeigt die Vorschau genau diesen Brief
  if v:Beschaeftigt() and v.brief then
    brief = v.brief
    self.empfaenger = v.empfaenger
  else
    self.vorschau = brief
  end
  local empf = self.empfaenger

  self.vorschauTitel:SetText(split and empf and string.format(L.NEXT_LETTER_TO, ns.Register:Anzeigename(empf)) or L.NEXT_LETTER)

  for i = 1, 12 do self.slots[i]:Zeigen(brief[i]) end
  local raus = 0
  for _ in pairs(self.ausgelassen or {}) do raus = raus + 1 end
  self.zurueck.text:SetText(string.format(L.PUT_BACK_N, raus))
  local undo = raus > 0 and not v:Beschaeftigt()
  self.zurueck:SetShown(undo)
  self.info:SetWidth(undo and INNEN - 64 or INNEN)
  self.anzahl:SetText(#brief > 0 and string.format(L.X_OF_Y, #brief, ns.Regeln.MaxAnhaenge()) or "")

  if not split and not empf then
    self.info:SetText("")
  elseif alle == 0 then
    -- Nichts passt. Liegt es nur an "nur volle Stapel", sagen wir das.
    self.info:SetText((reste or 0) > 0 and L.ONLY_PARTIAL_STACKS or L.NOTHING_MATCHES)
  else
    local briefText = briefe == 1 and L.ONE_LETTER or string.format(L.N_LETTERS, briefe)
    if split then
      self.info:SetText(string.format(L.SPLIT_INFO_LINE, ns.anhaenge(alle), briefText,
        empfaengerZahl == 1 and L.ONE_CHARACTER or string.format(L.N_CHARACTERS, empfaengerZahl), ns.geld(#brief * 30)))
    else
      self.info:SetText(string.format(L.INFO_LINE, ns.anhaenge(alle), briefText, ns.geld(#brief * 30)))
    end
  end

  local k = self.knopf
  local name = empf and ns.vorname(ns.Register:Anzeigename(empf)) or ""
  if v:Beschaeftigt() then
    k:Aussehen(L.BTN_WAIT, F.akzent, false)
  elseif not empf and not split then
    k:Aussehen(L.BTN_NO_RECIPIENT, F.akzent, false)
  elseif #brief == 0 then
    k:Aussehen(L.BTN_NOTHING, F.akzent, false)
  else
    k:Aussehen(string.format(split and L.BTN_SPLIT_SEND or L.BTN_SEND, name), F.akzent, true)
  end
end

-- Der große Knopf: genau ein Brief
function O:Klick()
  self.liste:Hide()
  if ns.Versand:Beschaeftigt() or not ersterBrief() then return end
  if verteilen() and ns.Versand.zustand == "bereit" then
    local empf = self.empfaenger
    if not empf then return end
    local ausgelassen = self.ausgelassen
    return ns.Versand:Klick(empf, function() return ns.Verteilen.NaechsterBriefAn(empf.guid, ausgelassen) end,
      ausgelassen, self.vorschau)
  end
  ns.Versand:Klick(self.empfaenger, self.regel, self.ausgelassen, self.vorschau)
end

function O:NieSenden(g)
  if beschaeftigt() then return end
  ns.db.nie[g.itemID] = g.name or tostring(g.itemID)
  ns.melde(string.format(L.MSG_NEVER, g.name or g.itemID))
  self:Aktualisieren()
  if ns.Fenster then ns.Fenster:Aktualisieren() end
end

-- Nur aus diesem Brief nehmen, bis der Briefkasten wieder zu ist
function O:Auslassen(g)
  if beschaeftigt() then return end
  self.ausgelassen = self.ausgelassen or {}
  self.ausgelassen[ns.Regeln.Platz(g)] = true
  self:Aktualisieren()
end

-- Briefkasten geht auf. Forever meldet MAIL_SHOW mehrmals: Herausgenommenes und Meldung nur
-- beim ersten Mal pro Besuch zurücksetzen.
function O:Oeffnen()
  if not MailFrame then return end
  if not self.panel then self:Bauen() end
  ns.Versand:NamensfeldBeobachten()
  if not self.sitzung then
    self.sitzung = true
    self.ausgelassen = {}
    self:Status("", "hinweis")
    -- Ohne Empfänger (nur ein Char) erst einmal eingeklappt, mit Hinweis im Tooltip
    local keiner = #ns.Register:Empfaenger() == 0
    self.sitzungZu = not ns.db.autoOeffnen or keiner
    self.laschenHilfe = keiner and L.NO_CHARS_TOOLTIP or nil
  end
  self:Anker()
  self:Sichtbarkeit()
  -- Zur Sicherheit noch einmal im nächsten Bild, wenn das Postfenster sicher sichtbar ist
  if C_Timer and C_Timer.After then C_Timer.After(0, function() O:Aktualisieren() end) end
end

-- Viele Taschen-Ereignisse kurz hintereinander: nur einmal neu rechnen, und nur wenn sichtbar
local geplant = false
function O:Bald()
  if geplant or not (self.panel and self.panel:IsVisible()) then return end
  if not (C_Timer and C_Timer.After) then return self:Aktualisieren() end
  geplant = true
  C_Timer.After(0.2, function()
    geplant = false
    O:Aktualisieren()
  end)
end

ns.Ereignis("MAIL_SHOW", function() O:Oeffnen() end)
ns.Ereignis("BAG_UPDATE_DELAYED", function() O:Bald() end)
ns.Ereignis("GET_ITEM_INFO_RECEIVED", function() O:Bald() end)

-- Im Tooltip jedes Gegenstands zeigen, in welche Kategorie Pigeon Post ihn einordnet
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tip, daten)
    if tip ~= GameTooltip or not daten or not ns.db or not ns.db.tooltip then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local ok, itemID = pcall(function() return daten.id end)
    if not ok or type(itemID) ~= "number" then return end
    local d = ns.Regeln.Daten(itemID)
    local kategorie = ns.Regeln.Kategorie(itemID, d)
    if kategorie then
      local text = L.TOOLTIP_PREFIX .. ns.KATEGORIE[kategorie].name
      if ns.db.nie[itemID] then text = text .. " " .. L.NEVER_SUFFIX end
      tip:AddLine(text, F.akzent[1], F.akzent[2], F.akzent[3])
    end
  end)
end
