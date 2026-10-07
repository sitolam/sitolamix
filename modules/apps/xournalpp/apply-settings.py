"""Merge the repo's settings into Xournal++'s settings.xml.

usage: apply-settings.py SETTINGS_JSON

Only the listed properties are touched; everything else Xournal++ wrote stays.
"""

import json
import os
import re
import sys
from xml.sax.saxutils import quoteattr

TARGET = os.path.expanduser("~/.config/xournalpp/settings.xml")
EMPTY = '<?xml version="1.0" encoding="UTF-8"?>\n<settings>\n</settings>\n'


def load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def main():
    values = load(sys.argv[1])

    try:
        with open(TARGET) as f:
            xml = f.read()
    except OSError:
        xml = EMPTY
    if "</settings>" not in xml:
        xml = EMPTY

    for name, value in values.items():
        line = f"<property name={quoteattr(name)} value={quoteattr(str(value))}/>"
        pattern = re.compile(r'<property name="%s" value="[^"]*"/>' % re.escape(name))
        if pattern.search(xml):
            xml = pattern.sub(lambda _: line, xml, count=1)
        else:
            xml = xml.replace("<settings>", f"<settings>\n  {line}", 1)

    os.makedirs(os.path.dirname(TARGET), exist_ok=True)
    tmp = TARGET + ".tmp"
    with open(tmp, "w") as f:
        f.write(xml)
    os.replace(tmp, TARGET)


main()
