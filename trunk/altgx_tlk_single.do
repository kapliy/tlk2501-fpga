quit -sim

# compile altera components
vcom -93 -work work {altgx_reco_single.vhd}
vcom -93 -work work {altgx_single.vhd}

# compile altgx wrappers
vcom -93 -work work {disparity_lookup.vhd}
vcom -93 -work work {tlk_wrap_tx.vhd}
vcom -93 -work work {tlk_wrap_rx.vhd}
vcom -93 -work work {tlk_byte_order.vhd}
vcom -93 -work work {altgx_reset.vhd}
vcom -93 -work work {altgx_tlk_single.vhd}

vsim -GSIMULATION=1 work.altgx_tlk_single(structure)

delete wave *

# general transmitter ports
add wave -noupdate \
{sim:/altgx_tlk_single/slowclk } \
{sim:/altgx_tlk_single/refclk } \
{sim:/altgx_tlk_single/power_up_rst_n } \
{sim:/altgx_tlk_single/gx_inst/pll_locked }

add wave -noupdate -divider transmit
add wave -noupdate \
{sim:/altgx_tlk_single/tx_clk } \
{sim:/altgx_tlk_single/tx_en } \
{sim:/altgx_tlk_single/tx_er }
add wave -noupdate -radix hexadecimal \
{sim:/altgx_tlk_single/txd }

add wave -noupdate -divider tx_wrap
add wave -noupdate \
{sim:/altgx_tlk_single/tx_wrap/tx_dispval } \
{sim:/altgx_tlk_single/tx_wrap/tx_ctrlenable } \
{sim:/altgx_tlk_single/tx_wrap/curdisp } \
{sim:/altgx_tlk_single/tx_wrap/do_flip } \
{sim:/altgx_tlk_single/tx_wrap/dispflip_d } 
add wave -noupdate -radix hexadecimal \
sim:/altgx_tlk_single/gx_inst/altgx_single_alt_c3gxb_component/transmit_pma0/datain
add wave -noupdate {sim:/altgx_tlk_single/gxb_tx0 }

# general receiver ports
add wave -noupdate -divider receive
add wave -noupdate \
{sim:/altgx_tlk_single/rx_clk0 } \
{sim:/altgx_tlk_single/rx_locked0 } \
{sim:/altgx_tlk_single/rx_er0 } \
{sim:/altgx_tlk_single/rx_dv0 }
add wave -noupdate -radix hexadecimal \
{sim:/altgx_tlk_single/rxd0 }
add wave -noupdate {sim:/altgx_tlk_single/gxb_rx0 }

# clocks
force -freeze /altgx_tlk_single/REFCLK  0 0ns, 1 5ns -repeat 10ns
force -freeze /altgx_tlk_single/SLOWCLK  0 0ns, 1 10ns -repeat 20ns
force -freeze /altgx_tlk_single/POWER_UP_RST_N 0 0ns, 1 18ns

# transmit
force -freeze /altgx_tlk_single/txd    16#0000 0ns
force -freeze /altgx_tlk_single/tx_en 0 0ns, 0 170ns, 1 190ns, 1       220ns, 0 250ns, 1       280ns, 0 320ns, 1       350ns
force -freeze /altgx_tlk_single/tx_er 0 0ns, 1 170ns, 1 190ns, 0       220ns, 0 250ns, 0       280ns, 0 320ns, 0       350ns
force -freeze /altgx_tlk_single/txd    16#ABCD 100ns,          16#0003 220ns,         16#FBFB  280ns,         16#0003  350ns


#    5ns      15ns    25ns    35ns   45ns   55ns     65ns
# - 50*BC* - 50*BC* - F7F7 - FEFE - 0003* + C5BC* -  50BC*
#								

run 700ns
view wave
update
