-- A wrapper around ALTGX receiver that (partially) implements TLK2501 protocol

LIBRARY work;
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL; -- for comparison operator

ENTITY tlk_wrap_rx IS
	PORT (
		-- reset
		RESET : IN STD_LOGIC;
		-- from ALTGX
		rx_clkout : IN STD_LOGIC;
		rx_dataout : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		rx_ctrldetect : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
		rx_errdetect  : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
		rx_byteorderalignstatus : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
		-- to LSC/LDC core
		RXD : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		RX_ER : OUT STD_LOGIC;
		RX_DV : OUT STD_LOGIC
		);
END tlk_wrap_rx;

ARCHITECTURE structure OF tlk_wrap_rx IS
	-- Signals that summarize the state of ALTGX receiver terminal
	SIGNAL data_invalid : STD_LOGIC;
	SIGNAL data_carrier : STD_LOGIC;
	SIGNAL data_error : STD_LOGIC;
	SIGNAL data_idle : STD_LOGIC;
	SIGNAL data_normal : STD_LOGIC;
	-- Special character code values (rightmost bit is LSB)
	CONSTANT ONES8 : STD_LOGIC_VECTOR := "11111111";
	CONSTANT ZERO8 : STD_LOGIC_VECTOR := "00000000";
	CONSTANT K23p7 : STD_LOGIC_VECTOR := "11110111";
	CONSTANT K28p5 : STD_LOGIC_VECTOR := "10111100";
	CONSTANT K30p7 : STD_LOGIC_VECTOR := "11111110";
	CONSTANT D5p6  : STD_LOGIC_VECTOR := "11000101";
	CONSTANT D16p2 : STD_LOGIC_VECTOR := "01010000";
	-- TLK-2501 keywords (rightmost byte is sent first)
	CONSTANT IDLE1 : STD_LOGIC_VECTOR   := D5p6 & K28p5;    --K25.8, D5.6
	CONSTANT IDLE2 : STD_LOGIC_VECTOR   := D16p2 & K28p5;   --K28.5, D16.2
	CONSTANT CARRIER : STD_LOGIC_VECTOR := K23p7 & K23p7;   --K23.7, K23.7
	CONSTANT GXERR : STD_LOGIC_VECTOR   := K30p7 & K30p7;   --K30.7, K30.7
	CONSTANT ONES16 : STD_LOGIC_VECTOR  := ONES8 & ONES8;   -- dummy all-ones pattern
BEGIN

-- parse the data on the receive terminal: data[16], control, and error status from ALTGX
data_invalid <= rx_errdetect(0) OR rx_errdetect(1) OR (not rx_byteorderalignstatus(0));
data_carrier <= '1' WHEN (rx_dataout = CARRIER AND rx_ctrldetect = "11") ELSE '0';
data_error <= '1' WHEN (rx_dataout = GXERR AND rx_ctrldetect = "11") ELSE '0';
data_idle <= '1' WHEN ( (rx_dataout = IDLE1 OR rx_dataout = IDLE2) AND rx_ctrldetect = "01") ELSE '0';
data_normal <= NOT (data_carrier OR data_error OR data_idle);
	
-- form TLK RX* signals
delay_process: PROCESS(RESET,rx_clkout)
BEGIN
	IF (RESET = '1') THEN  -- async reset
		RXD <= ONES16;
		RX_DV <= '1';
		RX_ER <= '1';
	ELSIF (rx_clkout='1') and (rx_clkout'event) THEN
		-- note that we do not implement most of TLK protocol for receiver data bus
		RXD <= rx_dataout;
		CASE data_invalid IS
			WHEN '1' =>
				RX_DV <= '1';
				RX_ER <= '1';
			WHEN '0' =>
				RX_DV <= (data_normal OR data_error);
				RX_ER <= (data_carrier OR data_error);
			WHEN others =>
				null;
		END CASE;
	END IF;
END PROCESS;

END structure;
