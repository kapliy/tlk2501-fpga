quit -sim
vcom -93 -work work {tlk_byte_order.vhd}

vsim work.tlk_byte_order(structure)
delete wave *
add wave -noupdate {sim:/tlk_byte_order/pres_state } 
add wave -noupdate {sim:/tlk_byte_order/reset } {sim:/tlk_byte_order/clk } {sim:/tlk_byte_order/rx_syncstatus }
add wave -noupdate -radix hexadecimal {sim:/tlk_byte_order/datain }
add wave -noupdate {sim:/tlk_byte_order/ctrlin} {sim:/tlk_byte_order/errin }

add wave -noupdate -divider outputs
add wave -noupdate -radix hexadecimal {sim:/tlk_byte_order/dataout }
add wave -noupdate {sim:/tlk_byte_order/ctrlout} {sim:/tlk_byte_order/errout}
add wave -noupdate {sim:/tlk_byte_order/status }

add wave -noupdate -divider debug
add wave -noupdate \
{sim:/tlk_byte_order/ctrl_nopad } \
{sim:/tlk_byte_order/ctrl_pad }

add wave -noupdate -radix hexadecimal \
{sim:/tlk_byte_order/pattern_nopad } \
{sim:/tlk_byte_order/pattern_pad }


force -freeze /tlk_byte_order/reset 1 0ns, 0 7ns
force -freeze /tlk_byte_order/clk  0 0ns, 1 5ns -repeat 10ns
force -freeze /tlk_byte_order/rx_syncstatus  0 0ns, 1 20ns, 0 100ns, 1 130ns

force -freeze /tlk_byte_order/datain  16#0000 0ns, 16#BCBC 10ns, 16#AAC5 60ns, 16#50BC 160ns
force -freeze /tlk_byte_order/ctrlin       00 0ns,      11 10ns,      00 60ns,      01 160ns
force -freeze /tlk_byte_order/errin  00 0ns

run 220ns
view wave
update
