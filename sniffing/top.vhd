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
        reset        : in  std_logic;           -- Reset signal (active low)
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
        -- Additional status LEDs (optional, can be connected if available)
        led_buffer_empty : out std_logic := '1'; -- LED to indicate buffer empty status
        led_buffer_full  : out std_logic := '0'; -- LED to indicate buffer full status
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
        buffer_wr   : out std_logic;
        buffer_full : in  std_logic
    );
    end component;

    component circular_buffer
    generic (
        DATA_WIDTH : integer;
        ADDR_WIDTH : integer
    );
    Port (
        clk        : in  std_logic;
        reset      : in  std_logic;
        wr_data    : in  std_logic_vector(47 downto 0);
        wr_en      : in  std_logic;
        rd_data    : out std_logic_vector(47 downto 0);
        rd_en      : in  std_logic;
        empty      : out std_logic;
        full       : out std_logic;
        data_count : out std_logic_vector(8 downto 0)
    );
    end component;

    component uart_transmitter
    Port (
        clk           : in  STD_LOGIC;
        reset         : in  STD_LOGIC;
        uart_txd      : out STD_LOGIC;
        buffer_data   : in  std_logic_vector(47 downto 0);
        buffer_rd     : out std_logic;
        buffer_empty  : in  std_logic;
        tx_busy       : out std_logic;
        tx_done       : out std_logic
    );
    end component;

    -- Signal declarations
    signal clk_selected    : std_logic;
    signal clk_200mhz      : std_logic;
    signal pll_locked      : std_logic;
    signal reset_not       : std_logic;

    -- Buffer signals
    signal buffer_data_in  : std_logic_vector(47 downto 0);
    signal buffer_data_out : std_logic_vector(47 downto 0);
    signal buffer_wr       : std_logic;
    signal buffer_rd       : std_logic;
    signal buffer_empty    : std_logic;
    signal buffer_full     : std_logic;
    signal buffer_count    : std_logic_vector(8 downto 0);  -- Number of entries in buffer
    
    -- UART status signals
    signal tx_busy         : std_logic;
    signal tx_done         : std_logic;

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
        buffer_data => buffer_data_in,
        buffer_wr   => buffer_wr,
        buffer_full => buffer_full
    );
    
    -- Instantiate the circular buffer
    buffer_inst: circular_buffer
    generic map (
        DATA_WIDTH => 48,
        ADDR_WIDTH => 8   -- 256 entries (can be adjusted as needed)
    )
    port map (
        clk        => clk_selected,
        reset      => reset_not,
        wr_data    => buffer_data_in,
        wr_en      => buffer_wr,
        rd_data    => buffer_data_out,
        rd_en      => buffer_rd,
        empty      => buffer_empty,
        full       => buffer_full,
        data_count => buffer_count
    );
    
    -- Instantiate the UART transmitter module
    uart_tx_inst: uart_transmitter
    port map (
        clk           => clk_selected,
        reset         => reset_not,
        uart_txd      => uart_txd,
        buffer_data   => buffer_data_out,
        buffer_rd     => buffer_rd,
        buffer_empty  => buffer_empty,
        tx_busy       => tx_busy,
        tx_done       => tx_done
    );
    
    -- Connect status LEDs
    led_pll_lock    <= pll_locked;
    led_buffer_empty <= buffer_empty;
    led_buffer_full  <= buffer_full;
    
end Behavioral;