-- top-level wrapper around single-channel ALTGX megafunction
-- that emulates the interface of TLK2501 device
-- (one transmitter + one receiver)
-- This module should be interfaced with LDC core

library IEEE;
use     IEEE.Std_Logic_1164.all;

entity altgx_tlk_single is
generic(
  SIMULATION  : integer :=  0
);
port (
	POWER_UP_RST_N    : in  std_logic;
	-- transmitter
	TXD            : in std_logic_vector(15 downto 0);
	TX_EN          : in std_logic;
	TX_ER          : in std_logic;
	TX_CLK         : out std_logic;  -- generated internally, passed to LSC/LDC core
	-- receiver:
	RXD0           : out std_logic_vector(15 downto 0); -- Received parallel data
	RX_CLK0        : out std_logic;  -- Recovered clock.
	RX_LOCKED0     : out std_logic;  -- Receiver locked and synced to incoming data
	RX_ER0         : out std_logic;
	RX_DV0         : out std_logic;
	-- Cyclone transceiver ports (connect to pins)
	SLOWCLK       : in std_logic;   -- 50 MHz, reconfig & calib clock
	REFCLK        : in std_logic;   -- 100 MHz, LVDS
	GXB_TX0       : out std_logic;
	GXB_RX0       : in std_logic;
	-- LOS signals
	LOS_stable   : in STD_LOGIC
   );
end altgx_tlk_single;

architecture structure of altgx_tlk_single is
	signal reset_sig : STD_LOGIC;
	signal tx_clk_sig : STD_LOGIC;
	signal tx_ready_sig : STD_LOGIC;
		
	signal rx_clkout0_sig : STD_LOGIC;
	signal rx_ready0_sig : STD_LOGIC;
	
	-- Signals for byte ordering block
	signal reset_byteorder_sig : STD_LOGIC;
	signal rx_ctrldetect_unord_sig	: STD_LOGIC_VECTOR (1 DOWNTO 0);
	signal rx_dataout_unord_sig		: STD_LOGIC_VECTOR (15 DOWNTO 0);
	signal rx_errdetect_unord_sig		: STD_LOGIC_VECTOR (1 DOWNTO 0);
	signal rx_syncstatus0_sig : STD_LOGIC;
	
	-- Signals for altgx_reconfig
	signal reconfig_clk_sig : STD_LOGIC;
	signal busy_sig		: STD_LOGIC ;
		
	-- Signals for ALTGX
	signal cal_blk_clk_sig		: STD_LOGIC;
	signal pll_areset_sig		: STD_LOGIC_VECTOR (0 DOWNTO 0);
	signal reconfig_togxb_sig		: STD_LOGIC_VECTOR (3 DOWNTO 0);
	signal rx_analogreset_sig		: STD_LOGIC_VECTOR (0 DOWNTO 0);
	signal rx_datain_sig		: STD_LOGIC_VECTOR (0 DOWNTO 0);
	signal rx_digitalreset_sig		: STD_LOGIC_VECTOR (0 DOWNTO 0);
	signal tx_ctrlenable_sig		: STD_LOGIC_VECTOR (1 DOWNTO 0);
	signal tx_datain_sig		: STD_LOGIC_VECTOR (15 DOWNTO 0);
	signal tx_digitalreset_sig		: STD_LOGIC_VECTOR (0 DOWNTO 0);
	signal tx_dispval_sig		: STD_LOGIC_VECTOR (1 DOWNTO 0);
	signal tx_forcedisp_sig		: STD_LOGIC_VECTOR (1 DOWNTO 0); --forced to 1111
	signal pll_locked_sig		: STD_LOGIC_VECTOR (0 DOWNTO 0);
	signal reconfig_fromgxb_sig		: STD_LOGIC_VECTOR (4 DOWNTO 0);
	signal rx_byteorderalignstatus_sig		: STD_LOGIC_VECTOR (0 DOWNTO 0);
	signal rx_clkout_sig		: STD_LOGIC_VECTOR (0 DOWNTO 0);
	signal rx_ctrldetect_sig		: STD_LOGIC_VECTOR (1 DOWNTO 0);
	signal rx_dataout_sig		: STD_LOGIC_VECTOR (15 DOWNTO 0);
	signal rx_disperr_sig		: STD_LOGIC_VECTOR (1 DOWNTO 0);
	signal rx_errdetect_sig		: STD_LOGIC_VECTOR (1 DOWNTO 0);
	signal rx_freqlocked_sig		: STD_LOGIC_VECTOR (0 DOWNTO 0);
	signal rx_patterndetect_sig		: STD_LOGIC_VECTOR (1 DOWNTO 0);
	signal rx_runningdisp_sig		: STD_LOGIC_VECTOR (1 DOWNTO 0);
	signal rx_syncstatus_sig		: STD_LOGIC_VECTOR (1 DOWNTO 0);
	signal tx_clkout_sig		: STD_LOGIC_VECTOR (0 DOWNTO 0);
	signal tx_dataout_sig		: STD_LOGIC_VECTOR (0 DOWNTO 0);

-- altgx_reconfig component (required for receiver channels)
component altgx_reco_single
	PORT
	(
		reconfig_clk		: IN STD_LOGIC ;
		reconfig_fromgxb		: IN STD_LOGIC_VECTOR (4 DOWNTO 0);
		busy		: OUT STD_LOGIC ;
		error		: OUT STD_LOGIC ;
		reconfig_togxb		: OUT STD_LOGIC_VECTOR (3 DOWNTO 0)
	);
end component;

-- reset FSM components
component altgx_reset_tx
	port (
		clk             : in  std_logic;
		POWER_UP_RST_N  : in  std_logic;
		pll_locked      : in  std_logic_vector (0 downto 0);
		pll_areset      : out std_logic_vector (0 downto 0);
		tx_digitalreset : out std_logic_vector (0 downto 0);
		tx_ready        : out std_logic; -- for rx reset machine
		debug_st        : out std_logic_vector (1 downto 0) -- will be synthesized away if not used
	);
end component;
component altgx_reset_rx is
	generic (
		TLTD : integer := 401
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
end component;

-- altgx component
component altgx_single
	PORT
	(
		cal_blk_clk		: IN STD_LOGIC ;
		pll_areset		: IN STD_LOGIC_VECTOR (0 DOWNTO 0);
		pll_inclk		: IN STD_LOGIC_VECTOR (0 DOWNTO 0);
		reconfig_clk		: IN STD_LOGIC ;
		reconfig_togxb		: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
		rx_analogreset		: IN STD_LOGIC_VECTOR (0 DOWNTO 0);
		rx_datain		: IN STD_LOGIC_VECTOR (0 DOWNTO 0);
		rx_digitalreset		: IN STD_LOGIC_VECTOR (0 DOWNTO 0);
		tx_ctrlenable		: IN STD_LOGIC_VECTOR (1 DOWNTO 0);
		tx_datain		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		tx_digitalreset		: IN STD_LOGIC_VECTOR (0 DOWNTO 0);
		tx_dispval		: IN STD_LOGIC_VECTOR (1 DOWNTO 0);
		tx_forcedisp		: IN STD_LOGIC_VECTOR (1 DOWNTO 0);
		pll_locked		: OUT STD_LOGIC_VECTOR (0 DOWNTO 0);
		reconfig_fromgxb		: OUT STD_LOGIC_VECTOR (4 DOWNTO 0);
		rx_clkout		: OUT STD_LOGIC_VECTOR (0 DOWNTO 0);
		rx_ctrldetect		: OUT STD_LOGIC_VECTOR (1 DOWNTO 0);
		rx_dataout		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
		rx_disperr		: OUT STD_LOGIC_VECTOR (1 DOWNTO 0);
		rx_errdetect		: OUT STD_LOGIC_VECTOR (1 DOWNTO 0);
		rx_freqlocked		: OUT STD_LOGIC_VECTOR (0 DOWNTO 0);
		rx_patterndetect		: OUT STD_LOGIC_VECTOR (1 DOWNTO 0);
		rx_runningdisp		: OUT STD_LOGIC_VECTOR (1 DOWNTO 0);
		rx_syncstatus		: OUT STD_LOGIC_VECTOR (1 DOWNTO 0);
		tx_clkout		: OUT STD_LOGIC_VECTOR (0 DOWNTO 0);
		tx_dataout		: OUT STD_LOGIC_VECTOR (0 DOWNTO 0)
	);
end component;

-- TLK-emulating wrapper for transmitter channel
component tlk_wrap_tx is
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
end component;

-- Byte ordering block (based on /I1/ or /I2/) for receiver channel
component tlk_byte_order is
	PORT (
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
end component;

-- TLK-emulating wrapper for receiver channel
component tlk_wrap_rx is
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
end component;

begin
	-- parallel assignments of general input ports
	reset_sig <= not POWER_UP_RST_N;
	reconfig_clk_sig <= SLOWCLK;
	cal_blk_clk_sig  <= SLOWCLK;
	-- parallel assignments of general output ports
	RX_LOCKED0 <= rx_byteorderalignstatus_sig(0);
	TX_CLK       <= tx_clk_sig;
	RX_CLK0      <= rx_clkout0_sig;
	
	-- serial receiver inputs
	rx_datain_sig(0) <= GXB_RX0;
	-- serial transmitter outputs
	GXB_TX0 <= tx_dataout_sig(0);
	
	-- assign unused ports to prevent unintended synthesis optimizations
	tx_forcedisp_sig <= "11";
	
	-- map receiver channel
	rx_clkout0_sig <= rx_clkout_sig(0);
	rx_syncstatus0_sig <= rx_syncstatus_sig(0) or rx_syncstatus_sig(1);
	
	-- altgx_reconfig instance
	reco_inst : altgx_reco_single PORT MAP (
		reconfig_clk	 => reconfig_clk_sig,
		reconfig_fromgxb	 => reconfig_fromgxb_sig,
		busy	 => busy_sig,
		error	 => open,
		reconfig_togxb	 => reconfig_togxb_sig
	);

	-- transmitter reset fsm instance
	tx_rst : altgx_reset_tx PORT MAP (
		clk              => REFCLK,
		POWER_UP_RST_N   => POWER_UP_RST_N,
		pll_locked       => pll_locked_sig,
		pll_areset       => pll_areset_sig,
		tx_digitalreset  => tx_digitalreset_sig,
		tx_ready         => tx_ready_sig,
		debug_st         => open
	);
	
	-- receiver reset fsm instance; LTD wait time is reduced for simulation
	RSTSIM : if SIMULATION = 1 generate
		rx_rst : altgx_reset_rx 
		GENERIC MAP (
			TLTD => 4
		)
		PORT MAP (
			clk              => REFCLK,
			POWER_UP_RST_N   => POWER_UP_RST_N,
			tx_ready         => tx_ready_sig,
			busy             => busy_sig,
			rx_analogreset   => rx_analogreset_sig,
			rx_freqlocked    => rx_freqlocked_sig,
			rx_digitalreset  => rx_digitalreset_sig,
			rx_ready         => rx_ready0_sig,
			debug_st         => open
		);
	end generate;
	RSTNOSIM : if SIMULATION = 0 generate
		rx_rst : altgx_reset_rx 
		GENERIC MAP (
			TLTD => 401
		)
		PORT MAP (
			clk              => REFCLK,
			POWER_UP_RST_N   => POWER_UP_RST_N,
			tx_ready         => tx_ready_sig,
			busy             => busy_sig,
			rx_analogreset   => rx_analogreset_sig,
			rx_freqlocked    => rx_freqlocked_sig,
			rx_digitalreset  => rx_digitalreset_sig,
			rx_ready         => rx_ready0_sig,
			debug_st         => open
		);
	end generate;

	-- wrap ALTGX transmitter channel to emulate TLK2501
	tx_wrap : tlk_wrap_tx
	port map (
		-- inputs (from LSC core)
		RESET         => reset_sig,
		TX_CLK        => tx_clk_sig,
		TX_EN         => TX_EN,
		TX_ER         => TX_ER,
		TD            => TXD,
		-- outputs (to altgx)
		tx_datain     => tx_datain_sig,
		tx_ctrlenable => tx_ctrlenable_sig,
		tx_dispval    => tx_dispval_sig
	);
	
	-- altgx instance
	gx_inst : altgx_single PORT MAP (
		cal_blk_clk	 => cal_blk_clk_sig,
		pll_areset	 => pll_areset_sig,
		pll_inclk(0)	 => REFCLK,
		reconfig_clk	 => reconfig_clk_sig,
		reconfig_togxb	 => reconfig_togxb_sig,
		rx_analogreset	 => rx_analogreset_sig,
		rx_datain	 => rx_datain_sig,
		rx_digitalreset	 => rx_digitalreset_sig,
		tx_ctrlenable	 => tx_ctrlenable_sig,
		tx_datain => tx_datain_sig,
		tx_digitalreset	 => tx_digitalreset_sig,
		tx_dispval => tx_dispval_sig,
		tx_forcedisp	 => tx_forcedisp_sig,  --force vcc always
		pll_locked	 => pll_locked_sig,
		reconfig_fromgxb	 => reconfig_fromgxb_sig,
		rx_clkout	 => rx_clkout_sig,
		rx_ctrldetect	 => rx_ctrldetect_unord_sig,
		rx_dataout	 => rx_dataout_unord_sig,
		rx_disperr   => open,
		rx_errdetect	 => rx_errdetect_unord_sig,
		rx_freqlocked	 => rx_freqlocked_sig,
		rx_patterndetect	 => rx_patterndetect_sig,
		rx_runningdisp	 => rx_runningdisp_sig,
		rx_syncstatus	 => rx_syncstatus_sig,
		tx_clkout(0)	 => tx_clk_sig,
		tx_dataout	 => tx_dataout_sig
	);

	-- synchronize combinational reset signals for byte ordering block
	rx0_reset : process(SLOWCLK,POWER_UP_RST_N)
	begin
	if POWER_UP_RST_N = '0' then  -- asynchronous reset (active high)
		reset_byteorder_sig <= '1';
	elsif SLOWCLK'event and SLOWCLK = '1' then  -- rising clock edge
		reset_byteorder_sig <= (not rx_ready0_sig) or (LOS_stable);
	end if;
	end process rx0_reset;
	
	-- Byte ordering block (based on /I1/ or /I2/) for receiver channel
	rx_ord : tlk_byte_order
	port map (
		clk             => rx_clkout0_sig,
		reset           => reset_byteorder_sig,
		rx_syncstatus    => rx_syncstatus0_sig,
		-- data from the serdes link:
		datain          => rx_dataout_unord_sig,
		ctrlin          => rx_ctrldetect_unord_sig,
		errin           => rx_errdetect_unord_sig,
		-- pipelined and byte-ordered output:
		dataout         => rx_dataout_sig,
		ctrlout         => rx_ctrldetect_sig,
		errout          => rx_errdetect_sig,
		status          => rx_byteorderalignstatus_sig,
		debug_st        => open
	);
	
	-- wrap ALTGX receiver channel to emulate TLK2501
	rx_wrap : tlk_wrap_rx
	port map (
		reset           => reset_sig,
		-- inputs (from altgx)
		rx_clkout       => rx_clkout0_sig,
		rx_dataout      => rx_dataout_sig,
		rx_ctrldetect   => rx_ctrldetect_sig,
		rx_errdetect    => rx_errdetect_sig,
		rx_byteorderalignstatus => rx_byteorderalignstatus_sig,
		-- outputs (to LSC core)
		RXD             => RXD0,
		RX_ER           => RX_ER0,
		RX_DV           => RX_DV0
	);

end structure;
