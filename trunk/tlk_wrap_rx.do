quit -sim
vcom -93 -work work {tlk_wrap_rx.vhd}

vsim work.tlk_wrap_rx(structure)
delete wave *
add wave -noupdate {sim:/tlk_wrap_rx/reset } {sim:/tlk_wrap_rx/rx_clkout }
add wave -noupdate -radix hexadecimal {sim:/tlk_wrap_rx/rx_dataout }
add wave -noupdate {sim:/tlk_wrap_rx/rx_ctrldetect } {sim:/tlk_wrap_rx/rx_errdetect } \
{sim:/tlk_wrap_rx/rx_byteorderalignstatus } \
{sim:/tlk_wrap_rx/rx_er } {sim:/tlk_wrap_rx/rx_dv } 
add wave -noupdate -radix hexadecimal {sim:/tlk_wrap_rx/rxd}

add wave -noupdate \
{sim:/tlk_wrap_rx/data_invalid } \
{sim:/tlk_wrap_rx/data_carrier } \
{sim:/tlk_wrap_rx/data_error } \
{sim:/tlk_wrap_rx/data_idle } \
{sim:/tlk_wrap_rx/data_normal } 

force -freeze /tlk_wrap_rx/reset 1 0ns, 0 7ns
force -freeze /tlk_wrap_rx/rx_clkout  0 0ns, 1 5ns -repeat 10ns
force -freeze /tlk_wrap_rx/rx_byteorderalignstatus 1 1ns

force -freeze /tlk_wrap_rx/rx_errdetect            00      0ns,           00      40ns,         10      80ns,         00      90ns
force -freeze /tlk_wrap_rx/rx_ctrldetect           00      0ns,           01      40ns,         00      80ns,         16#0003 90ns
force -freeze /tlk_wrap_rx/rx_dataout              16#ABCD 0ns,           16#50BC 40ns,         16#AAAA 80ns,         16#ABCD 90ns


#force -freeze /tlk_wrap_rx/rx_dv 0 0ns, 0 20ns, 1 30ns, 1       40ns, 0 50ns, 1       80ns, 0 100ns, 1       140ns
#force -freeze /tlk_wrap_rx/rx_er 0 0ns, 1 20ns, 1 30ns, 0       40ns, 0 50ns, 0       80ns, 0 100ns, 0       140ns
#    5ns      15ns    25ns    35ns   45ns   55ns     65ns
# - 50*BC* - 50*BC* - F7F7 - FEFE - 0003* + C5BC* -  50BC*
#								

run 130ns
view wave
update
