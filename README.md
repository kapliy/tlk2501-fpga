# tlk2501-fpga
Automatically exported from code.google.com/p/tlk2501-fpga

TLK2501 is a dedicated transceiver from Texas Instruments used in many legacy systems. It encodes each byte of the 16-bit parallel input via 8b/10b and then serializes the 20-bit word at 2-2.5 GHz.

Today, transceivers are usually hosted inside the FPGA. This small project provides several VHDL classes that implement the TLK2501 transmitter and receiver interface in the FPGA fabric that allows FPGAs to communicate directly with TLK2501. This interface was utilized in the 2011-2012 trigger upgrades for the ATLAS experiment at the Large Hadron Collider.

Everything was tested with the Altera Cyclone-IV FPGA in Quartus 11.1 and Altera-Modelsim. Note that the code for the actual Cyclone IV transceiver and its reconfiguration block (generated with Altera's megafunction wizard) could not be included due to licensing restrictions by Altera Corp.

vhd files contain the actual firmware code. do files are Modelsim TCL scripts that set up and run a simple testbench for each component.

List of entities:

* altgx_reset.vhd - a reset state machine for Cyclone IV transceivers.
* disparity_lookup.vhd - a quick disparity lookup table for 8b/10b encoding
* tlk_wrap_tx.vhd - a wrapper for the transmission part of TLK2501 protocol
* tlk_wrap_tx_simple.vhd - a simplified version of the above, which does not send alternating the IDLEs (IDLE1 and IDLE2) in the same way TLK2501 does.
* tlk_wrap_rx.vhd - a wrapper for the reception part of TLK2501 protocol
* tlk_byte_order.vhd - a byte ordering block to align word boundary across two bytes of a 16-bit word
* altgx_tlk_single.vhd - an example of how to connect all components to emulate TLK2501 in the FPGA. Note that you would need to generate your own megafunctions for Altera transceivers.
