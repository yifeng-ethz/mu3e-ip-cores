
## tDOM - a XML / DOM / XPath / XSLT / HTML / JSON implementation for Tcl
### Version 0.9.4

### tDOM contains:

   *  for convenience expat 2.6.2, the XML parser originated from
      James Clark, although you're able to link tDOM with other
      expat versions or the library provided by the system.

   *  building a DOM tree from XML in one go implemented in C for
      maximum performance and minimum memory usage, and DOM I and II
      methods to work on such a tree using either a OO-like or a
      handle syntax.

   *  a Tcl interface to expat for event-like (SAX-like) XML parsing.

   *  a complete, compliant and fast XPath implementation in C
      following the November 99 W3C recommendation for navigating and
      data extraction.

   *  a fast XSLT implementation in C following the W3C Recommendation
      16 November 1999.
   
   *  optional DTD validation.

   *  a rich and Tcl'ish language to describe structures and text
      content and to validate XML data or DOM trees or other forms of
      hierarchically data with that.
   
   *  a JSON parser which parses any possible JSON input into a DOM
      tree without losing information.

   *  an efficient and Tcl'ish way to create XML and HTML documents
      and JSON strings.

   *  as build option an interface to the gumbo HTML5 parser, which
      also digests almost any other HTML.

   *  an even faster simple XML parser for trusted XML input.

   *  a slim Tcl interface to use expat as pull-parser.

   *  a secure way to share DOM trees by threads

   *  additional convenience methods.

   *  and more.


### Documentation

The documentation is included into the source distribution in HTML and
man format. Alternatively, read it
[online](http://tdom.org/index.html/doc/trunk/doc/index.html).


### Getting the code

The development repository is hosted at <http://tdom.org> and is
mirrored at <http://core.tcl.tk/tdom>. You are invited to use trunk
which you get as
[tarball](http://tdom.org/index.html/tarball/trunk/tdom-trunk.tar.gz)
or as [zip archive](http://tdom.org/index.html/zip/trunk/tdom-trunk.zip)

The latest release is 0.9.4. Get the source code as
[tarball](http://tdom.org/downloads/tdom-0.9.4-src.tgz) or
as [zip archive](http://tdom.org/downloads/tdom-0.9.4-src.zip).

Windows binaries of the 0.9.4 release are also available. Get it for
[Tcl 8.6 / 64 bit](http://tdom.org/downloads/tdom-0.9.4-windows-x64.zip) or [Tcl 8.6
/ 32 bit](http://tdom.org/downloads/tdom-0.9.4-windows-x86.zip) or
[Tcl 9 / 64 bit](http://tdom.org/downloads/tcl9-tdom-0.9.4-windows-x64.zip)
or [Tcl 9 / 32 bit](http://tdom.org/downloads/tcl9-tdom-0.9.4-windows-x86.zip)

The provided windows binaries include (statically linked) the
HTML5 parser.


### Compiling tdom

Depending on your platform (unix/mac or win), go to the
corresponding directory and invoke the configure script:

    ../configure
    make 
    make test
    make install

Alternatively, you can build the tDOM package in just about any
directory elsewhere on the filesystem (since TEA-compatible).

You might also want to do "../configure --help" to get a list of
all supported options of the configure script. In the "unix"
directory there is a "CONFIG" file containing some examples on how
to invoke the "configure" script for some common cases. You can
peek there. This file also includes a short description of the
tDOM specific configure options.

Since tDOM is TEA-compatible you should be able to build it using
the MinGW build environment for Windows. There is also the MSVC
nmake file so you can compile the package with Microsoft tools.
Refer to the README in the win directory for more details about
building on Windows.

The compile process will build the tDOM shared library suitable for
loading into the Tcl shell using standard "package require" mechanism.


### Reporting bugs

Open a [ticket](http://tdom.org/index.html/ticket). Log in as
anonymous and report your findings. If you prefer to have an
individual login write Rolf a mail.


### History

tDOM was started by Jochen Loewer (loewerj@hotmail.com) and
developed by Jochen and Rolf Ade (rolf@pointsman.de) with
contributions by Zoran Vasiljevic (zv@archiware.com). Since more
than a dozen years it is maintained and developed by Rolf Ade.


### ... ahh, Licensing!!

Sigh. See LICENSE file.
