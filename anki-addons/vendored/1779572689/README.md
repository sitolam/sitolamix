# Deck duplication
Anki addon to clone existing deck (and it's subdecks) in place (media references retained, i.e. no separate copy is made of any media files).

![Screenshots](https://github.com/TRIAEIOU/Deck-duplication/blob/main/Screenshots/collage.png?raw=true)

- The duplicated deck will contain all notes with at least one card in the source deck (it is possible to assign different cards from the same note to different decks, the addon does not take this into consideration).
- Tags are not cloned.
- Right click the source deck in the browser (not available from the main Anki window) and select `Duplicate deck`.

To facilitate clean up of duplicate notes (which are now very easy to create) the addon also adds functionality to delete all identical clones.
- Only notes where all fields are identical will be detected as clones (c.f. core Anki and other duplication detection addons which lets you define a specific field to compare).
- Note that identical means same amount of white space, invisible tags etc.
- The oldest note (creation date) will be retained, scheduling state is not considered.
- The clone detection does not take tags into consideration.