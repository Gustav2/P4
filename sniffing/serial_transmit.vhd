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
        buffer_data     : in  std_logic_vector(47 downto 0); -- 48-bit data from buffer
        buffer_wr       : in  std_logic;                     -- Buffer write signal (triggers transmission)
        buffer_rd_addr  : out std_logic_vector(7 downto 0);  -- Read address to buffer
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
            ST_LOAD_BYTE,   -- Prepare the current byte for transmission
            ST_START_BIT,   -- Send UART start bit
            ST_DATA_BITS,   -- Send 8 data bits
            ST_STOP_BIT,    -- Send UART stop bit
            ST_NEXT_BYTE    -- Prepare for next byte or end transmission
        );
        signal tx_state : tx_state_type := ST_IDLE;
        
    -- Internal signals
        signal bit_counter     : integer range 0 to 7 := 0;              -- Counts bits within a byte
        signal byte_index      : integer range 0 to 5 := 0;              -- Tracks which byte (0-5) is being sent from the 48-bit data
        signal buffer_read_ptr : unsigned(7 downto 0) := (others => '0'); -- Current read position in buffer
        signal buffer_sent_ptr : unsigned(7 downto 0) := (others => '0'); -- Last fully transmitted buffer position
        signal current_data    : std_logic_vector(47 downto 0) := (others => '0'); -- Captured data from buffer
        signal current_byte    : std_logic_vector(7 downto 0) := (others => '0');  -- Current byte being transmitted
        signal bytes_sent      : unsigned(31 downto 0) := (others => '0'); -- Total bytes sent (diagnostic)
        signal bit_timer       : integer range 0 to CYCLES_PER_BIT-1 := 0; -- Timing counter for bit transmission
        signal tx_active       : std_logic := '0';                     -- Indicates active transmission
        signal tx_done_pulse   : std_logic := '0';                     -- Completion pulse
        
    begin
    -- Connect buffer read address output
        buffer_rd_addr <= std_logic_vector(buffer_read_ptr);
        
    -- Connect status signals
        tx_busy <= tx_active;
        tx_done <= tx_done_pulse;
        
    -- Main UART transmitter process
        uart_tx_process: process(clk, reset)
        begin
            if reset = '1' then
            -- Reset all signals to initial state
                tx_state <= ST_IDLE;
                uart_txd <= '1';  -- Idle high for UART
                bit_counter <= 0;
                byte_index <= 0;
                buffer_read_ptr <= (others => '0');
                buffer_sent_ptr <= (others => '0');
                current_data <= (others => '0');
                current_byte <= (others => '0');
                bytes_sent <= (others => '0');
                bit_timer <= 0;
                tx_active <= '0';
                tx_done_pulse <= '0';
                
            elsif rising_edge(clk) then
            -- Default state for tx_done_pulse (single clock pulse)
                tx_done_pulse <= '0';
                
            -- Ensure buffer_read_ptr is always assigned in all branches to avoid latches
            -- Default behavior: maintain current value unless explicitly changed
                
                case tx_state is
                    when ST_IDLE =>
                        uart_txd <= '1';  -- Idle high for UART
                        bit_timer <= 0;
                        
                    -- Start new transmission when buffer write signal received and not already transmitting
                        if buffer_wr = '1' and tx_active = '0' then
                        -- Capture the data from buffer
                            current_data <= buffer_data;
                            byte_index   <= 0;
                            tx_active    <= '1';
                            tx_state     <= ST_LOAD_BYTE;
                        -- Make sure buffer_read_ptr is assigned here if this is where it's intended to change
                        -- If buffer_read_ptr should be updated here, uncomment the next line:
                        -- buffer_read_ptr <= buffer_read_ptr + 1;
                        end if;
                        
                    when ST_LOAD_BYTE =>
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
                            buffer_sent_ptr <= buffer_sent_ptr + 1;
                            tx_active <= '0';     -- Release transmitter
                            tx_done_pulse <= '1'; -- Signal completion
                            tx_state <= ST_IDLE;  -- Return to idle state

                        -- If buffer_read_ptr needs to be updated after a complete transmission,
                        -- place that update here explicitly to avoid latch inference
                        -- This is likely where the latch is being inferred, so ensure an assignment:
                            buffer_read_ptr <= buffer_sent_ptr + 1;  -- Example: update to next entry
                        end if;
                end case;
            end if;
        end process uart_tx_process;
    end Behavioral;