/*----------------------------------------------------------------------------
|   Copyright (c) 2022  Rolf Ade (rolf@pointsman.de)
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
|   2022
|
\---------------------------------------------------------------------------*/

#include <dom.h>
#include <stdint.h>
#include <domjson.h>
#include <schema.h>

#ifndef TDOM_NO_SCHEMA

#define CHECK_TI                                                        \
    if (!sdata) {                                                       \
        SetResult ("Command called outside of schema context");         \
        return TCL_ERROR;                                               \
    }                                                                   \
    if (!sdata->isTextConstraint) {                                     \
        SetResult ("Command called in invalid schema context");         \
        return TCL_ERROR;                                               \
    }

#if !defined(PTR2UINT)
# if defined(HAVE_UINTPTR_T) || defined(uintptr_t)
#  define PTR2UINT(p) ((unsigned int)(uintptr_t)(p))
# else
#  define PTR2UINT(p) ((unsigned int)(p))
# endif
#endif
#if !defined(UINT2PTR)
# if defined(HAVE_UINTPTR_T) || defined(uintptr_t)
#  define UINT2PTR(p) ((void *)(uintptr_t)(p))
# else
#  define UINT2PTR(p) ((void *)(p))
# endif
#endif

#ifndef WHITESPACETC_BUFFER_LEN_INIT
#  define WHITESPACETC_BUFFER_LEN_INIT 200
#endif

#define SetResult(str) Tcl_ResetResult(interp);  \
                     Tcl_SetStringObj(Tcl_GetObjResult(interp), (str), -1)

static int
integerImplXsd (
    Tcl_Interp *UNUSED(interp),
    void *constraintData,
    char *text
    )
{
    char *c = text;
    if (*c == 0) return 0;
    switch ((intptr_t)constraintData) {
    case 0:
        /* integer */
        if (*c == '-' || *c == '+') c++;
        break;
    case 1:
        /* negativeInteger */
        if (*c != '-') return 0;
        c++;
        while (*c == '0') c++;
        break;
    case 2:
        /* nonNegativeInteger */
        if (*c == '+') c++;
        else if (*c == '-') {
            c++;
            if (*c == '0') {
                c++;
                while (*c == '0') c++;
                if (*c == 0) return 1;
            }
            return 0;
        }
        break;
    case 3:
        /* nonPositiveInteger */
        if (*c == '-') c++;
        else {
            if (*c == '+') c++;
            if (*c == 0) return 0;
            while (*c == '0') c++;
            if (*c == 0) return 1;
            return 0;
        }
        break;
    case 4:
        /* positiveInteger */
        if (*c == '+') c++;
        while (*c == '0') c++;
        break;
    }
    if (*c == 0) return 0;
    while (isdigit(*c)) {
        c++;
    }
    if (*c != 0) return 0;
    return 1;
}

static int
integerImplTcl (
    Tcl_Interp *interp,
    void *constraintData,
    char *text
    )
{
    int n;

    if (Tcl_GetInt (interp, text, &n) != TCL_OK) {
        return 0;
    }
    switch ((intptr_t)constraintData) {
    case 0:
        /* integer */
        break;
    case 1:
        /* negativeInteger */
        if (n >= 0) return 0;
        break;
    case 2:
        /* nonNegativeInteger */
        if (n < 0) return 0;
        break;
    case 3:
        /* nonPositiveInteger */
        if (n > 0) return 0;
        break;
    case 4:
        /* positiveInteger */
        if (n <= 0) return 0;
        break;
    }
    
    return 1;
}

static int
integerTCObjCmd (
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[]
    )
{
    SchemaData *sdata = GETASI;
    SchemaConstraint *sc;
    int type;

    static const char *types[] = {
        "xsd", "tcl", NULL
    };
    enum typeSyms {
        t_xsd, t_tcl
    };

    CHECK_TI
    checkNrArgs (1,2,"?xsd|tcl?");
    if (objc == 1) {
        type = t_xsd;
    } else {
        if (Tcl_GetIndexFromObj (interp, objv[1], types, "type", 0, &type)
            != TCL_OK) {
            return TCL_ERROR;
        }
    }
    ADD_CONSTRAINT (sdata, sc)
    switch ((enum typeSyms) type) {
    case t_xsd:
        sc->constraint = integerImplXsd;
        break;
    case t_tcl:
        sc->constraint = integerImplTcl;
        break;
    }
    sc->constraintData = clientData;
    return TCL_OK;
}

typedef struct
{
    int nrArg;
    Tcl_Obj **evalStub;
    SchemaData *sdata;
} tclTCData;

static void
tclImplFree (
    void *constraintData
    )
{
    tclTCData *tcdata = constraintData;
    int i;

    for (i = 0; i < tcdata->nrArg-1; i++) {
        Tcl_DecrRefCount (tcdata->evalStub[i]);
    }
    FREE (tcdata->evalStub);
    FREE (tcdata);
}

static int
tclImpl (
    Tcl_Interp *interp,
    void *constraintData,
    char *text
    )
{
    tclTCData *tcdata = constraintData;
    int result, bool;

    tcdata->evalStub[tcdata->nrArg-1] = Tcl_NewStringObj(text, -1);
    Tcl_IncrRefCount (tcdata->evalStub[tcdata->nrArg-1]);
    tcdata->sdata->currentEvals++;
    result = Tcl_EvalObjv (interp, tcdata->nrArg, tcdata->evalStub,
                           TCL_EVAL_GLOBAL);
    tcdata->sdata->currentEvals--;
    Tcl_DecrRefCount (tcdata->evalStub[tcdata->nrArg-1]);
    if (result != TCL_OK) {
        tcdata->sdata->evalError = 1;
        return 0;
    }
    result = Tcl_GetBooleanFromObj (interp, Tcl_GetObjResult (interp), &bool);
    if (result != TCL_OK) {
        return 0;
    }
    if (bool) {
        return 1;
    } 
    return 0;
}

static int
tclTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[]
    )
{
    SchemaData *sdata = GETASI;
    SchemaConstraint *sc;
    tclTCData *tcdata;
    int i;

    CHECK_TI
    if (objc < 2) {
        SetResult ("Expected: tclcmd ?arg arg ...?");
        return TCL_ERROR;
    }
    ADD_CONSTRAINT (sdata, sc)
    sc->constraint = tclImpl;
    sc->freeData = tclImplFree;
    tcdata = TMALLOC (tclTCData);
    tcdata->nrArg = objc;
    tcdata->evalStub = MALLOC (sizeof (Tcl_Obj*) * objc);
    for (i = 1; i < objc; i++) {
        tcdata->evalStub[i-1] = objv[i];
        Tcl_IncrRefCount (tcdata->evalStub[i-1]);
    }
    tcdata->sdata = sdata;
    sc->constraintData = tcdata;
    return TCL_OK;
}

static void
fixedImplFree (
    void *constraintData
    )
{
    FREE (constraintData);
}

static int
fixedImpl (
    Tcl_Interp *UNUSED(interp),
    void *constraintData,
    char *text
    )
{
    if (strcmp (text, (char *) constraintData) == 0) {
        return 1;
    }
    return 0;
}

static int
fixedTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[]
    )
{
    SchemaData *sdata = GETASI;
    SchemaConstraint *sc;

    CHECK_TI
    checkNrArgs (2,2,"Expected: <fixed value>");
    ADD_CONSTRAINT (sdata, sc)
    sc->constraint = fixedImpl;
    sc->freeData = fixedImplFree;
    sc->constraintData = tdomstrdup (Tcl_GetString (objv[1]));
    return TCL_OK;
}

static void
enumerationImplFree (
    void *constraintData
    )
{
    Tcl_HashTable *values = (Tcl_HashTable *) constraintData;

    Tcl_DeleteHashTable (values);
    FREE (values);
}

static int
enumerationImpl (
    Tcl_Interp *UNUSED(interp),
    void *constraintData,
    char *text
    )
{
    Tcl_HashTable *values = (Tcl_HashTable *) constraintData;

    if (Tcl_FindHashEntry(values, text)) return 1;
    return 0;
}

static int
enumerationTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[]
    )
{
    SchemaData *sdata = GETASI;
    SchemaConstraint *sc;
    Tcl_HashTable *values;
    domLength len, i;
    int hnew;
    Tcl_Obj *value;

    CHECK_TI
    checkNrArgs (2,2,"Expected: <value list>");
    if (Tcl_ListObjLength (interp, objv[1], &len) != TCL_OK) {
        SetResult ("The argument must be a valid tcl list");
        return TCL_ERROR;
    }
    ADD_CONSTRAINT (sdata, sc)
    sc->constraint = enumerationImpl;
    sc->freeData = enumerationImplFree;
    values = TMALLOC (Tcl_HashTable);
    Tcl_InitHashTable (values, TCL_STRING_KEYS);
    for (i = 0; i < len; i++) {
        Tcl_ListObjIndex (interp, objv[1], i, &value);
        Tcl_CreateHashEntry (values, Tcl_GetString (value), &hnew);
    }
    sc->constraintData = values;
    return TCL_OK;
}

static void
matchImplFree (
    void *constraintData
    )
{
    Tcl_DecrRefCount ((Tcl_Obj *) constraintData);
}

static int
matchImpl (
    Tcl_Interp *UNUSED(interp),
    void *constraintData,
    char *text
    )
{
    if (Tcl_StringCaseMatch (text, Tcl_GetString ((Tcl_Obj *) constraintData), 0))
        return 1;
    return 0;
}

static int
matchNocaseImpl (
    Tcl_Interp *UNUSED(interp),
    void *constraintData,
    char *text
    )
{
    if (Tcl_StringCaseMatch (text, Tcl_GetString ((Tcl_Obj *) constraintData),
            TCL_MATCH_NOCASE))
        return 1;
    return 0;
}

static int
matchTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[]
    )
{
    SchemaData *sdata = GETASI;
    SchemaConstraint *sc;

    CHECK_TI
    checkNrArgs (2,3,"Expected: ?-nocase? <match pattern>");
    if (objc == 3) {
        if (strcmp ("-nocase", Tcl_GetString (objv[1])) != 0) {
            SetResult ("Expected: ?-nocase? <match pattern>");
            return TCL_ERROR;
        }
        objv++;
    }
    ADD_CONSTRAINT (sdata, sc)
    if (objc == 2) {
        sc->constraint = matchImpl;
    } else {
        sc->constraint = matchNocaseImpl;
    }
    sc->freeData = matchImplFree;
    Tcl_IncrRefCount (objv[1]);
    sc->constraintData = objv[1];
    return TCL_OK;
}

static void
regexpImplFree (
    void *constraintData
    )
{
    Tcl_DecrRefCount ((Tcl_Obj *) constraintData);
}

static int
regexpImpl (
    Tcl_Interp *interp,
    void *constraintData,
    char *text
    )
{
    Tcl_Obj *textObj;
    int rc;


    textObj = Tcl_NewStringObj(text, -1);
    rc = Tcl_RegExpMatchObj (interp, textObj,  (Tcl_Obj *) constraintData);
    Tcl_DecrRefCount (textObj);
    /* rc may be 1, 0, -1 */
    if (rc == 1) {
        return 1;
    }
    return 0;
}

static int
regexpTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[]
    )
{
    SchemaData *sdata = GETASI;
    SchemaConstraint *sc;

    CHECK_TI
    checkNrArgs (2,2,"Expected: <regexp>");
    /* Compile it as syntax test (plus caches the complied regexp in
     * the internal value) */
    if (!Tcl_GetRegExpFromObj (interp, objv[1], TCL_REG_ADVANCED)) {
        return TCL_ERROR;
    }
    ADD_CONSTRAINT (sdata, sc)
    sc->constraint = regexpImpl;
    sc->freeData = regexpImplFree;
    Tcl_IncrRefCount (objv[1]);
    sc->constraintData = objv[1];
    return TCL_OK;
}

static int
nmtokenImpl (
    Tcl_Interp *interp,
    void *UNUSED(constraintData),
    char *text
    )
{
    char *p;
    int clen, tokenSeen = 0;

    p = text;
    /* Skip leading space */
    while (*p && *p == ' ') {
        p++;
    }
    while (*p && *p != ' ') {
        clen = UTF8_CHAR_LEN (*p);
        if (!clen) {
            SetResult ("Invalid UTF-8 character");
            return 0;
        }
        if (!UTF8_GET_NAMING_NMTOKEN (p, clen)) {
            SetResult ("Attribute value isn't a NMTOKEN");
            return 0;
        }
        tokenSeen = 1;
        p += clen;
    }
    /* Skip following space */
    while (*p && *p == ' ') {
        p++;
    }
    if (*p) {
        SetResult ("Attribute value isn't a NMTOKEN");
        return 0;
    }
    if (!*p && !tokenSeen) {
        SetResult ("Missing NMTOKEN value");
        return 0;
    }
    return 1;
}

static int
nmtokenTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const UNUSED(objv[])
    )
{
    SchemaData *sdata = GETASI;
    SchemaConstraint *sc;

    CHECK_TI
    checkNrArgs (1,1,"No arguments expected");
    ADD_CONSTRAINT (sdata, sc)
    sc->constraint = nmtokenImpl;
    return TCL_OK;
}

static int
nmtokensImpl (
    Tcl_Interp *interp,
    void *UNUSED(constraintData),
    char *text
    )
{
    char *p;
    int clen, tokenSeen = 0;

    p = text;
    /* Skip leading space */
    while (*p && *p == ' ') {
        p++;
    }
    while (*p) {
        if (*p == ' ') {
            p++; continue;
        }
        clen = UTF8_CHAR_LEN (*p);
        if (!clen) {
            SetResult ("Invalid UTF-8 character");
            return 0;
        }
        if (!UTF8_GET_NAMING_NMTOKEN (p, clen)) {
            SetResult ("Invalid character: attribute value isn't a NMTOKENS");
            return 0;
        }
        tokenSeen = 1;
        p += clen;
    }
    /* Any following space is already skipped above */
    if (!tokenSeen) {
        SetResult ("Missing NMTOKENS value");
        return 0;
    }
    return 1;
}

static int
nmtokensTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const UNUSED(objv[])
    )
{
    SchemaData *sdata = GETASI;
    SchemaConstraint *sc;

    CHECK_TI
    checkNrArgs (1,1,"No arguments expected");
    ADD_CONSTRAINT (sdata, sc)
    sc->constraint = nmtokensImpl;
    return TCL_OK;
}

static int
numberImplXsd (
    Tcl_Interp *UNUSED(interp),
    void *UNUSED(constraintData),
    char *text
    )
{
    char *c = text;
    if (!*c) return 0;
    if (*c == '-' || *c == '+') c++;
    while (isdigit(*c)) {
        c++;
    }
    if (*c == '.') c++;
    while (isdigit(*c)) {
        c++;
    }
    if (*c) return 0;
    return 1;
}

static int
numberImplTcl (
    Tcl_Interp *interp,
    void *UNUSED(constraintData),
    char *text
    )
{
    double d;

    if (Tcl_GetDouble (interp, text, &d) != TCL_OK) {
        return 0;
    }
    return 1;
}

static int
numberTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[]
    )
{
    SchemaData *sdata = GETASI;
    SchemaConstraint *sc;
    int type;

    static const char *types[] = {
        "xsd", "tcl", NULL
    };
    enum typeSyms {
        t_xsd, t_tcl
    };

    CHECK_TI
    checkNrArgs (1,2,"?xsd|tcl?");
    if (objc == 1) {
        type = t_xsd;
    } else {
        if (Tcl_GetIndexFromObj (interp, objv[1], types, "type", 0, &type)
            != TCL_OK) {
            return TCL_ERROR;
        }
    }
    ADD_CONSTRAINT (sdata, sc)
    switch ((enum typeSyms) type) {
    case t_xsd:
        sc->constraint = numberImplXsd;
        break;
    case t_tcl:
        sc->constraint = numberImplTcl;
        break;
    }
    return TCL_OK;
}

static int
booleanImplXsd (
    Tcl_Interp *UNUSED(interp),
    void *UNUSED(constraintData),
    char *text
    )
{
    char *c = text;
    switch (*c) {
    case '0':
    case '1':
        c++;
        if (*c == 0) return 1;
        break;
    case 't':
        if (strcmp (text, "true") == 0) return 1;
        break;
    case 'f':
        if (strcmp (text, "false") == 0) return 1;
        break;
    }
    return 0;
}

static int
booleanImplTcl (
    Tcl_Interp *interp,
    void *UNUSED(constraintData),
    char *text
    )
{
    int b;

    if (Tcl_GetBoolean (interp, text, &b) != TCL_OK) {
        return 0;
    }
    return 1;
}

static int
booleanTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[]
    )
{
    SchemaData *sdata = GETASI;
    SchemaConstraint *sc;
    int type;

    static const char *types[] = {
        "xsd", "tcl", NULL
    };
    enum typeSyms {
        t_xsd, t_tcl
    };
    
    CHECK_TI
    checkNrArgs (1,2,"?xsd|tcl?");
    if (objc == 1) {
        type = t_xsd;
    } else {
        if (Tcl_GetIndexFromObj (interp, objv[1], types, "type", 0, &type)
            != TCL_OK) {
            return TCL_ERROR;
        }
    }
    ADD_CONSTRAINT (sdata, sc)
    switch ((enum typeSyms) type) {
    case t_xsd:
        sc->constraint = booleanImplXsd;
        break;
    case t_tcl:
        sc->constraint = booleanImplTcl;
        break;
    }
    return TCL_OK;
}

static int
isodateImpl (
    Tcl_Interp *UNUSED(interp),
    void *constraintData,
    char *text
    )
{
    int i, y, m, d, h, min, s, zh, zm, seenNonzero = 0;

    if (constraintData < (void *)2) {
        if (*text == '-') {
            /* A bce date */
            text++;
        }
        i = 1;
        /* Parse year */
        while (*text >= '0' && *text <= '9') {
            if (*text > '0' && !seenNonzero) seenNonzero = i;
            text++;
            i++;
        }
        /* Premature end */
        if (i < 5) return 0;
        if (i > 5) {
            /* The year has more than 4 digits. Only allowed if in fact
             * needed (no extra leading zeros). */
            if (seenNonzero > 1) return 0;
        }
        if (*text != '-') return 0;
        /* We only need to know the modulo of the year for 4, 100 and 400,
         * for this the 4 last letters are enough */
        y = atoi(text-4);
        /* There isn't a year 0. it's either 0001 or -0001 */
        if (!seenNonzero) return 0;
        text++;
        /* Parse month */
        for (i = 0; i < 2; i++) {
            if (*text < '0' || *text > '9') return 0;
            text++;
        }
        if (*text != '-') return 0;
        m = atoi(text-2);
        if (m < 1 || m > 12) return 0;
        text++;
        /* Parse day */
        for (i = 0; i < 2; i++) {
            if (*text < '0' || *text > '9') return 0;
            text++;
        }
        d = atoi(text-2);
        if (d < 1) return 0;
        switch (m) {
        case 1:
        case 3:
        case 5:
        case 7:
        case 8:
        case 10:
        case 12:
            if (d > 31) return 0;
            break;
        case 4:
        case 6:
        case 9:
        case 11:
            if (d > 30) return 0;
            break;
        case 2:
            if (y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)) {
                if (d > 29) return 0;
            } else {
                if (d > 28) return 0;
            }
            break;
        }
    }
    /* Date part end */
    if (constraintData) {
        if (constraintData == (void *)1) {
            /* Time part starts */
            if (*text != 'T') return 0;
            text++;
        }
        /* Parse hour part */
        if (*text < '0' || *text > '9') return 0;
        h = (*text - 48) * 10;
        text++;
        if (*text < '0' || *text > '9') return 0;
        h += (*text - 48);
        if (h > 24) return 0;
        text++;
        if (*text != ':') return 0;
        text++;
        /* Parse minute part */
        if (*text < '0' || *text > '9') return 0;
        min = (*text - 48) * 10;
        text++;
        if (*text < '0' || *text > '9') return 0;
        min += (*text - 48);
        if (min > 59) return 0;
        text++;
        if (*text != ':') return 0;
        text++;
        /* Parse seconds part */
        if (*text < '0' || *text > '9') return 0;
        s = (*text - 48) * 10;
        text++;
        if (*text < '0' || *text > '9') return 0;
        s += (*text - 48);
        if (s > 59) return 0;
        text++;
        /* Check for optional fraction seconds part */
        if (*text == '.') {
            if (h == 24) return 0;
            text++;
            /* Dangling decimal point is not allowed */
            if (*text < '0' || *text > '9') return 0;
            text++;
            while (*text >= '0' && *text <= '9') text++;
        }
        if (h == 24 && (min > 0 || s > 0)) return 0;
    }
    if (*text == '\0') return 1;
    /* Parse optional timezone part */
    switch (*text) {
    case 'Z':
        text++;
        if (*text != '\0') return 0;
        break;
    case '+':
    case '-':
        text++;
        for (i = 0; i < 2; i++) {
            if (*text < '0' || *text > '9') return 0;
            text++;
        }
        if (*text != ':') return 0;
        zh = atoi(text-2);
        if (zh > 14) return 0;
        text++;
        for (i = 0; i < 2; i++) {
            if (*text < '0' || *text > '9') return 0;
            text++;
        }
        if (*text != '\0') return 0;
        zm = atoi(text-2);
        if (zh < 14) {
            if (zm > 59) return 0;
        } else {
            if (zm != 0) return 0;
        }
        break;
    default:
        return 0;
    }
    return 1;
}

static int
dateTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const UNUSED(objv[])
    )
{
    SchemaData *sdata = GETASI;
    SchemaConstraint *sc;

    CHECK_TI
    checkNrArgs (1,1,"No arguments expected");
    ADD_CONSTRAINT (sdata, sc)
    sc->constraint = isodateImpl;
    sc->constraintData = (void *) 0;
    return TCL_OK;
}

static int
dateTimeTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const UNUSED(objv[])
    )
{
    SchemaData *sdata = GETASI;
    SchemaConstraint *sc;

    CHECK_TI
    checkNrArgs (1,1,"No arguments expected");
    ADD_CONSTRAINT (sdata, sc)
    sc->constraint = isodateImpl;
    sc->constraintData = (void *) 1;
    return TCL_OK;
}

static int
timeTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const UNUSED(objv[])
    )
{
    SchemaData *sdata = GETASI;
    SchemaConstraint *sc;

    CHECK_TI
    checkNrArgs (1,1,"No arguments expected");
    ADD_CONSTRAINT (sdata, sc)
    sc->constraint = isodateImpl;
    sc->constraintData = (void *) 2;
    return TCL_OK;
}

static int
maxLengthImpl (
    Tcl_Interp *interp,
    void *constraintData,
    char *text
    )
{
    unsigned int len = 0, maxlen = PTR2UINT(constraintData);
    int clen;

    while (*text != '\0') {
        clen = UTF8_CHAR_LEN (*text);
        if (!clen) {
            SetResult ("Invalid UTF-8 character");
            return 0;
        }
        len++;
        if (len > maxlen) return 0;
        text += clen;
    }
    return 1;
}

static int
maxLengthTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[]
    )
{
    SchemaData *sdata = GETASI;
    SchemaConstraint *sc;
    int len;

    CHECK_TI
    checkNrArgs (2,2,"Expected: <maximal length as integer>");
    if (Tcl_GetIntFromObj (interp, objv[1], &len) != TCL_OK) {
        SetResult ("Expected: <maximal length as integer>");
        return TCL_ERROR;
    }
    if (len < 1) {
        SetResult ("The maximum length must be at least 1");
    }
    ADD_CONSTRAINT (sdata, sc)
    sc->constraint = maxLengthImpl;
    sc->constraintData = UINT2PTR(len);
    return TCL_OK;
}

static int
minLengthImpl (
    Tcl_Interp *interp,
    void *constraintData,
    char *text
    )
{
    unsigned int len = 0, minlen = PTR2UINT(constraintData);
    int clen;
    while (*text != '\0') {
        clen = UTF8_CHAR_LEN (*text);
        if (!clen) {
            SetResult ("Invalid UTF-8 character");
            return 0;
        }
        len++;
        if (len >= minlen) return 1;
        text += clen;
    }
    return 0;
}

static int
minLengthTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[]
    )
{
    SchemaData *sdata = GETASI;
    SchemaConstraint *sc;
    int len;

    CHECK_TI
    checkNrArgs (2,2,"Expected: <minimum length as integer>");
    if (Tcl_GetIntFromObj (interp, objv[1], &len) != TCL_OK) {
        SetResult ("Expected: <minimum length as integer>");
        return TCL_ERROR;
    }
    if (len < 1) {
        SetResult ("The minimum length must be at least 1");
    }
    ADD_CONSTRAINT (sdata, sc)
    sc->constraint = minLengthImpl;
    sc->constraintData = UINT2PTR(len);
    return TCL_OK;
}

static int
oneOfImpl (
    Tcl_Interp *interp,
    void *constraintData,
    char *text
    )
{
    SchemaCP *cp = (SchemaCP *) constraintData;
    SchemaConstraint *sc;
    unsigned int i;

    /* Look also at checkText */
    for (i = 0; i < cp->nc; i++) {
        sc = (SchemaConstraint *) cp->content[i];
        if ((sc->constraint) (interp, sc->constraintData, text)) {
            return 1;
        }
    }
    return 0;
}

static int
oneOfTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[]
    )
{
    SchemaData *sdata = GETASI;
    SchemaCP *cp;
    SchemaConstraint *sc;
    int rc;

    CHECK_TI
    checkNrArgs (2,2,"Expected: <text constraint script>");
    
    cp = initSchemaCP (SCHEMA_CTYPE_CHOICE, NULL, NULL);
    cp->type = SCHEMA_CTYPE_TEXT;
    REMEMBER_PATTERN (cp)
    rc = evalConstraints (interp, sdata, cp, objv[1]);
    if (rc == TCL_OK) {
        ADD_CONSTRAINT (sdata, sc)
        sc->constraint = oneOfImpl;
        sc->constraintData = (void *)cp;
        return TCL_OK;
    }
    return TCL_ERROR;
}

static int
allOfTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[]
    )
{
    SchemaData *sdata = GETASI;
    SchemaCP *cp;
    SchemaConstraint *sc;
    int rc;

    CHECK_TI
    checkNrArgs (2,2,"Expected: <text constraint script>");
    
    cp = initSchemaCP (SCHEMA_CTYPE_CHOICE, NULL, NULL);
    cp->type = SCHEMA_CTYPE_TEXT;
    REMEMBER_PATTERN (cp)
    rc = evalConstraints (interp, sdata, cp, objv[1]);
    if (rc == TCL_OK) {
        ADD_CONSTRAINT (sdata, sc)
        sc->constraint = tDOM_checkText;
        sc->constraintData = (void *)cp;
        return TCL_OK;
    }
    return TCL_ERROR;
}

static int
stripImpl (
    Tcl_Interp *interp,
    void *constraintData,
    char *text
    )
{
    SchemaCP *cp = (SchemaCP *) constraintData;
    int rc, restore = 0;
    char *end, saved;

    while(SPACE((unsigned char)*text)) text++;
    if(*text != 0) {
        /* Not white space only */
        /* Trim trailing space */
        end = text + strlen(text) - 1;
        while(end > text && SPACE((unsigned char)*end)) end--;
        saved = end[1];
        restore = 1;
        end[1] = '\0';
    }
    rc = checkText (interp, cp, text);
    if (restore) end[1] = saved;
    return rc;
}

static int
stripTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[]
    )
{
    SchemaData *sdata = GETASI;
    SchemaCP *cp;
    SchemaConstraint *sc;
    int rc;

    CHECK_TI
    checkNrArgs (2,2,"Expected: <text constraint script>");
    
    cp = initSchemaCP (SCHEMA_CTYPE_CHOICE, NULL, NULL);
    cp->type = SCHEMA_CTYPE_TEXT;
    REMEMBER_PATTERN (cp)
    rc = evalConstraints (interp, sdata, cp, objv[1]);
    if (rc == TCL_OK) {
        ADD_CONSTRAINT (sdata, sc)
        sc->constraint = stripImpl;
        sc->constraintData = (void *)cp;
        return TCL_OK;
    }
    return TCL_ERROR;
}

static int
splitWhitespaceImpl (
    Tcl_Interp *interp,
    void *constraintData,
    char *text
    )
{
    SchemaCP *cp = (SchemaCP *) constraintData;
    int rc = 0;
    char *p, *end, saved = 0;
    
    p = text;
    while (*p != 0) {
        while(SPACE (*p)) p++;
        if (*p == 0) break;
        end = p; end++;
        while (*end != 0 && !SPACE(*end)) end++;
        saved = *end;
        *end = 0;
        rc = checkText (interp, cp, p);
        *end = saved;
        p = end;
        if (!rc) break;
    }
    return rc;
}

typedef struct
{
    int         nrArg;
    Tcl_Obj   **evalStub;
    SchemaData *sdata;
    SchemaCP   *cp;
} splitTclTCData;


static int
splitTclImpl (
    Tcl_Interp *interp,
    void *constraintData,
    char *text
    )
{
    splitTclTCData *tcdata = (splitTclTCData *) constraintData;
    domLength listlen, i;
    int rc;
    Tcl_Obj *list, *listelm;

    tcdata->evalStub[tcdata->nrArg-1] = Tcl_NewStringObj(text, -1);
    Tcl_IncrRefCount (tcdata->evalStub[tcdata->nrArg-1]);
    tcdata->sdata->currentEvals++;
    rc = Tcl_EvalObjv (interp, tcdata->nrArg, tcdata->evalStub,
                       TCL_EVAL_GLOBAL);
    tcdata->sdata->currentEvals--;
    Tcl_DecrRefCount (tcdata->evalStub[tcdata->nrArg-1]);
    if (rc != TCL_OK) {
        tcdata->sdata->evalError = 1;
        return 0;
    }
    list = Tcl_GetObjResult (interp);
    Tcl_IncrRefCount (list);
    Tcl_ResetResult (interp);
    if (Tcl_ListObjLength (interp, list, &listlen) != TCL_OK) {
        Tcl_DecrRefCount (list);
        tcdata->sdata->evalError = 1;
        return 0;
    }
    rc = 0;
    for (i = 0; i < listlen; i++) {
        Tcl_ListObjIndex (interp, list, i, &listelm);
        rc = checkText (interp, tcdata->cp, Tcl_GetString (listelm));
        if (!rc) break;
    }
    Tcl_DecrRefCount (list);
    return rc;
}

static void
splitTclImplFree (
    void *constraintData
    )
{
    splitTclTCData *tcdata = constraintData;
    int i;

    for (i = 0; i < tcdata->nrArg-1; i++) {
        Tcl_DecrRefCount (tcdata->evalStub[i]);
    }
    FREE (tcdata->evalStub);
    FREE (tcdata);
}

static int
splitTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[]
    )
{
    SchemaData *sdata = GETASI;
    SchemaCP *cp;
    SchemaConstraint *sc;
    int methodIndex, rc, i;
    splitTclTCData *tcdata;
    
    static const char *methods[] = {
        "whitespace", "tcl", NULL
    };
    enum method {
        m_whitespace, m_tcl
    };

    CHECK_TI
    if (objc < 2) {
        SetResult("Expected: ?type ?args?? <text constraint script>");
        return TCL_ERROR;
    }
    
    if (objc == 2) {
        methodIndex = m_whitespace;
    } else {
        if (Tcl_GetIndexFromObj (interp, objv[1], methods, "type", 0,
                                 &methodIndex) != TCL_OK) {
            return TCL_ERROR;
        }
    }
    switch ((enum method) methodIndex) {
    case m_whitespace:
        if (objc > 2) {
            SetResult ("Type whitespace expects no argument.");
            return TCL_ERROR;
        }
        break;
    case m_tcl:
        if (objc < 3) {
            SetResult ("Expected: tclcmd ?arg ...?.");
            return TCL_ERROR;
        }
    }
    
    cp = initSchemaCP (SCHEMA_CTYPE_CHOICE, NULL, NULL);
    cp->type = SCHEMA_CTYPE_TEXT;
    REMEMBER_PATTERN (cp)
    rc = evalConstraints (interp, sdata, cp, objv[objc-1]);
    if (rc != TCL_OK) {
        return TCL_ERROR;
    }
    ADD_CONSTRAINT (sdata, sc)
    switch ((enum method) methodIndex) {
    case m_whitespace:
        sc->constraint = splitWhitespaceImpl;
        sc->constraintData = cp;
        break;
    case m_tcl:
        sc->constraint = splitTclImpl;
        sc->freeData = splitTclImplFree;
        tcdata = TMALLOC (splitTclTCData);
        tcdata->nrArg = objc - 2;
        tcdata->evalStub = MALLOC (sizeof (Tcl_Obj*) * (objc-2));
        for (i = 2; i < objc -1; i++) {
            tcdata->evalStub[i-2] = objv[i];
            Tcl_IncrRefCount (tcdata->evalStub[i-2]);
        }
        tcdata->sdata = sdata;
        tcdata->cp = cp;
        sc->constraintData = tcdata;
    }
    return TCL_OK;
}

static int
idImpl (
    Tcl_Interp *UNUSED(interp),
    void *constraintData,
    char *text
    )
{
    SchemaData *sdata = (SchemaData *) constraintData;
    int hnew;
    Tcl_HashEntry *h;

    h = Tcl_CreateHashEntry (&sdata->ids, text, &hnew);
    if (hnew) {
        Tcl_SetHashValue (h, 1);
        return 1;
    }
    if (Tcl_GetHashValue (h) == 0) {
        Tcl_SetHashValue (h, 1);
        sdata->unknownIDrefs--;
        return 1;
    } else {
        /* Duplicate ID value */
        return 0;
    }
}

static int
docidImpl (
    Tcl_Interp *UNUSED(interp),
    void *constraintData,
    char *text
    )
{
    SchemaDocKey *dk = (SchemaDocKey *) constraintData;
    int hnew;
    Tcl_HashEntry *h;

    h = Tcl_CreateHashEntry (&dk->ids, text, &hnew);
    if (hnew) {
        Tcl_SetHashValue (h, 1);
        return 1;
    }
    if (Tcl_GetHashValue (h) == 0) {
        Tcl_SetHashValue (h, 1);
        dk->unknownIDrefs--;
        return 1;
    } 
    /* Duplicate ID value */
    return 0;
}

static int
idTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[]
    )
{
    SchemaData *sdata = GETASI;
    SchemaConstraint *sc;
    Tcl_HashEntry *h;
    int hnew;
    SchemaDocKey *dk;

    CHECK_TI
    checkNrArgs (1,2,"?key_space?");
    ADD_CONSTRAINT (sdata, sc)
    if (objc == 1) {
        sc->constraint = idImpl;
        sc->constraintData = (void *)sdata;
    } else {
        h = Tcl_CreateHashEntry (&sdata->idTables, Tcl_GetString (objv[1]),
                                 &hnew);
        if (hnew) {
            dk = TMALLOC (SchemaDocKey);
            Tcl_InitHashTable (&dk->ids, TCL_STRING_KEYS);
            dk->unknownIDrefs = 0;
            Tcl_SetHashValue (h, dk);
        } else {
            dk = Tcl_GetHashValue (h);
        }
        sc->constraint = docidImpl;
        sc->constraintData = (void *)dk;
    }
    return TCL_OK;
}

static int
idrefImpl (
    Tcl_Interp *UNUSED(interp),
    void *constraintData,
    char *text
    )
{
    SchemaData *sdata = (SchemaData *) constraintData;
    int hnew;
    Tcl_HashEntry *h;

    h = Tcl_CreateHashEntry (&sdata->ids, text, &hnew);
    if (hnew) {
        Tcl_SetHashValue (h, 0);
        sdata->unknownIDrefs++;
    }
    return 1;
}

static int
docidrefImpl (
    Tcl_Interp *UNUSED(interp),
    void *constraintData,
    char *text
    )
{
    SchemaDocKey *dk = (SchemaDocKey *) constraintData;
    int hnew;
    Tcl_HashEntry *h;

    h = Tcl_CreateHashEntry (&dk->ids, text, &hnew);
    if (hnew) {
        Tcl_SetHashValue (h, 0);
        dk->unknownIDrefs++;
    }
    return 1;
}

static int
idrefTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[]
    )
{
    SchemaData *sdata = GETASI;
    SchemaConstraint *sc;
    Tcl_HashEntry *h;
    int hnew;
    SchemaDocKey *dk;

    CHECK_TI
    checkNrArgs (1,2,"?key_space?");
    ADD_CONSTRAINT (sdata, sc)
    if (objc == 1) {
        sc->constraint = idrefImpl;
        sc->constraintData = (void *)sdata;
    } else {
        h = Tcl_CreateHashEntry (&sdata->idTables, Tcl_GetString (objv[1]),
                                 &hnew);
        if (hnew) {
            dk = TMALLOC (SchemaDocKey);
            Tcl_InitHashTable (&dk->ids, TCL_STRING_KEYS);
            dk->unknownIDrefs = 0;
            Tcl_SetHashValue (h, dk);
        } else {
            dk = Tcl_GetHashValue (h);
        }
        sc->constraint = docidrefImpl;
        sc->constraintData = (void *)dk;
    }
    return TCL_OK;
}

static int
keyImpl (
    Tcl_Interp *UNUSED(interp),
    void *constraintData,
    char *text
    )
{
    SchemaKeySpace *ks = (SchemaKeySpace *) constraintData;
    int hnew;
    Tcl_HashEntry *h;

    if (!ks->active) return 1;
    h = Tcl_CreateHashEntry (&ks->ids, text, &hnew);
    if (hnew) {
        Tcl_SetHashValue (h, 1);
        return 1;
    }
    if (Tcl_GetHashValue (h) == 0) {
        Tcl_SetHashValue (h, 1);
        ks->unknownIDrefs--;
        return 1;
    } else {
        /* Duplicate ID value */
        return 0;
    }
}

static int
keyTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[]
    )
{
    SchemaData *sdata = GETASI;
    SchemaConstraint *sc;
    Tcl_HashEntry *h;
    int hnew;
    SchemaKeySpace *ks;

    CHECK_TI
    checkNrArgs (2,2,"key_space");
    ADD_CONSTRAINT (sdata, sc)
    h = Tcl_CreateHashEntry (&sdata->keySpaces, Tcl_GetString (objv[1]), &hnew);
    if (hnew) {
        ks = TMALLOC (SchemaKeySpace);
        ks->active = 0;
        ks->unknownIDrefs = 0;
        Tcl_SetHashValue (h, ks);
    } else {
        ks = Tcl_GetHashValue (h);
    }
    sc->constraint = keyImpl;
    sc->constraintData = (void *) ks;
    return TCL_OK;
}

static int
keyrefImpl (
    Tcl_Interp *UNUSED(interp),
    void *constraintData,
    char *text
    )
{
    SchemaKeySpace *ks = (SchemaKeySpace *) constraintData;
    int hnew;
    Tcl_HashEntry *h;

    if (!ks->active) return 1;
    h = Tcl_CreateHashEntry (&ks->ids, text, &hnew);
    if (hnew) {
        Tcl_SetHashValue (h, 0);
        ks->unknownIDrefs++;
    }
    return 1;
}

static int
keyrefTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[]
    )
{
    SchemaData *sdata = GETASI;
    SchemaConstraint *sc;
    Tcl_HashEntry *h;
    int hnew;
    SchemaKeySpace *ks;

    CHECK_TI
    checkNrArgs (2,2,"key_space");
    ADD_CONSTRAINT (sdata, sc)
    h = Tcl_CreateHashEntry (&sdata->keySpaces, Tcl_GetString (objv[1]),
                             &hnew);
    if (hnew) {
        ks = TMALLOC (SchemaKeySpace);
        Tcl_InitHashTable (&ks->ids, TCL_STRING_KEYS);
        ks->unknownIDrefs = 0;
        Tcl_SetHashValue (h, ks);
    } else {
        ks = Tcl_GetHashValue (h);
    }
    sc->constraint = keyrefImpl;
    sc->constraintData = (void *)ks;
    return TCL_OK;
}

static int
base64Impl (
    Tcl_Interp *UNUSED(interp),
    void *UNUSED(constraintData),
    char *text
    )
{
    int chars = 0, equals = 0;
    
    while (*text != '\0') {
        if (SPACE(*text)) {
            text++;
            continue;
        }
        if (   (*text >= 'A' && *text <= 'Z')
            || (*text >= 'a' && *text <= 'z')
            || (*text >= '0' && *text <= '9')
            || (*text = '+')
            || (*text = '/')) {
            chars++;
            text++;
            continue;
        }
        if (equals < 2 && *text == '=') {
            equals++;
            text++;
            continue;
        }
        break;
    }
    if (*text) {
        return 0;
    }
    if ((chars + equals) % 4 != 0) {
        return 0;
    }
    return 1;
}

static int
base64TCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const UNUSED(objv[])
    )
{
    SchemaData *sdata = GETASI;
    SchemaConstraint *sc;

    CHECK_TI
    checkNrArgs (1,1,"No arguments expected");
    ADD_CONSTRAINT (sdata, sc)
    sc->constraint = base64Impl;
    return TCL_OK;
}

static int
nameImpl (
    Tcl_Interp *UNUSED(interp),
    void *UNUSED(constraintData),
    char *text
    )
{
    return domIsNAME (text);
}

static int
nameTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const UNUSED(objv[])
    )
{
    SchemaData *sdata = GETASI;
    SchemaConstraint *sc;

    CHECK_TI
    checkNrArgs (1,1,"No arguments expected");
    ADD_CONSTRAINT (sdata, sc)
    sc->constraint = nameImpl;
    return TCL_OK;
}

static int
ncnameImpl (
    Tcl_Interp *UNUSED(interp),
    void *UNUSED(constraintData),
    char *text
    )
{
    return domIsNCNAME (text);
}

static int
ncnameTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const UNUSED(objv[])
    )
{
    SchemaData *sdata = GETASI;
    SchemaConstraint *sc;

    CHECK_TI
    checkNrArgs (1,1,"No arguments expected");
    ADD_CONSTRAINT (sdata, sc)
    sc->constraint = ncnameImpl;
    return TCL_OK;
}

static int
qnameImpl (
    Tcl_Interp *UNUSED(interp),
    void *UNUSED(constraintData),
    char *text
    )
{
    return domIsQNAME (text);
}

static int
qnameTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const UNUSED(objv[])
    )
{
    SchemaData *sdata = GETASI;
    SchemaConstraint *sc;

    CHECK_TI
    checkNrArgs (1,1,"No arguments expected");
    ADD_CONSTRAINT (sdata, sc)
    sc->constraint = qnameImpl;
    return TCL_OK;
}

static int
hexBinaryImpl (
    Tcl_Interp *UNUSED(interp),
    void *UNUSED(constraintData),
    char *text
    )
{
    int count = 0;

    if (*text == 0) return 0;
    while (*text) {
        if ((*text >= '0' && *text <= '9')
            || (*text >= 'A' && *text <= 'F')
            || (*text >= 'a' && *text <= 'f')) {
            text++;
            count++;
        } else return 0;
    }
    if (count % 2 == 0) return 1;
    return 0;
}

static int
hexBinaryTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const UNUSED(objv[])
    )
{
    SchemaData *sdata = GETASI;
    SchemaConstraint *sc;

    CHECK_TI
    checkNrArgs (1,1,"No arguments expected");
    ADD_CONSTRAINT (sdata, sc)
    sc->constraint = hexBinaryImpl;
    return TCL_OK;
}

static int
unsignedIntTypesImpl (
    Tcl_Interp *UNUSED(interp),
    void *constraintData,
    char *text
    )
{
    char *c;
    int count = 0;
    int nrDigits[] = {3, 5, 10, 20};
    const char *max[] = {
        "255",
        "65535",
        "4294967295",
        "18446744073709551615"
    };
    
    if (*text == '+') text++;
    if (*text == 0) return 0;
    if (*text == '0') {
        text++;
        while (*text == '0') text++;
        if (*text == 0) return 1;
    }
    c = text;
    while (*text) {
        if (*text >= '0' && *text <= '9') {
            text++;
            count++;
        } else return 0;
    }
    if (count < nrDigits[(intptr_t) constraintData]) return 1;
    if (count == nrDigits[(intptr_t) constraintData]) {
        if (strcmp (max[(intptr_t) constraintData], c) >= 0) {
            return 1;
        }
    }
    return 0;
}

static int
unsignedIntTypesTCObjCmd (
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const UNUSED(objv[])
    )
{
    SchemaData *sdata = GETASI;
    SchemaConstraint *sc;

    CHECK_TI
    checkNrArgs (1,1,"No arguments expected");
    ADD_CONSTRAINT (sdata, sc)
    sc->constraint = unsignedIntTypesImpl;
    sc->constraintData = clientData;
    return TCL_OK;
}

static int
intTypesImpl (
    Tcl_Interp *UNUSED(interp),
    void *constraintData,
    char *text
    )
{
    char *c;
    int count = 0;
    int nrDigits[] = {3, 5, 10, 20};
    const char *compare;
    const char *max[] = {
        "127",
        "32767",
        "2147483647",
        "9223372036854775807"
    };
    const char *min[] = {
        "128",
        "32768",
        "2147483648",
        "9223372036854775808"
    };

    if (*text == '-') {
        compare = min[(intptr_t) constraintData];
    } else {
        compare = max[(intptr_t) constraintData];
    }
    if (*text == '+' || *text == '-') text++;
    if (*text == 0) return 0;
    if (*text == '0') {
        text++;
        while (*text == '0') text++;
        if (*text == 0) return 1;
    }
    c = text;
    while (*text) {
        if (*text >= '0' && *text <= '9') {
            text++;
            count++;
        } else return 0;
    }
    if (count < nrDigits[(intptr_t) constraintData]) return 1;
    if (count == nrDigits[(intptr_t) constraintData]) {
        if (strcmp (compare, c) >= 0) return 1;
    }
    return 0;
}

static int
intTypesTCObjCmd (
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const UNUSED(objv[])
    )
{
    SchemaData *sdata = GETASI;
    SchemaConstraint *sc;

    CHECK_TI
    checkNrArgs (1,1,"No arguments expected");
    ADD_CONSTRAINT (sdata, sc)
    sc->constraint = intTypesImpl;
    sc->constraintData = clientData;
    return TCL_OK;
}

static void
setvarImplFree (
    void *constraintData
    )
{
    FREE (constraintData);
}

static int
setvarImpl (
    Tcl_Interp *interp,
    void *constraintData,
    char *text
    )
{
    char *varName = (char *)constraintData;

    if (!Tcl_SetVar (interp, varName, text, TCL_LEAVE_ERR_MSG)) {
        return 0;
    }
    return 1;
}

static int
setvarTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[]
    )
{
    SchemaData *sdata = GETASI;
    SchemaConstraint *sc;

    CHECK_TI
    checkNrArgs (2,2,"<tcl variable name>");
    ADD_CONSTRAINT (sdata, sc)
    sc->constraint = setvarImpl;
    sc->freeData = setvarImplFree;
    sc->constraintData = tdomstrdup (Tcl_GetString (objv[1]));
    return TCL_OK;
}

typedef struct
{
    SchemaCP *cp;
    SchemaData *sdata;
} WhitespaceTCData;

static void
whitespaceImplFree (
    void *constraintData
    )
{
    WhitespaceTCData *wsdata = (WhitespaceTCData *) constraintData;

    FREE (wsdata);
}

static int
whitespaceImplReplace (
    Tcl_Interp *interp,
    void *constraintData,
    char *text
    )
{
    WhitespaceTCData *wsdata = (WhitespaceTCData *) constraintData;
    char *p, *c, *alloced;
    SchemaData *sdata;

    sdata = wsdata->sdata;
    p = text;
    c = sdata->wsbuf;
    alloced = sdata->wsbuf + sdata->wsbufLen;
    while (*p) {
        if (*p == '\t' || *p == '\n' || *p == '\r') {
            *c = ' ';
        } else {
            *c = *p;
        }
        c++;
        if (c == alloced) {
            sdata->wsbuf = REALLOC (sdata->wsbuf, 2 * sdata->wsbufLen);
            c = sdata->wsbuf + sdata->wsbufLen;
            sdata->wsbufLen *= 2;
            alloced = sdata->wsbuf + sdata->wsbufLen;
        }
        p++;
    }
    *c = '\0';
    return checkText (interp, wsdata->cp, sdata->wsbuf);
}

static int
whitespaceImplCollapse (
    Tcl_Interp *interp,
    void *constraintData,
    char *text
    )
{
    WhitespaceTCData *wsdata = (WhitespaceTCData *) constraintData;
    char *p, *c, *alloced;
    SchemaData *sdata;

    sdata = wsdata->sdata;
    p = text;
    c = sdata->wsbuf;
    alloced = sdata->wsbuf + sdata->wsbufLen;
    while (SPACE(*p)) p++;
    while (*p) {
        if (SPACE (*p)) {
            *c = ' ';
            c++;
            if (c == alloced) {
                sdata->wsbuf = REALLOC (sdata->wsbuf, 2 * sdata->wsbufLen);
                c = sdata->wsbuf + sdata->wsbufLen;
                sdata->wsbufLen *= 2;
                alloced = sdata->wsbuf + sdata->wsbufLen;
            }
            p++;
            while (SPACE (*p)) p++;
            if (!*p) c--;
        } else {
            *c = *p;
            c++;
            if (c == alloced) {
                sdata->wsbuf = REALLOC (sdata->wsbuf, 2 * sdata->wsbufLen);
                c = sdata->wsbuf + sdata->wsbufLen;
                sdata->wsbufLen *= 2;
                alloced = sdata->wsbuf + sdata->wsbufLen;
            }
            p++;
        }
    }
    *c = '\0';
    return checkText (interp, wsdata->cp, wsdata->sdata->wsbuf);
}

static int
whitespaceTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[]
    )
{
    SchemaData *sdata = GETASI;
    SchemaCP *cp;
    SchemaConstraint *sc;
    int type;
    WhitespaceTCData *wsdata;

    static const char *types[] = {
        "preserve", "replace", "collapse", NULL
    };
    enum typeSyms {
        t_preserve, t_replace, t_collapse
    };
        
    CHECK_TI
    checkNrArgs (3,3,"(\"preserve\"|\"replace\"|\"collapse\") "
                 "<text constraint script>");
    if (Tcl_GetIndexFromObj (interp, objv[1], types, "type", 0, &type)
        != TCL_OK) {
        return TCL_ERROR;
    }
    cp = initSchemaCP (SCHEMA_CTYPE_CHOICE, NULL, NULL);
    cp->type = SCHEMA_CTYPE_TEXT;
    REMEMBER_PATTERN (cp)
    if (evalConstraints (interp, sdata, cp, objv[2]) != TCL_OK) {
        return TCL_ERROR;
    }
    if (type == t_preserve) {
        ADD_CONSTRAINT (sdata, sc)
        sc->constraint = tDOM_checkText;
        sc->constraintData = (void *)cp;
        return TCL_OK;
    }
    ADD_CONSTRAINT (sdata, sc)
    sc->freeData = whitespaceImplFree;
    if (sdata->wsbufLen == 0) {
        sdata->wsbuf = (char *) MALLOC (WHITESPACETC_BUFFER_LEN_INIT);
        sdata->wsbufLen = WHITESPACETC_BUFFER_LEN_INIT;
    }
    wsdata = TMALLOC (WhitespaceTCData);
    wsdata->sdata = sdata;
    wsdata->cp = cp;
    sc->constraintData = (void *)wsdata;
    if (type == t_replace) {
        sc->constraint = whitespaceImplReplace;
    } else {
        sc->constraint = whitespaceImplCollapse;
    }
    return TCL_OK;
}

static int
notImpl (
    Tcl_Interp *interp,
    void *constraintData,
    char *text
    )
{
    SchemaCP *cp = (SchemaCP *) constraintData;
    SchemaConstraint *sc;
    unsigned int i;

    /* Look also at checkText and oneOfImpl */
    for (i = 0; i < cp->nc; i++) {
        sc = (SchemaConstraint *) cp->content[i];
        if ((sc->constraint) (interp, sc->constraintData, text)) {
            return 0;
        }
    }
    return 1;
}

static int
notTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[]
    )
{
    SchemaData *sdata = GETASI;
    SchemaCP *cp;
    SchemaConstraint *sc;
    int rc;

    CHECK_TI
    checkNrArgs (2,2,"Expected: <text constraint script>");
    
    cp = initSchemaCP (SCHEMA_CTYPE_CHOICE, NULL, NULL);
    cp->type = SCHEMA_CTYPE_TEXT;
    REMEMBER_PATTERN (cp)
    rc = evalConstraints (interp, sdata, cp, objv[1]);
    if (rc == TCL_OK) {
        ADD_CONSTRAINT (sdata, sc)
        sc->constraint = notImpl;
        sc->constraintData = (void *)cp;
        return TCL_OK;
    }
    return TCL_ERROR;
}

static int
durationImpl (
    Tcl_Interp *UNUSED(interp),
    void *UNUSED(constraintData),
    char *text
    )
{
    /* PnYnMnDTnHnMnS */
    int p, n, seen = 0, seenT = 0;
    char des[9] = " YMDTHMS";
    
    if (*text == '-') {
        /* Negative duration is allowed */
        text++;
    }
    if (*text != 'P') return 0;
    text++;
    p = 0;
    while (*text) {
        n = 0;
        while (*text >= '0' && *text <= '9') {
            n++;
            text++;
        }
        if (!*text) return 0;
        if (*text == '.') {
            if (p < 4 || !n) return 0;
            text++;
            if (!*text) return 0;
            /* Ensure at least one digit after . */
            if (*text < '0' || *text > '9') return 0;
            text++;
            while (*text >= '0' && *text <= '9') text++;
            if (*text != 'S') return 0;
            text++;
            if (*text) return 0;
            return 1;
        }
        for (; p < 8; p++) {
            if (*text == des[p]) break;
        }
        if (p ==  4) {
            if (n) return 0;
            seenT = 1;
            text++;
            if (!*text) return 0;
            continue;
        } else {
            if (!n) return 0;
            seen = 1;
        }
        if (p > 4 && !seenT) return 0;
        if (p == 8 || !seen) return 0;
        text++;
    }
    if (!p) return 0;
    return 1;
}

static int
durationTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const UNUSED(objv[])
    )
{
    SchemaData *sdata = GETASI;
    SchemaConstraint *sc;

    CHECK_TI
    checkNrArgs (1,1,"No arguments expected");
    ADD_CONSTRAINT (sdata, sc)
    sc->constraint = durationImpl;
    return TCL_OK;
}

static int
lengthImpl (
    Tcl_Interp *interp,
    void *constraintData,
    char *text
    )
{
    unsigned int len = 0, length = PTR2UINT(constraintData);
    int clen;
    while (*text != '\0') {
        clen = UTF8_CHAR_LEN (*text);
        if (!clen) {
            SetResult ("Invalid UTF-8 character");
            return 0;
        }
        len++;
        if (len > length) return 0;
        text += clen;
    }
    if (len == length) return 1;
    return 0;
}

static int
lengthTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[]
    )
{
    SchemaData *sdata = GETASI;
    SchemaConstraint *sc;
    int len;

    CHECK_TI
    checkNrArgs (2,2,"Expected: <length as integer>");
    if (Tcl_GetIntFromObj (interp, objv[1], &len) != TCL_OK) {
        SetResult ("Expected: <length as integer>");
        return TCL_ERROR;
    }
    if (len < 0) {
        SetResult ("The length must be at least 0");
    }
    ADD_CONSTRAINT (sdata, sc)
    sc->constraint = lengthImpl;
    sc->constraintData = UINT2PTR(len);
    return TCL_OK;
}

static int
typeImpl (
    Tcl_Interp *interp,
    void *constraintData,
    char *text
    )
{
    return checkText (interp, constraintData, text);
}

static int
typeTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[]
    )
{
    SchemaData *sdata = GETASI;
    SchemaConstraint *sc;
    Tcl_HashEntry *h;
    int hnew;
    SchemaCP *pattern = NULL;

    CHECK_TI
    checkNrArgs (2,2,"Expected: <text type name>");
    h = Tcl_CreateHashEntry (&sdata->textDef, Tcl_GetString (objv[1]), &hnew);
    if (hnew) {
        pattern = initSchemaCP (SCHEMA_CTYPE_CHOICE, NULL, NULL);
        pattern->type = SCHEMA_CTYPE_TEXT;
        REMEMBER_PATTERN (pattern)
        pattern->flags |= FORWARD_PATTERN_DEF;
        sdata->forwardPatternDefs++;
        Tcl_SetHashValue (h, pattern);
    }
    ADD_CONSTRAINT (sdata, sc)
    sc->constraint = typeImpl;
    sc->constraintData = Tcl_GetHashValue (h);
    return TCL_OK;
}

static const char *jsonTextTypes[] = {
    "NULL",
    "TRUE",
    "FALSE",
    "STRING",
    "NUMBER",
    NULL
};

enum jsonTextType {
    jt_null, jt_true, jt_false, jt_string, jt_number
};

typedef struct {
    enum jsonTextType type;
    SchemaData *sdata;
} jsontypeTCData;

static void
jsontypeImplFree (
    void *constraintData
    )
{
    jsontypeTCData *cd = (jsontypeTCData *) constraintData;

    FREE (cd);
}

static int
jsontypeImpl (
    Tcl_Interp *UNUSED(interp),
    void *constraintData,
    char *UNUSED(text)
    )
{
    jsontypeTCData *cd = (jsontypeTCData *) constraintData;
    domTextNode *textNode = cd->sdata->textNode;

    if (!textNode) {
        return 1;
    }
    switch (cd->type) {
    case jt_null:
        return textNode->info == JSON_NULL ? 1 : 0;
    case jt_true:
        return textNode->info == JSON_TRUE ? 1 : 0;
    case jt_false:
        return textNode->info == JSON_FALSE ? 1 : 0;
    case jt_string:
        return textNode->info == JSON_STRING ? 1 : 0;
    case jt_number:
        return textNode->info == JSON_NUMBER ? 1 : 0;
    }
    return 0;
}

static int
jsontypeTCObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[]
    )
{
    SchemaData *sdata = GETASI;
    SchemaConstraint *sc;
    int jsonType;
    jsontypeTCData *cd;
    
    CHECK_TI
    checkNrArgs (2,2,"Expected: <JSON type>");
    if (Tcl_GetIndexFromObj (interp, objv[1], jsonTextTypes, "jsonType",
                             1, &jsonType) != TCL_OK) {
        return TCL_ERROR;
    }
    cd = TMALLOC (jsontypeTCData);
    cd->sdata = sdata;
    cd->type = jsonType;
    ADD_CONSTRAINT (sdata, sc)
    sc->constraint = jsontypeImpl;
    sc->constraintData = cd;
    sc->freeData = jsontypeImplFree;
    return TCL_OK;
}

static int
dateObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[]
    )
{
    checkNrArgs (2,2,"<text>");
    Tcl_SetObjResult (interp,
                      Tcl_NewBooleanObj (
                          isodateImpl (interp, NULL,
                                       Tcl_GetString (objv[1]))));
    return TCL_OK;
}

static int
dateTimeObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[]
    )
{
    checkNrArgs (2,2,"<text>");
    Tcl_SetObjResult (interp,
                      Tcl_NewBooleanObj (
                          isodateImpl (interp, (void *) 1,
                                       Tcl_GetString (objv[1]))));
    return TCL_OK;
}

static int
timeObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[]
    )
{
    checkNrArgs (2,2,"<text>");
    Tcl_SetObjResult (interp,
                      Tcl_NewBooleanObj (
                          isodateImpl (interp, (void *) 2,
                                       Tcl_GetString (objv[1]))));
    return TCL_OK;
}

static int
durationObjCmd (
    ClientData UNUSED(clientData),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[]
    )
{
    checkNrArgs (2,2,"<text>");
    Tcl_SetObjResult (interp,
                      Tcl_NewBooleanObj (
                          durationImpl (interp, NULL,
                                        Tcl_GetString (objv[1]))));
    return TCL_OK;
}

void
tDOM_DatatypesInit (
    Tcl_Interp *interp
    )
{

    /* The text constraint commands */
    Tcl_CreateObjCommand (interp,"tdom::schema::text::integer",
                          integerTCObjCmd, (ClientData) 0, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::negativeInteger",
                          integerTCObjCmd, (ClientData) 1, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::nonNegativeInteger",
                          integerTCObjCmd, (ClientData) 2, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::nonPositiveInteger",
                          integerTCObjCmd, (ClientData) 3, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::positiveInteger",
                          integerTCObjCmd, (ClientData) 4, NULL);
    Tcl_CreateObjCommand (interp, "tdom::schema::text::tcl",
                          tclTCObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp, "tdom::schema::text::fixed",
                          fixedTCObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp, "tdom::schema::text::enumeration",
                          enumerationTCObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp, "tdom::schema::text::match",
                          matchTCObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp, "tdom::schema::text::regexp",
                          regexpTCObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp, "tdom::schema::text::nmtoken",
                          nmtokenTCObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp, "tdom::schema::text::nmtokens",
                          nmtokensTCObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::number",
                          numberTCObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::boolean",
                          booleanTCObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::date",
                          dateTCObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::dateTime",
                          dateTimeTCObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::time",
                          timeTCObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::duration",
                          durationTCObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::maxLength",
                          maxLengthTCObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::minLength",
                          minLengthTCObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::oneOf",
                          oneOfTCObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::allOf",
                          allOfTCObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::strip",
                          stripTCObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::split",
                          splitTCObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::id",
                          idTCObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::idref",
                          idrefTCObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::base64",
                          base64TCObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::key",
                          keyTCObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::keyref",
                          keyrefTCObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::name",
                          nameTCObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::ncname",
                          ncnameTCObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::qname",
                          qnameTCObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::hexBinary",
                          hexBinaryTCObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::unsignedByte",
                          unsignedIntTypesTCObjCmd, (ClientData) 0, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::unsignedShort",
                          unsignedIntTypesTCObjCmd, (ClientData) 1, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::unsignedInt",
                          unsignedIntTypesTCObjCmd, (ClientData) 2, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::unsignedLong",
                          unsignedIntTypesTCObjCmd, (ClientData) 3, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::byte",
                          intTypesTCObjCmd, (ClientData) 0, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::short",
                          intTypesTCObjCmd, (ClientData) 1, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::int",
                          intTypesTCObjCmd, (ClientData) 2, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::long",
                          intTypesTCObjCmd, (ClientData) 3, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::setvar",
                          setvarTCObjCmd, (ClientData) 3, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::whitespace",
                          whitespaceTCObjCmd, (ClientData) 3, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::not",
                          notTCObjCmd, (ClientData) 3, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::length",
                          lengthTCObjCmd, (ClientData) 3, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::type",
                          typeTCObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp,"tdom::schema::text::jsontype",
                          jsontypeTCObjCmd, NULL, NULL);
    
    /* Exposed text type commands */
    Tcl_CreateObjCommand (interp,"tdom::type::date",
                          dateObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp,"tdom::type::dateTime",
                          dateTimeObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp,"tdom::type::time",
                          timeObjCmd, NULL, NULL);
    Tcl_CreateObjCommand (interp,"tdom::type::duration",
                          durationObjCmd, NULL, NULL);

}
#endif
