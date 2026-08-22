import re
from anki import collection
from anki.decks import DeckId
from aqt import mw, gui_hooks
from aqt.browser.sidebar import SidebarItemType
from aqt.qt import QAction
from aqt.utils import tooltip, askUser
from uuid import uuid4
from aqt.operations import CollectionOp

DUPLICATE_DECK_TITLE = 'Duplicate deck'
DELETE_CLONES_TITLE = 'Delete note clones'

#########################################################################
# Duplicate selected deck in place or to supplied destination
#########################################################################
def duplicate_deck(parent, refresh, sid, recurse = True, dname = None):
    def _duplicate_deck(col, sid, sroot, droot, recurse):
        def _duplicate_notes(sid, did):
            nonlocal note_cnt
            changes = collection.OpChanges()
            query = f'SELECT DISTINCT nid FROM cards WHERE did = {sid}'
            for nid, in col.db.all(query):
                snote = col.get_note(nid)
                dnote = col.new_note(snote.note_type())
                for key, val in snote.items():
                    dnote[key] = val
                change = col.add_note(dnote, did)
                #changes.append(change)
                note_cnt +=1
            return changes
        
        changes = collection.OpChanges()
        did = mw.col.decks.add_normal_deck_with_name(droot).id
        changes = _duplicate_notes(sid, did)

        dids = col.decks.children(sid) if recurse else [(sroot, sid)]
        for chld_sname, chld_sid in dids:
            chld_dname = droot + chld_sname[len(sroot):]
            chld_did = col.decks.add_normal_deck_with_name(chld_dname).id
            change = _duplicate_notes(chld_sid, chld_did)
            #changes.append(change)

        return changes

    def _success(changes):
        refresh()
        tooltip(msg=f'Copied {note_cnt} notes from {sname} to {dname}.', parent=parent)

    sname = mw.col.decks.name(sid)
    if dname == None:
        dname = f'{sname} - Copy'
        i = 2
        while mw.col.decks.by_name(dname) != None:
            dname = re.sub(r'- Copy(?: \(\d+\))?$', rf'- Copy ({i})', dname)
            i += 1

    note_cnt = 0

    if askUser(f'Duplicate "{sname}" to "{dname}"?', parent, title=DUPLICATE_DECK_TITLE):
        bgop = CollectionOp(parent=parent, op=lambda col: _duplicate_deck(col, sid, sname, dname, recurse))
        bgop.run_in_background()
        bgop.success(success=_success)

#########################################################################
# Delete identical notes within supplied directory,
# keeping newest or oldest note (not longest progression etc)
#########################################################################
def delete_clones(parent, refresh, did, recurse = True, keep = 'oldest'):
    def _delete_clones(col, did, recurse, keep):
        nonlocal note_cnt
        nonlocal dnotes
        changes = collection.OpChanges()
        decks = ' ,'.join([str(dids) for dids in col.decks.deck_and_child_ids(did)]) if recurse else str(did)
        query = f'''
        SELECT id, flds FROM notes
        WHERE flds IN (SELECT flds FROM notes GROUP BY flds HAVING COUNT(*) > 1)
            AND id IN (SELECT DISTINCT nid FROM cards WHERE did IN ({decks}))
        ORDER BY notes.flds ASC, notes.mod ASC
        '''
        cnotes = []
        for nid, flds in col.db.all(query):
            if len(cnotes) and flds != cnotes[-1][1]:
                dnotes += [n for n, f in (cnotes[:-1] if keep == 'newest' else cnotes[1:])]
                cnotes = []
            cnotes.append((nid, flds))

        # Last note
        dnotes += [n for n, f in (cnotes[:-1] if keep == 'newest' else cnotes[1:])]
        note_cnt = len(dnotes)
        return changes

    def _success(changes):
        refresh()
        if note_cnt and askUser(f'Delete {note_cnt} note clones?', parent, title=DUPLICATE_DECK_TITLE):
            changes = mw.col.remove_notes(dnotes)
            tooltip(msg=f'Deleted {note_cnt} duplicate notes.', parent=parent)

    note_cnt = 0
    dnotes = []
    bgop = CollectionOp(parent=parent, op=lambda col: _delete_clones(col, did, recurse, keep))
    bgop.run_in_background()
    bgop.success(success=_success)

#########################################################################
# Add supplied action to menu
#########################################################################
def add_to_menu(title, run, parent, refresh, menu, did):
    action = QAction(title, menu)
    action.triggered.connect(lambda: run(parent, refresh, did))
    menu.addAction(action)
    return menu


#########################################################################
# Main
#########################################################################
gui_hooks.browser_sidebar_will_show_context_menu.append(lambda sb, menu, itm, i: add_to_menu(DUPLICATE_DECK_TITLE, duplicate_deck, sb, sb.refresh, menu, DeckId(itm.id)) if itm.item_type == SidebarItemType.DECK else menu)

gui_hooks.browser_sidebar_will_show_context_menu.append(lambda sb, menu, itm, i: add_to_menu(DELETE_CLONES_TITLE, delete_clones, sb, sb.refresh, menu, DeckId(itm.id)) if itm.item_type == SidebarItemType.DECK else menu)