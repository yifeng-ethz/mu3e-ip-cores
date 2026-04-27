# Helper script to run xslt 1.0 conformance test suite created by the
# OASIS XSLT / XPath Conformance Technical Committee. 

catch {source uri.tcl}
package require uri
package require tdom

# The following is not needed, given, that tDOM is correctly
# installed. This code only ensures, that the tDOM script library gets
# sourced, if the script is called with a tcldomsh out of the build
# dir of a complete tDOM source installation.
if {[info commands ::tdom::xmlReadFile] == ""} {
    # tcldomsh without the script library. Source the lib.
    source [file join [file dir [info script]] ../lib tdom.tcl]
}

# Import the tDOM helper procs
namespace import tdom::*

set catalogfile ""
set loglevel 0
set skip [list]
set match [list]
set matchgroup [list]
set matchfile [list]
set matchcatalog [list]
set verbose 0

proc putsUsage {{channel stderr}} {
    puts $channel "usage: $::argv0 ?options? path/to/catalog.xml"
    puts $channel "where options can be:"
    puts $channel "-loglevel <int>"
    puts $channel "-skip patternlist"
    puts $channel "-match patternlist"
    puts $channel "-matchgroup patternlist"
    puts $channel "-matchfile patternlist"
    puts $channel "-matchcatalog patternlist"
    puts $channel "-verbose <boolean>"
}

proc processArgs {argc argv} {
    variable catalogfile
    variable skip
    variable match
    variable matchgroup
    variable matchfile
    variable matchcatalog
    variable loglevel
    variable verbose
    
    if {$argc == 0 || $argc % 2 == 0} {
        putsUsage
        exit 1
    }
    
    foreach {option value} $argv {
        if {$value eq ""} {
            break
        }
        switch $option {
            "-match" {
                set match $value
            }
            "-matchgroup" {
                set matchgroup $value
            }
            "-matchfile" {
                set matchfile $value
            }
            "-skip" {
                set skip $value
            }
            "-matchcatalog" {
                set matchcatalog $value
            }
            "-loglevel" {
                if {[string is integer -strict $value]} {
                    set loglevel $value
                } else {
                    putsUsage
                    exit 1
                }
            }
            "-verbose" {
                if {[string is boolean -strict $value]} {
                    set verbose $value
                } else {
                    putsUsage
                    exit 1
                }
            }
            default {
                puts stderr "Unknown option \"$option\""
                putsUsage
                exit 1
            }
        }
    }
    set catalogfile [lindex $argv end]
}

set compareOK 0
set compareDIFF 0
set compareFAILED 0
set failedOK 0
set failedXML 0
set failedXSLT 0
set failedProcessing 0
set notFailed 0

proc extRefHandler {base systemId publicId} {
    variable usageCounter

    set absolutURI [uri::resolve $base $systemId]
    incr usageCounter($absolutURI)
    if {$usageCounter($absolutURI) > 50} {
        error "Circular import/include?"
    }
    switch $systemId {
        "notfound.xml" {
            return [list string $absolutURI "<notfound/>"]
        }
    }
    array set uriData [uri::split $absolutURI]
    switch $uriData(scheme) {
        file {
            if {[catch {
                set xmlstr [xmlReadFile $uriData(path)]
            }]} {
                set pathlist [file split $uriData(path)]
                set file [findFile [lindex $pathlist end] [lrange $pathlist 0 end-1]]
                if {$file ne ""} {
                    set xmlstr [xmlReadFile $file]
                }
                error "not resolved external entity. Base: $base SystemID: $systemId"
            }
            return [list string $absolutURI [xmlReadFile $uriData(path)]]
        }
        default {
            error "can only handle file URI's"
        }
    }
}


# This is the callback proc for xslt:message elements. This proc is
# called once every time an xslt:message element is encountered during
# processing the stylesheet. The callback proc simply sends the text
# message to stderr.
proc xsltmsgcmd {msg terminate} {
    variable loglevel
    if {$loglevel >= 0} {
        puts stderr "xslt message: '$msg'"
    }
}

proc readCatalog {catalogPath} {
    variable catalogDir
    variable infoset

    set fd [open $catalogPath]
    set doc [dom parse -channel $fd]
    close $fd
    set catalogDir [file dirname $catalogPath]
    set infosetxsl [file join $catalogDir .. TOOLS infoset.xsl]
    set infosetdoc [dom parse -keepEmpties [xmlReadFile $infosetxsl]]
    set infoset [$infosetdoc toXSLTcmd]
    return $doc
}

proc checkAgainstPattern {patternlist text} {
    if {![llength $patternlist]} {
        return 1
    }
    foreach pattern $patternlist {
        if {[string match $pattern $text]} {
            return 1
        }
    }
    return 0
}

proc skip {id} {
    variable skip

    if {![llength $skip]} {
        return 0
    }
    return [checkAgainstPattern $skip $id]
}

proc matchcatalog {testcatalog} {
    variable matchcatalog

    if {![llength $matchcatalog]} {
        return 1
    }
    return [checkAgainstPattern $matchcatalog $testcatalog]
}

proc log {level text {detail ""}} {
    variable loglevel

    if {$level <= $loglevel} {
        puts $text
    }
    if {$detail ne "" && $level < $loglevel} {
        puts $detail
    }
}

proc findFile {filename path} {
    # The Microsoft testcatalog includes tests for which the physical
    # file name differ in case from the file name given by the test
    # definition. This proc tries to identify the correct file name in
    # such a case.

    log 3 "findFile called with $filename $path"
    set filelist [glob -nocomplain -tails -directory $path *]
    set nocasequal [lsearch -exact -nocase $filelist $filename]
    if {[llength $nocasequal] == 1} {
        if {$nocasequal >= 0} {
            return [file join $path [lindex $filelist $nocasequal]]
        }
    }
    return ""
}

proc runTest {testcase} {
    variable catalogDir
    variable majorpath
    variable matchgroup
    variable matchfile
    variable match
    variable infoset
    variable compareOK
    variable compareDIFF
    variable compareFAILED
    variable failedOK
    variable failedXML
    variable failedXSLT
    variable failedProcessing
    variable notFailed
    variable verbose
    variable usageCounter
    
    set filepath [$testcase selectNodes string(file-path)]
    if {![checkAgainstPattern $matchgroup $filepath]} {
        return
    }
    set scenario [$testcase selectNodes scenario]
    if {[llength $scenario] != 1 } {
        log 0 "Non-standard scenario!"
        log 0 [$testcase asXML]
        return
    }
    set operation [$scenario @operation]
    switch $operation {
        "standard" -
        "execution-error" {}
        default {
            log 0 "Non-standard scenario!"
            log 0 [$testcase asXML]
            return
        }
    }
    set xmlfile [$scenario selectNodes \
                     {string(input-file[@role="principal-data"])}]
    set xslfile [$scenario selectNodes \
                     {string(input-file[@role="principal-stylesheet"])}]
    set testid [$testcase @id "<no-id>"]
    if {![checkAgainstPattern $match $testid]} {
        return
    }
    if {[skip $testid]} {
        log 1 "Skipping test id $testid (filepath: $filepath)"
        return
    }

    if {![checkAgainstPattern $matchfile $xslfile]} {
        log 1 "Skipping xslfile $xslfile"
        return
    }
    if {$verbose} {
        puts [$testcase @id "<no-id>!!"]
    }
    set xmlfile [file join $catalogDir $majorpath $filepath $xmlfile]
    if {![file readable $xmlfile]} {
        set xmlfile [findFile $xmlfile \
                         [file join $catalogDir $majorpath $filepath]]
        if {$xmlfile eq ""} {
            log 0 "Couldn't find xmlfile \
                  [$scenario selectNodes \
                     {string(input-file[@role="principal-data"])}]"
            return
        }
    }
    if {![file readable $xslfile]} {
        set xslfile [findFile $xslfile \
                         [file join $catalogDir $majorpath $filepath]]
        if {$xslfile eq ""} {
            log 0 "Couldn't find xslfile \
                  [$scenario selectNodes \
                     {string(input-file[@role="principal-stylesheet"])}]"
            return
        }
    }
    set xslfile [file join $catalogDir $majorpath $filepath $xslfile]
    set xmlout [$scenario selectNodes \
                    {string(output-file[@role="principal" and @compare="XML"])}]
    set xmloutfile ""
    if {$xmlout ne ""} {
        set xmloutfile [file join $catalogDir $majorpath "REF_OUT" $filepath \
                            $xmlout]
    }
    array unset usageCounter
    if {[catch {
        set xmldoc [dom parse -baseurl [baseURL $xmlfile] \
                        -externalentitycommand extRefHandler \
                        -keepEmpties \
                        [xmlReadFile $xmlfile] ]
    } errMsg]} {
        incr failedXML
        log 0 "Unable to parse xml file '$xmlfile'. Reason:\n$errMsg"
        return
    }
    dom setStoreLineColumn 1
    if {[catch {
        set xsltdoc [dom parse -baseurl [baseURL $xslfile] \
                         -externalentitycommand extRefHandler \
                         -keepEmpties \
                         [xmlReadFile $xslfile] ]
    } errMsg]} {
        dom setStoreLineColumn 0
        incr failedXSLT
        log 0 "Unable to parse xsl file '$xslfile'. Reason:\n$errMsg"
        return
    }
    dom setStoreLineColumn 0
    set resultDoc ""
    if {[catch {$xmldoc xslt -xsltmessagecmd xsltmsgcmd $xsltdoc resultDoc} \
             errMsg]} {
        if {$operation eq "execution-error"} {
            incr failedOK
            log 2 $errMsg
        } else {
            incr failedProcessing
            log 0 $errMsg
        }
    } else {
        if {$operation eq "execution-error"} {
            incr notFailed
            log 0 "$xslfile - test should have failed, but didn't."
        }
    }
    if {$xmloutfile ne "" && [llength [info commands $resultDoc]]} {
        if {![catch {
            set refdoc [dom parse -keepEmpties [xmlReadFile $xmloutfile]]
        } errMsg]} {
            set refinfosetdoc [$infoset $refdoc]
            set resultinfosetdoc [$infoset $resultDoc]
            if {[$refinfosetdoc asXML -indent none] 
                ne [$resultinfosetdoc asXML -indent none]} {
                incr compareDIFF
                log 1 "Result and ref differ."
                log 2 "Ref:"
                log 2 [$refinfosetdoc asXML -indent none]
                log 2 "Result:"
                log 2 [$resultinfosetdoc asXML -indent none]
            } else {
                incr compareOK
            }
            $refinfosetdoc delete
            $resultinfosetdoc delete
        } else {
            incr compareFAILED
            log 3 "Unable to parse REF doc. Reason:\n$errMsg"
        }
    }
    $xmldoc delete
    $xsltdoc delete
    catch {$resultDoc delete}
}

proc runTests {catalogRoot} {
    variable majorpath
    variable compareOK
    variable compareDIFF
    variable compareFAILED
    variable failedOK
    variable failedXML
    variable failedXSLT
    variable failedProcessing
    variable notFailed
    
    foreach testcatalog [$catalogRoot selectNodes test-catalog] {
        if {![matchcatalog [$testcatalog @submitter]]} {
            continue
        }
        set majorpath [$testcatalog selectNodes string(major-path)]
        foreach testcase [$testcatalog selectNodes test-case] {
            runTest $testcase
        }
    }
    # Always output the summary
    variable loglevel 0
    log 0 "Finished."
    log 0 "XML parse failed: $failedXML"
    log 0 "XSLT parse failed: $failedXSLT"
    log 0 "Processing failed: $failedProcessing"
    log 0 "Compare OK: $compareOK"
    log 0 "Compare FAIL: $compareDIFF"
    log 0 "Compare BROKEN: $compareFAILED"
    log 0 "Not found errors: $notFailed"
    log 0 "Failed OK: $failedOK"
}

processArgs $argc $argv
set catalogDoc [readCatalog $catalogfile]
runTests [$catalogDoc documentElement]

proc exit args {}
