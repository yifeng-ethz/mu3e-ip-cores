/*----------------------------------------------------------------------------
|   Copyright (c) 2017  Rolf Ade (rolf@pointsman.de)
|-----------------------------------------------------------------------------
|
|
|   The contents of this file are subject to the Mozilla Public License
|   Version 2.0 (the "License"); you may not use this file except in
|   compliance with the License. You may obtain a copy of the License at
|   http://www.mozilla.org/MPL/
|
|   Software distributed under the License is distributed on an "AS IS"
|   basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
|   License for the specific language governing rights and limitations
|   under the License.
|
|   Contributor(s):
|
|
|   written by Rolf Ade
|   April 2017
|
\---------------------------------------------------------------------------*/

/* Some parts of the following are inspired, derivated or, for a few
 * smaller pieces, even verbatim copied from the (public domain)
 * sqlite JSON parser
 * (https://www.sqlite.org/src/artifact/312b4ddf4c7399dc) */

#include <tcl.h>
#include <dom.h>
#include <domjson.h>
#include <ctype.h>

static const char jsonIsSpace[] = {
  0, 0, 0, 0, 0, 0, 0, 0,     0, 1, 1, 0, 0, 1, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0,     0, 0, 0, 0, 0, 0, 0, 0,
  1, 0, 0, 0, 0, 0, 0, 0,     0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0,     0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0,     0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0,     0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0,     0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0,     0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0,     0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0,     0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0,     0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0,     0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0,     0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0,     0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0,     0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0,     0, 0, 0, 0, 0, 0, 0, 0,
};
#define skipspace(x)  while (jsonIsSpace[(unsigned char)json[(x)]]) { (x)++; }

#define rc(i) if (jparse->state != JSON_OK) return (i);

/* The meaning of parse state values */
typedef enum {
    JSON_OK,
    JSON_MAX_NESTING_REACHED,
    JSON_SYNTAX_ERR,
} JSONParseState;

/* Error string constants, indexed by JSONParseState. */
static const char *JSONParseStateStr[] = {
    "OK",
    "Maximum JSON object/array nesting depth exceeded",
    "JSON syntax error",
};

typedef struct {
    JSONParseState state;
    JSONWithin within;
    int  nestingDepth;
    int  maxnesting;
    char *arrItemElm;
    char *buf;
    domLength len;
} JSONParse;


#define errReturn(i,j) {jparse->state = j; return (i);}
    

/* #define DEBUG */
#ifdef DEBUG
# define DBG(x) x
#else
# define DBG(x) 
#endif

/*
** Return true if z[] begins with 4 (or more) hexadecimal digits
*/
static int jsonIs4Hex(const char *z){
  int i;
  for (i=0; i<4; i++) if (!isxdigit(z[i])) return 0;
  return 1;
}

/* Parse the single JSON string which begins (with the starting '"')
 * at json[i]. Return the index of the closing '"' of the string
 * parsed. */

static domLength jsonParseString (
    char *json,
    domLength i,
    JSONParse *jparse
    )
{
    unsigned char c;
    int clen;
    domLength j, k, savedStart;
    unsigned int u, u2;
    
    DBG(fprintf(stderr, "jsonParseString start: '%s'\n", &json[i]););
    if (jparse->len) jparse->buf[0] = '\0';
    savedStart = i;

    if (json[i] != '"') {
        errReturn(i,JSON_SYNTAX_ERR);
    }
    i++;
    if (json[i] == '"') {
        return i;
    }
    for(;;) {
        c = json[i];
        DBG(fprintf (stderr, "Looking at '%d'\n", c););
        /* Unescaped control characters are not allowed in JSON
         * strings. */
        if (c <= 0x1f) {
            errReturn(i,JSON_SYNTAX_ERR);
        }
        if (c == '\\') {
            goto unescape;
        }
        if (c == '"') {
            return i;
        }
        if (c == 0xC0 && (unsigned char)json[i+1] == 0x80)
            errReturn(i,JSON_SYNTAX_ERR);
        if ((clen = UTF8_CHAR_LEN(c)) == 0)
            errReturn(i,JSON_SYNTAX_ERR);
        i += clen;
    }
    unescape:
    DBG(fprintf (stderr, "Continue with unescaping ..\n"););
    /* If we here, then i points to the first backslash in the string
     * to parse */
    if (i - savedStart + 200 > jparse->len) {
        jparse->buf = REALLOC(jparse->buf, i-savedStart+200);
        jparse->len = i-savedStart+200;
    }
    memcpy (jparse->buf, &json[savedStart+1], i-savedStart);
    j = i-savedStart-1;
    for(;;) {
        c = json[i];
        DBG(fprintf (stderr, "Looking at '%c'\n", c););
        /* Unescaped control characters are not allowed in JSON
         * strings. */
        if (c <= 0x1f) errReturn(i,JSON_SYNTAX_ERR);
        if (jparse->len - j < 14) {
            jparse->buf = REALLOC (jparse->buf, jparse->len * 2);
            jparse->len *= 2;
        }
        if (c == '\\') {
            c = json[i+1];
            if (c == 'u' && jsonIs4Hex(&json[i+2])) {
                u = 0;
                for (k = 2; k < 6; k++) {
                    c = json[i+k];
                    if (c <= '9') u = u*16 + c - '0';
                    else if (c <= 'F') u = u*16 + c - 'A' + 10;
                    else u = u*16 + c - 'a' + 10;
                }
                if (u <= 0x7f) {
                    if (u == 0) {
                        jparse->buf[j++] = (char)0xC0;
                        jparse->buf[j++] = (char)0x80;
                    } else {
                        jparse->buf[j++] = (char)u;
                    }
                } else if (u <= 0x7ff) {
                    jparse->buf[j++] = (char)(0xc0 | (u>>6));
                    jparse->buf[j++] = 0x80 | (u&0x3f);
                } else {
                    if ((u&0xfc00)==0xd800
                        && (char)json[i+6] == '\\'
                        && (char)json[i+7] == 'u'
                        && jsonIs4Hex(&json[i+8]))
                    {
                        /* A surrogate pair */
                        u2 = 0;
                        for (k = 8; k < 12; k++) {
                            c = json[i+k];
                            if (c <= '9') u2 = u2*16 + c - '0';
                            else if (c <= 'F') u2 = u2*16 + c - 'A' + 10;
                            else u2 = u2*16 + c - 'a' + 10;
                        }
                        u = ((u&0x3ff)<<10) + (u2&0x3ff) + 0x10000;
                        i += 6;
                        jparse->buf[j++] = 0xf0 | (u>>18);
                        jparse->buf[j++] = 0x80 | ((u>>12)&0x3f);
                        jparse->buf[j++] = 0x80 | ((u>>6)&0x3f);
                        jparse->buf[j++] = 0x80 | (u&0x3f);
                    } else {
                        jparse->buf[j++] = (char)(0xe0 | (u>>12));
                        jparse->buf[j++] = 0x80 | ((u>>6)&0x3f);
                        jparse->buf[j++] = 0x80 | (u&0x3f);
                    }
                }
                i += 6;
            } else {
                if (c == '\\') {
                    c = '\\';
                } else if (c == '"') {
                    c = '"';
                } else if (c == '/') {
                    c = '/';
                } else if (c == 'b') {
                    c = '\b';
                } else if (c == 'f') {
                    c = '\f';
                } else if (c == 'n') {
                    c = '\n';
                } else if (c == 'r') {
                    c = '\r';
                } else if (c == 't') {
                    c = '\t';
                } else {
                    errReturn(i+1,JSON_SYNTAX_ERR);
                }
                jparse->buf[j++] = c;
                i += 2;
            }
            continue;
        }
        if (c == '"') {
            jparse->buf[j] = '\0';
            return i;
        }
        if ((clen = UTF8_CHAR_LEN(json[i])) == 0)
            errReturn(i,JSON_SYNTAX_ERR);
        for (k = 0; k < clen; k++) {
            jparse->buf[j++] = json[i+k];
        }
        i += clen;
    }
}

/* Parse a single JSON value which begins at json[i]. Return the index
 * of the first character past the end of the value parsed. */

static domLength jsonParseValue(
    domNode   *parent,
    char      *json,
    domLength  i,
    JSONParse *jparse
    )
{
    char c, save;
    domLength j;
    domNode *node;
    domTextNode *newTextNode;
    JSONWithin savedWithin = jparse->within;
    
    DBG(fprintf(stderr, "jsonParseValue start: '%s'\n", &json[i]););
    if (jparse->len) jparse->buf[0] = 0;
    skipspace(i);
    if ((c = json[i]) == '{' ) {
        /* Parse object */
        if (++jparse->nestingDepth > jparse->maxnesting)
            errReturn(i,JSON_MAX_NESTING_REACHED);
        i++;
        if (jparse->within == JSON_ARRAY) {
            node = domNewElementNode (parent->ownerDocument,
                                      JSON_OBJECT_CONTAINER);
            node->info = JSON_OBJECT;
            domAppendChild(parent, node);
            parent = node;
        } else {
            parent->info  = JSON_OBJECT;
        }
        skipspace(i);
        if (json[i] == '}') {
            /* Empty object. */
            jparse->nestingDepth--;
            return i+1;
        }
        jparse->within = JSON_WITHIN_OBJECT;
        for (;;) {
            j = jsonParseString (json, i, jparse);
            rc(j);
            if (jparse->len && jparse->buf[0]) {
                DBG(fprintf(stderr, "New object member '%s'\n", jparse->buf););
                node = domNewElementNode (parent->ownerDocument,
                                          jparse->buf);
                domAppendChild (parent, node);
                jparse->buf[0] = 0;
            } else {
                save = json[j];
                json[j] = '\0';
                DBG(fprintf(stderr, "New object member '%s'\n", jparse->buf););
                DBG(fprintf(stderr, "New object member '%s'\n", &json[i+1]););
                node = domNewElementNode (parent->ownerDocument, &json[i+1]);
                domAppendChild (parent, node);
                json[j] = save;
            }
            i = j+1;
            skipspace(i);
            if (json[i] != ':') errReturn(i,JSON_SYNTAX_ERR);
            i++;
            skipspace(i);
            j = jsonParseValue (node, json, i, jparse);
            rc(j);
            i = j;
            skipspace(i);
            if (json[i] == '}') {
                jparse->nestingDepth--;
                jparse->within = savedWithin;
                return i+1;
            }
            if (json[i] == ',') {
                i++; skipspace(i);
                continue;
            }
            errReturn(i,JSON_SYNTAX_ERR);
        }
    } else if (c == '[') {
        /* Parse array */
        if (++jparse->nestingDepth > jparse->maxnesting)
            errReturn(i,JSON_MAX_NESTING_REACHED);
        i++;
        skipspace(i);
        parent->info = JSON_ARRAY;
        if (jparse->within == JSON_WITHIN_ARRAY) {
            node = domNewElementNode (parent->ownerDocument,
                                      JSON_ARRAY_CONTAINER);
            node->info = JSON_ARRAY;
            domAppendChild(parent, node);
        } else {
            node = parent;
        }
        if (json[i] == ']') {
            /* empty array */
            DBG(fprintf(stderr,"Empty JSON array.\n"););
            jparse->nestingDepth--;
            return i+1;
        }
        jparse->within = JSON_WITHIN_ARRAY;
        for (;;) {
            DBG(fprintf(stderr, "Next array value node '%s'\n", &json[i]););
            skipspace(i);
            i = jsonParseValue (node, json, i, jparse);
            rc(i);
            skipspace(i);
            if (json[i] == ']') {
                jparse->within = savedWithin;
                jparse->nestingDepth--;
                return i+1;
            }
            if (json[i] == ',') {
                i++;
                continue;
            }
            errReturn(i,JSON_SYNTAX_ERR);
        }
    } else if (c == '"') {
        /* Parse string */
        j = jsonParseString (json, i, jparse);
        rc(j);
        if (jparse->len && jparse->buf[0]) {
            DBG(fprintf(stderr, "New unescaped text node '%s'\n", jparse->buf));
            newTextNode = domNewTextNode (parent->ownerDocument,
                                          jparse->buf, strlen(jparse->buf),
                                          TEXT_NODE);
            domAppendChild (parent, (domNode *) newTextNode);
        } else {
            DBG(save = json[j];json[j] = '\0';fprintf(stderr, "New text node '%s'\n", &json[i+1]);json[j] = save;);
            newTextNode = domNewTextNode (parent->ownerDocument,
                                          &json[i+1], j-i-1, TEXT_NODE);
            domAppendChild (parent, (domNode *) newTextNode);
        }
        newTextNode->info = JSON_STRING;
        return j+1;
    } else if (c == 'n'
               && strncmp (json+i, "null", 4) == 0
               && !isalnum(json[i+4])) {
        newTextNode = domNewTextNode (parent->ownerDocument, "null", 4,
                                      TEXT_NODE);
        newTextNode->info = JSON_NULL;
        domAppendChild (parent, (domNode *) newTextNode);
        return i+4;
    } else if (c == 't'
               && strncmp (json+i, "true", 4) == 0
               && !isalnum(json[i+4])) {
        newTextNode = domNewTextNode (parent->ownerDocument, "true", 4,
                                      TEXT_NODE);
        newTextNode->info = JSON_TRUE;
        domAppendChild (parent, (domNode *) newTextNode);
        return i+4;
    } else if (c == 'f'
               && strncmp (json+i, "false", 5) == 0
               && !isalnum(json[i+5])) {
        newTextNode = domNewTextNode (parent->ownerDocument, "false", 5,
                                      TEXT_NODE);
        newTextNode->info = JSON_FALSE;
        domAppendChild (parent, (domNode *) newTextNode);
        return i+5;
    } else if (c == '-' || (c>='0' && c<='9')) {
        /* Parse number */
        int seenDP = 0;
        int seenE = 0;
        if (c<='0') {
            j = (c == '-' ? i+1 : i);
            if (json[j] == '0' && json[j+1] >= '0' && json[j+1] <= '9')
                errReturn(j+1,JSON_SYNTAX_ERR);
        }
        j = i+1;
        for (;; j++) {
            c = json[j];
            if (c >= '0' && c <= '9') continue;
            if (c == '.') {
                if (json[j-1] == '-') errReturn(j,JSON_SYNTAX_ERR);
                if (seenDP) errReturn(j,JSON_SYNTAX_ERR);
                seenDP = 1;
                continue;
            }
            if (c == 'e' || c == 'E') {
                if (json[j-1] < '0') errReturn(j,JSON_SYNTAX_ERR);
                if (seenE) errReturn(j,JSON_SYNTAX_ERR);
                seenDP = seenE = 1;
                c = json[j+1];
                if (c == '+' || c == '-') {
                    j++;
                    c = json[j+1];
                }
                if (c < '0' || c > '9') errReturn(j,JSON_SYNTAX_ERR);
                continue;
            }
            break;
        }
        /* Catches a plain '-' without following digits */
        if( json[j-1]<'0' ) errReturn(j-1,JSON_SYNTAX_ERR);
        DBG(save = json[j];json[j] = '\0';fprintf(stderr, "New text node '%s'\n", &json[i]);json[j] = save;);
        newTextNode = domNewTextNode (parent->ownerDocument, &json[i], j-i,
                                      TEXT_NODE);
        newTextNode->info = JSON_NUMBER;
        domAppendChild(parent, (domNode *) newTextNode);
        return j;
    } else if (c == '\0') {
        return 0;   /* End of input */
    } else {
        errReturn(i,JSON_SYNTAX_ERR);
    }
}


domDocument *
JSON_Parse (
    char *json,    /* Complete text of the json string being parsed */
    char *documentElement, /* name of the root element, may be NULL */
    int   maxnesting,
    char **errStr,
    domLength *byteIndex
    )
{
    domDocument *doc = domCreateDoc (NULL, 0);
    domNode *root;
    Tcl_HashEntry *h;
    JSONParse jparse;
    int hnew;
    domLength pos = 0;

    h = Tcl_CreateHashEntry(&HASHTAB(doc, tdom_tagNames), "item", &hnew);
    jparse.state = JSON_OK;
    jparse.within = JSON_START;
    jparse.nestingDepth = 0;
    jparse.maxnesting = maxnesting;
    jparse.arrItemElm = (char*)&h->key;
    jparse.buf = NULL;
    jparse.len = 0;

    skipspace(pos);
    if (json[pos] == '\0') {
        *byteIndex = pos;
        jparse.state = JSON_SYNTAX_ERR;
        goto reportError;
    }
    if (documentElement) {
        root = domNewElementNode(doc, documentElement);
        domAppendChild(doc->rootNode, root);
    } else {
        root = doc->rootNode;
    }
    *byteIndex = jsonParseValue (root, json, pos, &jparse );
    if (jparse.state != JSON_OK) goto reportError;
    if (*byteIndex > 0) {
        pos = *byteIndex;
        skipspace(pos);
    }
    if (json[pos] != '\0') {
        *byteIndex = pos;
        jparse.state = JSON_SYNTAX_ERR;
        goto reportError;
    }
    if (jparse.len > 0) {
        FREE (jparse.buf);
    }
    domSetDocumentElement (doc);
    return doc;
reportError:
    if (jparse.len > 0) {
        FREE (jparse.buf);
    }
    domFreeDocument (doc, NULL, NULL);
    doc = NULL;
    *errStr = (char *)JSONParseStateStr[jparse.state];
    return doc;
}
