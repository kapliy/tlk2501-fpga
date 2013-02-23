-- Reset machines for ALTGX on Cyclone IV
-- * POWER_UP_RST_N must be guaranteed for at least 1 microsecond
-- * tx and rx state machines are separated for convenience.
-- * All inputs are syncrhonized to clk and filtered against glitches

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

entity altgx_reset_tx is
port (
	clk             : in  std_logic;
	POWER_UP_RST_N  : in  std_logic;
	pll_locked      : in  std_logic_vector (0 downto 0);
	pll_areset      : out std_logic_vector (0 downto 0);
	tx_digitalreset : out std_logic_vector (0 downto 0);
	tx_ready        : out std_logic; -- for rx reset machine
	debug_st        : out std_logic_vector (1 downto 0) -- will be synthesized away if not used
);
end altgx_reset_tx;

architecture structure of altgx_reset_tx is
	type state_type is (STATE_RESET, STATE_PLLREADY, STATE_TXREADY);
	signal pres_state, next_state : state_type;
	attribute syn_encoding : string;
	attribute syn_encoding of state_type : type is "safe";
	-- synchronization registers
	signal pll_locked_d : std_logic_vector(4 downto 0);
	signal pll_locked_stable : std_logic;
begin

pll_areset(0) <= not POWER_UP_RST_N;

-- FSM sequential logic
reset_fsm : process (clk, POWER_UP_RST_N)
begin
	if POWER_UP_RST_N = '0' then  -- asynchronous reset (active low)
		pres_state <= STATE_RESET;
		pll_locked_d <= "00000";
		pll_locked_stable <= '0';
	elsif clk'event and clk = '1' then  -- rising clock edge
		pres_state <= next_state;
		pll_locked_d(0) <= pll_locked(0);
		pll_locked_d(1) <= pll_locked_d(0);
		pll_locked_d(2) <= pll_locked_d(1);
		pll_locked_d(3) <= pll_locked_d(2);
		pll_locked_d(4) <= pll_locked_d(3);
		pll_locked_stable <= pll_locked_d(4) and pll_locked_d(3) and pll_locked_d(2) and pll_locked_d(1);
	end if;
end process reset_fsm;

-- FSM combinational logic
fsm_comb : process (pres_state, pll_locked_stable)
begin
	next_state <= pres_state;
	case pres_state is
		when STATE_RESET =>
			if pll_locked_stable = '1' then
				next_state <= STATE_PLLREADY;
			end if;
		when STATE_PLLREADY =>
			next_state <= STATE_TXREADY;
		when STATE_TXREADY =>
			if pll_locked_stable = '0' then
				next_state <= STATE_RESET;
			end if;
		when others =>
			next_state <= STATE_RESET;
	end case;
end process fsm_comb;

-- FSM output multiplexer [with an extra register]
out_mux : process (pres_state, clk, POWER_UP_RST_N)
begin
	if POWER_UP_RST_N = '0' then  -- asynchronous reset (active low)
			tx_ready <= '0';
			tx_digitalreset  <= (others => '1');
			debug_st <= "00";
	elsif clk'event and clk = '1' then  -- rising clock edge
		case pres_state is	
			when STATE_RESET =>
				tx_ready <= '0';
				tx_digitalreset  <= (others => '1');
				debug_st <= "00";
			when STATE_PLLREADY =>
				tx_ready <= '0';
				tx_digitalreset  <= (others => '1');
				debug_st <= "01";
			when STATE_TXREADY =>
				tx_ready <= '1';
				tx_digitalreset <= (others => '0');
				debug_st <= "10";
			when others => null;
		end case;
	end if;
end process out_mux;

end structure;


library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

entity altgx_reset_rx is
generic (
	-- LTD_auto = 4000 ns for Cyclone IV, which means 400 counts at 100 MHz 
	TLTD                        : integer   := 401
);
port (
	clk             : in  std_logic;
	POWER_UP_RST_N  : in  std_logic;
	tx_ready        : in  std_logic; -- rx is only initialized after tx is up
	busy            : in  std_logic;
	rx_analogreset  : out std_logic_vector (0 downto 0);
	rx_freqlocked   : in  std_logic_vector (0 downto 0);
	rx_digitalreset : out std_logic_vector (0 downto 0);
	rx_ready        : out std_logic; -- for byte ordering block
	debug_st        : out std_logic_vector (1 downto 0) -- will be synthesized away if not used
);
end altgx_reset_rx;

architecture structure of altgx_reset_rx is
	type state_type is (STATE_RESET, STATE_RXANALOG, STATE_RXLOCKED, STATE_READY);
	signal pres_state, next_state : state_type;
	attribute syn_encoding : string;
	attribute syn_encoding of state_type : type is "safe";
	signal busy_cleared, wait_done : std_logic;
	signal busy_clear_cnt, wait_clear_cnt : std_logic;
	-- synchronization registers
	signal tx_ready_d : std_logic_vector(4 downto 0);
	signal tx_ready_stable : std_logic;
	signal busy_d : std_logic_vector(4 downto 0);
	signal busy_stable : std_logic;
	signal rx_freqlocked_d : std_logic_vector(4 downto 0);
	signal rx_freqlocked_stable : std_logic;
begin

-- FSM sequential logic and registers
reset_fsm : process (clk, POWER_UP_RST_N)
begin
	if POWER_UP_RST_N = '0' then  -- asynchronous reset (active low)
		pres_state <= STATE_RESET;
		tx_ready_d <= "00000";
		tx_ready_stable <= '0';
		busy_d <= "11111";
		busy_stable <= '1';
		rx_freqlocked_d <= "00000";
		rx_freqlocked_stable <= '0';
	elsif clk'event and clk = '1' then  -- rising clock edge
		pres_state <= next_state;
		tx_ready_d(0) <= tx_ready;
		tx_ready_d(1) <= tx_ready_d(0);
		tx_ready_d(2) <= tx_ready_d(1);
		tx_ready_d(3) <= tx_ready_d(2);
		tx_ready_d(4) <= tx_ready_d(3);
		tx_ready_stable <= tx_ready_d(4) and tx_ready_d(3) and tx_ready_d(2) and tx_ready_d(1);
		busy_d(0) <= busy;
		busy_d(1) <= busy_d(0);
		busy_d(2) <= busy_d(1);
		busy_d(3) <= busy_d(2);
		busy_d(4) <= busy_d(3);		
		busy_stable <= busy_d(4) and busy_d(3) and busy_d(2) and busy_d(1);
		rx_freqlocked_d(0) <= rx_freqlocked(0);
		rx_freqlocked_d(1) <= rx_freqlocked_d(0);
		rx_freqlocked_d(2) <= rx_freqlocked_d(1);
		rx_freqlocked_d(3) <= rx_freqlocked_d(2);
		rx_freqlocked_d(4) <= rx_freqlocked_d(3);
		rx_freqlocked_stable <= rx_freqlocked_d(4) and rx_freqlocked_d(3) and rx_freqlocked_d(2) and rx_freqlocked_d(1);
	end if;
end process reset_fsm;

-- FSM combinational logic
fsm_comb : process (pres_state, tx_ready_stable, busy_cleared, rx_freqlocked_stable, wait_done)
begin
	next_state <= pres_state;
	case pres_state is
		when STATE_RESET =>
			if tx_ready_stable = '1' and busy_cleared = '1' then
				next_state <= STATE_RXANALOG;
			end if;
		when STATE_RXANALOG =>
			if tx_ready_stable = '0' then
				next_state <= STATE_RESET;
			elsif rx_freqlocked_stable = '1' then
				next_state <= STATE_RXLOCKED;
			end if;
		when STATE_RXLOCKED =>
			if tx_ready_stable = '0' then
				next_state <= STATE_RESET;
			elsif rx_freqlocked_stable = '0' then
				next_state <= STATE_RXANALOG;
			elsif wait_done = '1' then
				next_state <= STATE_READY;
			end if;
		when STATE_READY =>
			if tx_ready_stable = '0' then
				next_state <= STATE_RESET;
			elsif rx_freqlocked_stable = '0' then
				next_state <= STATE_RXANALOG;
			end if;
		when others => 
			next_state <= STATE_RESET;
	end case;
end process fsm_comb;

-- FSM output multiplexer [with an extra register]
out_mux : process (clk, POWER_UP_RST_N, pres_state)
begin
	if POWER_UP_RST_N = '0' then  -- asynchronous reset (active low)
		rx_ready <= '0';	
		rx_analogreset   <= (others => '1');
		rx_digitalreset  <= (others => '1');
		busy_clear_cnt <= '0';
		wait_clear_cnt <= '1';
		debug_st  <= "00";
	elsif clk'event and clk = '1' then  -- rising clock edge
		case pres_state is	
			when STATE_RESET =>
				rx_ready <= '0';	
				rx_analogreset   <= (others => '1');
				rx_digitalreset  <= (others => '1');
				busy_clear_cnt <= '0';
				wait_clear_cnt <= '1';
				debug_st  <= "00";
			when STATE_RXANALOG =>
				rx_ready <= '0';
				rx_analogreset  <= (others => '0');
				rx_digitalreset <= (others => '1');
				busy_clear_cnt <= '1';
				wait_clear_cnt <= '1';
				debug_st  <= "01";
			when STATE_RXLOCKED =>
				rx_ready <= '0';
				rx_analogreset  <= (others => '0');
				rx_digitalreset <= (others => '1');
				busy_clear_cnt <= '1';
				wait_clear_cnt <= '0';
				debug_st  <= "10";
			when STATE_READY =>
				rx_ready <= '1';
				rx_analogreset  <= (others => '0');
				rx_digitalreset <= (others => '0');
				busy_clear_cnt <= '1';
				wait_clear_cnt <= '1';
				debug_st <= "11";
			when others => null;
		end case;
	end if;
end process out_mux;

-- Wait for busy to clear, plus two clock cycles
busy_proc : process (clk, POWER_UP_RST_N, busy_stable, busy_clear_cnt)
variable cnt : integer range 0 to 2 := 0;
begin
	if POWER_UP_RST_N = '0' then
		cnt := 0;
		busy_cleared <= '0';
	elsif clk'event and clk = '1' then  -- rising clock edge
		if busy_stable = '1' or busy_clear_cnt = '1' then
			cnt := 0;
			busy_cleared <= '0';
		else
			if cnt = 2 then 
				cnt := cnt;
				busy_cleared <= '1';
			else
				cnt := cnt + 1;
				busy_cleared <= '0';
			end if;
		end if;
	end if;
end process busy_proc;

-- Delay for TLTD after CDR locks, before receiver becomes operational
wait_proc : process (clk, POWER_UP_RST_N, wait_clear_cnt)
variable cnt : integer range 0 to TLTD+1 := 0;
begin
	if POWER_UP_RST_N = '0' then
		cnt := 0;
		wait_done <= '0';
	elsif clk'event and clk = '1' then  -- rising clock edge
		if wait_clear_cnt = '1' then
			cnt := 0;
			wait_done <= '0';
		else
			if cnt = TLTD then
				cnt := cnt;
				wait_done <= '1';
			else
				cnt := cnt + 1;
				wait_done <= '0';
			end if;
		end if;
	end if;
end process wait_proc;

end structure;
