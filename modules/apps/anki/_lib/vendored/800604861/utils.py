# As in add-on 413416269
from anki.utils import int_time

from .config import getUserOption
from anki.notes import Note

def getRelationsFromNote(note:Note):
    relations = set()
    for relation in note.tags:
        for prefix in getUserOption("tag prefixes", ["relation_"]):
            if relation.startswith(prefix):
                relations.add(relation)
                break
    return relations


def createRelationTag():
    return f"""{getUserOption("current tag prefix", "relation_")}{int_time(1000)}"""
