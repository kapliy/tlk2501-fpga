-- A special FTK feature that allows to disable XOFF functionality on FTK channel
-- by sending a special pattern through the return lines (LRL)
-- ENABLE FTK XOFF (NORMAL):  d1e2 a3d4 b5a6 b7e8
-- ENABLE FTK XOFF (DEBUG) :  d1e2 a3d4 b5a9 b7e8
-- DISABLE                 :  ffff
-- "0", or same-pattern, have no effect. Otherwise, it drops down to RESET
-- "F" immediately drops down to RESET
-- FTK_SEND_ACK signal goes online for up to 10 clock cycles
-- during the programming of the DEBUG FTK_XOFF_ENA pattern
-- to provide acknowledgement to FTK_IM mezzanine.

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

entity lrl_xoff_control is
generic(
	LRL_STABLE_LENGTH : integer :=    5   -- how long LRL must be stable to be registered?
);
port (
	POWER_UP_RST_N  : in  std_logic;
	URESET_N        : in  std_logic;
	LOS             : in  std_logic;  -- Loss-of-signal from the optical transceiver
	RX_CLK          : in  std_logic;  -- (100 MHz) - to operate the state machine
	TX_CLK          : in  std_logic;  -- (100 MHz) - to synchronize FTK_SEND_ACK
	ICLK_2          : in  std_logic;  -- (50 MHz)  - to synchronize FTK_XOFF_ENA
	LRL             : in  std_logic_vector(3 downto 0);
	FTK_XOFF_ENA    : out std_logic;
	FTK_SEND_ACK    : out std_logic
);
end lrl_xoff_control;

architecture structure of lrl_xoff_control is
	type state_type is (RESET,S1,S2,S3,S4,S5,S6,S7,S8,S9,S10,S11,S12,S13,S14,S15,D12,D13,D14,D15,READY);
	signal pres_state, next_state : state_type;
	attribute syn_encoding : string;
	attribute syn_encoding of state_type : type is "safe";
	signal ftk_ack_counting : std_logic;
	-- input registers for URESET (to synchronize with RX clock)
	signal ureset_n_rx1,ureset_n_rx : std_logic;
	-- input registers for LOS (to synchronize with TX clock)
	signal LOS_tx1,LOS_tx : std_logic;
	-- input registers for lrl glitch filtering
	signal lrl_d : std_logic_vector(3 downto 0);
	signal lrl_sync : std_logic_vector(3 downto 0); -- synchronized version across N clock cycles
	-- output registers for FTK_SEND_ACK (to TX_CLK)
	signal ftk_send_ack_sig, ftk_send_ack_tx1 : std_logic;
	-- output registers for FTK_XOFF_ENA (to ICLK_2)
	signal ftk_xoff_ena_sig, ftk_xoff_ena_i1 : std_logic;
begin

-- synchronize to RX_CLK
ureset_sync_rx : process(RX_CLK,POWER_UP_RST_N)
begin
	if POWER_UP_RST_N = '0' then  -- asynchronous reset (active low)
		ureset_n_rx1 <= '0';
		ureset_n_rx  <= '0';
	elsif RX_CLK'event and RX_CLK='1' then
		ureset_n_rx1 <= URESET_N;
		ureset_n_rx  <= ureset_n_rx1;
	end if;
end process ureset_sync_rx;

-- synchronize to TX_CLK
los_sync_tx : process(TX_CLK,POWER_UP_RST_N)
begin
	if POWER_UP_RST_N = '0' then  -- asynchronous reset (active low)
		LOS_tx1 <= '0';
		LOS_tx  <= '0';
	elsif TX_CLK'event and TX_CLK='1' then
		LOS_tx1 <= LOS;
		LOS_tx  <= LOS_tx1;
	end if;
end process los_sync_tx;

-- FSM sequential logic
lrl_fsm : process (RX_CLK, POWER_UP_RST_N)
begin
	if POWER_UP_RST_N = '0' then  -- asynchronous reset (active low)
		pres_state <= RESET;
	elsif RX_CLK'event and RX_CLK = '1' then  -- rising clock edge
		if ureset_n_rx = '0' then    -- synchronous reset
			pres_state <= RESET;
		else
			pres_state <= next_state;
		end if;
	end if;
end process lrl_fsm;

-- LRL glitch filtering (needed for FILAR, but optional for FTK_IM)
-- Basically, we only update lrl_sync if LRL has been stable for N clock cycles
lrl_filt : process (RX_CLK, POWER_UP_RST_N)
	variable cnt: integer range 0 to LRL_STABLE_LENGTH :=0;
begin
	if POWER_UP_RST_N = '0' then  -- asynchronous reset (active low)
		cnt := 0;
		lrl_d <= "0000";
		lrl_sync <= "0000";
	elsif RX_CLK'event and RX_CLK = '1' then  -- rising clock edge
		lrl_d <= LRL;
		-- same count as last tick: increment counter
		if LRL = lrl_d then
			if cnt<LRL_STABLE_LENGTH then
				cnt := cnt + 1;
				-- don't update LRL until it's been stable for 50 cycles
				lrl_sync <= "0000";
			else
				lrl_sync <= LRL;
			end if;
		-- new value: reset counter
		else
			cnt := 0;
			lrl_sync <= "0000";
		end if;
	end if;
end process lrl_filt;

-- FSM combinational logic
fsm_comb : process (pres_state,lrl_sync)
begin
	next_state <= RESET;
	case pres_state is
		-- d1e2 a3d4 b5a6 b7e8
		when RESET =>
			if lrl_sync = x"d" then
				next_state <= S1;
			end if;
		when S1 =>
			if lrl_sync = x"1" then
				next_state <= S2;
			elsif lrl_sync = x"0" or lrl_sync = x"d" then
				next_state <= pres_state;				
			end if;
		when S2 =>
			if lrl_sync = x"e" then
				next_state <= S3;
			elsif lrl_sync = x"0" or lrl_sync = x"1" then
				next_state <= pres_state;
			end if;
		when S3 =>
			if lrl_sync = x"2" then
				next_state <= S4;
			elsif lrl_sync = x"0" or lrl_sync = x"e" then
				next_state <= pres_state;
			end if;
		when S4 =>
			if lrl_sync = x"a" then
				next_state <= S5;
			elsif lrl_sync = x"0" or lrl_sync = x"2" then
				next_state <= pres_state;
			end if;
		when S5 =>
			if lrl_sync = x"3" then
				next_state <= S6;
			elsif lrl_sync = x"0" or lrl_sync = x"a" then
				next_state <= pres_state;
			end if;
		when S6 =>
			if lrl_sync = x"d" then
				next_state <= S7;
			elsif lrl_sync = x"0" or lrl_sync = x"3" then
				next_state <= pres_state;
			end if;
		when S7 =>
			if lrl_sync = x"4" then
				next_state <= S8;
			elsif lrl_sync = x"0" or lrl_sync = x"d" then
				next_state <= pres_state;
			end if;
		when S8 =>
			if lrl_sync = x"b" then
				next_state <= S9;
			elsif lrl_sync = x"0" or lrl_sync = x"4" then
				next_state <= pres_state;
			end if;
		when S9 =>
			if lrl_sync = x"5" then
				next_state <= S10;
			elsif lrl_sync = x"0" or lrl_sync = x"b" then
				next_state <= pres_state;
			end if;
		when S10 =>
			if lrl_sync = x"a" then
				next_state <= S11;
			elsif lrl_sync = x"0" or lrl_sync = x"5" then
				next_state <= pres_state;
			end if;
		-- this is where the LRL XOFF controller can detect a debug path
		-- (under debug path, FTK_XOFF_ENA is held high between now and READY)
		when S11 =>
			if lrl_sync = x"6" then
				next_state <= S12;
			elsif lrl_sync = x"9" then
				next_state <= D12;
			elsif lrl_sync = x"0" or lrl_sync = x"a" then
				next_state <= pres_state;
			end if;
		-- default pattern path:
		when S12 =>
			if lrl_sync = x"b" then
				next_state <= S13;
			elsif lrl_sync = x"0" or lrl_sync = x"6" then
				next_state <= pres_state;
			end if;
		when S13 =>
			if lrl_sync = x"7" then
				next_state <= S14;
			elsif lrl_sync = x"0" or lrl_sync = x"b" then
				next_state <= pres_state;
			end if;
		when S14 =>
			if lrl_sync = x"e" then
				next_state <= S15;
			elsif lrl_sync = x"0" or lrl_sync = x"7" then
				next_state <= pres_state;
			end if;
		when S15 =>
			if lrl_sync = x"8" then
				next_state <= READY;
			elsif lrl_sync = x"0" or lrl_sync = x"e" then
				next_state <= pres_state;
			end if;
		-- debug pattern path:
		when D12 =>
			if lrl_sync = x"b" then
				next_state <= D13;
			elsif lrl_sync = x"0" or lrl_sync = x"9" then
				next_state <= pres_state;
			end if;
		when D13 =>
			if lrl_sync = x"7" then
				next_state <= D14;
			elsif lrl_sync = x"0" or lrl_sync = x"b" then
				next_state <= pres_state;
			end if;
		when D14 =>
			if lrl_sync = x"e" then
				next_state <= D15;
			elsif lrl_sync = x"0" or lrl_sync = x"7" then
				next_state <= pres_state;
			end if;
		when D15 =>
			if lrl_sync = x"8" then
				next_state <= READY;
			elsif lrl_sync = x"0" or lrl_sync = x"e" then
				next_state <= pres_state;
			end if;
		when READY =>
			if lrl_sync = x"F" then
				next_state <= RESET;
			else
				next_state <= pres_state;
			end if;
		when others =>
			next_state <= RESET;
	end case;
end process fsm_comb;

-- FSM output multiplexer [with an extra register]
out_mux : process (pres_state, RX_CLK, POWER_UP_RST_N)
begin
	if POWER_UP_RST_N = '0' then  -- asynchronous reset (active low)
			FTK_XOFF_ENA_sig <= '0';
			ftk_ack_counting <= '0';
	elsif RX_CLK'event and RX_CLK = '1' then  -- rising clock edge
		FTK_XOFF_ENA_sig <= '0';
		ftk_ack_counting <= '0';
		case pres_state is	
			when READY =>
				FTK_XOFF_ENA_sig <= '1';
				ftk_ack_counting <= '0';
			when D15 =>
				FTK_XOFF_ENA_sig <= '0';
				ftk_ack_counting <= '1';
			when others => 
				FTK_XOFF_ENA_sig <= '0';
				ftk_ack_counting <= '0';
		end case;
	end if;
end process out_mux;

-- when we are in D15 state, set FTK_SEND_ACK for up to 10 clock cycles
ack_out : process (RX_CLK, POWER_UP_RST_N)
	variable cnt: integer range 0 to 10 :=0;
begin
	if POWER_UP_RST_N = '0' then  -- asynchronous reset (active low)
		FTK_SEND_ACK_sig <= '0';
	elsif RX_CLK'event and RX_CLK = '1' then  -- rising clock edge
		FTK_SEND_ACK_sig <= '0';
		if ftk_ack_counting = '1' then
			if cnt<10 then
				cnt := cnt + 1;
				FTK_SEND_ACK_sig <= '1';
			end if;
		else
		    cnt := 0;
		end if;
	end if;
end process ack_out;

-- synchronize FTK_SEND_ACK_sig to TX_CLK
sendack_sync : process(TX_CLK,POWER_UP_RST_N)
begin
	if POWER_UP_RST_N = '0' then  -- asynchronous reset (active low)
		FTK_SEND_ACK_tx1 <= '0';
		FTK_SEND_ACK     <= '0';
	elsif TX_CLK'event and TX_CLK = '1' then
		if LOS_tx = '1' then    -- synchronous reset
			FTK_SEND_ACK_tx1 <= '0';
			FTK_SEND_ACK     <= '0';
		else
			FTK_SEND_ACK_tx1 <= FTK_SEND_ACK_sig;
			FTK_SEND_ACK     <= FTK_SEND_ACK_tx1;
		end if;
	end if;
end process sendack_sync;

-- synchronize FTK_XOFF_ENA_sig to TX_CLK
xoffena_sync : process(ICLK_2,POWER_UP_RST_N)
begin
	if POWER_UP_RST_N = '0' then  -- asynchronous reset (active low)
		FTK_XOFF_ENA_i1 <= '0';
		FTK_XOFF_ENA     <= '0';
	elsif ICLK_2'event and ICLK_2 = '1' then
		FTK_XOFF_ENA_i1 <= FTK_XOFF_ENA_sig;
		FTK_XOFF_ENA     <= FTK_XOFF_ENA_i1;
	end if;
end process xoffena_sync;

end structure;
