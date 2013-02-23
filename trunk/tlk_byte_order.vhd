-- A byte-ordering block to establish the order of two bytes
-- using an /IDLE1/ or /IDLE2/ 16-byte patterns, per IEEE std.
-- This block should sit between altgx and tlk_wrap_rx.
-- Output is twice-pipelined to guarantee proper byte-alignment.
-- Note that this FSM is (re-)started when the reset controller 
-- reports that rx circuitry is ready (e.g, on raising edge of rx_syncstatus)

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

entity tlk_byte_order is
port (
	clk             : in  std_logic;  -- recovered clock
	reset           : in  std_logic;  -- power-up reset (active-high)
	rx_syncstatus   : in  std_logic;  -- is byte boundary locked?
	-- data from the serdes link:
	datain          : in  std_logic_vector(15 downto 0);
	ctrlin          : in  std_logic_vector(1 downto 0);
	errin           : in  std_logic_vector(1 downto 0);
	-- pipelined and byte-ordered output:
	dataout         : out std_logic_vector(15 downto 0);
	ctrlout         : out std_logic_vector(1 downto 0);
	errout          : out std_logic_vector(1 downto 0);
	status          : out std_logic_vector(0 downto 0);
	debug_st        : out std_logic_vector (1 downto 0) -- will be synthesized away if not used
);
end tlk_byte_order;

architecture structure of tlk_byte_order is
	-- fsm
	type state_type is (IDLE, LOOKING, LOCKED_NOPAD, LOCKED_PAD);
	signal pres_state, next_state : state_type;
	-- synchronization registers
	signal rx_syncstatus0, rx_syncstatus1 : std_logic;
	signal data0, data1 : std_logic_vector(15 downto 0);
	signal ctrl0, ctrl1 : std_logic_vector(1 downto 0);
	signal err0, err1   : std_logic_vector(1 downto 0);
	-- outputs just before they are registered off
	signal dataout_sig : std_logic_vector(15 downto 0);
	signal ctrlout_sig : std_logic_vector(1 downto 0);
	signal errout_sig  : std_logic_vector(1 downto 0);
	signal status_sig  : std_logic_vector(0 downto 0);
	-- other signals
	signal pattern_nopad, pattern_pad : std_logic_vector(15 downto 0);
	signal ctrl_nopad, ctrl_pad : std_logic_vector(1 downto 0);
	signal err_nopad, err_pad : std_logic_vector(1 downto 0);
	signal found_boundary : std_logic_vector(1 downto 0);
	-- constants
	CONSTANT ZERO8 : STD_LOGIC_VECTOR := "00000000";
	CONSTANT K28p5 : STD_LOGIC_VECTOR := "10111100";
	CONSTANT D5p6  : STD_LOGIC_VECTOR := "11000101";
	CONSTANT D16p2 : STD_LOGIC_VECTOR := "01010000";
	-- TLK-2501 keywords (rightmost byte is sent first)
	CONSTANT ZEROS : STD_LOGIC_VECTOR   := ZERO8 & ZERO8;
	CONSTANT IDLE1 : STD_LOGIC_VECTOR   := D5p6 & K28p5;    --K25.8, D5.6
	CONSTANT IDLE2 : STD_LOGIC_VECTOR   := D16p2 & K28p5;   --K28.5, D16.2
begin

-- parallel assignments
pattern_nopad <= data0;
pattern_pad   <= data1(7 DOWNTO 0) & data0(15 DOWNTO 8);
ctrl_nopad    <= ctrl0;
ctrl_pad      <= ctrl1(0) & ctrl0(1);
err_nopad     <= err0;
err_pad       <= err1(0) & err0(1);

-- FSM and other sequential logic
order_fsm : process (clk, reset)
begin
	if reset = '1' then  -- asynchronous reset (active high)
		pres_state <= IDLE;
		rx_syncstatus0 <= '0';
		rx_syncstatus1 <= '0';
		data0 <= ZEROS;
		data1 <= ZEROS;
		ctrl0 <= "00";
		ctrl1 <= "00";
		err0  <= "11";
		err1  <= "11";
	elsif clk'event and clk = '1' then  -- rising clock edge
		pres_state <= next_state;
		rx_syncstatus1 <= rx_syncstatus;
		rx_syncstatus0 <= rx_syncstatus1;
		data1 <= datain;
		data0 <= data1;
		ctrl1 <= ctrlin;
		ctrl0 <= ctrl1;
		err1  <= errin;
		err0  <= err1;
	end if;
end process order_fsm;

-- register off outputs
register_process : process (clk, reset)
begin
	if reset = '1' then  -- asynchronous reset (active high)
		dataout <= ZEROS;
		ctrlout <= "00";
		errout <= "11";
		status(0) <= '0';
	elsif clk'event and clk = '1' then  -- rising clock edge
		dataout <= dataout_sig;
		ctrlout <= ctrlout_sig;
		errout <= errout_sig;
		status <= status_sig;
	end if;
end process register_process;

-- FSM combinational logic
fsm_comb : process (pres_state, rx_syncstatus0, found_boundary)
begin
	next_state <= pres_state;
	case pres_state is
		when IDLE =>
			if rx_syncstatus0 = '1' then
				next_state <= LOOKING;
			end if;
		when LOOKING =>
			if rx_syncstatus0 = '0' then
				next_state <= IDLE;
			elsif found_boundary = "01" then
				next_state <= LOCKED_NOPAD;
			elsif found_boundary = "10" then
				next_state <= LOCKED_PAD;
			end if;
		when LOCKED_NOPAD =>
			if (rx_syncstatus0 = '0') then
				next_state <= IDLE;
			end if;
		when LOCKED_PAD =>
			if (rx_syncstatus0 = '0') then
				next_state <= IDLE;
			end if;
		when others => 
			next_state <= IDLE;
	end case;
end process fsm_comb;

-- FSM output multiplexer
out_mux : process (pres_state, err_nopad, err_pad, ctrl_nopad, ctrl_pad, pattern_nopad, pattern_pad)
begin
	case pres_state is	
		when IDLE =>
			status_sig(0) <= '0';
			dataout_sig <= ZEROS;
			ctrlout_sig <= "00";
			errout_sig  <= "11";
			debug_st <= "00";
		when LOOKING =>
			status_sig(0) <= '0';
			dataout_sig <= ZEROS;
			ctrlout_sig <= "00";
			errout_sig  <= "11";
			debug_st <= "01";
		when LOCKED_NOPAD =>
			status_sig(0) <= '1';
			dataout_sig <= pattern_nopad;
			ctrlout_sig <= ctrl_nopad;
			errout_sig  <= err_nopad;
			debug_st <= "10";
		when LOCKED_PAD =>
			status_sig(0) <= '1';
			dataout_sig <= pattern_pad;
			ctrlout_sig <= ctrl_pad;
			errout_sig  <= err_pad;
			debug_st <= "11";
		when others => null;
	end case;
end process out_mux;

-- Looking for the pattern
look_proc : process (clk, reset, pres_state, err_nopad, err_pad, ctrl_nopad, ctrl_pad, pattern_nopad, pattern_pad)
begin
	if reset = '1' then
		found_boundary <= "00";
	elsif clk'event and clk = '1' then  -- rising clock edge
		if not (pres_state = LOOKING) then
			found_boundary <= "00";
		else			
			if err_nopad = "00" and ctrl_nopad = "01" and (pattern_nopad = IDLE1 or pattern_nopad = IDLE2) then
				found_boundary <= "01";
			elsif err_pad = "00" and ctrl_pad = "01" and (pattern_pad = IDLE1 or pattern_pad = IDLE2) then
				found_boundary <= "10";
			else
				found_boundary <= "00";
			end if;
		end if;
	end if;
end process look_proc;

end structure;
