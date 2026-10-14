-- Befehle für /pigeon. Alles Wichtige geht auch im Fenster, die Befehle sind nur Abkürzungen.
local ADDON, ns = ...
local L = ns.L

local BEFEHLE = {
  { "", L.CMD_WINDOW },
  { "panel", L.CMD_PANEL },
  { "split", L.CMD_SPLIT },
  { "profile <name>", L.CMD_PROFILE },
  { "favorite <name>", L.CMD_FAVORITE },
  { "remove <name>", L.CMD_REMOVE },
  { "log", L.CMD_LOG },
  { "check", L.CMD_CHECK },
  { "help", L.CMD_HELP },
}
ns.BEFEHLE = BEFEHLE

local function zeile(text) DEFAULT_CHAT_FRAME:AddMessage("  " .. text) end

local function hilfe()
  ns.melde(L.COMMANDS)
  for _, b in ipairs(BEFEHLE) do
    zeile("/pigeon" .. (b[1] ~= "" and (" " .. b[1]) or "") .. ": " .. b[2])
  end
end

local ERGEBNIS = { gesendet = L.RESULT_SENT, probelauf = L.RESULT_TEST, fehlgeschlagen = L.RESULT_FAILED, unklar = L.RESULT_UNCLEAR }

local function protokoll()
  local p = ns.db.protokoll
  ns.melde(L.HISTORY_TITLE)
  for i = math.max(1, #p - 9), #p do
    local e = p[i]
    zeile(string.format(L.LOG_LINE, e.zeit, string.format(L.FROM_TO, e.von or "?", e.an or "?"),
      ns.anhaenge(#(e.inhalt or {})), ERGEBNIS[e.ergebnis] or tostring(e.ergebnis)))
  end
  if #p == 0 then zeile(L.HISTORY_EMPTY) end
end

local function charPerName(name)
  local guid, c = ns.Register:NachName(name)
  if not guid then ns.melde(string.format(L.ERR_NO_CHAR, name or "")) end
  return guid, c
end

SLASH_PIGEONPOST1 = "/pigeon"
SLASH_PIGEONPOST2 = "/pigeonpost"
SlashCmdList.PIGEONPOST = function(eingabe)
  if not ns.db then return end
  local wort, rest = string.match(eingabe or "", "^%s*(%S*)%s*(.-)%s*$")
  wort = string.lower(wort or "")
  if wort == "" then
    ns.Fenster:Umschalten()
  elseif wort == "help" then
    hilfe()
  elseif wort == "panel" then
    if MailFrame and MailFrame:IsShown() and ns.Oberflaeche.panel then
      ns.db.eingeklappt = not ns.db.eingeklappt
      ns.Oberflaeche.sitzungZu = false
      ns.Oberflaeche:Sichtbarkeit()
    else
      ns.melde(L.ERR_MAILBOX_CLOSED)
    end
  elseif wort == "split" then
    if ns.Versand:Beschaeftigt() then return ns.melde(L.ERR_BUSY) end
    ns.ArtWaehlen(ns.Verteilen.An() and "einzeln" or "verteilen")
    ns.melde(ns.Verteilen.An() and string.format(L.MSG_SPLIT_ON, ns.Verteilen.Aktiv().name) or L.MSG_SPLIT_OFF)
  elseif wort == "profile" then
    if ns.Versand:Beschaeftigt() then return ns.melde(L.ERR_BUSY) end
    local gesucht = string.lower(rest or "")
    for i, pr in ipairs(ns.Verteilen.Profile()) do
      if string.lower(pr.name) == gesucht then
        ns.Verteilen.Waehlen(i)
        ns.melde(string.format(L.MSG_PROFILE, pr.name))
        ns.Oberflaeche:Aktualisieren()
        return ns.Fenster:Aktualisieren()
      end
    end
    local namen = {}
    for _, pr in ipairs(ns.Verteilen.Profile()) do table.insert(namen, pr.name) end
    ns.melde(string.format(L.ERR_NO_PROFILE, table.concat(namen, ", ")))
  elseif wort == "favorite" then
    local guid, c = charPerName(rest)
    if guid then
      local neu = ns.Register:Favorit(guid)
      ns.melde(string.format(neu and L.MSG_FAVORITE_ON or L.MSG_FAVORITE_OFF, c.name))
      ns.Oberflaeche:Aktualisieren()
      ns.Fenster:Aktualisieren()
    end
  elseif wort == "remove" then
    if ns.Versand:Beschaeftigt() then return ns.melde(L.ERR_BUSY) end
    local guid = charPerName(rest)
    if guid then
      local name = ns.Register:Entfernen(guid)
      ns.melde(name and string.format(L.MSG_REMOVED, name) or L.REMOVE_SELF)
      ns.Oberflaeche:Aktualisieren()
      ns.Fenster:Aktualisieren()
    end
  elseif wort == "log" then
    protokoll()
  elseif wort == "check" then
    ns.Fenster:Zeigen("pruefen")
  else
    ns.melde(L.ERR_UNKNOWN_CMD)
  end
end
