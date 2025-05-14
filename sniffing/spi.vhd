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

    -- Synchronization registers for external signals
    signal sclk_meta, sclk_sync : std_logic := '0';
    signal miso_meta, miso_sync : std_logic := '0';
    signal mosi_meta, mosi_sync : std_logic := '0';
    signal cs_meta, cs_sync     : std_logic := '0';

    -- Edge detection
    signal sclk_prev    : std_logic := '0';
    signal sclk_rising  : std_logic := '0';
    signal sclk_falling : std_logic := '0';

    -- Frequency measurement
    signal sclk_counter : unsigned(31 downto 0) := (others => '0');
    signal sclk_period  : unsigned(31 downto 0) := (others => '0');

    -- Timestamp counter
    signal timestamp_counter : unsigned(31 downto 0) := (others => '0');

    -- Frequency calculation signals
    signal system_clk_freq : unsigned(31 downto 0) := to_unsigned(get_clk_freq(USE_PLL_CONSTANT), 32);
    signal calculated_freq : unsigned(31 downto 0) := (others => '0');
    signal freq_hz         : unsigned(12 downto 0) := (others => '0'); -- 13 bits as per buffer_data structure

    -- Buffer write control
    signal buffer_wr_internal : std_logic := '0';

begin
    -- Connect internal write signal to output through buffer full check
    buffer_wr <= buffer_wr_internal and (not buffer_full);

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                -- Reset synchronizers
                sclk_meta <= '0';
                sclk_sync <= '0';
                miso_meta <= '0';
                miso_sync <= '0';
                mosi_meta <= '0';
                mosi_sync <= '0';
                cs_meta   <= '0';
                cs_sync   <= '0';
                
                -- Reset other signals
                sclk_counter       <= (others => '0');
                sclk_period        <= (others => '0');
                timestamp_counter  <= (others => '0');
                sclk_prev          <= '0';
                buffer_wr_internal <= '0';
                sclk_rising        <= '0';
                sclk_falling       <= '0';
                calculated_freq    <= (others => '0');
                freq_hz            <= (others => '0');
            else
                -- Double-flop synchronization for all inputs
                -- First stage (meta)
                sclk_meta <= sclk;
                miso_meta <= miso;
                mosi_meta <= mosi;
                cs_meta   <= cs;
                
                -- Second stage (sync) - use these signals in your logic
                sclk_sync <= sclk_meta;
                miso_sync <= miso_meta;
                mosi_sync <= mosi_meta;
                cs_sync   <= cs_meta;
                
                -- Timestamp increment
                timestamp_counter <= timestamp_counter + 1;

                -- Default state
                buffer_wr_internal <= '0';
                sclk_rising  <= '0';
                sclk_falling <= '0';

                -- Edge detection - using synchronized signals
                if sclk_sync = '1' and sclk_prev = '0' then -- RISING EDGE
                    sclk_rising <= '1';
                    sclk_period <= sclk_counter; -- Capture period on rising edge (full cycle)
                    sclk_counter <= (others => '0');
                elsif sclk_sync = '0' and sclk_prev = '1' then -- FALLING EDGE
                    sclk_falling <= '1';
                    -- Keep counting for period measurement based on rising edge
                    sclk_counter <= sclk_counter + 1;
                else
                    -- Continue counting between edges
                    sclk_counter <= sclk_counter + 1;
                end if;
                sclk_prev <= sclk_sync;

                -- Calculate actual frequency in Hz (based on rising edge period)
                -- Ensure calculation runs even if sampling is on falling edge
                if sclk_rising = '1' then -- Calculate freq when period is updated
                    if sclk_period > 0 and sclk_period < system_clk_freq then
                        calculated_freq <= system_clk_freq / sclk_period;
                        -- Convert and store in 13-bit value
                        freq_hz <= resize(calculated_freq(31 downto 17), 13);
                    else
                        calculated_freq <= (others => '0');
                        freq_hz <= (others => '0');
                    end if;
                end if;


                -- Update status LEDs with synchronized signals
                led_sclk <= sclk_sync;

                -- On FALLING edge of SCLK, sample signals and store to buffer
                if sclk_falling = '1' then
                    -- Use synchronized signals for LEDs and buffer data
                    led_miso <= miso_sync;
                    led_mosi <= mosi_sync;
                    led_cs   <= cs_sync;

                    -- Provide data to output ports using synchronized values
                    buffer_data <= miso_sync & mosi_sync & cs_sync & std_logic_vector(freq_hz) & std_logic_vector(timestamp_counter);
                    buffer_wr_internal <= '1'; -- Assert write request
                end if;
            end if; -- end reset check
        end if; -- end rising_edge(clk)
    end process;
end Behavioral;