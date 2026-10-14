-- Versand: legt Gegenstände in den Brief und sendet ihn. Ein Klick, höchstens ein Brief.
-- Zustände: bereit -> packen -> senden -> bereit
-- Sicherungen vor dem Packen und noch einmal direkt vor dem Senden:
--   Briefkasten offen, nicht im Kampf, Empfänger aus dem Register, kein Gold und keine
--   Nachnahme im Postfenster, keine fremden Anhänge, Anhänge genau wie in der Vorschau.
-- SetSendMailMoney und SetSendMailCOD werden nie aufgerufen. Gold wird nur gelesen, um abzubrechen.
local ADDON, ns = ...
local L = ns.L

local Versand = { zustand = "bereit" }
ns.Versand = Versand

local PRUEF_TAKT = 0.2      -- Sekunden zwischen zwei Prüfungen der Anhänge
local PRUEF_VERSUCHE = 15   -- danach Abbruch
local SENDE_WARTEZEIT = 15  -- Sekunden bis zur Antwort des Servers
local PORTO = 30            -- Kupfer je Anhang, nur für die Vorabprüfung

local function status(text, art)
  if ns.Oberflaeche then ns.Oberflaeche:Status(text, art) end
end

local function aktualisieren()
  if ns.Oberflaeche then ns.Oberflaeche:Aktualisieren() end
end

local function protokoll(empfaenger, brief, ergebnis, fehler)
  local inhalt = {}
  for _, g in ipairs(brief) do
    table.insert(inhalt, { id = g.itemID, name = g.name, anzahl = g.anzahl })
  end
  local eintrag = {
    zeit = ns.jetzt(), von = ns.Register:Anzeigename(ns.db.chars[UnitGUID("player")]),
    an = ns.Register:Anzeigename(empfaenger), adresse = ns.Register:Adresse(empfaenger),
    ergebnis = ergebnis, inhalt = inhalt, fehler = fehler,
  }
  table.insert(ns.db.protokoll, eintrag)
  while #ns.db.protokoll > 200 do table.remove(ns.db.protokoll, 1) end
  return eintrag
end

-- Betreff: "Pigeon Post: Herbs, Mining". Das Betreff-Feld des Spiels fasst 64 Zeichen.
local BETREFF_MAX = 64
local function betreff(brief)
  local namen, gesehen = {}, {}
  for _, g in ipairs(brief) do
    local name = g.kategorie and ns.KATEGORIE[g.kategorie].kurz or L.SUBJECT_ITEMS
    if not gesehen[name] then
      gesehen[name] = true
      table.insert(namen, name)
    end
  end
  local text = L.SUBJECT_PREFIX .. table.concat(namen, ", ")
  if #text > BETREFF_MAX then text = string.sub(text, 1, BETREFF_MAX) end
  return text
end

-- Steht irgendwo Gold oder Nachnahme im Postfenster? Nur lesen, nie setzen.
-- Kann das Spiel es gar nicht sagen, gilt das als "ja": lieber kein Brief als ein Brief mit Gold.
local function goldImBrief()
  local betrag, gelesen = 0, false
  if GetSendMailMoney then betrag = betrag + (GetSendMailMoney() or 0) gelesen = true end
  if GetSendMailCOD then betrag = betrag + (GetSendMailCOD() or 0) end
  if MoneyInputFrame_GetCopper and SendMailMoney then
    local ok, kupfer = pcall(MoneyInputFrame_GetCopper, SendMailMoney)
    if ok then betrag = betrag + (kupfer or 0) gelesen = true end
  end
  return betrag > 0 or not gelesen
end

-- Aktuelle Anhänge im Postfenster: Platz -> { itemID, anzahl }, dazu die Anzahl
local function anhaenge()
  local t, n = {}, 0
  for i = 1, ns.Regeln.MaxAnhaenge() do
    local name, itemID, _, anzahl = GetSendMailItem(i)
    if name or itemID then
      t[i] = { itemID = itemID, anzahl = anzahl or 1 }
      n = n + 1
    end
  end
  return t, n
end

-- Stimmen die Anhänge genau mit dem Brief überein?
local function anhaengePassen(brief)
  local da, n = anhaenge()
  if n ~= #brief then return false end
  for i, g in ipairs(brief) do
    if not da[i] or da[i].itemID ~= g.itemID or da[i].anzahl ~= g.anzahl then return false end
  end
  return true
end

function Versand:Beschaeftigt()
  return self.zustand ~= "bereit"
end

function Versand:AnhaengeLeeren()
  for i = 1, ns.Regeln.MaxAnhaenge() do
    if GetSendMailItem(i) then ClickSendMailItemButton(i, true) end
  end
end

function Versand:Pruefen(empfaenger)
  if InCombatLockdown and InCombatLockdown() then return false, L.ERR_COMBAT end
  if not (MailFrame and MailFrame:IsShown()) then return false, L.ERR_MAILBOX_CLOSED end
  if not empfaenger or not ns.Register:IstEmpfaenger(empfaenger.guid) then return false, L.ERR_RECIPIENT end
  if goldImBrief() then return false, L.ERR_GOLD end
  return true
end

-- Der Knopf in der Leiste.
-- quelle: die Regel des Empfängers (Einzelbrief) oder eine Funktion, die den Brief frisch aus den
-- Taschen rechnet (Verteilen). ausgelassen: Gegenstände, die der Spieler aus diesem Brief genommen hat.
-- vorschau: der Brief, den die Leiste gerade zeigt. Weicht der echte Brief davon ab, wird nichts
-- gepackt: Der Spieler soll nur senden, was er gesehen hat.
function Versand:Klick(empfaenger, quelle, ausgelassen, vorschau)
  if self.zustand ~= "bereit" then return end

  local ok, grund = self:Pruefen(empfaenger)
  if not ok then return status(grund, "fehler") end

  local brief
  if type(quelle) == "function" then
    brief = quelle()
  elseif type(quelle) == "table" then
    brief = ns.Regeln.NaechsterBrief(quelle, ausgelassen)
  else
    brief = {}
  end
  if vorschau and not ns.Regeln.GleicherBrief(brief, vorschau) then
    status(L.ERR_PREVIEW_CHANGED, "hinweis")
    return aktualisieren()
  end
  if #brief == 0 then return status(L.ERR_NOTHING, "hinweis") end

  local _, schonDa = anhaenge()
  if schonDa > 0 then return status(L.ERR_ALREADY_ATTACHED, "fehler") end
  if GetMoney() < #brief * PORTO then return status(L.ERR_POSTAGE, "fehler") end

  self:Packen(empfaenger, brief)
end

function Versand:Packen(empfaenger, brief)
  -- Postfenster auf den Reiter "Send Mail" umschalten
  if SendMailFrame and not SendMailFrame:IsShown() and MailFrameTab2 then MailFrameTab2:Click() end
  if not (SendMailFrame and SendMailFrame:IsShown()) then return status(L.ERR_SEND_TAB, "fehler") end

  self.empfaenger, self.brief = empfaenger, brief
  self.adresse = ns.Register:Adresse(empfaenger)
  self.serverFehler = nil
  self.zustand = "packen"
  aktualisieren()

  ClearCursor()
  for i, g in ipairs(brief) do
    local info = C_Container.GetContainerItemInfo(g.tasche, g.platz)
    if not info or info.itemID ~= g.itemID or (info.stackCount or 1) ~= g.anzahl or info.isLocked then
      return self:Abbrechen(L.ERR_BAGS_CHANGED)
    end
    C_Container.PickupContainerItem(g.tasche, g.platz)
    ClickSendMailItemButton(i)
    if CursorHasItem and CursorHasItem() then
      ClearCursor()
      return self:Abbrechen(L.ERR_ATTACH)
    end
  end

  -- Empfänger auch im Postfenster anzeigen. Ändert ihn dort jemand, bricht Pigeon Post ab.
  if SendMailNameEditBox then SendMailNameEditBox:SetText(self.adresse) end

  self.versuche = 0
  self:AnhaengePruefen()
end

-- Wartet, bis die Anhänge im Postfenster angekommen sind, und vergleicht sie mit der Vorschau
function Versand:AnhaengePruefen()
  if self.zustand ~= "packen" then return end
  if anhaengePassen(self.brief) then return self:Senden() end
  self.versuche = self.versuche + 1
  if self.versuche >= PRUEF_VERSUCHE then return self:Abbrechen(L.ERR_MISMATCH) end
  C_Timer.After(PRUEF_TAKT, function() Versand:AnhaengePruefen() end)
end

function Versand:Senden()
  if self.zustand ~= "packen" then return end
  local ok, grund = self:Pruefen(self.empfaenger)
  if not ok then return self:Abbrechen(grund) end
  if not anhaengePassen(self.brief) then return self:Abbrechen(L.ERR_CHANGED) end
  if GetSendMailPrice and GetSendMailPrice() > GetMoney() then return self:Abbrechen(L.ERR_POSTAGE) end

  -- Adresse noch einmal frisch aus dem Register, nie aus dem Postfenster
  self.adresse = ns.Register:Adresse(self.empfaenger)
  if not self.adresse then return self:Abbrechen(L.ERR_RECIPIENT) end

  self.zustand = "senden"
  self.sendeNr = (self.sendeNr or 0) + 1
  local nr = self.sendeNr
  SendMail(self.adresse, betreff(self.brief), "")
  status(string.format(L.MSG_SENDING, self.adresse), "hinweis")
  aktualisieren()

  C_Timer.After(SENDE_WARTEZEIT, function()
    if Versand.zustand == "senden" and Versand.sendeNr == nr then
      -- Kommt die Bestätigung später doch noch, wird der Eintrag nachgetragen
      Versand.unklar = { eintrag = protokoll(Versand.empfaenger, Versand.brief, "unklar"), zeit = time(),
        anzahl = #Versand.brief, adresse = Versand.adresse }
      Versand:Fertig(L.ERR_NO_ANSWER, "fehler")
    end
  end)
end

-- Abbruch vor dem Senden: Anhänge zurück in die Taschen
function Versand:Abbrechen(grund)
  if self.zustand == "packen" then self:AnhaengeLeeren() end
  self:Fertig(grund, "fehler")
end

function Versand:Fertig(text, art)
  self.zustand = "bereit"
  self.brief = nil
  status(text, art)
  aktualisieren()
end

-- Briefkasten zu. MAIL_CLOSED kommt in Forever nicht (Beta, 13. Okt), deshalb ruft die Leiste
-- das auch aus ihrem OnHide auf. Das Spiel legt Anhänge beim Schließen selbst zurück.
function Versand:BriefkastenZu()
  if self.zustand == "bereit" then return end
  if self.zustand == "senden" then
    -- Der Brief ist schon unterwegs. Die Antwort des Servers kommt trotzdem.
    return
  end
  self:Fertig(L.MSG_CLOSED, "hinweis")
end

ns.Ereignis("MAIL_SEND_SUCCESS", function()
  if Versand.zustand == "bereit" and Versand.unklar and time() - Versand.unklar.zeit < 120 then
    local u = Versand.unklar
    Versand.unklar = nil
    u.eintrag.ergebnis = "gesendet"
    local text = string.format(L.MSG_SENT, ns.anhaenge(u.anzahl), u.adresse or "?")
    ns.melde(text)
    return Versand:Fertig(text, "erfolg")
  end
  if Versand.zustand ~= "senden" then return end
  local text = string.format(L.MSG_SENT, ns.anhaenge(#Versand.brief), Versand.adresse or ns.Register:Anzeigename(Versand.empfaenger))
  protokoll(Versand.empfaenger, Versand.brief, "gesendet")
  ns.melde(text)
  Versand:Fertig(text, "erfolg")
end)

-- Fehlermeldung des Servers merken (z. B. unbekannter Empfänger), damit sie im Protokoll steht.
-- Nur Meldungen zur Post, nicht "Nicht genug Wut" oder Ähnliches, das zufällig gleichzeitig kommt.
local POSTFEHLER
local function postFehler(nachricht)
  if not POSTFEHLER then
    POSTFEHLER = {}
    for name, wert in pairs(_G) do
      if type(name) == "string" and type(wert) == "string" and string.sub(name, 1, 9) == "ERR_MAIL_" then
        POSTFEHLER[wert] = true
      end
    end
    if ERR_NOT_ENOUGH_MONEY then POSTFEHLER[ERR_NOT_ENOUGH_MONEY] = true end
  end
  -- Ohne bekannte Texte (alter Client) lieber alles nehmen als nichts
  return next(POSTFEHLER) == nil or POSTFEHLER[nachricht] == true
end

ns.Ereignis("UI_ERROR_MESSAGE", function(_, nachricht)
  if Versand.zustand == "senden" and type(nachricht) == "string" and postFehler(nachricht) then
    Versand.serverFehler = nachricht
  end
end)

ns.Ereignis("MAIL_FAILED", function()
  if Versand.zustand ~= "senden" then return end
  local fehler = Versand.serverFehler
  protokoll(Versand.empfaenger, Versand.brief, "fehlgeschlagen", fehler)
  Versand:AnhaengeLeeren()
  Versand:Fertig(fehler and (L.ERR_FAILED .. " (" .. fehler .. ")") or L.ERR_FAILED, "fehler")
end)

ns.Ereignis("MAIL_CLOSED", function() Versand:BriefkastenZu() end)

-- Neuere Clients melden das Schließen über den Interaktions-Manager (Typ 17 = Briefkasten)
ns.Ereignis("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(typ)
  local briefkasten = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.MailInfo or 17
  if typ == briefkasten then Versand:BriefkastenZu() end
end)

-- Wer den Empfänger im Postfenster ändert, während Pigeon Post packt, bricht den Brief ab.
-- Ein leeres Feld zählt nicht: Das Spiel leert es selbst, nachdem ein Brief verschickt wurde,
-- und an "niemand" kann nichts gehen.
-- Dazu: Schließt der Briefkasten, während die Leiste eingeklappt ist, bekommt sie kein OnHide.
-- Deshalb auch das Verstecken des Postfensters selbst beobachten.
function Versand:NamensfeldBeobachten()
  if self.beobachtet then return end
  self.beobachtet = true
  if SendMailNameEditBox and SendMailNameEditBox.HookScript then
    SendMailNameEditBox:HookScript("OnTextChanged", function(feld)
      local text = feld:GetText()
      if Versand.zustand == "packen" and Versand.adresse
         and text and text ~= "" and text ~= Versand.adresse then
        Versand:Abbrechen(L.ERR_NAME_CHANGED)
      end
    end)
  end
  if MailFrame and MailFrame.HookScript then
    MailFrame:HookScript("OnHide", function() Versand:BriefkastenZu() end)
  end
end
