# Test power reporting
read_liberty ../../test/sky130hd/sky130_fd_sc_hd__tt_025C_1v80.lib
read_verilog power_test1.v
link_design power_test1

create_clock -name clk -period 10 [get_ports clk]
set_input_delay -clock clk 0 [get_ports in1]
set_output_delay -clock clk 0 [get_ports out1]
set_input_transition 0.1 [get_ports in1]

set_power_activity -global -activity 0.5 -duty 0.5

# Report power with explicit checks on returned content.
with_output_to_variable pwr_default { report_power }
if {![regexp {Total} $pwr_default]} {
  error "report_power output missing Total section"
}

with_output_to_variable pwr_inst { report_power -instances [get_cells reg1] }
if {![regexp {reg1} $pwr_inst]} {
  error "instance power report missing reg1 entry"
}

with_output_to_variable pwr_json { report_power -format json }
if {![regexp {"Total"} $pwr_json]} {
  error "json power report missing Total field"
}

# A pin can remain in the topological clock network after case analysis
# removes all of its clock arrivals. Power activity lookup must tolerate it.
read_liberty ../../test/nangate45/Nangate45_typ.lib
read_verilog power_clock_activity.v
link_design power_clock_activity
create_clock -name clk -period 4 [get_ports clk]
set_propagated_clock [all_clocks]
unset_power_activity -global

proc checked_clock_power {} {
  # Ensure clock paths are refreshed before activity lookup.
  with_output_to_variable checks { report_checks }
  set powers [sta::design_power [sta::cmd_scene]]
  foreach value $powers {
    if {![expr {$value >= 0.0 && $value < Inf}]} {
      error "invalid clock-network power: $value"
    }
  }
  return $powers
}

set normal_power [checked_clock_power]
set_case_analysis 0 [get_ports clk]
set constant_power [checked_clock_power]
if {[lindex $constant_power 1] >= [lindex $normal_power 1]} {
  error "constant clock did not reduce switching power"
}

# Keep the global and per-pin activity overrides usable without a clock path.
set_power_activity -global -activity 0.5 -duty 0.5
checked_clock_power
unset_power_activity -global
set_power_activity -pins [get_pins mux1/A] -activity 0.2 -duty 0.25
checked_clock_power
unset_power_activity -pins [get_pins mux1/A]

# Removing case analysis restores valid clock activities and original power.
unset_case_analysis [get_ports clk]
set restored_power [checked_clock_power]
foreach expected $normal_power actual $restored_power {
  if {abs($expected - $actual) > 1e-5 * max(abs($expected), 1e-20)} {
    error "clock power was not restored: expected $expected, got $actual"
  }
}
