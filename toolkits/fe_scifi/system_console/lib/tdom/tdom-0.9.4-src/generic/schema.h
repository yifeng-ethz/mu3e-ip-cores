/*----------------------------------------------------------------------------
|   Copyright (c) 2018-2022  Rolf Ade (rolf@pointsman.de)
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
|   2018-2022
|
\---------------------------------------------------------------------------*/

#ifndef __SCHEMA_H__
#define __SCHEMA_H__

#include <tcldom.h>
#include <domxpath.h>

#define SPACE(c) IS_XML_WHITESPACE ((c))
    

#if !defined(checkNrArgs)
#define checkNrArgs(l,h,err) if (objc < l || objc > h) {      \
        SetResult (err);                                      \
        return TCL_ERROR;                                     \
    }
#endif

typedef enum {
  SCHEMA_CTYPE_ANY,
  SCHEMA_CTYPE_NAME,
  SCHEMA_CTYPE_CHOICE,
  SCHEMA_CTYPE_INTERLEAVE,
  SCHEMA_CTYPE_PATTERN,
  SCHEMA_CTYPE_TEXT,
  SCHEMA_CTYPE_VIRTUAL,
  SCHEMA_CTYPE_KEYSPACE,
  SCHEMA_CTYPE_KEYSPACE_END,
  SCHEMA_CTYPE_JSON_STRUCT,
} Schema_CP_Type;

typedef enum {
  SCHEMA_CQUANT_ONE,
  SCHEMA_CQUANT_OPT,
  SCHEMA_CQUANT_REP,
  SCHEMA_CQUANT_PLUS,
  SCHEMA_CQUANT_NM,
  SCHEMA_CQUANT_ERROR,
} SchemaQuant;

typedef enum {
    MATCH_GLOBAL = 1,
    MATCH_ELEMENT_START,
    MATCH_ELEMENT_END,
    MATCH_TEXT,
    MATCH_ATTRIBUTE_TEXT,
    MATCH_DOM_KEYCONSTRAINT,
    MATCH_DOM_XPATH_BOOLEAN
} ValidationAction;


typedef int (*SchemaConstraintFunc) (Tcl_Interp *interp,
                                     void *constraintData, char *text);
typedef void (*SchemaConstraintFreeFunc) (void *constraintData);

typedef struct 
{
    void *constraintData;
    SchemaConstraintFunc constraint;
    SchemaConstraintFreeFunc freeData;
} SchemaConstraint;

typedef struct SchemaAttr
{
    char              *namespace;
    char              *name;
    int                required;
    struct SchemaAttr *next;
    struct SchemaCP   *cp;
} SchemaAttr;

typedef unsigned int SchemaFlags;

/* The SchemaFlags flags */
#define FORWARD_PATTERN_DEF     1
#define PLACEHOLDER_PATTERN_DEF 2
#define AMBIGUOUS_PATTERN       4
#define LOCAL_DEFINED_ELEMENT   8
#define CONSTRAINT_TEXT_CHILD  16
#define MIXED_CONTENT          32
#define ELEMENTTYPE_DEF        64
#define FORWARD_TYPE_DEF      128
#define TYPED_ELEMENT         256
#define HASH_ENTRY_DELETED    512
#define ANY_NOT              1024 

typedef struct domKeyConstraint {
    char     *name;
    ast       selector;
    ast      *fields;
    domLength nrFields;
    int       flags;
    char     *emptyFieldSetValue;
    size_t    efsv_len;
    struct domKeyConstraint *next;
} domKeyConstraint;

typedef struct 
{
    char *name;
    int active;
    Tcl_HashTable ids;
    int unknownIDrefs;
} SchemaKeySpace;

typedef struct SchemaCP
{
    Schema_CP_Type    type;
    char             *namespace;
    char             *name;
    struct SchemaCP  *typeptr;
    struct SchemaCP  *next;
    SchemaFlags       flags;
    struct SchemaCP **content;
    SchemaQuant      *quants;
    unsigned int      nc;
    void             *typedata;
    SchemaAttr      **attrs;
    unsigned int      numAttr;
    unsigned int      numReqAttr;
    domKeyConstraint *domKeys;
    SchemaKeySpace   *keySpace;
    Tcl_Obj          *defScript;
    Tcl_Obj          *associated;
} SchemaCP;

typedef struct SchemaValidationStack
{
    SchemaCP *pattern;
    struct SchemaValidationStack *next;
    struct SchemaValidationStack *down;
    int               activeChild;
    int               hasMatched;
    int              *interleaveState;
} SchemaValidationStack;

typedef enum {
    VALIDATION_READY,
    VALIDATION_STARTED,
    VALIDATION_ERROR,
    VALIDATION_FINISHED
} ValidationState;

typedef struct 
{
    Tcl_HashTable ids;
    int unknownIDrefs;
} SchemaDocKey;

typedef struct SchemaData_
{
    Tcl_Obj *self;
    char *start;
    char *startNamespace;
    Tcl_HashTable element;
    Tcl_HashTable elementType;
    Tcl_HashTable elementTypeInstance;
    Tcl_HashTable namespace;
    char **prefixns;
    Tcl_HashTable prefix;
    Tcl_HashTable pattern;
    Tcl_HashTable attrNames;
    Tcl_HashTable textDef;
    SchemaCP **patternList; 
    unsigned int numPatternList;
    unsigned int patternListSize;
    unsigned int forwardPatternDefs;
    SchemaQuant *quants;
    int       inuse;
    int       currentEvals;
    int       cleanupAfterUse;
    int       evalError;
    Tcl_Obj  *reportCmd;
    SchemaValidationStack *lastMatchse;
    int       recoverFlags;
    Tcl_Obj **evalStub;
    Tcl_Obj **textStub;
    char *currentNamespace;
    int   defineToplevel;
    int   isTextConstraint;
    int   isAttributeConstraint;
    SchemaCP *cp;
    unsigned int contentSize;
    SchemaAttr **currentAttrs;
    unsigned int numAttr;
    unsigned int numReqAttr;
    unsigned int attrSize;
    SchemaValidationStack *stack;
    SchemaValidationStack *stackPool;
    ValidationState validationState;
    ValidationAction vaction;
    const char *vname;
    const char *vns;
    const char *vtext;
    unsigned int skipDeep;
    Tcl_DString *cdata;
    Tcl_HashTable ids;
    int unknownIDrefs;
    Tcl_HashTable idTables;
    Tcl_HashTable keySpaces;
    XML_Parser parser;
    domNode *node;
    domNode *insideNode;
    domTextNode *textNode;
    unsigned int choiceHashThreshold;
    unsigned int attributeHashThreshold;
    char *wsbuf;
    int wsbufLen;
} SchemaData;

#define GETASI (SchemaData*)Tcl_GetAssocData(interp, "tdom_schema", NULL);
#define SETASI(v) Tcl_SetAssocData (interp, "tdom_schema", NULL, v)

#define ADD_CONSTRAINT(sdata, sc)                                       \
    sc = TMALLOC (SchemaConstraint);                                    \
    memset (sc, 0, sizeof (SchemaConstraint));                          \
    if (sdata->cp->nc == sdata->contentSize) {                          \
        sdata->cp->content =                                            \
            REALLOC (sdata->cp->content,                                \
                     2 * sdata->contentSize                             \
                     * sizeof (SchemaCP*));                             \
        sdata->cp->quants =                                             \
            REALLOC (sdata->cp->quants,                                 \
                     2 * sdata->contentSize                             \
                     * sizeof (SchemaQuant));                           \
        sdata->contentSize *= 2;                                        \
    }                                                                   \
    sdata->cp->content[sdata->cp->nc] = (SchemaCP *) sc;                \
    sdata->cp->quants[sdata->cp->nc] = SCHEMA_CQUANT_ONE;               \
    sdata->cp->nc++;                                                    \

#define REMEMBER_PATTERN(pattern)                                       \
    if (sdata->numPatternList == sdata->patternListSize) {              \
        sdata->patternList = (SchemaCP **) REALLOC (                    \
            sdata->patternList,                                         \
            sizeof (SchemaCP*) * sdata->patternListSize * 2);           \
        sdata->patternListSize *= 2;                                    \
    }                                                                   \
    sdata->patternList[sdata->numPatternList] = pattern;                \
    sdata->numPatternList++;


SchemaCP*
tDOM_initSchemaCP (
    Schema_CP_Type type,
    void *namespace,
    char *name
    );

#define initSchemaCP(type,namespace,name) \
    tDOM_initSchemaCP(type,namespace,name)

int
tDOM_evalConstraints (
    Tcl_Interp *interp,
    SchemaData *sdata,
    SchemaCP *cp,
    Tcl_Obj *script
    );

#define evalConstraints(interp,sdata,cp,script) \
    tDOM_evalConstraints(interp,sdata,cp,script)

int
tDOM_checkText (
    Tcl_Interp *interp,
    void *clientData,
    char *text
    );

#define checkText(interp,clientData,text) \
    tDOM_checkText(interp,clientData,text)

int 
tDOM_schemaInstanceCmd (
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[]
    );

void tDOM_SchemaInit (
    Tcl_Interp *interp
    );

int
tDOM_probeElement (
    Tcl_Interp *interp,
    SchemaData *sdata,
    const char *name,
    void *namespace
    );

int
tDOM_probeAttributes (
    Tcl_Interp *interp,
    SchemaData *sdata,
    const char **attr
    );

int tDOM_probeDomAttributes (
    Tcl_Interp *interp,
    SchemaData *sdata,
    domAttrNode *attr
    );
    
int
tDOM_probeElementEnd (
    Tcl_Interp * interp,
    SchemaData *sdata
    );

int
tDOM_probeText (
    Tcl_Interp *interp,
    SchemaData *sdata,
    char *text,
    int *only_whites
    );

void
tDOM_schemaReset (
    SchemaData *sdata
    );

#endif 
