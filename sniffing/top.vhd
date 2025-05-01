library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.constants.all;

entity top is
    generic (
        USE_PLL_CONSTANT   : boolean := USE_PLL_CONSTANT
    );

    Port (
        clk_12mhz    : in  std_logic;           -- 12 MHz input clock from CYC1000 board
        reset        : in  std_logic;             -- Reset signal (active low)
        -- SPI signals
        miso         : in  std_logic;
        mosi         : in  std_logic;
        cs           : in  std_logic;
        sclk         : in  std_logic;
        -- LEDs
        led_miso     : out std_logic;
        led_mosi     : out std_logic;
        led_cs       : out std_logic;
        led_sclk     : out std_logic;
        led_pll_lock : out std_logic;           -- LED to indicate PLL lock status
        -- UART transmit
        uart_txd     : out std_logic
    );
end top;

architecture Behavioral of top is
    -- Component declarations
    component pll_200mhz
    Port (
        inclk0  : in  std_logic;
        c0      : out std_logic;
        locked  : out std_logic
    );
end component;

component spi
Port (
    clk         : in  std_logic;
    reset       : in  std_logic;
    miso        : in  std_logic;
    mosi        : in  std_logic;
    cs          : in  std_logic;
    sclk        : in  std_logic;
    led_miso    : out std_logic;
    led_mosi    : out std_logic;
    led_cs      : out std_logic;
    led_sclk    : out std_logic;
    buffer_data : out std_logic_vector(47 downto 0);
    buffer_addr : out std_logic_vector(7 downto 0);
    buffer_wr   : out std_logic
);
end component;

component uart_transmitter
Port (
    clk           : in  STD_LOGIC;
    reset         : in  STD_LOGIC;
    uart_txd      : out STD_LOGIC;
    buffer_data   : in  std_logic_vector(47 downto 0);
    buffer_wr     : in  std_logic;
    buffer_rd_addr: out std_logic_vector(7 downto 0)
);
end component;

    -- Signal declarations
signal clk_selected    : std_logic;
signal clk_200mhz      : std_logic;
signal pll_locked      : std_logic;
signal reset_not       : std_logic;

    -- Buffer signals
signal buffer_data     : std_logic_vector(47 downto 0);
signal buffer_addr     : std_logic_vector(7 downto 0);
signal buffer_wr       : std_logic;
signal buffer_rd_addr  : std_logic_vector(7 downto 0);

begin
    -- Instantiate the PLL
    pll_inst: pll_200mhz
    port map (
        inclk0  => clk_12mhz,
        c0      => clk_200mhz,
        locked  => pll_locked
    );
    
    -- Create active high reset from active low input
    reset_not <= not reset;
    clk_selected <= clk_200mhz when USE_PLL_CONSTANT else clk_12mhz;
    
    -- Instantiate the SPI module
    spi_inst: spi
    port map (
        clk         => clk_selected,
        reset       => reset_not,
        sclk        => sclk,
        miso        => miso,
        mosi        => mosi,
        cs          => cs,
        led_miso    => led_miso,
        led_mosi    => led_mosi,
        led_cs      => led_cs,
        led_sclk    => led_sclk,
        buffer_data => buffer_data,
        buffer_addr => buffer_addr,
        buffer_wr   => buffer_wr
    );
    
    -- Instantiate the UART transmitter module
    uart_tx_inst: uart_transmitter
    port map (
        clk           => clk_selected,
        reset         => reset_not,
        uart_txd      => uart_txd,
        buffer_data   => buffer_data,
        buffer_wr     => buffer_wr,
        buffer_rd_addr=> buffer_rd_addr
    );
    
    -- Connect PLL lock indicator to LED
    led_pll_lock <= pll_locked;
    
end Behavioral;