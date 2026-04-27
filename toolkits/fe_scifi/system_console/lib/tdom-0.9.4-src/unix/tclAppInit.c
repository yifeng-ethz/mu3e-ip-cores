/*----------------------------------------------------------------------------
|   Copyright (c) 2007 Rolf Ade (rolf@pointsman.de)
+-----------------------------------------------------------------------------
|
|   $Id$
|
|
|   Main file for a standalone tclsh with tDOM build in ('big tclsh').
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
|   The Initial Developer of the Original Code is Jochen Loewer
|   Portions created by Jochen Loewer are Copyright (C) 1998, 1999
|   Jochen Loewer. All Rights Reserved.
|
|   Contributor(s):
|
|
|   written by Rolf Ade
|   August, 2007
|
\---------------------------------------------------------------------------*/

#include "tcl.h"

#ifndef MODULE_SCOPE
#   define MODULE_SCOPE extern
#endif
MODULE_SCOPE int Tcl_AppInit(Tcl_Interp *);
MODULE_SCOPE int main(int, char **);
 
extern int Tdom_Init (Tcl_Interp *interp);
extern int Tdom_SafeInit (Tcl_Interp *interp);

/*----------------------------------------------------------------------------
|   main
|
\---------------------------------------------------------------------------*/
int
main(
    int    argc,
    char **argv
    )
{
    Tcl_Main (argc, argv, Tcl_AppInit);
    return 0;
}

/*----------------------------------------------------------------------------
|   Tcl_AppInit
|
\---------------------------------------------------------------------------*/
int
Tcl_AppInit(interp)
    Tcl_Interp *interp;
{
    if ((Tcl_Init)(interp) == TCL_ERROR) {
        return TCL_ERROR;
    }
    if (Tdom_Init(interp) == TCL_ERROR) {
        return TCL_ERROR;
    }
    /* This double announce of tDOM with two names tries to reduce the
     * fall-out of TIP 595. */
    Tcl_StaticPackage(interp, "tdom", Tdom_Init, Tdom_SafeInit);
    Tcl_StaticPackage(interp, "Tdom", Tdom_Init, Tdom_SafeInit);
#if (TCL_MAJOR_VERSION > 8)
    Tcl_EvalEx(interp, "set tcl_rcFileName [file tildeexpand ~/.tcldomshrc]",
               -1, TCL_EVAL_GLOBAL);
#else
    Tcl_SetVar(interp, "tcl_rcFileName", "~/.tcldomshrc", TCL_GLOBAL_ONLY);
#endif
    return TCL_OK;
}
