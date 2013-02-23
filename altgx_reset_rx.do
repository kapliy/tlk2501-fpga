quit -sim
vlib work
vlib gate_work

# compile altera components
vcom -93 -work work {altgx_reset.vhd}

vsim -GTLTD=4 work.altgx_reset_rx

delete wave *

add wave -noupdate \
{sim:/altgx_reset_rx/clk } \
{sim:/altgx_reset_rx/power_up_rst_n } \
{sim:/altgx_reset_rx/tx_ready } \
{sim:/altgx_reset_rx/busy } \
{sim:/altgx_reset_rx/rx_freqlocked }
add wave -noupdate -divider divider
add wave -noupdate \
{sim:/altgx_reset_rx/rx_digitalreset } \
{sim:/altgx_reset_rx/rx_analogreset }
add wave -noupdate -divider divider
add wave -noupdate \
{sim:/altgx_reset_rx/busy_cleared } \
{sim:/altgx_reset_rx/wait_done} \
{sim:/altgx_reset_rx/pres_state }

force -freeze sim:/altgx_reset_rx/tx_ready 0 0ns, 1 22ns
force -freeze sim:/altgx_reset_rx/power_up_rst_n 0 0ns, 1 20ns
force -freeze sim:/altgx_reset_rx/clk 0 0ns, 1 10ns -repeat 20ns
force -freeze sim:/altgx_reset_rx/busy 1 0ns, 0 40ns
force -freeze sim:/altgx_reset_rx/rx_freqlocked 0 0ns, 1 125ns

run 500 ns
view wave
update
