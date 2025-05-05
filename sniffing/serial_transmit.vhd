library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.constants.all;

entity uart_transmitter is
    generic (
        USE_PLL_CONSTANT   : boolean := USE_PLL_CONSTANT;  -- Select between PLL or standard clock
        BAUD_RATE_CONSTANT : integer := BAUD_RATE_CONSTANT  -- Configurable baud rate
    );
    Port (
        clk             : in  STD_LOGIC;                     -- System clock input
        reset           : in  STD_LOGIC;                     -- Asynchronous reset, active high
        uart_txd        : out STD_LOGIC;                     -- UART TX data line
        
        -- Modified buffer interface for circular buffer
        buffer_data     : in  std_logic_vector(47 downto 0); -- 48-bit data from buffer
        buffer_rd       : out std_logic;                     -- Buffer read signal
        buffer_empty    : in  std_logic;                     -- Signal indicating buffer is empty
        
        -- Status signals
        tx_busy         : out std_logic;                     -- Indicates transmitter is busy
        tx_done         : out std_logic                      -- Pulses high for one clock when a transmission completes
    );
end uart_transmitter;

architecture Behavioral of uart_transmitter is
    -- Function to select clock frequency based on PLL constant
    function get_clk_freq(use_pll : boolean) return integer is
    begin
        if use_pll then
            return 200_000_000;  -- 200MHz with PLL
        else
            return 12_000_000;   -- 12MHz base clock
        end if;
    end function;
    
    -- Constants
    constant CLK_FREQ       : integer := get_clk_freq(USE_PLL_CONSTANT);
    constant BAUD_RATE      : integer := BAUD_RATE_CONSTANT;
    constant CYCLES_PER_BIT : integer := CLK_FREQ / BAUD_RATE;
    
    -- UART State machine
    type tx_state_type is (
        ST_IDLE,        -- Wait for transmission request
        ST_FETCH_DATA,  -- Read data from circular buffer
        ST_LOAD_BYTE,   -- Prepare the current byte for transmission
        ST_START_BIT,   -- Send UART start bit
        ST_DATA_BITS,   -- Send 8 data bits
        ST_STOP_BIT,    -- Send UART stop bit
        ST_NEXT_BYTE    -- Prepare for next byte or end transmission
    );
    signal tx_state : tx_state_type := ST_IDLE;
    
    -- Internal signals
    signal bit_counter     : integer range 0 to 7 := 0;               -- Counts bits within a byte
    signal byte_index      : integer range 0 to 5 := 0;               -- Tracks which byte (0-5) is being sent
    signal bytes_sent      : unsigned(31 downto 0) := (others => '0'); -- Total bytes sent (diagnostic)
    signal current_data    : std_logic_vector(47 downto 0) := (others => '0'); -- Captured data from buffer
    signal current_byte    : std_logic_vector(7 downto 0) := (others => '0');  -- Current byte being transmitted
    signal bit_timer       : integer range 0 to CYCLES_PER_BIT-1 := 0; -- Timing counter for bit transmission
    signal tx_active       : std_logic := '0';                     -- Indicates active transmission
    signal tx_done_pulse   : std_logic := '0';                     -- Completion pulse
    signal buffer_rd_i     : std_logic := '0';                     -- Internal buffer read signal
    
begin
    -- Connect status signals
    tx_busy <= tx_active;
    tx_done <= tx_done_pulse;
    buffer_rd <= buffer_rd_i;
    
    -- Main UART transmitter process
    uart_tx_process: process(clk, reset)
    begin
        if reset = '1' then
            -- Reset all signals to initial state
            tx_state <= ST_IDLE;
            uart_txd <= '1';  -- Idle high for UART
            bit_counter <= 0;
            byte_index <= 0;
            current_data <= (others => '0');
            current_byte <= (others => '0');
            bytes_sent <= (others => '0');
            bit_timer <= 0;
            tx_active <= '0';
            tx_done_pulse <= '0';
            buffer_rd_i <= '0';
            
        elsif rising_edge(clk) then
            -- Default state for tx_done_pulse and buffer_rd (single clock pulse)
            tx_done_pulse <= '0';
            buffer_rd_i <= '0';
            
            case tx_state is
                when ST_IDLE =>
                    uart_txd <= '1';  -- Idle high for UART
                    bit_timer <= 0;
                    
                    -- Start new transmission when buffer is not empty and not already transmitting
                    if buffer_empty = '0' and tx_active = '0' then
                        tx_active <= '1';
                        tx_state <= ST_FETCH_DATA;
                    end if;
                    
                when ST_FETCH_DATA =>
                    -- Assert buffer read signal for one clock cycle
                    buffer_rd_i <= '1';
                    -- Data will be available on the next clock cycle
                    tx_state <= ST_LOAD_BYTE;
                    byte_index <= 0;
                    
                when ST_LOAD_BYTE =>
                    -- Capture the data from buffer
                    if byte_index = 0 then
                        -- Only update current_data on the first byte
                        current_data <= buffer_data;
                    end if;
                    
                    -- Extract the current byte to send based on byte_index (MSB first)
                    case byte_index is
                        when 0 => current_byte <= current_data(47 downto 40);  -- Most significant byte first
                        when 1 => current_byte <= current_data(39 downto 32);
                        when 2 => current_byte <= current_data(31 downto 24);
                        when 3 => current_byte <= current_data(23 downto 16);
                        when 4 => current_byte <= current_data(15 downto 8);
                        when 5 => current_byte <= current_data(7 downto 0);    -- Least significant byte last
                        when others => current_byte <= X"00";  -- Safety case, should never occur
                    end case;
                    bit_timer <= 0;
                    tx_state <= ST_START_BIT;
                    
                when ST_START_BIT =>
                    uart_txd <= '0';  -- Start bit (always 0)
                    bit_counter <= 0;  -- Reset bit counter for upcoming data bits
                    
                    -- Wait for the full bit period using bit_timer
                    if bit_timer = CYCLES_PER_BIT-1 then
                        bit_timer <= 0;
                        tx_state <= ST_DATA_BITS;
                    else
                        bit_timer <= bit_timer + 1;
                    end if;
                    
                when ST_DATA_BITS =>
                    -- Send each bit of the current byte (LSB first per UART standard)
                    uart_txd <= current_byte(bit_counter);
                    
                    -- Maintain bit timing
                    if bit_timer = CYCLES_PER_BIT-1 then
                        bit_timer <= 0;
                        
                        -- Move to next bit or to stop bit when all 8 bits sent
                        if bit_counter < 7 then
                            bit_counter <= bit_counter + 1;
                        else
                            tx_state <= ST_STOP_BIT;
                        end if;
                    else
                        bit_timer <= bit_timer + 1;
                    end if;
                    
                when ST_STOP_BIT =>
                    uart_txd <= '1';  -- Stop bit (always 1)
                    
                    -- Wait for the full bit period
                    if bit_timer = CYCLES_PER_BIT-1 then
                        bit_timer <= 0;
                        bytes_sent <= bytes_sent + 1;  -- Increment diagnostic counter
                        tx_state <= ST_NEXT_BYTE;
                    else
                        bit_timer <= bit_timer + 1;
                    end if;
                    
                when ST_NEXT_BYTE =>
                    if byte_index < 5 then
                        -- Move to next byte in current 48-bit data packet
                        byte_index <= byte_index + 1;
                        tx_state <= ST_LOAD_BYTE;
                    else
                        -- All 6 bytes from this buffer entry have been sent
                        tx_active <= '0';     -- Release transmitter
                        tx_done_pulse <= '1'; -- Signal completion
                        tx_state <= ST_IDLE;  -- Return to idle state
                    end if;
            end case;
        end if;
    end process uart_tx_process;
end Behavioral;