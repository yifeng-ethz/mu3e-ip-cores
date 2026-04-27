
#include <tdom.h>
#include <dom.h>
#include <tcldom.h>
#include <schema.h>

#define SetResult(str) Tcl_ResetResult(interp); \
                     Tcl_SetStringObj(Tcl_GetObjResult(interp), (str), -1)

#define CHECK_TI                                                        \
    if (!sdata) {                                                       \
        SetResult ("Command called outside of schema context");         \
        return TCL_ERROR;                                               \
    }                                                                   \
    if (!sdata->isTextConstraint) {                                     \
        SetResult ("Command called in invalid schema context");         \
        return TCL_ERROR;                                               \
    }

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

extern char *Tdom_InitStubs (Tcl_Interp *interp, char *version, int exact);

#define GTIN_8   1
#define GTIN_12  2
#define GTIN_13  4
#define GTIN_14  8


static int
gtinImpl (
    Tcl_Interp *interp,
    void *constraintData,
    char *text
    )
{
    int len, sum, i, mult, digit;
    long flags = (long) constraintData;

    len = strlen (text);
    if (len == 8) {
        if (flags && !(flags & GTIN_8)) return 0;
    } else if (len == 12) {
        if (flags && !(flags & GTIN_12)) return 0;
    } else if (len == 13) {
        if (flags && !(flags & GTIN_13)) return 0;
    } else if (len == 14) {
        if (flags && !(flags & GTIN_14)) return 0;
    } else {
        return 0;
    }

    sum = 0;
    mult = len % 2;
    for (i = len - 1; i >= 0; i--) {
        digit = text[i] - '0';
        if (digit < 0 || digit > 9) return 0;
        if (i % 2 == mult) digit *= 3;
        sum += digit;
    }
    if (sum % 10 != 0) return 0;
    return 1;
}

/*
 *----------------------------------------------------------------------------
 *
 *  gtinTCObjCmd
 *
 *	This procedure is invoked to process the
 *	"tdom::schema::text::gtin" command.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	The usual schema text constraint command machinery.
 *
 *----------------------------------------------------------------------------
 */

int
gtinTCObjCmd (dummy, interp, objc, objv)
     ClientData dummy;
     Tcl_Interp *interp;
     int objc;
     Tcl_Obj *const objv[];
{
    SchemaData *sdata = tdomGetSchemadata();
    SchemaConstraint *sc;
    int optionIndex;
    long flags = 0;
        
    CHECK_TI;

    static const char *options[] = {
        "-gtin8", "-gtin12", "-gtin13", "-gtin14", NULL
    };
    enum option {
        m_gtin8, m_gtin12, m_gtin13, m_gtin14
    };

    while (objc > 1) {
        if (Tcl_GetIndexFromObj (interp, objv[1], options, "option", 0,
                                 &optionIndex) != TCL_OK) {
            return TCL_ERROR;
        }
        switch ((enum option) optionIndex) {
        case m_gtin8:
            flags |= GTIN_8;
            break;
        case m_gtin12:
            flags |= GTIN_12;
            break;
        case m_gtin13:
            flags |= GTIN_13;
            break;
        case m_gtin14:
            flags |= GTIN_14;
            break;
        }
        objv++;
        objc--;
    }
    
    ADD_CONSTRAINT (sdata, sc)
    sc->constraint = gtinImpl;
    sc->constraintData = (void *)flags;
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------------
 *
 * Schemadtx_Init --
 *
 *	Initialization routine for loadable module
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Defines the additional text constraint commands
 *
 *----------------------------------------------------------------------------
 */
#if defined(_MSC_VER) || defined(__MINGW32__) 
#  undef TCL_STORAGE_CLASS
#  define TCL_STORAGE_CLASS DLLEXPORT
#endif

EXTERN
int
Schemadtx_Init (interp)
    Tcl_Interp *interp;
{
#ifdef USE_TCL_STUBS
    if (Tcl_InitStubs(interp, "8", 0) == NULL) {
        return TCL_ERROR;
    }
#endif
#ifdef USE_TDOM_STUBS
    if (Tdom_InitStubs(interp, "0.9.2", 0) == NULL) {
        return TCL_ERROR;
    }
#endif
    if (Tcl_PkgRequire (interp, "tdom", "0.9.2", 0) == NULL) {
        return TCL_ERROR;
    };
    Tcl_CreateObjCommand (interp,"tdom::schema::text::gtin",
                          gtinTCObjCmd, (ClientData) 3, NULL);
    Tcl_PkgProvide (interp, "schemadtx", "1.0");
    return TCL_OK;
}
