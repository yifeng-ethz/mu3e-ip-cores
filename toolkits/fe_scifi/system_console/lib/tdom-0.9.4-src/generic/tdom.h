
#define __TDOM_H

#include "tcl.h"
#include <expat.h>
#include <tclexpat.h>

#ifdef BUILD_tdom
# undef TCL_STORAGE_CLASS
# define TCL_STORAGE_CLASS DLLEXPORT
#endif

#include "dom.h"
#include "tdomDecls.h"
