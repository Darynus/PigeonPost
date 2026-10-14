# Pigeon Post changelog

## 0.5.0-beta (2026-10-14)

- **Simpler panel**: the Test, Attach and Send modes are gone. The panel shows the next letter, and one click attaches exactly these items and sends it. Before your very first letter Pigeon Post asks once. `/pigeon test` was removed.
- Full stacks only is now a single checkbox in the panel, so the panel is much shorter.
- Hover the recipient or profile field to read its full description.
- New: **Distribute**. Set up profiles (for example "Bank" and "Crafters") that split your items between several characters: herbs to your alchemist, ore to your blacksmith, cloth to your tailor, everything else to your bank character. Item rules send a single item to a single character. At the mailbox, switch the panel to Distribute and Pigeon Post plans all letters. Still one click per letter.
- New category **Cooking**: meat, fish, eggs and spices. Off by default. In existing Distribute profiles it stays in your bags until you choose a target.
- **Never send**: drag an item from your bags onto the box in the window to add it, just like item rules.
- Fixed: closing the mailbox while the panel was collapsed could leave a letter half packed.
- Fixed: the game fires the mailbox event several times. Items you took out of a letter no longer come back by themselves.
- If the server confirms a letter late, the history now says sent instead of unclear.
- Only mail errors end up in the history, not unrelated error messages.
- Hint when only partial stacks are left and Full stacks only is selected.
- The panel moves next to an opened letter instead of covering it.
- The recipient list scrolls with the mouse wheel when you have many characters.
- Characters that have not logged in for two weeks are marked in the recipient list.
- Safer: if the game cannot tell whether gold is in the mail window, nothing is sent. In WoW Forever the last name is always required.
- Subject stays within the 64 characters the game allows. Copper shows as c.
- If a character unlearns a profession, the list updates.
- Shorter hint below an empty preview, it no longer gets cut off.

## 0.4.0-beta

- New name: **Pigeon Post** (was AltPost during the closed beta). Command is now `/pigeon` (or `/pigeonpost`).
- First release on CurseForge.

## 0.3.1-beta

- Fixed: the preview could show items from your last mailbox visit, for example an item you sold in between. The panel now refreshes every time it appears.
- New safety check: if your bags changed since the preview was drawn, Pigeon Post attaches nothing, refreshes the preview and asks you to click again. You only ever send what you saw.
- The info line below the preview is no longer cut off.
- Panel and window backgrounds are fully opaque, nothing from the game world shines through.

## 0.3.0-beta

- WoW Forever names: Pigeon Post now remembers first **and** last name and mails the full name. A first name alone is not unique in Forever and could reach someone else. Characters without a known last name get no mail until you log in with them once more.
- The window shows the exact mail address for every character.
- Right-click an item in the preview to take it out of this letter. Shift + right-click puts it on the Never send list.
- If the server rejects a letter, its message is shown and kept in the history.
- Fixed: the Options button overlapped the subtitle. New drop-down arrow.

## 0.2.0-beta

- English interface in every game language. Items are recognized by item data, not by names.
- New Pigeon Post window (`/pigeon`): Characters, Settings, Never send, History, Item check, Help.
- Favorite recipient: preselected on every character.
- Remove characters from the list.
- Edit the rules for each recipient in the window.
- Modes renamed to Test, Attach and Send, with a short explanation in the panel.
- Minimap button, addon compartment entry and a page under Options > AddOns.
- Closing the mailbox while a letter is being packed now cancels it cleanly.
- Professions are read after login, when the game has them ready.

## 0.1.0

- First version for the WoW Forever beta.
