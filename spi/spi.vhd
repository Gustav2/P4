library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi is
    Port (
        clk         : in  std_logic;              -- System clock (e.g., 50 MHz)
        reset       : in  std_logic;
        sclk        : in  std_logic;              -- SPI clock
        miso        : in  std_logic;
        mosi        : in  std_logic;
        cs          : in  std_logic;
        led_miso    : out std_logic;
        led_mosi    : out std_logic;
        led_cs      : out std_logic;
        -- Circular buffer output
        buffer_data     : out std_logic_vector(7 downto 0);
        buffer_timestamp: out std_logic_vector(31 downto 0);
        buffer_addr     : out std_logic_vector(7 downto 0);
        buffer_wr       : out std_logic
    );
end spi;

architecture Behavioral of spi is
    -- Buffer entry: 8-bit data + 32-bit timestamp
    type spi_sample is record
        data      : std_logic_vector(7 downto 0);
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
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '0' then
                write_ptr         <= (others => '0');
                sclk_counter      <= (others => '0');
                sclk_period       <= (others => '0');
                timestamp_counter <= (others => '0');
                sclk_prev         <= '0';
                buffer_wr         <= '0';
                sclk_rising       <= '0';
            else
                -- Timestamp increment
                timestamp_counter <= timestamp_counter + 1;
                
                -- Default state
                buffer_wr <= '0';
                sclk_rising <= '0';
                
                -- SCLK edge detection
                if sclk = '1' and sclk_prev = '0' then
                    -- Rising edge detected
                    sclk_rising <= '1';
                    -- Store frequency
                    sclk_period  <= sclk_counter;
                    sclk_counter <= (others => '0');
                else
                    sclk_counter <= sclk_counter + 1;
                end if;
                sclk_prev <= sclk;
                
                -- On SCLK rising edge
                if sclk_rising = '1' then
                    -- Sample SPI lines
                    miso_reg <= miso;
                    mosi_reg <= mosi;
                    cs_reg   <= cs;
                    
                    -- Update LEDs
                    led_miso <= miso;
                    led_mosi <= mosi;
                    led_cs   <= cs;
                    
                    -- Create and store sample
                    circ_buffer(to_integer(write_ptr)).data      <= miso & mosi & cs & "00000";
                    circ_buffer(to_integer(write_ptr)).timestamp <= std_logic_vector(timestamp_counter);
                    
                    -- Output buffer values for UART/reader
                    buffer_data      <= miso & mosi & cs & "00000";
                    buffer_timestamp <= std_logic_vector(timestamp_counter);
                    buffer_addr      <= std_logic_vector(write_ptr);
                    buffer_wr        <= '1';
                    
                    -- Advance circular buffer pointer
                    write_ptr <= write_ptr + 1;
                end if;
            end if;
        end if;
    end process;
end Behavioral;