-- Kategorien und bekannte Gegenstände.
-- Erkennung in zwei Stufen (siehe Regeln.lua):
--   1. Feste Liste bekannter Classic-IDs. Greift auch, wenn Forever keine Unterklassen setzt.
--   2. Gegenstandsklasse und Unterklasse aus den Spieldaten (C_Item.GetItemInfoInstant).
-- Ob beides in Forever stimmt, zeigt /pigeon katalog.
local ADDON, ns = ...
local L = ns.L

ns.KLASSE = {
  VERBRAUCH = 0,
  BEHAELTER = 1,
  WAFFE = 2,
  EDELSTEIN = 3,
  RUESTUNG = 4,
  HANDELSWAREN = 7,
  QUEST = 12,
}
ns.QUALITAET_GRUEN = 2

-- Reihenfolge = Reihenfolge in der Oberfläche und im Brief
ns.KATEGORIEN = {
  { schluessel = "kraeuter", name = L.CAT_HERBS, kurz = L.CAT_HERBS, unterklasse = 9, standard = true,
    hilfe = L.CAT_HERBS_HELP },
  { schluessel = "bergbau", name = L.CAT_MINING, kurz = L.CAT_MINING, unterklasse = 7, standard = true,
    hilfe = L.CAT_MINING_HELP },
  { schluessel = "stoff", name = L.CAT_CLOTH, kurz = L.CAT_CLOTH, unterklasse = 5, standard = false,
    hilfe = L.CAT_CLOTH_HELP },
  { schluessel = "leder", name = L.CAT_LEATHER, kurz = L.CAT_LEATHER, unterklasse = 6, standard = false,
    hilfe = L.CAT_LEATHER_HELP },
  { schluessel = "verzauberung", name = L.CAT_ENCHANTING, kurz = L.CAT_ENCHANTING, unterklasse = 12, standard = false,
    hilfe = L.CAT_ENCHANTING_HELP },
  -- Handelswaren Unterklasse 8 (Fleisch, Kochen). Roher Fisch ist essbar und damit Verbrauchsgut,
  -- deshalb gilt für die Liste dieser Kategorie auch Klasse 0.
  { schluessel = "kochen", name = L.CAT_COOKING, kurz = L.CAT_COOKING, unterklasse = 8, standard = false,
    hilfe = L.CAT_COOKING_HELP, auchVerbrauch = true },
  { schluessel = "gruen", name = L.CAT_GREEN, kurz = L.CAT_GREEN_SHORT, standard = false,
    hilfe = L.CAT_GREEN_HELP },
}

ns.KATEGORIE = {}
for i, k in ipairs(ns.KATEGORIEN) do
  k.nr = i
  ns.KATEGORIE[k.schluessel] = k
end

-- Bekannte Classic-IDs je Kategorie
local LISTEN = {
  kraeuter = {
    765, 785, 2447, 2449, 2450, 2452, 2453, 3355, 3356, 3357, 3358, 3369, 3818, 3819, 3820, 3821,
    4625, 8831, 8836, 8838, 8839, 8845, 8846, 13463, 13464, 13465, 13466, 13467, 13468,
  },
  bergbau = {
    -- Erz
    2770, 2771, 2772, 2775, 2776, 3340, 3858, 4278, 5833, 7911, 10620, 11370,
    -- Stein
    2835, 2836, 2838, 7912, 12365,
    -- Barren
    2840, 2841, 2842, 3575, 3576, 3577, 3859, 3860, 6037, 11371, 12359, 12360, 12655,
    -- Edelsteine
    774, 818, 1206, 1210, 1529, 1705, 3864, 7909, 7910, 12361, 12363, 12364, 12799, 12800,
  },
  stoff = { 2589, 2592, 4306, 4338, 14047, 14256, 14342 },
  leder = { 783, 2318, 2319, 2934, 4232, 4234, 4235, 4304, 8169, 8170, 8171 },
  verzauberung = {
    10938, 10939, 10940, 10978, 10998, 11082, 11083, 11084, 11134, 11135, 11137, 11138, 11139,
    11174, 11175, 11176, 11177, 11178, 14343, 14344, 16202, 16203, 16204, 20725,
  },
  kochen = {
    -- Fleisch, Eier, Krabben und Muscheln
    723, 729, 730, 731, 769, 1015, 1080, 1081, 1468, 2251, 2672, 2673, 2674, 2675, 2677, 2886, 2924,
    3173, 3404, 3667, 3685, 3712, 3730, 3731, 4655, 5465, 5467, 5469, 5470, 5471, 5503, 5504, 6889,
    7974, 12037, 12184, 12202, 12203, 12204, 12205, 12206, 12207, 12208, 20424,
    -- Roher Fisch
    4603, 6289, 6291, 6303, 6308, 6317, 6361, 6362, 8365, 13754, 13755, 13756, 13758, 13759, 13760, 13889, 13893,
    -- Gewürze
    2678, 2692, 3713,
  },
}

ns.BEKANNT = {}
for schluessel, ids in pairs(LISTEN) do
  for _, id in ipairs(ids) do ns.BEKANNT[id] = schluessel end
end
