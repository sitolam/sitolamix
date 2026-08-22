from anki.utils import guid64, int_time


def timestampID(db, table, t=None):
    "Return a non-conflicting timestamp for table."
    # be careful not to create multiple objects without flushing them, or they
    # may share an ID.
    # t = t or intTime(1000)
    t = t or int_time(1000)
    while db.scalar("select id from %s where id = ?" % table, t):
        t += 1
    return t
