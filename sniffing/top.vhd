
-- ============================================================================
--  TOP MODULE
--
--  Description:
--      This design captures SPI traffic and buffers it for transmission over UART.
--
--  Clock:
--      - 12 MHz input from the FPGA board (e.g., CYC1000)
--      - Optional PLL generates a 200 MHz internal clock
--
--  Submodules:
--      - pll_200mhz       : Generates fast internal clock
--      - spi              : Captures SPI traffic and writes to circular buffer
--      - circular_buffer  : FIFO structure for buffering SPI data
--      - uart_transmitter : Reads buffered data and sends over UART
--
-- ============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.constants.all;

entity top is
    Port (
        -- FPGA signals
        clk_12mhz           : in  std_logic;
        reset               : in  std_logic;
        
        -- SPI signals
        miso                : in  std_logic;
        mosi                : in  std_logic;
        cs                  : in  std_logic;
        sclk                : in  std_logic;
        
        -- LEDs
        led_miso            : out std_logic;
        led_mosi            : out std_logic;
        led_cs              : out std_logic;
        led_sclk            : out std_logic;
        led_pll_lock        : out std_logic;
        led_buffer_empty    : out std_logic;
        led_buffer_full     : out std_logic;
        
        -- UART transmit
        uart_txd            : out std_logic
    );
end top;

architecture Behavioral of top is

    -- Signal declarations
    signal clk_selected     : std_logic;
    signal clk_200mhz       : std_logic;
    signal pll_locked       : std_logic;
    signal reset_not        : std_logic;

    -- Buffer signals
    signal buffer_data_in   : std_logic_vector(47 downto 0);
    signal buffer_data_out  : std_logic_vector(47 downto 0);
    signal buffer_wr        : std_logic;
    signal buffer_rd        : std_logic;
    signal buffer_empty     : std_logic;
    signal buffer_full      : std_logic;

begin
    -- Instantiate the PLL
    pll_inst: entity work.pll_200mhz
    port map (
        inclk0      => clk_12mhz,
        c0          => clk_200mhz,
        locked      => pll_locked
    );

    -- Instantiate the SPI sniffing module
    spi_inst: entity work.spi
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
        buffer_data => buffer_data_in,
        buffer_wr   => buffer_wr,
        buffer_full => buffer_full
    );
    
    -- Instantiate the circular buffer
    buffer_inst: entity work.circular_buffer
    port map (
        clk         => clk_selected,
        reset       => reset_not,
        wr_data     => buffer_data_in,
        wr_en       => buffer_wr,
        rd_data     => buffer_data_out,
        rd_en       => buffer_rd,
        empty       => buffer_empty,
        full        => buffer_full
    );

    -- Instantiate the UART transmit module
    uart_tx_inst: entity work.uart_transmitter
    port map (
        clk           => clk_selected,
        reset         => reset_not,
        uart_txd      => uart_txd,
        buffer_data   => buffer_data_out,
        buffer_rd     => buffer_rd,
        buffer_empty  => buffer_empty
    );

    -- Connect status LEDs
    led_pll_lock     <= pll_locked;
    led_buffer_empty <= buffer_empty;
    led_buffer_full  <= buffer_full;
    
    -- Active high reset from active low input
    reset_not <= not reset;
    
    -- Define clock usage
    clk_selected <= clk_200mhz when USE_PLL_CONSTANT else clk_12mhz;

end Behavioral;