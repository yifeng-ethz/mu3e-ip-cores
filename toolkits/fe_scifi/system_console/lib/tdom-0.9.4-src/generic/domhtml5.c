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
|   March 2017
|
\---------------------------------------------------------------------------*/

#ifdef TDOM_HAVE_GUMBO

#define MAX_TAG_LEN 201

/*----------------------------------------------------------------------------
|   Includes
|
\---------------------------------------------------------------------------*/
#include <tcl.h>
#include <dom.h>
#include "gumbo.h"
#include <assert.h>

static const char *xhtml = "http://www.w3.org/1999/xhtml";
static const char *svg = "http://www.w3.org/2000/svg";
static const char *mathml = "http://www.w3.org/1998/Math/MathML";
static const char *xlink = "http://www.w3.org/1999/xlink";

#ifdef DEBUG
# define DBG(x) x
#else
# define DBG(x) 
#endif

static void
convertGumboToDom (
    domNode *parent,
    GumboNode *gumboParent,
    int ignoreWhiteSpaces,
    int ignorexmlns
    ) 
{
    int hnew;
    unsigned int i, j;
    GumboVector *children = &gumboParent->v.element.children;
    GumboNode *child;
    GumboElement *gumboElm;
    GumboAttribute *gumboAtt;
    const char *tag;
    const char *attValue;
    const char *attUri = NULL;
    char buf[MAX_TAG_LEN];
    domNode *node;
    domNS *ns;
    domNodeType nodeType = ALL_NODES;
    domAttrNode *attr = NULL;
    Tcl_HashEntry *h;
    const char *elmns = NULL;
    
    for (i = 0; i < children->length; ++i) {
        child = (GumboNode*) (children->data[i]);
        switch (child->type) {
        case GUMBO_NODE_DOCUMENT:
            assert(false &&
                   "This gumbo node type can't happen here.");
            break;
        case GUMBO_NODE_ELEMENT:
        case GUMBO_NODE_TEMPLATE:
            gumboElm = &child->v.element;
            tag = gumbo_normalized_tagname(gumboElm->tag);
            if (!domIsNAME(tag)) {
                gumbo_tag_from_original_text(&gumboElm->original_tag);
                if (gumboElm->original_tag.length < MAX_TAG_LEN - 1) {
                    strncpy(&buf[0],
                            gumboElm->original_tag.data,
                            gumboElm->original_tag.length);
                    buf[gumboElm->original_tag.length] = '\0';
                    Tcl_UtfToLower(&buf[0]);
                    if (!domIsNAME(&buf[0])) {
                        DBG(fprintf (stderr, "invalid tag name '%s'\n", tag););
                        continue;
                    }
                    tag = &buf[0];
                } else {
                    /* Just skip this subtree */
                    DBG(fprintf(stderr, "long tag: %d bytes\n", gumboElm->original_tag.length););
                    continue;
                }
            }
            if (!ignorexmlns) {
                switch (gumboElm->tag_namespace) {
                case GUMBO_NAMESPACE_HTML:
                    elmns = xhtml;
                    break;
                case GUMBO_NAMESPACE_SVG:
                    elmns = svg;
                    break;
                case GUMBO_NAMESPACE_MATHML:
                    elmns = mathml;
                    break;
                default:
                    /* do nothing */
                    break;
                }
            }
            if (elmns == NULL) {
                node = domNewElementNode (parent->ownerDocument, tag);
            } else {
                DBG(fprintf (stderr, "namespaced node %s\n", tag););
                node = domNewElementNodeNS (parent->ownerDocument, tag,
                                            elmns);
            }
            domAppendChild(parent, node);
            for (j = 0; j < gumboElm->attributes.length; ++j) {
                gumboAtt = gumboElm->attributes.data[j];
                /* This is to ensure the same behavior as the -html
                 * parser: if there is just the attribute name given
                 * in the source (as 'selected' on a checkbox) then do
                 * it the XHTML style (att value is the att name,
                 * selected="selected"). If there is any value given
                 * in the source, including the empty string, use
                 * that. See gumbo.h for the details why/how this
                 * works.*/
                if (gumboAtt->original_value.data[0] != '"'
                    && gumboAtt->original_value.data[0] != '\'') {
                    attValue = gumboAtt->name;
                } else {
                    attValue = gumboAtt->value;
                }

                if (ignorexmlns) {
                    if (gumboAtt->attr_namespace != GUMBO_ATTR_NAMESPACE_NONE) {
                        if (gumboAtt->original_name.length < MAX_TAG_LEN - 1) {
                            strncpy(&buf[0],
                                    gumboAtt->original_name.data,
                                    gumboAtt->original_name.length);
                            buf[gumboAtt->original_name.length] = '\0';
                            Tcl_UtfToLower(&buf[0]);
                            DBG(fprintf (stderr, "original att name: %s\n",
                                         &buf[0]););
                            if (!domIsNAME(&buf[0])) {
                                DBG(fprintf (stderr, "invalid att name '%s'\n", tag););
                                continue;
                            }
                            domSetAttribute(node, &buf[0], attValue);
                        } else {
                            continue;
                        }
                    } else {
                        attr = domSetAttribute (node, gumboAtt->name, attValue);
                    }
                } else {
                    attUri = NULL;
                    switch (gumboAtt->attr_namespace) {
                    case GUMBO_ATTR_NAMESPACE_XLINK:
                        DBG(fprintf (stderr, "GUMBO_ATTR_NAMESPACE_XLINK\n"););
                        attUri = xlink;
                        break;
                    case GUMBO_ATTR_NAMESPACE_XMLNS:
                        DBG(fprintf (stderr, "GUMBO_ATTR_NAMESPACE_XMLNS\n"););
                        if (attValue[5] == ':') {
                            ns = domLookupPrefix (node, &(attValue[6]));
                        } else {
                            ns = domLookupPrefix (node, "");
                        }
                        DBG(fprintf (stderr, "xmns att name: %s\n att value %s\n",
                                     gumboAtt->name,
                                     attValue););
                        if (ns) {
                            if (strcmp(ns->uri, attValue) == 0) {
                                /* Namespace already in scope. Skip
                                 * this attribute to prevent invalid
                                 * double attributes and unnecessary
                                 * namespace declarations. */
                                DBG(fprintf (stderr, "namespace %s already in scope\n",
                                             attValue););
                                continue;
                            }
                        }
                        if (gumboAtt->original_name.length < MAX_TAG_LEN - 1) {
                            strncpy(&buf[0],
                                    gumboAtt->original_name.data,
                                    gumboAtt->original_name.length);
                            buf[gumboAtt->original_name.length] = '\0';
                            Tcl_UtfToLower(&buf[0]);
                            DBG(fprintf (stderr, "original att name: %s\n",
                                         &buf[0]););
                            if (!domIsNAME(&buf[0])) {
                                DBG(fprintf (stderr, "invalid att name '%s'\n", tag););
                                continue;
                            }
                            domSetAttributeNS(node, &buf[0], attValue, NULL, 1);
                        }
                        continue;
                    case GUMBO_ATTR_NAMESPACE_XML:
                        /* The XML namespace is always in scope, nothing
                         * to do. */
                        continue;
                    default:
                        break;
                    }

                    if (attUri) {
                        if (gumboAtt->original_name.length < MAX_TAG_LEN - 1) {
                            strncpy(&buf[0],
                                    gumboAtt->original_name.data,
                                    gumboAtt->original_name.length);
                            buf[gumboAtt->original_name.length] = '\0';
                            Tcl_UtfToLower(&buf[0]);
                            DBG(fprintf (stderr, "original att name: %s\n",
                                         &buf[0]););
                            if (!domIsNAME(&buf[0])) {
                                DBG(fprintf (stderr, "invalid att name '%s'\n", tag););
                                continue;
                            }
                        } else {
                            continue;
                        }
                        DBG(fprintf (stderr, "name: %s value %s\n", &buf[0], attValue););
                        attr = domSetAttributeNS (node, &buf[0],
                                                  attValue, xlink, 0);
                        DBG(fprintf(stderr, "attr: %p\n", attr););
                    } else {
                        attr = domSetAttribute (node, gumboAtt->name,
                                                attValue);
                    }
                }
                if (attr) {
                    if (strcmp(gumboAtt->name, "id") == 0) {
                        if (!node->ownerDocument->ids) {
                            node->ownerDocument->ids = (Tcl_HashTable *)
                                MALLOC (sizeof (Tcl_HashTable));
                            Tcl_InitHashTable (
                                node->ownerDocument->ids,
                                TCL_STRING_KEYS);
                        }
                        h = Tcl_CreateHashEntry (
                            node->ownerDocument->ids,
                            gumboAtt->value,
                            &hnew);
                        /* How to resolve in case of duplicates?  We
                           follow, what the core dom building code does:
                           the first value in document order wins. */
                        if (hnew) {
                            Tcl_SetHashValue (h, node);
                            attr->nodeFlags |= IS_ID_ATTRIBUTE;
                        }
                    }
                }
            }
            convertGumboToDom(node, child, ignoreWhiteSpaces, ignorexmlns);
            break;
        case GUMBO_NODE_WHITESPACE:
            if (ignoreWhiteSpaces) {
                continue;
            }
            /* fall through */;
        case GUMBO_NODE_CDATA:
        case GUMBO_NODE_TEXT:
            nodeType = TEXT_NODE
            /* fall through */;
        case GUMBO_NODE_COMMENT:
            if (nodeType == ALL_NODES) nodeType = COMMENT_NODE;
            node = (domNode*)domNewTextNode(parent->ownerDocument,
                                            child->v.text.text,
                                            strlen(child->v.text.text),
                                            nodeType);
            domAppendChild(parent, node);
            break;
        default:
            assert(false && "unknown node type");
        }
    }
}

domDocument *
HTML_GumboParseDocument (
    char   *html,              /* Complete text of the XML being parsed.  */
    int     ignoreWhiteSpaces,
    int     ignorexmlns
    ) {
    domDocument *doc = domCreateDoc(NULL, 0);
    GumboOutput *output = gumbo_parse(html);
    GumboDocument* doctype = & output->document->v.document;
    /* Generate and populate doctype info. */
    doc->doctype = (domDocInfo *)MALLOC(sizeof(domDocInfo));
    memset(doc->doctype, 0,(sizeof(domDocInfo)));
    doc->doctype->publicId = tdomstrdup(doctype->public_identifier);
    doc->doctype->systemId = tdomstrdup(doctype->system_identifier);
    convertGumboToDom (doc->rootNode, output->document, ignoreWhiteSpaces,
                       ignorexmlns);
    domSetDocumentElement (doc);
    gumbo_destroy_output(&kGumboDefaultOptions, output);    
    return doc;
}
#else
typedef int make_pedantic_compiler_happy;
#endif
