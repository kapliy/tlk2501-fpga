# possible modes: default, debug, error
if {$argc >= 1} {
	set mode $1
} else {
	set mode "default"
}

quit -sim

vlib work
vlib gate_work
vlib hola_sim_lib

# compile altera components
vcom -93 -work work {lrl_xoff_control.vhd}

vsim work.lrl_xoff_control -GLRL_STABLE_LENGTH=5

delete wave *

add wave -noupdate -radix hexadecimal {sim:/lrl_xoff_control/lrl}

add wave -noupdate \
{sim:/lrl_xoff_control/power_up_rst_n } \
{sim:/lrl_xoff_control/rx_clk } \
{sim:/lrl_xoff_control/tx_clk } \
{sim:/lrl_xoff_control/iclk_2 }
add wave -noupdate -radix hexadecimal \
{sim:/lrl_xoff_control/lrl } \
{sim:/lrl_xoff_control/lrl_sync }
add wave -noupdate {sim:/lrl_xoff_control/los_tx } 
add wave -noupdate \
{sim:/lrl_xoff_control/ftk_xoff_ena } \
{sim:/lrl_xoff_control/ftk_ack_counting } \
{sim:/lrl_xoff_control/ack_out/cnt} \
{sim:/lrl_xoff_control/ftk_send_ack } \
{sim:/lrl_xoff_control/pres_state }


force -freeze sim:/lrl_xoff_control/ureset_n 1 0ns, 1 20ns
force -freeze sim:/lrl_xoff_control/LOS 0 0ns
force -freeze sim:/lrl_xoff_control/power_up_rst_n 0 0ns, 1 20ns
force -freeze sim:/lrl_xoff_control/tx_clk 0 0ns, 1 5ns -repeat 10ns
force -freeze sim:/lrl_xoff_control/rx_clk 0 0ns, 1 5ns -repeat 10ns
force -freeze sim:/lrl_xoff_control/iclk_2 0 0ns, 1 10ns -repeat 20ns

# ENABLE FTK XOFF:  d1e2 a3d4 b5a6 b7e8
force -freeze sim:/lrl_xoff_control/lrl 16#F 0ns, 16#d 25ns, 16#1 225ns, 16#e 425ns, 16#2 600ns
force -freeze sim:/lrl_xoff_control/lrl 16#a 805ns, 16#3 1005ns, 16#d 1205ns, 16#4 1405ns
if {$mode == "default"} {
	force -freeze sim:/lrl_xoff_control/lrl 16#b 1605ns, 16#5 1805ns, 16#a 2005ns, 16#6 2205ns
} elseif {$mode == "debug"} {
	force -freeze sim:/lrl_xoff_control/lrl 16#b 1605ns, 16#5 1805ns, 16#a 2005ns, 16#9 2205ns
} else {
	force -freeze sim:/lrl_xoff_control/lrl 16#b 1605ns, 16#c 1805ns, 16#a 2005ns, 16#6 2205ns	
}
force -freeze sim:/lrl_xoff_control/lrl 16#0 2405ns
force -freeze sim:/lrl_xoff_control/lrl 16#b 2605ns, 16#7 2805ns, 16#e 3005ns, 16#8 3505ns

force -freeze sim:/lrl_xoff_control/lrl 16#c 3705ns
force -freeze sim:/lrl_xoff_control/lrl 16#f 4000ns

run 4300 ns
view wave
update
WaveRestoreZoom {0 ps} {4310 ns}
