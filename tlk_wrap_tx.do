quit -sim
vcom -93 -work work {disparity_lookup.vhd}
vcom -93 -work work {tlk_wrap_tx.vhd}

vsim work.tlk_wrap_tx(structure)
delete wave *
add wave -noupdate {sim:/tlk_wrap_tx/reset } {sim:/tlk_wrap_tx/tx_clk } {sim:/tlk_wrap_tx/tx_en } {sim:/tlk_wrap_tx/tx_er }
add wave -noupdate -radix hexadecimal {sim:/tlk_wrap_tx/td } {sim:/tlk_wrap_tx/tx_datain }
add wave -noupdate {sim:/tlk_wrap_tx/tx_ctrlenable } {sim:/tlk_wrap_tx/tx_dispval } \
	{sim:/tlk_wrap_tx/curdisp } {sim:/tlk_wrap_tx/dispflip_d } {sim:/tlk_wrap_tx/do_flip }

force -freeze /tlk_wrap_tx/reset 1 0ns, 0 7ns
force -freeze /tlk_wrap_tx/tx_clk  0 0ns, 1 5ns -repeat 10ns

force -freeze /tlk_wrap_tx/tx_en 0 0ns, 0 20ns, 1 30ns, 1       40ns, 0 50ns, 1       80ns, 0 100ns, 1       140ns
force -freeze /tlk_wrap_tx/tx_er 0 0ns, 1 20ns, 1 30ns, 0       40ns, 0 50ns, 0       80ns, 0 100ns, 0       140ns
force -freeze /tlk_wrap_tx/td    16#ABCD 0ns,           16#0003 40ns,         16#FBFB 80ns,         16#0003 80ns

#    5ns      15ns    25ns    35ns   45ns   55ns     65ns
# - 50*BC* - 50*BC* - F7F7 - FEFE - 0003* + C5BC* -  50BC*
#								

run 130ns
view wave
update
