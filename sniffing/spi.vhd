library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.constants.all;

entity spi is
    generic (
        USE_PLL_CONSTANT : boolean := USE_PLL_CONSTANT
    );
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
        
        -- Modified buffer interface for circular buffer
        buffer_data : out std_logic_vector(47 downto 0);
        buffer_wr   : out std_logic;
        buffer_full : in  std_logic    -- New signal to indicate if buffer is full
    );
end spi;

architecture Behavioral of spi is
    -- Function to select clock frequency based on PLL constant
    function get_clk_freq(use_pll : boolean) return integer is
    begin
        if use_pll then
            return 200_000_000;
        else
            return 12_000_000;
        end if;
    end function;
    
    -- Edge detection
    signal sclk_prev   : std_logic := '0';
    signal sclk_rising : std_logic := '0';
    
    -- Frequency measurement
    signal sclk_counter : unsigned(31 downto 0) := (others => '0');
    signal sclk_period  : unsigned(31 downto 0) := (others => '0');
    
    -- Timestamp counter
    signal timestamp_counter : unsigned(31 downto 0) := (others => '0');
    
    -- Sampled SPI values
    signal miso_reg, mosi_reg, cs_reg : std_logic;
    
    -- Frequency calculation signals
    signal system_clk_freq : unsigned(31 downto 0) := to_unsigned(get_clk_freq(USE_PLL_CONSTANT), 32);
    signal calculated_freq : unsigned(31 downto 0) := (others => '0');
    signal freq_hz        : unsigned(12 downto 0) := (others => '0');
    
    -- Buffer write control
    signal buffer_wr_internal : std_logic := '0';
    
begin
    -- Connect internal write signal to output through buffer full check
    buffer_wr <= buffer_wr_internal and (not buffer_full);
    
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                sclk_counter      <= (others => '0');
                sclk_period       <= (others => '0');
                timestamp_counter <= (others => '0');
                sclk_prev         <= '0';
                buffer_wr_internal <= '0';
                sclk_rising       <= '0';
                calculated_freq   <= (others => '0');
                freq_hz           <= (others => '0');
            else
                -- Timestamp increment
                timestamp_counter <= timestamp_counter + 1;
                
                -- Default state
                buffer_wr_internal <= '0';
                sclk_rising <= '0';
                
                -- Edge detection
                if sclk = '1' and sclk_prev = '0' then
                    sclk_rising <= '1';
                    sclk_period  <= sclk_counter;
                    sclk_counter <= (others => '0');
                else
                    sclk_counter <= sclk_counter + 1;
                end if;
                sclk_prev <= sclk;
                
                -- Calculate actual frequency in Hz
                if sclk_period > 0 and sclk_period < system_clk_freq then
                    calculated_freq <= system_clk_freq / sclk_period;
                    -- Convert and store in 13-bit value
                    freq_hz <= resize(calculated_freq(31 downto 17), 13);
                else
                    calculated_freq <= (others => '0');
                    freq_hz <= (others => '0');
                end if;
                
                -- Update status LEDs
                led_sclk <= sclk;
                
                -- On rising edge of SCLK, sample signals and store to buffer
                if sclk_rising = '1' then
                    -- Sample and store SPI signals
                    miso_reg <= miso;
                    mosi_reg <= mosi;
                    cs_reg   <= cs;
                    
                    -- Update LEDs with current values
                    led_miso <= miso;
                    led_mosi <= mosi;
                    led_cs   <= cs;
                    
                    -- Provide data to output ports
                    buffer_data <= miso & mosi & cs & std_logic_vector(freq_hz) & std_logic_vector(timestamp_counter);
                    buffer_wr_internal <= '1';
                end if;
            end if;
        end if;
    end process;
end Behavioral;