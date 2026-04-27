/*----------------------------------------------------------------------------
|   Copyright (C) 1999  Jochen C. Loewer (loewerj@hotmail.com)
+-----------------------------------------------------------------------------
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
|   The Original Code is tDOM.
|
|   The Initial Developer of the Original Code is Jochen Loewer.
|
|   Portions created by Jochen Loewer are Copyright (C) 1998, 1999
|   Jochen Loewer. All Rights Reserved.
|
|   Portions created by Zoran Vasiljevic are Copyright (C) 2000-2002
|   Zoran Vasiljevic. All Rights Reserved.
|
|   Portions created by Rolf Ade are Copyright (C) 1999-2002
|   Rolf Ade. All Rights Reserved.
|
|   Written by Zoran Vasiljevic
|   July 12, 2000
|
\---------------------------------------------------------------------------*/


/*----------------------------------------------------------------------------
|   Includes
|
\---------------------------------------------------------------------------*/
#include <dom.h>
#include <tcldom.h>
#include <tcl.h>
#include <nodecmd.h>

/*----------------------------------------------------------------------------
|   Types
|
|   This structure represents one stack slot. The stack itself
|   is implemented as double-linked-list of following structures.
|
\---------------------------------------------------------------------------*/
typedef struct StackSlot {
    void             *element;   /* The stacked element */
    struct StackSlot *nextPtr;   /* Next link */
    struct StackSlot *prevPtr;   /* Previous link */
} StackSlot;

/*----------------------------------------------------------------------------
|   Beginning of the stack and current element pointer are local
|   to current thread and also local to this file.
|   For non-threaded environments, it's a regular static.
|
\---------------------------------------------------------------------------*/
typedef struct CurrentStack {
    StackSlot *elementStack;
    StackSlot *currentSlot;
} CurrentStack;

/*----------------------------------------------------------------------------
|   Structure used as clientData of the created commands.
|   The structure stores, which type of node the command has
|   to create and, in case of elementNodes and if given, the
|   namespace of the node.
\---------------------------------------------------------------------------*/
typedef struct NodeInfo {
    int   type;
    char *namespace;
    int   jsonType;
    char *tagName;
} NodeInfo;

/*----------------------------------------------------------------------------
|   Forward declarations
|
\---------------------------------------------------------------------------*/
static void * StackPush  (Tcl_Interp *, void *);
static void * StackPop   (Tcl_Interp *);
static void * StackTop   (Tcl_Interp *);
static int    NodeObjCmd (ClientData, Tcl_Interp *, int, Tcl_Obj *const o[]);
static void   StackFinalize (ClientData, Tcl_Interp *);

extern int tcldom_appendXML (Tcl_Interp *, domNode *, Tcl_Obj *);


/*----------------------------------------------------------------------------
|   StackPush
|
\---------------------------------------------------------------------------*/
static void *
StackPush (
    Tcl_Interp *interp,
    void *element
) {
    StackSlot *newElement;
    CurrentStack *csPtr =
	(CurrentStack *) Tcl_GetAssocData(interp, "tdom_stk", NULL);

    /* nodecmd_init() initialize "tdom_stk", so csPtr never will be NULL. */

    /*-------------------------------------------------------------------
    |   Reuse already allocated stack slots, if any
    |
    \------------------------------------------------------------------*/
    if (csPtr->currentSlot && csPtr->currentSlot->nextPtr) {
        csPtr->currentSlot = csPtr->currentSlot->nextPtr;
        csPtr->currentSlot->element = element;
        return element;
    }

    /*-------------------------------------------------------------------
    |   Allocate new stack slot
    |
    \------------------------------------------------------------------*/
    newElement = (StackSlot *) MALLOC(sizeof(StackSlot));
    memset(newElement, 0, sizeof(StackSlot));

    if (csPtr->elementStack == NULL) {
        csPtr->elementStack = newElement;
    } else {
        csPtr->currentSlot->nextPtr = newElement;
        newElement->prevPtr = csPtr->currentSlot;
    }

    csPtr->currentSlot = newElement;
    csPtr->currentSlot->element = element;

    return element;
}

/*----------------------------------------------------------------------------
|   StackPop  -  pops the element from stack
|
\---------------------------------------------------------------------------*/
static void *
StackPop (Tcl_Interp *interp)
{
    void *element;
    CurrentStack *csPtr =
	(CurrentStack *) Tcl_GetAssocData(interp, "tdom_stk", NULL);

    element = csPtr->currentSlot->element;
    if (csPtr->currentSlot->prevPtr) {
        csPtr->currentSlot = csPtr->currentSlot->prevPtr;
    } else {
        csPtr->currentSlot->element = NULL;
    }

    return element;
}

/*----------------------------------------------------------------------------
|   StackTop  -  returns top-level element from stack
|
\---------------------------------------------------------------------------*/
static void *
StackTop (Tcl_Interp *interp)
{
    CurrentStack *csPtr =
	(CurrentStack *) Tcl_GetAssocData(interp, "tdom_stk", NULL);

    if (csPtr->currentSlot == NULL) {
        return NULL;
    }

    return csPtr->currentSlot->element;
}


/*----------------------------------------------------------------------------
|   StackFinalize - reclaims stack memory (slots only, not elements)
|
\---------------------------------------------------------------------------*/
static void
StackFinalize (
    ClientData clientData,
    Tcl_Interp *UNUSED(interp)
) {
    CurrentStack *csPtr = (CurrentStack *) clientData;
    StackSlot *tmp, *stack = csPtr->elementStack;

    while (stack) {
        tmp = stack->nextPtr;
        FREE((char *) stack);
        stack = tmp;
    }
    FREE((char *) csPtr);
}

/*
 *----------------------------------------------------------------------
 *
 * namespaceTail --
 *
 *      Returns the trailing name at the end of a string with "::"
 *      namespace qualifiers. These qualifiers are namespace names
 *      separated by "::"s. For example, for "::foo::p" this function
 *      returns a pointer to the "p" in that obj string rep, and for
 *      "::" it returns a pointer to "".
 *
 * Results:
 *	Returns a pointer to the start of the tail name.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */
static char*
namespaceTail (
    Tcl_Obj *nameObj
)    
{
    char *name,*p;
    domLength len;
    
    name = Tcl_GetStringFromObj(nameObj, &len);
    p = name + len;
    /* Isolate just the tail name, i.e. skip it's parent namespace */
    while (--p > name) {
        if ((*p == ':') && (*(p-1) == ':')) {
            p++; /* just after the last "::" */
            name = p;
            break;
        }
    }
    return name;
}

/*----------------------------------------------------------------------------
|   NodeObjCmdDeleteProc
|
\---------------------------------------------------------------------------*/
static void
NodeObjCmdDeleteProc (
    ClientData clientData
    )
{
    NodeInfo *nodeInfo = (NodeInfo *) clientData;
    
    if (nodeInfo->namespace) {
        FREE (nodeInfo->namespace);
    }
    if (nodeInfo->tagName) {
        FREE (nodeInfo->tagName);
    }
    FREE (nodeInfo);
}

/*----------------------------------------------------------------------------
|   nodecmd_processAttributes
|
\---------------------------------------------------------------------------*/
int
nodecmd_processAttributes (
    Tcl_Interp *interp,
    domNode *node,
    int type,
    int             objc,
    Tcl_Obj *const  objv[],
    Tcl_Obj **cmdObj
    )
{
    Tcl_Obj **opts;
    domLength i, len;
    char *tval, *aval;
    
    /*
     * Allow for following syntax:
     *   cmd ?-option value ...? ?script?
     *   cmd ?option value ...? ?script?
     *   cmd key_value_list script
     *       where list contains "-key value ..." or "key value ..."
     */

    if ((objc % 2) == 0) {
        *cmdObj = objv[objc-1];
        len  = objc - 2; /* skip both command and script */
        opts = (Tcl_Obj**)objv + 1;
    } else if((objc == 3)
              && Tcl_ListObjGetElements(interp,objv[1],&len,&opts)==TCL_OK
              && (len == 0 || len > 1)) {
        if ((len % 2)) {
            Tcl_AppendResult(interp, "list must have "
                             "an even number of elements", NULL);
            return TCL_ERROR;
        }
        *cmdObj = objv[2];
    } else {
        cmdObj = NULL;
        len  = objc - 1; /* skip command */
        opts = (Tcl_Obj**)objv + 1;
    }
    for (i = 0; i < len; i += 2) {
        tval = Tcl_GetString(opts[i]);
        if (*tval == '-') {
            tval++;
        }
        if (abs(type) == ELEMENT_NODE_ANAME_CHK
            || abs(type) == ELEMENT_NODE_CHK) {
            if (!tcldom_nameCheck (interp, tval, "attribute", 0)) {
                return TCL_ERROR;
            }
        }
        aval = Tcl_GetString(opts[i+1]);
        if (abs(type) == ELEMENT_NODE_AVALUE_CHK
            || abs(type) == ELEMENT_NODE_CHK) {
            if (!tcldom_textCheck (interp, aval, "attribute")) {
                return TCL_ERROR;
            }
        }
        domSetAttribute(node, tval, aval);
    }
    return TCL_OK;
}


/*----------------------------------------------------------------------------
|   NodeObjCmd
|
\---------------------------------------------------------------------------*/
static int
NodeObjCmd (
    ClientData      arg,                /* Type of node to create. */
    Tcl_Interp    * interp,             /* Current interpreter. */
    int             objc,               /* Number of arguments. */
    Tcl_Obj *const  objv[]             /* Argument objects. */
) {
    int type, createType, ret, disableOutputEscaping = 0, 
        index = 1;
    domLength len, dlen;
    char *tag, *p, *tval, *aval;
    domNode *parent, *newNode = NULL;
    domTextNode *textNode = NULL;
    domDocument *doc;
    Tcl_Obj *cmdObj;
    NodeInfo *nodeInfo = (NodeInfo*) arg;

    /*------------------------------------------------------------------------
    |   Need parent node to get the owner document and to append new 
    |   child tag to it. The current parent node is stored on the stack.
    |
    \-----------------------------------------------------------------------*/

    parent = (domNode *) StackTop(interp);
    if (parent == NULL) {
        Tcl_AppendResult(interp, "called outside domNode context", NULL);
        return TCL_ERROR;
    }
    doc = parent->ownerDocument;

    /*------------------------------------------------------------------------
    |   Create new node according to type. Special case is the ELEMENT_NODE
    |   since here we may enter into recursion. The ELEMENT_NODE is the only
    |   node type which may have script body as last argument.
    |
    \-----------------------------------------------------------------------*/

    ret  = TCL_OK;
    type = nodeInfo->type;

    switch (abs(type)) {
    case CDATA_SECTION_NODE:     
    case CDATA_SECTION_NODE_CHK: 
    case COMMENT_NODE:           
    case COMMENT_NODE_CHK:       
    case TEXT_NODE:              
    case TEXT_NODE_CHK:
        if (objc != 2) {
            if (abs(type) == TEXT_NODE || abs(type) == TEXT_NODE_CHK) {
                if (objc != 3 ||
                    strcmp ("-disableOutputEscaping",
                            Tcl_GetStringFromObj (objv[1], &len))!=0) {
                    Tcl_WrongNumArgs(interp, 1, objv,
                                     "?-disableOutputEscaping? text");
                    return TCL_ERROR;
                } else {
                    disableOutputEscaping = 1;
                    index = 2;
                }
            } else {
                Tcl_WrongNumArgs(interp, 1, objv, "text");
                return TCL_ERROR;
            }
        }
        tval = Tcl_GetStringFromObj(objv[index], &len);
        switch (abs(type)) {
        case TEXT_NODE_CHK:
            if (!tcldom_textCheck (interp, tval, "text")) return TCL_ERROR;
            createType = TEXT_NODE;
            break;
        case COMMENT_NODE_CHK:
            if (!tcldom_commentCheck (interp, tval)) return TCL_ERROR;
            createType = COMMENT_NODE;
            break;
        case CDATA_SECTION_NODE_CHK:
            if (!tcldom_CDATACheck (interp, tval)) return TCL_ERROR;
            createType = CDATA_SECTION_NODE;
            break;
        default:
            createType = nodeInfo->type;
            break;
        }
        textNode = domNewTextNode(doc, tval, len, createType);
        textNode->info = nodeInfo->jsonType;
        if (disableOutputEscaping) {
            textNode->nodeFlags |= DISABLE_OUTPUT_ESCAPING;
        }
        domAppendChild(parent, (domNode*) textNode);
        break;

    case PROCESSING_INSTRUCTION_NODE_NAME_CHK:
    case PROCESSING_INSTRUCTION_NODE_VALUE_CHK:
    case PROCESSING_INSTRUCTION_NODE_CHK:
    case PROCESSING_INSTRUCTION_NODE:
        if (objc != 3) {
            Tcl_WrongNumArgs(interp, 1, objv, "target data");
            return TCL_ERROR;
        } 
        tval = Tcl_GetStringFromObj(objv[1], &len);
        if (abs(type) == PROCESSING_INSTRUCTION_NODE_NAME_CHK
            || abs(type) == PROCESSING_INSTRUCTION_NODE_CHK) {
            if (!tcldom_PINameCheck (interp, tval)) return TCL_ERROR;
        }
        aval = Tcl_GetStringFromObj(objv[2], &dlen);
        if (abs(type) == PROCESSING_INSTRUCTION_NODE_VALUE_CHK
            || abs(type) == PROCESSING_INSTRUCTION_NODE_CHK) {
            if (!tcldom_PIValueCheck (interp, aval)) return TCL_ERROR;
        }
        newNode = (domNode *)
            domNewProcessingInstructionNode(doc, tval, len, aval, dlen);
        domAppendChild(parent, newNode);
        break;

    case PARSER_NODE: /* non-standard node-type : a hack! */
        if (objc != 2) {
            Tcl_WrongNumArgs(interp, 1, objv, "markup");
            return TCL_ERROR;
        }
        ret = tcldom_appendXML(interp, parent, objv[1]);
        break;

    case ELEMENT_NODE_ANAME_CHK:
    case ELEMENT_NODE_AVALUE_CHK:
    case ELEMENT_NODE_CHK:
    case ELEMENT_NODE:
        if (!nodeInfo->tagName) {
            tag = Tcl_GetStringFromObj(objv[0], &len);
            p = tag + len;
            /* Isolate just the tag name, i.e. skip it's parent namespace */
            while (--p > tag) {
                if ((*p == ':') && (*(p-1) == ':')) {
                    p++; /* just after the last "::" */
                    tag = p;
                    break;
                }
            }
        } else {
            tag = nodeInfo->tagName;
        }

        newNode = domAppendNewElementNode (parent, tag, nodeInfo->namespace);
        newNode->info = nodeInfo->jsonType;

        cmdObj = NULL;
        if (nodecmd_processAttributes (interp, newNode, type, objc, objv,
                                         &cmdObj) != TCL_OK) {
            return TCL_ERROR;
        }
        if (cmdObj) {
            ret = nodecmd_appendFromScript(interp, newNode, cmdObj);
        }
        break;
    }

    if (type < 0 && newNode != NULL) {
        char buf[64];
        tcldom_createNodeObj(interp, newNode, buf);
        Tcl_SetObjResult(interp, Tcl_NewStringObj(buf, strlen(buf)));
    }
    
    if (ret == TCL_OK) doc->nodeFlags |= NEEDS_RENUMBERING;
    return ret;
}

/*----------------------------------------------------------------------------
|   nodecmd_createNodeCmd  -  implements the "createNodeCmd" method of
|                             "dom" Tcl command
|
|   This command is used to generate other Tcl commands which in turn
|   generate tDOM nodes. These new commands can only be called within
|   the context of the domNode command, however.
|
|   Syntax: dom createNodeCmd ?-returnNodeCmd? <nodeType> cmdName
|
|           where <nodeType> can be one of:
|              elementNode, commentNode, textNode, cdataNode or piNode
|
|   The optional "-returnNodeCmd" parameter, if given, instructs the
|   command to return the object-based node command of the newly generated
|   node. Without the parameter, the command returns current interp result.
|
|   Example:
|
|      % dom createNodeCmd                elementNode html::body
|      % dom createNodeCmd -returnNodeCmd elementNode html::title
|      % dom createNodeCmd                textNode    html::t
|
|   And usage:
|
|      % set d [dom createDocument html]
|      % set n [$d documentElement]
|      % $n appendFromScript {
|           html::body {
|           set title [html::title {html::t "This is an example"}]
|           $title setAttribute dummy 1
|      }
|      % puts [$n asHTML]
|
\---------------------------------------------------------------------------*/
int
nodecmd_createNodeCmd (
    Tcl_Interp    * interp,             /* Current interpreter. */
    int             objc,               /* Number of arguments. */
    Tcl_Obj *const  objv[],             /* Argument objects. */
    int             checkName,          /* Flag: Name checks? */
    int             checkCharData       /* Flag: Data checks? */
) {
    int index, ret, type, nodecmd = 0, jsonType = 0, haveJsonType = 0;
    int isElement = 0;
    char *nsName, buf[64];
    Tcl_Obj *tagName = NULL, *namespace = NULL;
    Tcl_DString cmdName;
    NodeInfo *nodeInfo;

    /*
     * Syntax:  
     *
     *     dom createNodeCmd ?-returnNodeCmd? nodeType commandName
     */

    enum subCmd {
        ELM_NODE, TXT_NODE, CDS_NODE, CMT_NODE, PIC_NODE, PRS_NODE
    };

    static const char *subcmds[] = {
        "elementNode", "textNode", "cdataNode", "commentNode", "piNode",
        "parserNode", NULL
    };

    static const char *options[] = {
        "-returnNodeCmd", "-jsonType", "-tagName", "-namespace", NULL
    };

    enum option {
        o_returnNodeCmd, o_jsonType, o_tagName, o_namespace
    };

    static const char *jsonTypes[] = {
        "NONE",
        "ARRAY",
        "OBJECT",
        "NULL",
        "TRUE",
        "FALSE",
        "STRING",
        "NUMBER"
    };

    if (objc < 3 ) {
        goto usage;
    }

    while (objc > 3) {
        if (Tcl_GetIndexFromObj (interp, objv[1], options, "option",
                                 0, &index) != TCL_OK) {
            return TCL_ERROR;
        }
        switch ((enum option) index) {
        case o_returnNodeCmd:
            nodecmd = 1;
            objc--;
            objv++;
            break;
            
        case o_jsonType:
            if (Tcl_GetIndexFromObj (interp, objv[2], jsonTypes, "jsonType",
                                     1, &jsonType) != TCL_OK) {
                return TCL_ERROR;
            }
            haveJsonType = 1;
            objc -= 2;
            objv += 2;
            break;
            
        case o_tagName:
            tagName = objv[2];
            objc -= 2;
            objv += 2;
            break;

        case o_namespace:
            namespace = objv[2];
            objc -= 2;
            objv += 2;
            break;
            
        }
    }
    if (objc != 3) {
        goto usage;
    }

    ret = Tcl_GetIndexFromObj(interp, objv[1], subcmds, "nodeType", 0, &index);
    if (ret != TCL_OK) {
        return ret;
    }

    /*--------------------------------------------------------------------
    |   Construct fully qualified command name using current namespace
    |
    \-------------------------------------------------------------------*/
    Tcl_DStringInit(&cmdName);
    strcpy(buf, "namespace current");
    ret = Tcl_Eval(interp, buf);
    if (ret != TCL_OK) {
        return ret;
    }
    nsName = (char *)Tcl_GetStringResult(interp);
    Tcl_DStringAppend(&cmdName, nsName, -1);
    if (strcmp(nsName, "::")) {
        Tcl_DStringAppend(&cmdName, "::", 2);
    }
    Tcl_DStringAppend(&cmdName, Tcl_GetString(objv[2]), -1);

    Tcl_ResetResult (interp);
    switch ((enum subCmd)index) {
    case ELM_NODE: 
        isElement = 1;
        if (!haveJsonType) {
            if (!tcldom_nameCheck(interp, namespaceTail(objv[2]),
                                  "tag", 0)) {
                return TCL_ERROR;
            }
            if (checkName && checkCharData) {
                type = ELEMENT_NODE_CHK;
            } else if (checkName) {
                type = ELEMENT_NODE_ANAME_CHK;
            } else if (checkCharData) {
                type = ELEMENT_NODE_AVALUE_CHK;
            } else {
                type = ELEMENT_NODE;
            }
        } else {
            if (jsonType > 2) {
                Tcl_SetResult(interp, "For an element node the jsonType"
                              " argument must be one out of this list: ARRAY"
                              " OBJECT NONE.", NULL);
                return TCL_ERROR;
            }
            type = ELEMENT_NODE;
        }
        break;
    case PRS_NODE: 
        type = PARSER_NODE;
        break;
    case TXT_NODE: 
        if (!haveJsonType) {
            if (checkCharData) {
                type = TEXT_NODE_CHK;
            } else {
                type = TEXT_NODE;
            }
        } else {
            if (jsonType < 3 && jsonType > 0) {
                Tcl_SetResult(interp, "For a text node the jsonType "
                              "argument must be one out of this list: "
                              "TRUE FALSE NULL NUMBER STRING NONE",
                              NULL);
                return TCL_ERROR;
            }
            type = TEXT_NODE;
        }
        break;
    case CDS_NODE: 
        if (checkCharData) {
            type = CDATA_SECTION_NODE_CHK;
        } else {
            type = CDATA_SECTION_NODE;
        }
        break;
    case CMT_NODE:
        if (checkCharData) {
            type = COMMENT_NODE_CHK;
        } else {
            type = COMMENT_NODE;
        }
        break;
    case PIC_NODE: 
        if (checkName && checkCharData) {
            type = PROCESSING_INSTRUCTION_NODE_CHK;
        } else if (checkName) {
            type = PROCESSING_INSTRUCTION_NODE_NAME_CHK;
        } else if (checkCharData) {
            type = PROCESSING_INSTRUCTION_NODE_VALUE_CHK;
        } else {
            type = PROCESSING_INSTRUCTION_NODE;
        }
        break;
    default:
        Tcl_SetResult (interp, "Invalid/unexpected node type", NULL);
        return TCL_ERROR;
    }

    if (tagName && !isElement) {
        Tcl_SetResult(interp, "The -tagName option is allowed only for "
                      "element node commands.", NULL);
        return TCL_ERROR;        
    }

    if (namespace && !isElement) {
        Tcl_SetResult(interp, "The -namespace option is allowed only for "
                      "element node commands.", NULL);
        return TCL_ERROR;        
    }
    
    if (haveJsonType && type != ELEMENT_NODE && type != TEXT_NODE) {
        Tcl_SetResult(interp, "Only element and text nodes may have a "
                      "JSON type.", NULL);
        return TCL_ERROR;        
    }
    
    nodeInfo = (NodeInfo *) MALLOC (sizeof (NodeInfo));
    nodeInfo->namespace = NULL;
    nodeInfo->type = type;
    if (nodecmd) {
        nodeInfo->type *= -1; /* Signal this fact */
    }
    nodeInfo->jsonType = jsonType;
    nodeInfo->tagName = NULL;
    if (namespace) {
        nodeInfo->namespace = tdomstrdup (Tcl_GetString(namespace));
    }
    if (tagName) {
        nodeInfo->tagName = tdomstrdup (Tcl_GetString(tagName));
    }
    Tcl_CreateObjCommand(interp, Tcl_DStringValue(&cmdName), NodeObjCmd,
                         (ClientData)nodeInfo, NodeObjCmdDeleteProc);
    Tcl_DStringResult(interp, &cmdName);
    Tcl_DStringFree(&cmdName);

    return TCL_OK;

 usage:
    Tcl_AppendResult(interp, "dom createNodeCmd\n"
                     "\t?-returnNodeCmd?\n"
                     "\t?-jsonType <jsonType>?\n"
                     "\t?-tagName <tagName>?\n"
                     " nodeType cmdName", NULL);
    return TCL_ERROR;
}


/*
 *----------------------------------------------------------------------
 *
 * nodecmd_appendFromScript --
 *
 *	This procedure implements the dom method appendFromScript.
 *      See the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	Appends new child nodes to node.
 *
 *----------------------------------------------------------------------
 */

int
nodecmd_appendFromScript (
    Tcl_Interp *interp,                /* Current interpreter. */
    domNode    *node,                  /* Parent dom node */
    Tcl_Obj    *cmdObj                 /* Argument objects. */
) {
    int ret, insideEval;
    domNode *oldLastChild, *child, *nextChild;
    domDocument *doc;
    
    if (node->nodeType != ELEMENT_NODE) {
        Tcl_SetResult (interp, "NOT_AN_ELEMENT : can't append nodes", NULL);
        return TCL_ERROR;
    }
    
    doc = node->ownerDocument;
    oldLastChild = node->lastChild;

    StackPush(interp, (void *) node);
    insideEval = (doc->nodeFlags & INSIDE_FROM_SCRIPT);
    if (!insideEval) {
        doc->nodeFlags |= INSIDE_FROM_SCRIPT;
    }
    Tcl_AllowExceptions(interp);
    ret = Tcl_EvalObjEx(interp, cmdObj, 0);
    if (ret != TCL_ERROR) {
        Tcl_ResetResult(interp);
    }
    StackPop(interp);

    if (ret == TCL_ERROR) {
        if (oldLastChild) {
            child = oldLastChild->nextSibling;
        } else {
            child = node->firstChild;
        }
        while (child) {
            nextChild = child->nextSibling;
            domFreeNode (child, NULL, NULL, 0);
            child = nextChild;
        }
        if (oldLastChild) {
            oldLastChild->nextSibling = NULL;
            node->lastChild = oldLastChild;
        } else {
            node->firstChild = NULL;
            node->lastChild = NULL;
        }
    }

    if (!insideEval) {
        /* Top level reached */
        node->ownerDocument->nodeFlags &= ~INSIDE_FROM_SCRIPT;
        if (doc->nodeFlags & DELETE_AFTER_FROM_SCRIPT) {
            tcldom_deleteDoc(interp, doc);
            return TCL_BREAK;
        }
    }
    return (ret == TCL_BREAK) ? TCL_OK : ret;
}


/*
 *----------------------------------------------------------------------
 *
 * nodecmd_insertBeforeFromScript --
 *
 *	This procedure implements the dom method
 *	insertBeforeFromScript. See the user documentation for details
 *	on what it does.
 *
 *      This procedure is actually mostly a wrapper around
 *      nodecmd_appendFromScript.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	Insert new child nodes before referenceChild to node.
 *
 *----------------------------------------------------------------------
 */

int
nodecmd_insertBeforeFromScript (
    Tcl_Interp *interp,                 /* Current interpreter. */
    domNode    *node,                   /* Parent dom node */
    Tcl_Obj    *cmdObj,                 /* Argument objects. */
    domNode    *refChild                /* Insert new children before this
                                         * node; may be NULL */
) {
    int      ret;
    domNode *storedLastChild, *n;

    if (!refChild) {
        return nodecmd_appendFromScript (interp, node, cmdObj);
    }
    
    if (node->nodeType != ELEMENT_NODE) {
        Tcl_SetResult (interp, "NOT_AN_ELEMENT : can't append nodes", NULL);
        return TCL_ERROR;
    }

    /* check, if node is in deed the parent of refChild */
    if (refChild->parentNode != node) {
        /* If node is the root node of a document and refChild
           is in deed a child of this node, then 
           refChild->parentNode will be NULL. In this case, we
           loop throu the children of node, to see, if the refChild
           is valid. */
        Tcl_ResetResult (interp);
        if (node->ownerDocument->rootNode == node) {
            n = node->firstChild;
            while (n) {
                if (n == refChild) {
                    /* refChild is in deed a child of node */
                    break;
                }
                n = n->nextSibling;
            }
            if (!n) {
                Tcl_SetStringObj(Tcl_GetObjResult(interp), "NOT_FOUND_ERR",
                                 -1);
                return TCL_ERROR;
            }
        } else {
            Tcl_SetStringObj(Tcl_GetObjResult(interp), "NOT_FOUND_ERR", -1);
            return TCL_ERROR;
        }
    }

    storedLastChild = node->lastChild;
    if (refChild->previousSibling) {
        refChild->previousSibling->nextSibling = NULL;
        node->lastChild = refChild->previousSibling;
    } else {
        node->firstChild = NULL;
        node->lastChild = NULL;
    }
    ret = nodecmd_appendFromScript (interp, node, cmdObj);
    if (node->lastChild) {
        node->lastChild->nextSibling = refChild;
        refChild->previousSibling = node->lastChild;
    } else {
        node->firstChild = refChild;
    }
    node->lastChild = storedLastChild;
    
    return ret;
}


/*----------------------------------------------------------------------------
|   nodecmd_curentNode
|
\---------------------------------------------------------------------------*/

domNode *
nodecmd_currentNode(Tcl_Interp *interp)
{
    return StackTop(interp);
}


void
nodecmd_init (Tcl_Interp *interp) 
{
    CurrentStack *csPtr = (CurrentStack *) MALLOC(sizeof(CurrentStack));
    csPtr->elementStack = NULL;
    csPtr->currentSlot = NULL;
    Tcl_SetAssocData(interp, "tdom_stk", StackFinalize, (ClientData) csPtr);
}


/* EOF $RCSfile $ */

/* Emacs Setup Variables */
/* Local Variables:      */
/* mode: C               */
/* indent-tabs-mode: nil */
/* c-basic-offset: 4     */
/* End:                  */

