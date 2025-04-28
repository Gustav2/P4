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
        led_pll_lock : out std_logic;           -- LED to indicate PLL lock status
        -- transmit
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
    sclk        : in  std_logic;
    miso        : in  std_logic;
    mosi        : in  std_logic;
    cs          : in  std_logic;
    led_miso    : out std_logic;
    led_mosi    : out std_logic;
    led_cs      : out std_logic;
    led_sclk    : out std_logic;
    buffer_data : out std_logic_vector(47 downto 0);
    buffer_addr : out std_logic_vector(7 downto 0);
    buffer_wr   : out std_logic
);
end component;

component usb_speed_test
Port (
    clk           : in  STD_LOGIC;
    rst_n         : in  STD_LOGIC;
    uart_txd      : out STD_LOGIC;
    led_out       : out STD_LOGIC_VECTOR(7 downto 0);
    buffer_data   : in  std_logic_vector(47 downto 0);
    buffer_wr     : in  std_logic;
    buffer_rd_addr: out std_logic_vector(7 downto 0)
);
end component;

    -- Signal declarations
signal clk_200mhz      : std_logic;
signal pll_locked      : std_logic;
signal reset_sync      : std_logic;

    -- Buffer signals
signal buffer_data_out : std_logic_vector(47 downto 0);
signal buffer_addr_out : std_logic_vector(7 downto 0);
signal buffer_wr_out   : std_logic;
signal buffer_rd_addr  : std_logic_vector(7 downto 0);

    -- Buffer memory to store SPI data
type buffer_mem_type is array (0 to 255) of std_logic_vector(47 downto 0);
signal buffer_mem      : buffer_mem_type := (others => (others => '0'));
signal buffer_data_read: std_logic_vector(47 downto 0);

    -- Debug signals
signal led_debug       : std_logic_vector(7 downto 0);

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
        clk         => clk_12mhz,    -- Using 200 MHz clock
        reset       => reset_sync,
        sclk        => sclk,
        miso        => miso,
        mosi        => mosi,
        cs          => cs,
        led_miso    => led_miso,
        led_mosi    => led_mosi,
        led_cs      => led_cs,
        led_sclk    => led_sclk,
        buffer_data => buffer_data_out,
        buffer_addr => buffer_addr_out,
        buffer_wr   => buffer_wr_out
    );
    
    -- Shared buffer implementation
    process(clk_12mhz)
    begin
        if rising_edge(clk_12mhz) then
            -- Write to buffer when SPI writes
            if buffer_wr_out = '1' then
                buffer_mem(to_integer(unsigned(buffer_addr_out))) <= buffer_data_out;
            end if;
            
            -- Read from buffer for USB TX
            buffer_data_read <= buffer_mem(to_integer(unsigned(buffer_rd_addr)));
        end if;
    end process;
    
    -- Instantiate the USB transmitter module
    usb_tx_inst: usb_speed_test
    port map (
        clk           => clk_12mhz,
        rst_n         => reset_n,
        uart_txd      => uart_txd,
        led_out       => led_debug,
        buffer_data   => buffer_data_read,
        buffer_wr     => buffer_wr_out,
        buffer_rd_addr=> buffer_rd_addr
    );
    
    -- Connect PLL lock indicator to LED
    led_pll_lock <= pll_locked;
    
end Behavioral;