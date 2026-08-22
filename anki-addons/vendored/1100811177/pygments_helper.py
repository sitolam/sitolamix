import os
import sys

addon_path = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(addon_path, "libs"))

from pygments import highlight as pyg__highlight
from pygments.lexers import get_all_lexers as pyg__get_all_lexers
from pygments.lexers import get_lexer_by_name as pyg__get_lexer_by_name
from pygments.formatters import HtmlFormatter as pyg__HtmlFormatter
from pygments.util import ClassNotFound as pyg__ClassNotFound
from pygments.styles import get_all_styles as pyg__get_all_styles


# This code sets a correspondence between:
#  The "language names": long, descriptive names we want
#                        to show the user AND
#  The "language aliases": short, cryptic names for internal
#                          use by HtmlFormatter
# get_all_lexers is a generator that returns name, aliases, filenames, mimetypes
# since pygments 2.8 from 2021-02 for some lexers the tuple aliases is empty
# so the old code fails:
#   LANG_MAP = {lex[0]: lex[1][0] for lex in get_all_lexers()}
LANG_MAP = {}
for lex in pyg__get_all_lexers():
    try:
        LANG_MAP[lex[0]] = lex[1][0]
    except:
        pass
        # for 2.8.1 affected lexers are:
        # - JsonBareObject but changelog for 2.7.3 says "Deprecated JsonBareObjectLexer, 
        #   which is now identical to JsonLexer (#1600)"
        # - "Raw token data" no longer has the "raw" alias - see 
        #   https://github.com/pygments/pygments/commit/a169fef00bb998d27bbbe57642a367cb951b60a4
        #   the comment was "was broken until 2.7.4, so it seems pretty much unused"
