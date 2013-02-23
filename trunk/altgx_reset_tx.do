quit -sim
vlib work
vlib gate_work

# compile altera components
vcom -93 -work work {altgx_reset.vhd}

vsim work.altgx_reset_tx

delete wave *

add wave -noupdate \
{sim:/altgx_reset_tx/clk } \
{sim:/altgx_reset_tx/power_up_rst_n } \
{sim:/altgx_reset_tx/pll_locked }
add wave -noupdate -divider divider
add wave -noupdate \
{sim:/altgx_reset_tx/pll_areset } \
{sim:/altgx_reset_tx/tx_digitalreset }
add wave -noupdate -divider divider
add wave -noupdate \
{sim:/altgx_reset_tx/pres_state }

force -freeze sim:/altgx_reset_tx/power_up_rst_n 0 0ns, 1 20ns
force -freeze sim:/altgx_reset_tx/clk 0 0ns, 1 10ns -repeat 20ns
force -freeze sim:/altgx_reset_tx/pll_locked 0 0ns, 1 80ns

run 500 ns
view wave
update
