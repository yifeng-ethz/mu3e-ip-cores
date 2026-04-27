
#------------------------------------------------------------------------
# TDOM_ENABLE_DTD --
#
#   Allows the building with DTD support
#
# Arguments:
#   None
#   
# Results:
#
#   Adds the following arguments to configure:
#       --enable-dtd=yes|no
#
#   Defines the following vars:
#
#   Sets the following vars:
#
#------------------------------------------------------------------------

AC_DEFUN(TDOM_ENABLE_DTD, [
    AC_MSG_CHECKING([whether to enable expat dtd support])
    AC_ARG_ENABLE(dtd,
        AC_HELP_STRING([--enable-dtd],
            [build expat with dtd support (default: on)]),
        [tcl_ok=$enableval], [tcl_ok=yes])

    if test "${enable_dtd+set}" = set; then
        enableval="$enable_dtd"
        tcl_ok=$enableval
    else
        tcl_ok=yes
    fi

    if test "$tcl_ok" = "yes" ; then
        AC_MSG_RESULT([yes])
        AC_DEFINE(XML_DTD)
    else
        AC_MSG_RESULT([no])
    fi
])

#------------------------------------------------------------------------
# TDOM_CONTEXT_BYTES --
#
#   Allows to adjust the context bytes buffer size
#
# Arguments:
#   None
#   
# Results:
#
#   Adds the following arguments to configure:
#       --with-context-bytes=
#
#   Defines the following vars:
#
#   Sets the following vars:
#
#------------------------------------------------------------------------

AC_DEFUN(TDOM_CONTEXT_BYTES, [
    AC_MSG_CHECKING([expat context bytes buffer size])
    AC_ARG_WITH(contextbytes,
        AC_HELP_STRING([--with-context-bytes],
            [configure expat context bytes buffer size (default: 1024)]),
        , [with_contextbytes=1024])

    AC_MSG_RESULT([${with_contextbytes}])
    AC_DEFINE_UNQUOTED(XML_CONTEXT_BYTES, [${with_contextbytes}])
])

#------------------------------------------------------------------------
# TDOM_ENABLE_NS --
#
#   Allows the building with namespace support
#
# Arguments:
#   None
#   
# Results:
#
#   Adds the following arguments to configure:
#       --enable-ns=yes|no
#
#   Defines the following vars:
#
#   Sets the following vars:
#
#------------------------------------------------------------------------

AC_DEFUN(TDOM_ENABLE_NS, [
    AC_MSG_CHECKING([whether to enable namespace support])
    AC_ARG_ENABLE(ns,
        AC_HELP_STRING([--enable-ns],
            [build with XML namespace support (default: on)]),
        [tcl_ok=$enableval], [tcl_ok=yes])

    if test "${enable_ns+set}" = set; then
        enableval="$enable_ns"
        tcl_ok=$enableval
    else
        tcl_ok=yes
    fi

    if test "$tcl_ok" = "yes" ; then
        AC_MSG_RESULT([yes])
        AC_DEFINE(XML_NS)
    else
        AC_MSG_RESULT([no])
    fi
])

#------------------------------------------------------------------------
# TDOM_ENABLE_UNKNOWN --
#
#   Allows the building with (or without) the custom unknown command
#
# Arguments:
#   none
#   
# Results:
#
#   Adds the following arguments to configure:
#       --enable-unknown=yes|no
#
#   Defines the following vars:
#
#   Sets the following vars:
#
#------------------------------------------------------------------------

AC_DEFUN(TDOM_ENABLE_UNKNOWN, [
    AC_MSG_CHECKING([whether to enable built-in unknown command])
    AC_ARG_ENABLE(ucmd,
        AC_HELP_STRING([--enable-unknown],
            [enable built-in unknown command (default: off)]),
        [tcl_ok=$enableval], [tcl_ok=no])

    if test "${enable_unknown+set}" = set; then
        enableval="$enable_unknown"
        tcl_ok=$enableval
    else
        tcl_ok=no
    fi

    if test "$tcl_ok" = "no" ; then
        AC_MSG_RESULT([no])
        AC_DEFINE(TDOM_NO_UNKNOWN_CMD)
    else
        AC_MSG_RESULT([yes])
    fi
])
#------------------------------------------------------------------------
# TDOM_ENABLE_TDOMALLOC --
#
#   Allows the building with tDOMs block allocator for nodes
#
# Arguments:
#   none
#
# Results:
#
#   Adds the following arguments to configure:
#       --enable-tdomalloc=yes|no
#
#   Defines the following vars:
#
#   Sets the following vars:
#
#------------------------------------------------------------------------

AC_DEFUN(TDOM_ENABLE_TDOMALLOC, [
    AC_MSG_CHECKING([whether to enable tDOMs block allocator])
    AC_ARG_ENABLE(tdomalloc,
        AC_HELP_STRING([--enable-tdomalloc],
            [build with the tDOM allocator (default: off)]),
        [tcl_ok=$enableval], [tcl_ok=no])

    if test "${enable_tdomalloc+set}" = set; then
        enableval="$enable_tdomalloc"
        tcl_ok=$enableval
    else
        tcl_ok=no
    fi

    if test "$tcl_ok" = "yes" ; then
        AC_MSG_RESULT([yes])
        TEA_ADD_SOURCES([generic/domalloc.c])
    else
        AC_MSG_RESULT([no])
        AC_DEFINE(USE_NORMAL_ALLOCATOR)
    fi
])

#------------------------------------------------------------------------
# TDOM_ENABLE_LESS_NS --
#
#   Building with lower limit of different XML namespace declarations
#   per document.
#
# Arguments:
#   None
#   
# Results:
#
#   Adds the following arguments to configure:
#       --enable-lessns=yes|no
#
#   Defines the following vars:
#
#   Sets the following vars:
#
#------------------------------------------------------------------------

AC_DEFUN(TDOM_ENABLE_LESS_NS, [
    AC_MSG_CHECKING([whether to enable lower limit for XML ns declarations per document])
    AC_ARG_ENABLE(lessns,
        AC_HELP_STRING([--enable-lessns],
            [build with lower limit for XML ns declarations (default: off)]),
        [tcl_ok=$enableval], [tcl_ok=no])

    if test "${enable_lessns+set}" = set; then
        enableval="$enable_lessns"
        tcl_ok=$enableval
    else
        tcl_ok=no
    fi

    if test "$tcl_ok" = "yes" ; then
        AC_MSG_RESULT([yes])
        AC_DEFINE(TDOM_LESS_NS)
    else
        AC_MSG_RESULT([no])
    fi
])

#------------------------------------------------------------------------
# TDOM_ENABLE_SCHEMA --
#
#   Building with validation features.
#
# Arguments:
#   None
#   
# Results:
#
#   Adds the following arguments to configure:
#       --enable-validation=yes|no
#
#   Defines the following vars:
#
#   Sets the following vars:
#
#------------------------------------------------------------------------

AC_DEFUN(TDOM_ENABLE_SCHEMA, [
    AC_MSG_CHECKING([whether to enable valiation features])
    AC_ARG_ENABLE(schema,
        AC_HELP_STRING([--enable-schema],
            [build with valiation features (default: on)]),
        [tcl_ok=$enableval], [tcl_ok=yes])

    if test "${enable_schema+set}" = set; then
        enableval="$enable_schema"
        tcl_ok=$enableval
    else
        tcl_ok=yes
    fi

    if test "$tcl_ok" = "no" ; then
        AC_MSG_RESULT([no])
        AC_DEFINE(TDOM_NO_SCHEMA)
    else
        AC_MSG_RESULT([yes])
    fi
])

#------------------------------------------------------------------------
# TDOM_ENABLE_HTML5 --
#
#   Building with gumbo support for HTML5 parsing (dom parse -html5)
#
# Arguments:
#   None
#   
# Results:
#
#   Adds the following arguments to configure:
#       --enable-html5=yes|no
#
#   Defines the following vars:
#
#   Sets the following vars:
#
#------------------------------------------------------------------------

AC_DEFUN(TDOM_ENABLE_HTML5, [
    AC_PATH_TOOL([PKG_CONFIG],[pkg-config])
    AC_MSG_CHECKING([whether to enable support for HTML5 parsing (using gumbo)])
    AC_ARG_ENABLE(html5,
        AC_HELP_STRING([--enable-html5],
            [build with HTML5 parsing support (default: off)]),
        [tcl_ok=$enableval], [tcl_ok=no])

    if test "${enable_html5+set}" = set; then
        enableval="$enable_html5"
        tcl_ok=$enableval
    else
        tcl_ok=no
    fi
    HTML5_LIBS=""
    HTML5_INCLUDES=""
    if test "$tcl_ok" = "yes" ; then
        # Check if pkg-config is available
        if test "x$PKG_CONFIG" = x; then
            tcl_ok=no
	    AC_MSG_ERROR([cannot find pkg-config needed for --enable-html5.])
        fi
    fi
    if test "$tcl_ok" = "yes" ; then
        HAVEGUMBO=`$PKG_CONFIG --exists gumbo && echo "1"`
        if test "$HAVEGUMBO" = "1" ; then
            AC_MSG_RESULT([yes])
            AC_DEFINE(TDOM_HAVE_GUMBO)
            if test "${TEA_PLATFORM}" = "windows" ; then
                HTML5_LIBS="-Wl,-Bstatic `$PKG_CONFIG --static --libs gumbo` -Wl,-Bdynamic"
            else
                HTML5_LIBS="`$PKG_CONFIG --libs gumbo`"
            fi
            HTML5_INCLUDES="`$PKG_CONFIG --cflags gumbo`"
        else
            AC_MSG_ERROR([The required lib gumbo not found])
        fi
    else    
        AC_MSG_RESULT([no])
    fi
])

#------------------------------------------------------------------------
# TDOM_PATH_AOLSERVER
#
#   Allows the building with support for AOLserver 
#
# Arguments:
#   none
#   
# Results:
#
#   Adds the following arguments to configure:
#       --with-aolserver=...
#
#   Defines the following vars:
#       AOL_DIR Full path to the directory containing AOLserver distro
#
#   Sets the following vars:
#       NS_AOLSERVER 
#------------------------------------------------------------------------

AC_DEFUN(TDOM_PATH_AOLSERVER, [
    AC_MSG_CHECKING([for AOLserver configuration])
    AC_ARG_WITH(aol, 
        AC_HELP_STRING([--with-aolserver],
            [directory with AOLserver distribution]),
        with_aolserver=${withval})

    AC_CACHE_VAL(ac_cv_c_aolserver,[
    if test x"${with_aolserver}" != x ; then
        if test -f "${with_aolserver}/include/ns.h" ; then
            ac_cv_c_aolserver=`(cd ${with_aolserver}; pwd)`
        else
            AC_MSG_ERROR([${with_aolserver} directory doesn't contain ns.h])
        fi
    fi
    ])
    if test x"${ac_cv_c_aolserver}" = x ; then
        AC_MSG_RESULT([none found])
    else
        AOL_DIR=${ac_cv_c_aolserver}
        AOL_INCLUDES="-I\"${AOL_DIR}/include\""
        if test "`uname -s`" = Darwin ; then
            aollibs=`ls ${AOL_DIR}/lib/libns* 2>/dev/null`
            if test x"$aollibs" != x ; then
                AOL_LIBS="-L\"${AOL_DIR}/lib\" -lnsd -lnsthread"
            fi
        fi
        AC_MSG_RESULT([found AOLserver in $AOL_DIR])
        AC_DEFINE(NS_AOLSERVER)
        AC_DEFINE(USE_NORMAL_ALLOCATOR)
    fi
])

#------------------------------------------------------------------------
# TDOM_PATH_EXPAT
#
#   Allows the building against a shared, system-wide expat library In
#   doubt, it falls back to the bundled expat copy
#
# Arguments:
#   none
#
# Results:
#
#   Adds the following arguments to configure:
#       --with-expat=...
#
#   Defines the following vars:
#
#   Sets the following vars:
#
#------------------------------------------------------------------------

AC_DEFUN(TDOM_PATH_EXPAT, [
    AC_MSG_CHECKING([for expat])
    AC_ARG_WITH(expat,
        AC_HELP_STRING([--with-expat],
            [directory with expat installation]), , [with_expat=no])

    AC_CACHE_VAL(ac_cv_c_expat,[
        case $with_expat in
            no) ;;
            yes)
                for f in /usr/local /usr; do
                    if test -f "$f/include/expat.h" ; then
                        ac_cv_c_expat=`(cd $f; pwd)`
                        break
                    fi
                done
                ;;
            *)                
                if test -f "$with_expat/include/expat.h"; then
                    ac_cv_c_expat=`(cd $with_expat; pwd)`
                else                  
                     AC_MSG_ERROR([${with_expat} directory doesn't contain expat.h])
                fi
        esac             
    ])
    if test x"${ac_cv_c_expat}" = x ; then
        AC_MSG_RESULT([Using bundled expat distribution])
        TEA_ADD_SOURCES([expat/xmlrole.c \
                         expat/xmltok.c \
                         expat/xmlparse.c])
        TEA_ADD_INCLUDES([-I${srcdir}/expat])
        AC_DEFINE([XML_POOR_ENTROPY], 1,
          [Define to use poor entropy in lack of better source.])
    else
        AC_MSG_RESULT([Using shared expat found in ${ac_cv_c_expat}])
        TEA_ADD_INCLUDES(-I${ac_cv_c_expat}/include)
        TEA_ADD_LIBS([-lexpat])
    fi
])

#------------------------------------------------------------------------
# TDOM_EXPAT_ENTROPY
#
#   Only useful if building with the included expat. Allows to
#   determine the source of entropy used by the lib. If the argument
#   is something else then the default "auto", this argument value
#   will be a #define. Use XML_POOR_ENTROPY to fall back to the old
#   expat hash table salting. The default is to determine the best
#   available source and to use this.
#
# Arguments:
#   none
#
# Results:
#
#   Adds the following arguments to configure:
#       --with-entropy=...
#
#   Defines the following vars:
#
#   Sets the following vars:
#
#------------------------------------------------------------------------

AC_DEFUN(TDOM_EXPAT_ENTROPY, [
    AC_MSG_NOTICE([checking which source of entropy to use])
    AC_ARG_WITH(entropy,
        AC_HELP_STRING([--with-entropy],
            [source of entropy to use]), , [with_entropy=auto])

        case $with_entropy in
            no) 
                AC_DEFINE([XML_POOR_ENTROPY], 1,
                          [Define to use poor entropy.])
            ;;
            auto)
                AC_MSG_CHECKING([for arc4random_buf (BSD or libbsd)])
                AC_LINK_IFELSE([AC_LANG_SOURCE([
                  #include <stdlib.h>  /* for arc4random_buf on BSD, for NULL */
                  #if defined(HAVE_LIBBSD)
                  # include <bsd/stdlib.h>
                  #endif
                  int main() {
                    arc4random_buf(NULL, 0U);
                    return 0;
                  }
                ])], [
                    AC_DEFINE([HAVE_ARC4RANDOM_BUF], [1],
                        [`arc4random_buf' function.])
                    AC_MSG_RESULT([yes])
                ], [
                    AC_MSG_RESULT([no])

                    AC_MSG_CHECKING([for arc4random (BSD, macOS or libbsd)])
                    AC_LINK_IFELSE([AC_LANG_SOURCE([
                      #if defined(HAVE_LIBBSD)
                      # include <bsd/stdlib.h>
                      #else
                      # include <stdlib.h>
                      #endif
                      int main() {
                          arc4random();
                          return 0;
                      }
                    ])], [
                        AC_DEFINE([HAVE_ARC4RANDOM], [1],
                            [`arc4random' function.])
                        AC_MSG_RESULT([yes])
                    ], [
                        AC_MSG_RESULT([no])
                    ])
                ])


                AC_MSG_CHECKING([for getrandom (Linux 3.17+, glibc 2.25+)])
                AC_LINK_IFELSE([AC_LANG_SOURCE([
                  #include <stdlib.h>  /* for NULL */
                  #include <sys/random.h>
                  int main() {
                    return getrandom(NULL, 0U, 0U);
                  }
                ])], [
                    AC_DEFINE([HAVE_GETRANDOM], [1],
                        [`getrandom' function.])
                    AC_MSG_RESULT([yes])
                ], [
                    AC_MSG_RESULT([no])

                    AC_MSG_CHECKING([for syscall SYS_getrandom (Linux 3.17+)])
                    AC_LINK_IFELSE([AC_LANG_SOURCE([
                      #include <stdlib.h>  /* for NULL */
                      #include <unistd.h>  /* for syscall */
                      #include <sys/syscall.h>  /* for SYS_getrandom */
                      int main() {
                        syscall(SYS_getrandom, NULL, 0, 0);
                        return 0;
                      }
                    ])], [
                        AC_DEFINE([HAVE_SYSCALL_GETRANDOM], [1],
                            [`syscall' and `SYS_getrandom'.])
                        AC_MSG_RESULT([yes])
                    ], [
                        AC_MSG_RESULT([no])
                    ])
                ])
                AC_DEFINE([XML_DEV_URANDOM], 1,
                          [include code reading entropy from `/dev/urandom'.])
                AC_DEFINE([XML_POOR_ENTROPY], 1,
                          [Define to use poor entropy in lack of better source.])
            ;;
            HAVE_GETRANDOM)
                AC_DEFINE([HAVE_GETRANDOM], 1,
                          [Linux + glibc >=2.25])
            ;;
            HAVE_SYSCALL_GETRANDOM)
                AC_DEFINE([HAVE_SYSCALL_GETRANDOM], 1,
                          [Linux + glibc <2.25])
            ;;
            HAVE_ARC4RANDOM_BUF)
                AC_DEFINE([HAVE_ARC4RANDOM_BUF], 1,
                          [BSD / macOS >=10.7])
            ;;
            HAVE_ARC4RANDOM)
                AC_DEFINE([HAVE_ARC4RANDOM], 1,
                          [BSD / macOS <10.7])
            ;;
            XML_DEV_URANDOM)
                AC_DEFINE([XML_DEV_URANDOM], 1,
                          [Linux / BSD / macOS (/dev/urandom).])
            ;;
            XML_POOR_ENTROPY)
                AC_DEFINE([XML_POOR_ENTROPY], 1,
                          [Define to use poor entropy in lack of better source.])
            ;;
            *)
                AC_MSG_ERROR([${with_entropy} not known.])
        esac             
])

#------------------------------------------------------------------------
# TDOM_PATH_CONFIG --
#
#	Locate the tdomConfig.sh file
#
# Arguments:
#	None
#
# Results:
#
#	Adds the following arguments to configure:
#       --with-tdom=...
#
#	Defines the following vars:
#       TDOM_BIN_DIR   Full path to the directory with tdomConfig.sh
#------------------------------------------------------------------------

AC_DEFUN(TDOM_PATH_CONFIG, [
    if test x"${no_tdom}" = x ; then
	    AC_MSG_CHECKING([for tDOM configuration])
	    AC_ARG_WITH(tdom, 
                AC_HELP_STRING([--with-tdom],
                    [directory containing tDOM configuration (tdomConfig.sh)]),
                with_tdomconfig=${withval})

	    no_tdom=true
        if test "${TEA_PLATFORM}" = "windows" ; then
            tdom_bindir=win
        else
            tdom_bindir=unix
        fi

            AC_CACHE_VAL(ac_cv_c_tdomconfig,[

	    # First check to see if --with-tdom was specified.
	    if test x"${with_tdomconfig}" != x ; then
		    if test -f "${with_tdomconfig}/tdomConfig.sh" ; then
		        ac_cv_c_tdomconfig=`(cd ${with_tdomconfig}; pwd)`
		    else
		        AC_MSG_ERROR([${with_tdomconfig} directory doesn't contain tdomConfig.sh])
		    fi
	    fi
	    # Then check for a sibling installation
	    if test x"${ac_cv_c_tdomconfig}" = x ; then
		    for i in \
			    ../tdom `ls -dr ../tdom-* 2>/dev/null` \
			    ../../tdom `ls -dr ../../tdom-* 2>/dev/null` \
			    ../../../tdom `ls -dr ../../../tdom-* 2>/dev/null` ; do
		        if test -f "$i/$tdom_bindir/tdomConfig.sh" ; then
			        ac_cv_c_tdomconfig=`(cd $i/$tdom_bindir; pwd)`
		        fi
		    done
	    fi
            # Then check if tnc/tdom are compilied in the source tree
	    if test x"${ac_cv_c_tdomconfig}" = x ; then
                    if test -f "../../$tdom_bindir/tdomConfig.sh" ; then 
		        ac_cv_c_tdomconfig=`(cd ../../$tdom_bindir; pwd)`
 	            fi
            fi
	    # Check in a few common install locations
	    if test x"${ac_cv_c_tdomconfig}" = x ; then
		    for i in \
                `ls -d ${prefix}/lib 2>/dev/null` \
			    `ls -d /usr/local/lib 2>/dev/null` ; do
		        if test -f "$i/tdomConfig.sh" ; then
			        ac_cv_c_tdomconfig=`(cd $i; pwd)`
		        fi
		    done
	    fi
	    # Check in a few other private locations
	    if test x"${ac_cv_c_tdomconfig}" = x ; then
		for i in \
            ${srcdir}/../tdom \
            `ls -dr ${srcdir}/../tdom[[0-9]].[[0-9]]* 2>/dev/null` ; do
		        if test -f "$i/$tdom_bindir/tdomConfig.sh" ; then
		            ac_cv_c_tdomconfig=`(cd $i/$tdom_bindir; pwd)`
		        fi
		    done
	    fi
	    ])
	    if test x"${ac_cv_c_tdomconfig}" = x ; then
	        TDOM_BIN_DIR="# no tDOM configuration file found"
	        AC_MSG_WARN(Can't find tDOM configuration definitions)
	        exit 0
	    else
	        no_tdom=
	        TDOM_BIN_DIR=${ac_cv_c_tdomconfig}
	        AC_MSG_RESULT(found $TDOM_BIN_DIR/tdomConfig.sh)
	    fi
    fi
])

#------------------------------------------------------------------------
# TDOM_LOAD_CONFIG --
#
#	Load the tdomConfig.sh file
#
# Arguments:
#	
#	Requires the following vars to be set:
#		TDOM_BIN_DIR
#
#   Defines the following vars:
#
#   Sets the following vars:
#
#------------------------------------------------------------------------

AC_DEFUN(TDOM_LOAD_CONFIG, [
    AC_MSG_CHECKING([for existence of $TDOM_BIN_DIR/tdomConfig.sh])
    if test -f "$TDOM_BIN_DIR/tdomConfig.sh" ; then
        AC_MSG_RESULT([loading])
	    . $TDOM_BIN_DIR/tdomConfig.sh
    else
        AC_MSG_RESULT([file not found])
    fi
    if test -f "${TDOM_BIN_DIR}/Makefile" ; then
        TDOM_STUB_LIB_SPEC=${TDOM_BUILD_STUB_LIB_SPEC}
    fi
    AC_SUBST(TDOM_VERSION)
    AC_SUBST(TDOM_STUB_LIB_SPEC)
    AC_SUBST(TDOM_SRC_DIR)
])

#------------------------------------------------------------------------
# TDOM_EXPORT_CONFIG --
#
#	Define the data to insert into the ${PACKAGE_NAME}Config.sh file
#
# Arguments:
#	None
#
# Results:
#	Subst the following vars:
#
#------------------------------------------------------------------------

AC_DEFUN(TDOM_EXPORT_CONFIG, [
    #--------------------------------------------------------------------
    # These are for ${PACKAGE_NAME}Config.sh
    #--------------------------------------------------------------------

    # pkglibdir must be a fully qualified path and (not ${exec_prefix}/lib)
    eval pkglibdir="[$]{libdir}/${PACKAGE_NAME}${PACKAGE_VERSION}"
    if test "${TCL_LIB_VERSIONS_OK}" = "ok"; then
	eval PKG_STUB_LIB_FLAG="-l${PACKAGE_NAME}stub${PACKAGE_VERSION}"
    else
	eval PKG_STUB_LIB_FLAG="-l${PACKAGE_NAME}stub`echo ${PACKAGE_VERSION} | tr -d .`"
    fi
    PKG_BUILD_STUB_LIB_SPEC="-L`pwd` ${PKG_STUB_LIB_FLAG}"
    PKG_STUB_LIB_SPEC="-L${pkglibdir} ${PKG_STUB_LIB_FLAG}"
    PKG_BUILD_STUB_LIB_PATH="`pwd`/[$]{PKG_STUB_LIB_FILE}"
    PKG_STUB_LIB_PATH="${pkglibdir}/[$]{PKG_STUB_LIB_FILE}"

    AC_SUBST(PKG_BUILD_STUB_LIB_SPEC)
    AC_SUBST(PKG_STUB_LIB_SPEC)
    AC_SUBST(PKG_BUILD_STUB_LIB_PATH)
    AC_SUBST(PKG_STUB_LIB_PATH)
])

# Local Variables:
# mode: autoconf
# End:
# EOF
