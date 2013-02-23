-- A wrapper around ALTGX transmitter that (partially) implements TLK2501 protocol
-- When IDLE is requested, it sends /I1/ or /I2/
-- depending on current disparity (per Gigabit Ethernet Standard).

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL; -- for comparison operator

ENTITY tlk_wrap_tx IS
	PORT (
		-- reset
		RESET : IN STD_LOGIC;
		-- from LSC/LDC core
		TX_CLK : IN STD_LOGIC;
		TX_EN  : IN STD_LOGIC;
		TX_ER  : IN STD_LOGIC;
		TD     : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		-- to ALTGX
		tx_datain     : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		tx_ctrlenable : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
		tx_dispval    : OUT STD_LOGIC_VECTOR(1 DOWNTO 0)
	);
END tlk_wrap_tx;

ARCHITECTURE structure OF tlk_wrap_tx IS
	-- Register off the inputs
	SIGNAL TX_EN_REG, TX_ER_REG : STD_LOGIC;
	SIGNAL TD_REG : STD_LOGIC_VECTOR(15 DOWNTO 0);
	-- Signals
	SIGNAL curdisp : STD_LOGIC;
	SIGNAL do_flip : STD_LOGIC;
	SIGNAL DISPFLIP_D_0: STD_LOGIC;
	SIGNAL DISPFLIP_D_1: STD_LOGIC;
	SIGNAL DISPFLIP_D: STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL TX_BITS : STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL TX_BITS_D : STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL TD_LSB : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL TD_MSB : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL TD_D : STD_LOGIC_VECTOR(15 DOWNTO 0);
	-- Output signals just before they are registered
	SIGNAL tx_datain_sig : STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL tx_ctrlenable_sig : STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL tx_dispval_sig : STD_LOGIC_VECTOR(1 DOWNTO 0);
	-- Special character code values (rightmost bit is LSB and is sent first)
	CONSTANT ONES8 : STD_LOGIC_VECTOR := "11111111";
	CONSTANT ZERO8 : STD_LOGIC_VECTOR := "00000000";
	CONSTANT K23p7 : STD_LOGIC_VECTOR := "11110111";
	CONSTANT K28p5 : STD_LOGIC_VECTOR := "10111100";
	CONSTANT K30p7 : STD_LOGIC_VECTOR := "11111110";
	CONSTANT D5p6  : STD_LOGIC_VECTOR := "11000101";
	CONSTANT D16p2 : STD_LOGIC_VECTOR := "01010000";
	-- TLK-2501 keywords (rightmost byte is LSB and is sent first)
	CONSTANT IDLE1 : STD_LOGIC_VECTOR   := D5p6 & K28p5;    --K25.8, D5.6
	CONSTANT IDLE2 : STD_LOGIC_VECTOR   := D16p2 & K28p5;   --K28.5, D16.2
	CONSTANT CARRIER : STD_LOGIC_VECTOR := K23p7 & K23p7;   --K23.7, K23.7
	CONSTANT GXERR : STD_LOGIC_VECTOR   := K30p7 & K30p7;   --K30.7, K30.7
	CONSTANT ONES16 : STD_LOGIC_VECTOR  := ONES8 & ONES8;   -- dummy all-ones pattern
	
	-- Components
	COMPONENT disparity_lookup IS
	PORT
	(
		clk_in : in STD_LOGIC;
		data_in : in STD_LOGIC_VECTOR(7 downto 0);
		dispflip_out : out STD_LOGIC
	);
	END COMPONENT;
BEGIN

-- create a shortcut for TX_EN and TX_ER:
TX_BITS <= TX_EN_REG & TX_ER_REG;
-- split input data into two bytes:
TD_LSB <= TD_REG(7 DOWNTO 0);
TD_MSB <= TD_REG(15 DOWNTO 8);

-- register inputs;
-- delay inputs until disparity lookup is completed
delay_process: PROCESS(RESET,TX_CLK)
BEGIN
	IF (RESET = '1') THEN  -- async reset
		TX_EN_REG <= '0';
		TX_ER_REG <= '0';
		TD_REG <= ONES16;
		TX_BITS_D <= "00";
		TD_D <= ONES16;
		curdisp <= '1';  -- start in negative disparity
	ELSIF (TX_CLK = '1') and (TX_CLK'EVENT) THEN
		TX_EN_REG <= TX_EN;
		TX_ER_REG <= TX_ER;
		TD_REG <= TD;
		TX_BITS_D  <= TX_BITS;
		TD_D  <= TD_MSB & TD_LSB;
		-- see if the previous word flipped the running disparity
		-- (curdisp signifies starting disparity at word boundaries)
		IF (do_flip='1') THEN
			curdisp <= NOT curdisp;
		END IF;		
	END IF;
END PROCESS;

-- register off the outputs
register_process: PROCESS(RESET,TX_CLK)
BEGIN
	IF (RESET = '1') THEN  -- async reset
		tx_datain <= ONES16;
		tx_ctrlenable <= "00";
		tx_dispval <= "11";
	ELSIF (TX_CLK = '1') and (TX_CLK'EVENT) THEN
		tx_datain <= tx_datain_sig;
		tx_ctrlenable <= tx_ctrlenable_sig;
		tx_dispval <= tx_dispval_sig;
	END IF;
END PROCESS;

-- consult a LUT about the effect of a word on running disparity
-- dispflip_out=1 means the word flips disparity
-- Note1: disparity_lookup might be synthesized into altsyncram
-- Note2: the output is delayed until next clock
lsb_lookup : disparity_lookup PORT MAP(
	clk_in    => TX_CLK,
	data_in   => TD_LSB,
	dispflip_out  => DISPFLIP_D_0
);
msb_lookup : disparity_lookup PORT MAP(
	clk_in    => TX_CLK,
	data_in   => TD_MSB,
	dispflip_out  => DISPFLIP_D_1
);
DISPFLIP_D <= DISPFLIP_D_1 & DISPFLIP_D_0;

-- form inputs for the ALTGX transmitter
output_process: PROCESS(curdisp,DISPFLIP_D,TX_BITS_D,TD_D)
BEGIN
	-- LSB byte disparity is already known
	tx_dispval_sig(0) <= curdisp;
	-- default value for MSB byte disparity
	tx_dispval_sig(1) <= curdisp;
	-- default value for do_flip (whether disparity is flipped after this word)
	do_flip       <= '0';
	CASE TX_BITS_D IS
		WHEN "00" =>  -- idle
			IF curdisp='1' THEN
				-- negative running disparity after previous word -> send /I2/
				tx_datain_sig <= IDLE2;
				tx_ctrlenable_sig <= "01";
				tx_dispval_sig(1) <= NOT curdisp;
			ELSE
				-- positive running disparity after previous word -> send /I1/
				tx_datain_sig <= IDLE1;
				tx_ctrlenable_sig <= "01";
				tx_dispval_sig(1) <= NOT curdisp;
				do_flip <= '1';
			END IF;
		WHEN "01" =>  -- carrier extend
			tx_datain_sig <= CARRIER;
			tx_ctrlenable_sig <= "11";
		WHEN "11" =>  -- error propagation code
			tx_datain_sig <= GXERR;
			tx_ctrlenable_sig <= "11";
		WHEN "10" =>  -- normal data
			tx_datain_sig <= TD_D;
			tx_ctrlenable_sig <= "00";
			CASE DISPFLIP_D(0) IS
				WHEN '0' => tx_dispval_sig(1) <= curdisp;
				WHEN '1' => tx_dispval_sig(1) <= NOT curdisp;
				WHEN others => null;
			END CASE;
			do_flip <= DISPFLIP_D(0) XOR DISPFLIP_D(1);
		WHEN others =>
			null;
	END CASE;
END PROCESS;

END structure;
