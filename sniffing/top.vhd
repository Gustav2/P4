library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top is
    Port (
        clk_12mhz    : in  std_logic;           -- 12 MHz input clock from CYC1000 board
        reset_n      : in  std_logic;           -- Reset signal (active low)
        -- SPI signals
        sclk         : in  std_logic;
        miso         : in  std_logic;
        mosi         : in  std_logic;
        cs           : in  std_logic;
        -- LEDs
        led_miso     : out std_logic;
        led_mosi     : out std_logic;
        led_cs       : out std_logic;
		  led_sclk     : out std_logic;
        led_pll_lock : out std_logic            -- LED to indicate PLL lock status
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
            sclk        : in  std_logic;
            miso        : in  std_logic;
            mosi        : in  std_logic;
            cs          : in  std_logic;
            led_miso    : out std_logic;
            led_mosi    : out std_logic;
            led_cs      : out std_logic;
				led_sclk    : out std_logic;
            buffer_data : out std_logic_vector(47 downto 0);  -- Updated to 48-bit combined data
            buffer_addr : out std_logic_vector(7 downto 0);
            buffer_wr   : out std_logic
        );
    end component;
    
    -- Signal declarations
    signal clk_200mhz   : std_logic;
    signal pll_locked   : std_logic;
    signal reset_sync   : std_logic;
    
    -- Buffer signals (if needed externally)
    signal buffer_data_out  : std_logic_vector(47 downto 0);  -- Updated to 48-bit combined data+timestamp
    signal buffer_addr_out  : std_logic_vector(7 downto 0);
    signal buffer_wr_out    : std_logic;
    
    -- Optional: Extracted signals for use elsewhere if needed
    signal data_portion     : std_logic_vector(15 downto 0);  -- Lower 16 bits
    signal timestamp_portion: std_logic_vector(31 downto 0);  -- Upper 32 bits
    
begin
    -- Instantiate the PLL
    pll_inst: pll_200mhz
    port map (
        inclk0  => clk_12mhz,
        c0      => clk_200mhz,
        locked  => pll_locked
    );
    
    -- Synchronized reset (active low from board, active high for spi module)
    reset_sync <= not (reset_n and pll_locked);
    
    -- Instantiate the SPI module
    spi_inst: spi
    port map (
        clk         => clk_200mhz,     -- Using 200 MHz clock
        reset       => reset_sync,
        sclk        => sclk,
        miso        => miso,
        mosi        => mosi,
        cs          => cs,
        led_miso    => led_miso,
        led_mosi    => led_mosi,
        led_cs      => led_cs,
		  led_sclk	  => led_sclk,
        buffer_data => buffer_data_out,  -- Connect to the 48-bit combined data
        buffer_addr => buffer_addr_out,
        buffer_wr   => buffer_wr_out
    );
    
    -- Optional: Extract data and timestamp portions if needed elsewhere in the design
    data_portion      <= buffer_data_out(15 downto 0);       -- Lower 16 bits contain the original data
    timestamp_portion <= buffer_data_out(47 downto 16);      -- Upper 32 bits contain the timestamp
    
    -- Connect PLL lock indicator to LED
    led_pll_lock <= pll_locked;
    
end Behavioral;