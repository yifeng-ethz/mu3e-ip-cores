/*----------------------------------------------------------------------------
|   Copyright (c) 2018  Rolf Ade (rolf@pointsman.de)
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
|   February 2018
|
\---------------------------------------------------------------------------*/

#ifndef TDOM_NO_PULL

#include <dom.h>
#include <fcntl.h>
#ifdef _MSC_VER
#include <io.h>
#else
#include <unistd.h>
#endif

#ifndef O_BINARY
#ifdef _O_BINARY
#define O_BINARY _O_BINARY
#else
#define O_BINARY 0
#endif
#endif

#ifndef TDOM_EXPAT_READ_SIZE
# define TDOM_EXPAT_READ_SIZE (1024*8)
#endif

/* For information about why this work-around for a certain expat
 * version is necessary see
 * https://github.com/libexpat/libexpat/issues/204 */
#if (XML_MAJOR_VERSION == 2) && (XML_MINOR_VERSION == 2) && (XML_MICRO_VERSION == 5)
# define EXPAT_RESUME_BUG
#endif

/* #define DEBUG */
/*----------------------------------------------------------------------------
|   Debug Macros
|
\---------------------------------------------------------------------------*/
#ifdef DEBUG
# define DBG(x) x
#else
# define DBG(x) 
#endif

typedef enum {
    PULLPARSERSTATE_READY,
    PULLPARSERSTATE_START_DOCUMENT,
    PULLPARSERSTATE_END_DOCUMENT,
    PULLPARSERSTATE_START_TAG,
    PULLPARSERSTATE_END_TAG,
    PULLPARSERSTATE_TEXT,
    PULLPARSERSTATE_PARSE_ERROR
} PullParserState;

typedef enum {
    PULLPARSEMODE_NORMAL,
    PULLPARSEMODE_SKIP,
    PULLPARSEMODE_FIND
} PullParseMode;
    
typedef struct tDOM_PullParserInfo 
{
    XML_Parser      parser;
    Tcl_Obj        *inputString;
    Tcl_Channel     inputChannel;
    int             inputfd;
    PullParserState state;
    PullParserState nextState;
    PullParserState next2State;
    Tcl_DString    *cdata;
    Tcl_HashTable  *elmCache;
    Tcl_Obj        *currentElm;
    const char    **atts;
    Tcl_Obj        *channelReadBuf;
    Tcl_Obj        *start_tag;
    Tcl_Obj        *end_tag;
    Tcl_Obj        *text;
    int             ignoreWhiteSpaces;
    PullParseMode   mode;
    int             skipDepth;
    Tcl_Obj       **firstFindElement;
    domLength       countFindElement;
#ifdef EXPAT_RESUME_BUG
    long            elmStartCounter;
#endif
} tDOM_PullParserInfo;

#define SetResult(str) Tcl_ResetResult(interp); \
                     Tcl_SetStringObj(Tcl_GetObjResult(interp), (str), -1)

DBG(
static void
printParserState (
    XML_Parser parser
    )
{
    XML_ParsingStatus pstatus;
    
    XML_GetParsingStatus (parser, &pstatus);
    switch (pstatus.parsing) {
    case XML_INITIALIZED:
        fprintf (stderr, "parser status: XML_INITIALIZED\n");
        break;
    case XML_PARSING:
        fprintf (stderr, "parser status: XML_PARSING\n");
        break;
    case XML_FINISHED:
        fprintf (stderr, "parser status: XML_FINISHED\n");
        break;
    case XML_SUSPENDED:
        fprintf (stderr, "parser status: XML_SUSPENDED\n");
        break;
    default:
        fprintf (stderr, "unexpected parser status: %d\n",
                 pstatus.parsing);
        break;
    }
}
)

static void
characterDataHandler (
    void        *userData,
    const char  *s,
    int          len
)
{
    tDOM_PullParserInfo *pullInfo = userData;

    DBG(fprintf(stderr, "cdata handler called\n"));
    Tcl_DStringAppend (pullInfo->cdata, s, len);    
}

static void
endElement (
    void        *userData,
    const char  *name
)
{
    tDOM_PullParserInfo *pullInfo = userData;
    XML_ParsingStatus status;
    int reportStartTag = 0, reportText = 0, hnew;
    Tcl_HashEntry *h;

    DBG(fprintf(stderr, "endElement tag %s\n", name));

    if (pullInfo->mode == PULLPARSEMODE_SKIP) {
        if (pullInfo->skipDepth > 0) {
            pullInfo->skipDepth--;
            return;
        }
        pullInfo->mode = PULLPARSEMODE_NORMAL;
        XML_SetCharacterDataHandler (pullInfo->parser, characterDataHandler);
    }
            
    XML_GetParsingStatus (pullInfo->parser, &status);
    if (status.parsing == XML_SUSPENDED) {
        reportStartTag = 1;
    }

    if (Tcl_DStringLength (pullInfo->cdata) > 0) {
        if (pullInfo->ignoreWhiteSpaces) {
            char *pc; domLength len;
            len = Tcl_DStringLength(pullInfo->cdata);
            for (pc = Tcl_DStringValue (pullInfo->cdata);
                 len > 0;
                 len--, pc++) 
            {
                if ( (*pc != ' ')  &&
                     (*pc != '\t') &&
                     (*pc != '\n') &&
                     (*pc != '\r') ) {
                    reportText = 1;
                    break;
                }
            }
        } else {
            reportText = 1;
        }
    }

    if (reportStartTag && reportText) {
        /* This happens if in mixed content an empty element written
         * with the empty element syntax (<foo/>) follows text. */
        DBG(fprintf(stderr, "schedule 2 events\n"));
        pullInfo->state = PULLPARSERSTATE_TEXT;
        pullInfo->nextState= PULLPARSERSTATE_START_TAG;
        pullInfo->next2State = PULLPARSERSTATE_END_TAG;
    } else if (reportStartTag) {
        /* This happens if not in mixed content and the parser saw an
         * empty element written with the empty element syntax. */
        DBG(fprintf(stderr, "schedule 1 event (reportStartTag)\n"));
        pullInfo->state = PULLPARSERSTATE_START_TAG;
        pullInfo->nextState = PULLPARSERSTATE_END_TAG;
#ifdef EXPAT_RESUME_BUG
        DBG(fprintf(stderr, "EXPAT_RESUME_BUG\n"));
        if (pullInfo->elmStartCounter == 1) {
            pullInfo->next2State = PULLPARSERSTATE_END_DOCUMENT;
        }
#endif        
    } else if (reportText) {
        DBG(fprintf(stderr, "schedule 1 event (reportText)\n"));
        pullInfo->state = PULLPARSERSTATE_TEXT;
        pullInfo->nextState = PULLPARSERSTATE_END_TAG;
    } else {
        pullInfo->state = PULLPARSERSTATE_END_TAG;
    }

    h = Tcl_FindHashEntry (pullInfo->elmCache, name);
    if (h == NULL) {
        /* The start tag entry creation was skipped during a
         * find-element, create it now. */
        h = Tcl_CreateHashEntry (pullInfo->elmCache, name, &hnew);
        DBG(fprintf(stderr, "endElement: create tag hash table entry %s\n", name));
        pullInfo->currentElm = Tcl_NewStringObj (name, -1);
        Tcl_IncrRefCount (pullInfo->currentElm);
        Tcl_SetHashValue (h, pullInfo->currentElm);
    }
    pullInfo->currentElm = (Tcl_Obj *) Tcl_GetHashValue(h);
    XML_StopParser(pullInfo->parser, 1);
}

static void
startElement(
    void         *userData,
    const char   *name,
    const char  **atts
)
{
    tDOM_PullParserInfo *pullInfo = userData;
    int i, hnew;
    int match;
    Tcl_HashEntry *h;
    
    DBG(fprintf(stderr, "startElement tag %s\n", name));

#ifdef EXPAT_RESUME_BUG
    pullInfo->elmStartCounter++;
#endif

    switch (pullInfo->mode) {
    case PULLPARSEMODE_SKIP:
        DBG(fprintf (stderr, "PULLPARSEMODE_SKIP\n"));
        pullInfo->skipDepth++;
        return;
    case PULLPARSEMODE_FIND:
        match = 0;
        for (i=0 ; i < pullInfo->countFindElement ; i++) {
            char * findElement = Tcl_GetString(pullInfo->firstFindElement[i]);

            DBG(fprintf (stderr, "PULLPARSEMODE_FIND this %s search for %s\n",
                name, findElement));

            if (strcmp (name, findElement) == 0) {
                match = 1;
                break;
            }
        }
        if (!match) {
            return;
        }
        pullInfo->mode = PULLPARSEMODE_NORMAL;
        XML_SetCharacterDataHandler (pullInfo->parser, characterDataHandler);
        XML_SetEndElementHandler (pullInfo->parser, endElement);
        break;
    case PULLPARSEMODE_NORMAL:
        break;
    }
    if (Tcl_DStringLength (pullInfo->cdata) > 0) {
        if (pullInfo->ignoreWhiteSpaces) {
            char *pc; domLength len, wso = 1;
            len = Tcl_DStringLength(pullInfo->cdata);
            for (pc = Tcl_DStringValue (pullInfo->cdata);
                 len > 0;
                 len--, pc++) 
            {
                if ( (*pc != ' ')  &&
                     (*pc != '\t') &&
                     (*pc != '\n') &&
                     (*pc != '\r') ) {
                    wso = 0;
                    break;
                }
            }
            if (wso) {
                Tcl_DStringSetLength (pullInfo->cdata, 0);
                pullInfo->state = PULLPARSERSTATE_START_TAG;
            } else {
                DBG(fprintf(stderr, "schedule TEXT event\n"));
                pullInfo->state = PULLPARSERSTATE_TEXT;
                pullInfo->nextState = PULLPARSERSTATE_START_TAG;
            }
        } else {
            DBG(fprintf(stderr, "schedule TEXT event\n"));
            pullInfo->state = PULLPARSERSTATE_TEXT;
            pullInfo->nextState = PULLPARSERSTATE_START_TAG;
        }
    } else {
        pullInfo->state = PULLPARSERSTATE_START_TAG;
    }
    h = Tcl_CreateHashEntry (pullInfo->elmCache, name, &hnew);
    if (hnew) {
        DBG(fprintf(stderr, "startElement: create tag hash table entry %s\n", name));
        pullInfo->currentElm = Tcl_NewStringObj (name, -1);
        Tcl_IncrRefCount (pullInfo->currentElm);
        Tcl_SetHashValue (h, pullInfo->currentElm);
    } else {
        pullInfo->currentElm = (Tcl_Obj *) Tcl_GetHashValue (h);
    }
    pullInfo->atts = atts;

    XML_StopParser(pullInfo->parser, 1);
}

static void
tDOM_PullParserDeleteCmd (
    ClientData clientdata
    )
{
    tDOM_PullParserInfo *pullInfo = clientdata;
    Tcl_HashEntry *entryPtr;
    Tcl_HashSearch search;

    XML_ParserFree (pullInfo->parser);
    if (pullInfo->inputString) {
        Tcl_DecrRefCount (pullInfo->inputString);
    }
    if (pullInfo->inputfd) {
        close (pullInfo->inputfd);
    }
    Tcl_DStringFree (pullInfo->cdata);
    FREE (pullInfo->cdata);
    if (pullInfo->channelReadBuf) {
        Tcl_DecrRefCount (pullInfo->channelReadBuf);
    }
    entryPtr = Tcl_FirstHashEntry(pullInfo->elmCache, &search);
    while (entryPtr) {
        Tcl_DecrRefCount ((Tcl_Obj*) Tcl_GetHashValue (entryPtr));
        entryPtr = Tcl_NextHashEntry (&search);
    }
    Tcl_DeleteHashTable (pullInfo->elmCache);
    FREE (pullInfo->elmCache);
    Tcl_DecrRefCount(pullInfo->start_tag);
    Tcl_DecrRefCount(pullInfo->end_tag);
    Tcl_DecrRefCount(pullInfo->text);
    FREE (pullInfo);
}

static void
tDOM_ReportXMLError (
    Tcl_Interp *interp,
    tDOM_PullParserInfo *pullInfo
    )
{
    char s[255];

    Tcl_ResetResult (interp);
    sprintf(s, "%ld", XML_GetCurrentLineNumber(pullInfo->parser));
    Tcl_AppendResult(interp, "error \"",
                     XML_ErrorString(
                         XML_GetErrorCode(pullInfo->parser)),
                     "\" at line ", s, " character ", NULL);
    sprintf(s, "%ld", XML_GetCurrentColumnNumber(pullInfo->parser));
    Tcl_AppendResult(interp, s, NULL);
}

static void
tDOM_CleanupInputSource (
    tDOM_PullParserInfo *pullInfo
    )
{
    if (pullInfo->inputString) {
        Tcl_DecrRefCount (pullInfo->inputString);
        pullInfo->inputString = NULL;
    }
    pullInfo->inputChannel = NULL;
    if (pullInfo->inputfd) {
        close (pullInfo->inputfd);
        pullInfo->inputfd = 0;
    }
}

static int
tDOM_resumeParseing (
    Tcl_Interp *interp,
    tDOM_PullParserInfo *pullInfo
    ) 
{
    XML_ParsingStatus pstatus;
    int done, result;
    domLength len;
    char *data;
    

    switch (XML_ResumeParser (pullInfo->parser)) {
    case XML_STATUS_OK:
        if (pullInfo->inputString) {
            Tcl_DecrRefCount (pullInfo->inputString);
            pullInfo->inputString = NULL;
            pullInfo->state = PULLPARSERSTATE_END_DOCUMENT;
            break;
        }
        XML_GetParsingStatus (pullInfo->parser, &pstatus);
        if (pstatus.parsing == XML_FINISHED) {
            tDOM_CleanupInputSource (pullInfo);
            pullInfo->state = PULLPARSERSTATE_END_DOCUMENT;
            break;
        }
        if (pullInfo->inputChannel) {
            do {
                len = Tcl_ReadChars (pullInfo->inputChannel,
                                     pullInfo->channelReadBuf,
                                     1024, 0);
                done = (len < 1024);
                data = Tcl_GetStringFromObj (
                    pullInfo->channelReadBuf, &len
                    );
                result = XML_Parse (pullInfo->parser, data,
                                    (int)len, done);
            } while (result == XML_STATUS_OK && !done);
        } else {
            /* inputfile */
            do {
                char *fbuf = 
                    XML_GetBuffer (pullInfo->parser,
                                   TDOM_EXPAT_READ_SIZE);
                len = read (pullInfo->inputfd, fbuf,
                            TDOM_EXPAT_READ_SIZE);
                done = (len < TDOM_EXPAT_READ_SIZE);
                result = XML_ParseBuffer (pullInfo->parser,
                                          (int)len, done);
            } while (result == XML_STATUS_OK && !done);
        }
        if (result == XML_STATUS_ERROR) {
            tDOM_CleanupInputSource (pullInfo);
            tDOM_ReportXMLError (interp, pullInfo);
            pullInfo->state = PULLPARSERSTATE_PARSE_ERROR;
            return TCL_ERROR;
        }
        if (done && result == XML_STATUS_OK) {
            tDOM_CleanupInputSource (pullInfo);
            pullInfo->state = PULLPARSERSTATE_END_DOCUMENT;
        }
        /* If here result == XML_STATUS_SUSPENDED,
         * state was set in handler, just take care to
         * report */
        break;
    case XML_STATUS_ERROR:
        tDOM_CleanupInputSource (pullInfo);
        tDOM_ReportXMLError (interp, pullInfo);
        pullInfo->state = PULLPARSERSTATE_PARSE_ERROR;
        return TCL_ERROR;
    case XML_STATUS_SUSPENDED:
        /* Nothing to do here, state was set in handler, just
         * take care to report */
        break;
    }
    
    return TCL_OK;
}

static int
tDOM_PullParserInstanceCmd (
    ClientData  clientdata,
    Tcl_Interp *interp,
    int         objc,
    Tcl_Obj    *const objv[]
    )
{
    tDOM_PullParserInfo *pullInfo = clientdata;
    int methodIndex, result, mode, fd, optionIndex, done;
    domLength len;
    char *data;
    const char **atts;
    Tcl_Obj *resultPtr;
    Tcl_Channel channel;
    
    static const char *const methods[] = {
        "input", "inputchannel", "inputfile",
        "next", "state", "tag", "attributes",
        "text", "delete", "reset", "skip",
        "find-element", "line", "column", NULL
    };
    static const char *const findelement_options[] = {
        "-names", NULL
    };

    enum method {
        m_input, m_inputchannel, m_inputfile,
        m_next, m_state, m_tag, m_attributes,
        m_text, m_delete, m_reset, m_skip,
        m_find_element, m_line, m_column
    };

    if (objc == 1) {
        /* Default method call is next */
        methodIndex = m_next;
    } else {
        if (Tcl_GetIndexFromObj (interp, objv[1], methods, "method", 0,
                                 &methodIndex) != TCL_OK) {
            return TCL_ERROR;
        }
    }
    switch ((enum method) methodIndex) {

    case m_input:
        if (objc != 3) {
            Tcl_WrongNumArgs (interp, 2, objv, "<xml>");
            return TCL_ERROR;
        }
        if (pullInfo->state != PULLPARSERSTATE_READY) {
            SetResult ("Can't change input while already parsing.");
            return TCL_ERROR;
        }
        Tcl_IncrRefCount (objv[2]);
        pullInfo->inputString = objv[2];
        pullInfo->state = PULLPARSERSTATE_START_DOCUMENT;
        break;

    case m_inputchannel:
        if (objc != 3) {
            Tcl_WrongNumArgs (interp, 2, objv, "<channel>");
            return TCL_ERROR;
        }
        if (pullInfo->state != PULLPARSERSTATE_READY) {
            SetResult ("Can't change input while already parsing.");
            return TCL_ERROR;
        }
        channel = Tcl_GetChannel (interp, Tcl_GetString(objv[2]), &mode);
        if (channel == NULL) {
            Tcl_ResetResult (interp);
            Tcl_AppendResult (interp, "\"", Tcl_GetString(objv[2]),
                              "\" isn't a Tcl channel in this interpreter", 
                              NULL);
            return TCL_ERROR;
        }
        if (!(mode & TCL_READABLE)) {
            Tcl_ResetResult (interp);
            Tcl_AppendResult (interp, "channel \"", Tcl_GetString(objv[2]),
                              "wasn't opened for reading", NULL);
            return TCL_ERROR;
        }
        pullInfo->inputChannel = channel;
        if (pullInfo->channelReadBuf == NULL) {
            pullInfo->channelReadBuf = Tcl_NewObj ();
            Tcl_IncrRefCount (pullInfo->channelReadBuf);
            Tcl_SetObjLength (pullInfo->channelReadBuf, 6144);
        }
        pullInfo->state = PULLPARSERSTATE_START_DOCUMENT;
        break;

    case m_inputfile:
        if (objc != 3) {
            Tcl_WrongNumArgs (interp, 2, objv, "<filename>");
            return TCL_ERROR;
        }
        if (pullInfo->state != PULLPARSERSTATE_READY) {
            SetResult ("Can't change input while already parsing.");
            return TCL_ERROR;
        }
        fd = open(Tcl_GetString(objv[2]), O_BINARY|O_RDONLY);
        if (fd < 0) {
            Tcl_ResetResult (interp);
            Tcl_AppendResult (interp, "error opening file \"",
                              Tcl_GetString(objv[2]), "\"", NULL);
            return TCL_ERROR;
        }
        pullInfo->inputfd = fd;
        pullInfo->state = PULLPARSERSTATE_START_DOCUMENT;
        break;

    case m_next:
        if (objc != 2) {
            Tcl_WrongNumArgs (interp, 2, objv, "");
            return TCL_ERROR;
        }
        if (pullInfo->state == PULLPARSERSTATE_TEXT) {
            Tcl_DStringSetLength (pullInfo->cdata, 0);
        }
        if (pullInfo->next2State) {
            pullInfo->state = pullInfo->nextState;
            pullInfo->nextState = pullInfo->next2State;
            pullInfo->next2State = 0;
        } else if (pullInfo->nextState) {
            pullInfo->state = pullInfo->nextState;
            pullInfo->nextState = 0;
        } else {
            switch (pullInfo->state) {
            case PULLPARSERSTATE_READY:
                SetResult ("No input");
                return TCL_ERROR;
            case PULLPARSERSTATE_PARSE_ERROR:
                SetResult ("Parsing stopped with XML parsing error.");
                return TCL_ERROR;
            case PULLPARSERSTATE_END_DOCUMENT:
                SetResult ("No next event after END_DOCUMENT");
                return TCL_ERROR;
            case PULLPARSERSTATE_TEXT:
                /* Since PULLPARSERSTATE_TEXT always has nextState set
                 * this case is handled in the if part of this if else
                 * and this is never reached. It's just here to eat up
                 * this case in the switch. */
                break;
            case PULLPARSERSTATE_START_DOCUMENT:
                if (pullInfo->inputfd) {
                    do {
                        char *fbuf =
                            XML_GetBuffer (pullInfo->parser,
                                           TDOM_EXPAT_READ_SIZE);
                        len = read(pullInfo->inputfd, fbuf,
                                   TDOM_EXPAT_READ_SIZE);
                        result = XML_ParseBuffer (pullInfo->parser,
                                                  (int)len, len == 0);
                    } while (result == XML_STATUS_OK);
                } else if (pullInfo->inputChannel) {
                    do {
                        len = Tcl_ReadChars (pullInfo->inputChannel,
                                             pullInfo->channelReadBuf,
                                             1024, 0);
                        data = Tcl_GetString (pullInfo->channelReadBuf);
                        result = XML_Parse (pullInfo->parser, data, (int)len,
                                            len == 0);
                    } while (result == XML_STATUS_OK);
                } else {
                    data = Tcl_GetStringFromObj(pullInfo->inputString, &len);
                    do {
                        done = (len < PARSE_CHUNK_SIZE);
                        result = XML_Parse (pullInfo->parser, data, (int)len,
                                            done);
                        if (!done) {
                            data += PARSE_CHUNK_SIZE;
                            len -= PARSE_CHUNK_SIZE;
                        }
                    } while (!done && result == XML_STATUS_OK);
                }
                switch (result) {
                case XML_STATUS_OK:
                    tDOM_CleanupInputSource (pullInfo);
                    pullInfo->state = PULLPARSERSTATE_END_DOCUMENT;
                    break;
                case XML_STATUS_ERROR:
                    tDOM_CleanupInputSource (pullInfo);
                    tDOM_ReportXMLError (interp, pullInfo);
                    pullInfo->state = PULLPARSERSTATE_PARSE_ERROR;
                    return TCL_ERROR;
                case XML_STATUS_SUSPENDED:
                    /* Nothing to do here, state was set in handler, just
                     * take care to report */
                    break;
                }
                break;
            default:
                DBG (printParserState(pullInfo->parser));
                if (tDOM_resumeParseing (interp, pullInfo) != TCL_OK) {
                    return TCL_ERROR;
                }
                DBG (printParserState(pullInfo->parser));
                break;
            }
        }
        /* To report state:*/
        /* fall through */
    case m_state:
        if (objc != 2) {
            Tcl_WrongNumArgs (interp, 2, objv, "");
            return TCL_ERROR;
        }
        switch (pullInfo->state) {
        case PULLPARSERSTATE_READY:
            SetResult("READY");
            break;
        case PULLPARSERSTATE_PARSE_ERROR:
            SetResult("PARSE_ERROR");
            break;
        case PULLPARSERSTATE_START_DOCUMENT:
            SetResult("START_DOCUMENT");
            break;
        case PULLPARSERSTATE_END_DOCUMENT:
            SetResult("END_DOCUMENT");
            break;
        case PULLPARSERSTATE_START_TAG:
            Tcl_SetObjResult (interp, pullInfo->start_tag);
            break;
        case PULLPARSERSTATE_END_TAG:
            Tcl_SetObjResult (interp, pullInfo->end_tag);
            break;
        case PULLPARSERSTATE_TEXT:
            Tcl_SetObjResult (interp, pullInfo->text);
            break;
        }
        break;

    case m_tag:
        if (objc != 2) {
            Tcl_WrongNumArgs (interp, 2, objv, "");
            return TCL_ERROR;
        }
        if (pullInfo->state != PULLPARSERSTATE_START_TAG
            && pullInfo->state != PULLPARSERSTATE_END_TAG) {
            SetResult("Invalid state");
            return TCL_ERROR;
        }
        Tcl_SetObjResult (interp, pullInfo->currentElm);
        break;

    case m_attributes:
        if (objc != 2) {
            Tcl_WrongNumArgs (interp, 2, objv, "");
            return TCL_ERROR;
        }
        if (pullInfo->state != PULLPARSERSTATE_START_TAG) {
            SetResult("Invalid state - attribute method is only valid in state START_TAG.");
            return TCL_ERROR;
        }
        Tcl_ResetResult(interp);
        resultPtr = Tcl_GetObjResult(interp);
        atts = pullInfo->atts;
        while (atts[0] != NULL) {
            Tcl_ListObjAppendElement (interp, resultPtr,
                                      Tcl_NewStringObj(atts[0], -1));
            atts++;
        }
        break;

    case m_text:
        if (objc != 2) {
            Tcl_WrongNumArgs (interp, 2, objv, "");
            return TCL_ERROR;
        }
        Tcl_ResetResult (interp);
        Tcl_SetStringObj (
            Tcl_GetObjResult (interp),
            Tcl_DStringValue (pullInfo->cdata),
            Tcl_DStringLength (pullInfo->cdata)
            );
        break;

    case m_skip:
        if (objc != 2) {
            Tcl_WrongNumArgs (interp, 2, objv, "");
            return TCL_ERROR;
        }
        if (pullInfo->state != PULLPARSERSTATE_START_TAG) {
            SetResult("Invalid state - skip method is only valid in state START_TAG.");
            return TCL_ERROR;
        }
        if (pullInfo->nextState == PULLPARSERSTATE_END_TAG
            || pullInfo->next2State == PULLPARSERSTATE_END_TAG) {
            pullInfo->state = PULLPARSERSTATE_END_TAG;
#ifdef EXPAT_RESUME_BUG
            if (pullInfo->next2State == PULLPARSERSTATE_END_DOCUMENT) {
                pullInfo->nextState = PULLPARSERSTATE_END_DOCUMENT;
            } else {
                pullInfo->nextState = 0;
            }
#else            
            pullInfo->nextState = 0;
#endif            
            pullInfo->next2State = 0;
            Tcl_DStringSetLength (pullInfo->cdata, 0);
            Tcl_SetObjResult (interp, pullInfo->end_tag);
            break;
        }
        pullInfo->mode = PULLPARSEMODE_SKIP;
        pullInfo->skipDepth = 0;
        Tcl_DStringSetLength (pullInfo->cdata, 0);
        XML_SetCharacterDataHandler (pullInfo->parser, NULL);
        if (tDOM_resumeParseing (interp, pullInfo) != TCL_OK) {
            return TCL_ERROR;
        }
        Tcl_SetObjResult (interp, pullInfo->end_tag);
        break;
        
    case m_find_element:
        
        if (objc < 3 || objc > 4) {
            Tcl_WrongNumArgs (interp, 2, objv, "-names list"); 
            return TCL_ERROR;
        } else if (objc == 3) {
            /* Single argument version */
            Tcl_ListObjGetElements(interp, objv[2], &pullInfo->countFindElement, &pullInfo->firstFindElement);
        } else {
            if (Tcl_GetIndexFromObj (interp, objv[2], findelement_options, "option", 0,
                                                         &optionIndex) != TCL_OK) {
                 return TCL_ERROR;
             } else {
               Tcl_ListObjGetElements(interp, objv[3], &pullInfo->countFindElement, &pullInfo->firstFindElement);
             }

        }
        if (pullInfo->state != PULLPARSERSTATE_START_TAG
            && pullInfo->state != PULLPARSERSTATE_END_TAG
            && pullInfo->state != PULLPARSERSTATE_START_DOCUMENT) {
            SetResult("Invalid state - find-element method is only valid in states "
                      "START_DOCUMENT, START_TAG and END_TAG.");
            return TCL_ERROR;
        }
#ifdef EXPAT_RESUME_BUG
        if (pullInfo->state == PULLPARSERSTATE_END_TAG
            && pullInfo->nextState == PULLPARSERSTATE_END_DOCUMENT) {
            pullInfo->state = PULLPARSERSTATE_END_DOCUMENT;
            SetResult ("END_DOCUMENT");
            break;
        }
#endif
        pullInfo->mode = PULLPARSEMODE_FIND;
        /* As long as we don't evaluate any Tcl script code during a
         * pull parser method call this should be secure. */
        Tcl_DStringSetLength (pullInfo->cdata, 0);
        XML_SetCharacterDataHandler (pullInfo->parser, NULL);
        XML_SetEndElementHandler (pullInfo->parser, NULL);
        if (pullInfo->state == PULLPARSERSTATE_START_DOCUMENT) {
            Tcl_Obj * thisObjv[2];
            Tcl_Obj * thisMethod = Tcl_NewStringObj ("next", 4);
            Tcl_IncrRefCount (thisMethod);
            thisObjv[0] = objv[0];
            thisObjv[1] = thisMethod;
            result = tDOM_PullParserInstanceCmd (pullInfo, interp, 2,
                                                 thisObjv);
            Tcl_DecrRefCount (thisMethod);
            if (result != TCL_OK) {
                return TCL_ERROR;
            }
        } else {
            if (tDOM_resumeParseing (interp, pullInfo) != TCL_OK) {
                return TCL_ERROR;
            }
        }
        if (pullInfo->state == PULLPARSERSTATE_START_TAG) {
            Tcl_SetObjResult (interp, pullInfo->start_tag);
        } else {
            SetResult ("END_DOCUMENT");
        }
        break;

    case m_line:
    case m_column:
        if (objc != 2) {
            Tcl_WrongNumArgs (interp, 2, objv, "");
            return TCL_ERROR;
        }
        switch (pullInfo->state) {
        case PULLPARSERSTATE_READY:
            SetResult("No input");
            return TCL_ERROR;
        case PULLPARSERSTATE_TEXT:
            SetResult("Invalid state");
            return TCL_ERROR;
        case PULLPARSERSTATE_END_TAG:
        case PULLPARSERSTATE_START_TAG:
        case PULLPARSERSTATE_END_DOCUMENT:
        case PULLPARSERSTATE_PARSE_ERROR:
            if ((enum method) methodIndex == m_line) {
                Tcl_SetObjResult(interp,
                    Tcl_NewWideIntObj (XML_GetCurrentLineNumber(pullInfo->parser)));
            } else {
                Tcl_SetObjResult(interp,
                    Tcl_NewWideIntObj (XML_GetCurrentColumnNumber(pullInfo->parser)));
            }
            break;
        case PULLPARSERSTATE_START_DOCUMENT:
            Tcl_SetObjResult(interp, Tcl_NewIntObj (0));
            break;
        }
        break;
        
    case m_delete:
        if (objc != 2) {
            Tcl_WrongNumArgs (interp, 2, objv, "");
            return TCL_ERROR;
        }
        Tcl_DeleteCommand (interp, Tcl_GetString (objv[0]));
        break;

    case m_reset:
        if (objc != 2) {
            Tcl_WrongNumArgs (interp, 2, objv, "");
            return TCL_ERROR;
        }
        tDOM_CleanupInputSource (pullInfo);
        pullInfo->state = PULLPARSERSTATE_READY;
        pullInfo->nextState = 0;
        pullInfo->mode = PULLPARSEMODE_NORMAL;
        Tcl_DStringSetLength (pullInfo->cdata, 0);
        if (XML_ParserReset (pullInfo->parser, NULL) != XML_TRUE) {
            SetResult ("Parser reset failed!");
            return TCL_ERROR;
        }
        XML_SetElementHandler (pullInfo->parser, startElement, endElement);
        XML_SetCharacterDataHandler (pullInfo->parser, characterDataHandler);
        XML_SetUserData (pullInfo->parser, pullInfo);
        break;
        
    }

    return TCL_OK;
}


int
tDOM_PullParserCmd (
    ClientData  UNUSED(dummy),
    Tcl_Interp *interp,
    int         objc,
    Tcl_Obj    *const objv[]
    )
{
    tDOM_PullParserInfo *pullInfo;
    int flagIndex, ignoreWhiteSpaces = 0;

    static const char *const flags[] = {
        "-ignorewhitecdata", NULL
    };
    
    enum flag {
        f_ignoreWhiteSpaces
    };

    if (objc < 2 || objc > 3) {
        Tcl_WrongNumArgs (interp, 1, objv, "cmdName ?-ignorewhitecdata?");
        return TCL_ERROR;
    }

    if (objc == 3) {
        if (Tcl_GetIndexFromObj (interp, objv[2], flags, "flag", 0,
                                 &flagIndex) != TCL_OK) {
            return TCL_ERROR;
        }
        switch ((enum flag) flagIndex) {
        case f_ignoreWhiteSpaces:
            ignoreWhiteSpaces = 1;
            break;
        }
    }
    
    pullInfo = (tDOM_PullParserInfo *) MALLOC(sizeof(tDOM_PullParserInfo));
    memset (pullInfo, 0, sizeof (tDOM_PullParserInfo));

    pullInfo->parser = XML_ParserCreate_MM(NULL, MEM_SUITE, NULL);
    XML_SetUserData (pullInfo->parser, pullInfo);
    XML_SetElementHandler (pullInfo->parser, startElement, endElement);
    XML_SetCharacterDataHandler (pullInfo->parser, characterDataHandler);
    pullInfo->cdata = (Tcl_DString*) MALLOC (sizeof (Tcl_DString));
    Tcl_DStringInit (pullInfo->cdata);
    pullInfo->state = PULLPARSERSTATE_READY;
    pullInfo->start_tag = Tcl_NewStringObj("START_TAG", 9);
    Tcl_IncrRefCount (pullInfo->start_tag);
    pullInfo->end_tag = Tcl_NewStringObj("END_TAG", 7);
    Tcl_IncrRefCount (pullInfo->end_tag);
    pullInfo->text = Tcl_NewStringObj("TEXT", 4);
    Tcl_IncrRefCount (pullInfo->text);
    pullInfo->ignoreWhiteSpaces = ignoreWhiteSpaces;
    pullInfo->elmCache = (Tcl_HashTable *)MALLOC(sizeof (Tcl_HashTable));
    Tcl_InitHashTable(pullInfo->elmCache, TCL_STRING_KEYS);
    pullInfo->mode = PULLPARSEMODE_NORMAL;
#ifdef EXPAT_RESUME_BUG
    pullInfo->elmStartCounter = 0;
#endif
    
    Tcl_CreateObjCommand (interp, Tcl_GetString(objv[1]),
                          tDOM_PullParserInstanceCmd, (ClientData) pullInfo,
                          tDOM_PullParserDeleteCmd);
    Tcl_SetObjResult(interp, objv[1]);
    return TCL_OK;
}

#endif /* ifndef TDOM_NO_PULL */
