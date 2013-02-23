quit -sim
vcom -93 -work work {D:/quartus_tang_10p1/disparity_lookup.vhd}

vsim work.disparity_lookup(structure)
delete wave *
add wave -noupdate {sim:/disparity_lookup/clk_in} {sim:/disparity_lookup/dispflip_out}
add wave -noupdate -radix hexadecimal {sim:/disparity_lookup/data_in}

force -freeze /disparity_lookup/clk_in  0 0ns, 1 5ns -repeat 10ns
force -freeze /disparity_lookup/data_in 16#00 0ns, 16#01 23ns, 16#03 43ns, 16#04 47ns
run 100ns
view wave
update
