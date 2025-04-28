library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi is
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
        -- Circular buffer output
        buffer_data : out std_logic_vector(47 downto 0);  -- 16 bits for data (miso, mosi, cs, (13) sclk freq)
        buffer_addr : out std_logic_vector(7 downto 0);
        buffer_wr   : out std_logic
    );
end spi;

architecture Behavioral of spi is
    -- Buffer entry: 16-bit data + 32-bit timestamp
    type spi_sample is record
        data      : std_logic_vector(15 downto 0);
        timestamp : std_logic_vector(31 downto 0);
    end record;
    -- Circular buffer type
    type buffer_type is array (0 to 255) of spi_sample;
    signal circ_buffer : buffer_type;
    signal write_ptr : unsigned(7 downto 0) := (others => '0');
    
    -- Edge detection
    signal sclk_prev : std_logic := '0';
    signal sclk_rising : std_logic := '0';
    
    -- Frequency measurement
    signal sclk_counter : unsigned(31 downto 0) := (others => '0');
    signal sclk_period  : unsigned(31 downto 0) := (others => '0');
    
    -- Timestamp counter
    signal timestamp_counter : unsigned(31 downto 0) := (others => '0');
    
    -- Sampled SPI values
    signal miso_reg, mosi_reg, cs_reg : std_logic;
    
    -- Frequency calculation signals
    signal system_clk_freq : unsigned(31 downto 0) := to_unsigned(200000000, 32);  -- Assuming 50 MHz system clock
    signal calculated_freq : unsigned(31 downto 0) := (others => '0');           -- Frequency in Hz
    signal freq_hz        : unsigned(12 downto 0) := (others => '0');           -- Frequency in Hz for buffer
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                write_ptr         <= (others => '0');
                sclk_counter      <= (others => '0');
                sclk_period       <= (others => '0');
                timestamp_counter <= (others => '0');
                sclk_prev         <= '0';
                buffer_wr         <= '0';
                sclk_rising       <= '0';
                calculated_freq   <= (others => '0');
                freq_hz           <= (others => '0');
            else
                -- Timestamp increment
                timestamp_counter <= timestamp_counter + 1;
                
                -- Default state
                buffer_wr <= '0';
                sclk_rising <= '0';
                
                if sclk = '1' and sclk_prev = '0' then
                    sclk_rising <= '1';
                    sclk_period  <= sclk_counter;
                    sclk_counter <= (others => '0');
                else
                    sclk_counter <= sclk_counter + 1;
                end if;
                sclk_prev <= sclk;
                
                -- Calculate actual frequency in Hz
                -- Frequency = System clock frequency / Period
                if sclk_period > 0 and sclk_period < system_clk_freq then
                    calculated_freq <= system_clk_freq / sclk_period;
                    -- Convert to 100 kHz units (divide by 100,000)
                    -- Integer division by 100,000 is equivalent to shifting right by 16.61 bits
                    -- We'll use a 17-bit shift for simplicity and efficiency (divide by 131,072)
                    freq_hz <= resize(calculated_freq(31 downto 17), 13);
                else
                    calculated_freq <= (others => '0');
                    freq_hz <= (others => '0');
                end if;
                led_sclk <= sclk;
                
                
                if sclk_rising = '1' then
                    miso_reg <= miso;
                    mosi_reg <= mosi;
                    cs_reg   <= cs;
                    led_miso <= miso;
                    led_mosi <= mosi;
                    led_cs   <= cs;

                    
                    -- Update LEDs (could be removed in future)
                    
                    
                    circ_buffer(to_integer(write_ptr)).data      <= miso & mosi & cs & std_logic_vector(freq_hz);
                    circ_buffer(to_integer(write_ptr)).timestamp <= std_logic_vector(timestamp_counter);
                    
                    buffer_data <= std_logic_vector(timestamp_counter) & miso & mosi & cs & std_logic_vector(freq_hz);
                    buffer_addr <= std_logic_vector(write_ptr);
                    buffer_wr   <= '1';
                    
                    write_ptr <= write_ptr + 1;
                end if;
            end if;
        end if;
    end process;
end Behavioral;