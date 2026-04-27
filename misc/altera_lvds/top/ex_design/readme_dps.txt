###############################################################################
What is this?
###############################################################################

This is the readme.txt file for the dynamic phase shift (DPS) example
design file set of the Altera LVDS SERDES IP. This allows you to do
the following:

   Use the Dynamic Phase Shift Quartus Prime project that instantiates an
   LVDS interface (same configuration as what you specified in generation),
   but exposes the PLL's Dynamic Phase Shift ports and makes them acessible
   through Altera's In-System Source Probe (ISSP) components.
   For information about Dynamic Phase Shift: 
      http://www.altera.com/literature/an/an728.pdf
      Section: Dynamic Phase Shift Ports in Altera IOPLL IP Core
   For information about ISSP components:
      http://www.altera.com/literature/hb/qts/qts_qii5v3.pdf
      Section: Design Debugging Using In-System Sources and Probes
   For this example design, the PLL must be external. A dps_issp.tcl
   script which controls the sources/probes in the design and does
   an example phase shift of an extra clock added for demonstration.
   For more information regarding scripting with ISSPs:
      http://www.altera.com/literature/hb/qts/qts_qii5v3.pdf
      Section: Tcl interface for the In-System Sources and Probes Editor 

###############################################################################
Generating a Quartus Prime Dynamic Phase Shift Example Design
###############################################################################
For information about supported arguments, run:
   quartus_sh -t make_qii_design.tcl -help
   
To generate the dynamic phase shift project, run:   
   quartus_sh -t make_qii_design.tcl -device [device_name] -system ed_synth_dps
   
The generated example design is stored under the "qii_dps" sub-directory. 
To re-generate the design, simply delete it and re-run the commands above.
   
###############################################################################
Running the DPS Example Design
###############################################################################
A dps_issp.tcl file is provided with the Dynamic Phase Shift (DPS)
example design. After programming the design onto your chip, run:
    quartus_stp -t dps_issp.tcl [path_to_project]

For example:
    quartus_stp -t dps_issp.tcl qii_dps/ed_synth_dps
    
Modify the dps_issp.tcl file to suit your needs.