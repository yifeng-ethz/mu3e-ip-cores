#

set project_name [ lindex $quartus(args) 0 ]

package require ::quartus::flow

# `-force` - overwrite the compilation database if the database version is incompatible
project_open -force $project_name
# `-dont_export_assignments` - do not to export assignments to file
# `-compile` - full compilation
# `-implement` - run compilation up to route stage and skip all time intensive algorithms after
execute_flow -dont_export_assignments -compile
#execute_flow -dont_export_assignments -implement
project_close
