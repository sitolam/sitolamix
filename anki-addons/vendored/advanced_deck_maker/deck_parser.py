import re
from typing import List


def expand_deck_names(expression: str) -> List[str]:
    """
    Expand a deck name expression into a list of deck names.

    Syntax:
      Parent::Child1||Child2    -> Parent::Child1, Parent::Child2
      Parent::{A,B,C}          -> Parent::A, Parent::B, Parent::C
      Multiple lines            -> one expression per line
    """
    results = []
    for line in expression.strip().splitlines():
        line = line.strip()
        if line:
            results.extend(_expand_line(line))
    seen: set = set()
    unique: List[str] = []
    for name in results:
        if name not in seen:
            seen.add(name)
            unique.append(name)
    return unique


def _expand_line(line: str) -> List[str]:
    if "||" in line:
        parts = line.split("||")
        first = parts[0].strip()
        if "::" in first:
            idx = first.rfind("::")
            prefix = first[: idx + 2]
            tail = first[idx + 2 :]
        else:
            prefix = ""
            tail = first
        names = [prefix + tail] + [prefix + p.strip() for p in parts[1:]]
        result: List[str] = []
        for name in names:
            result.extend(_expand_braces(name))
        return result
    return _expand_braces(line)


def _expand_braces(line: str) -> List[str]:
    match = re.search(r"\{([^{}]+)\}", line)
    if not match:
        return [line]
    before = line[: match.start()]
    after = line[match.end() :]
    options = [o.strip() for o in match.group(1).split(",")]
    result: List[str] = []
    for option in options:
        result.extend(_expand_braces(before + option + after))
    return result
