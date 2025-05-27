
-- ============================================================================
--  UART TRANSMIT MODULE
--
--  Description:
--      UART transmitter module for SPI sniffer system.
--      Reads 48-bit words from a circular buffer and transmits them over UART
--      at a configurable baud rate. Implements a FSM-based UART protocol.
--
--  Clock Domain:
--      - Configurable via USE_PLL_CONSTANT (defaults to 200 MHz if PLL enabled)
--      - Bit timing derived from BAUD_RATE_CONSTANT
--
--  Buffer Input:
--      - Accepts 48-bit input from circular buffer
--      - Sends 6 bytes (MSB first) per UART transmission cycle
--
--  FSM States:
--      - ST_IDLE        : Waits for data
--      - ST_FETCH_DATA  : Reads from buffer
--      - ST_LOAD_BYTE   : Extracts a byte from the word
--      - ST_START_BIT   : Sends UART start bit
--      - ST_DATA_BITS   : Sends UART data bits (LSB first)
--      - ST_STOP_BIT    : Sends UART stop bit
--      - ST_NEXT_BYTE   : Moves to next byte or ends cycle
--
-- ============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.constants.all;

entity uart_transmitter is
    Port (
        -- FPGA signals
        clk             : in  STD_LOGIC;
        reset           : in  STD_LOGIC;
        uart_txd        : out STD_LOGIC;
        
        -- Buffer interface
        buffer_data     : in  std_logic_vector(47 downto 0);
        buffer_rd       : out std_logic;
        buffer_empty    : in  std_logic;
        
        -- Status signals
        tx_busy         : out std_logic;
        tx_done         : out std_logic
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
    constant CYCLES_PER_BIT : integer := CLK_FREQ / BAUD_RATE_CONSTANT;
    
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
        signal bit_counter     : integer range 0 to 7 := 0;                         -- Counts bits within a byte
        signal byte_index      : integer range 0 to 5 := 0;                         -- Tracks which byte (0-5) is being sent
        signal bytes_sent      : unsigned(31 downto 0) := (others => '0');          -- Total bytes sent (diagnostic)
        signal current_byte    : std_logic_vector(7 downto 0) := (others => '0');   -- Current byte being transmitted
        signal bit_timer       : integer range 0 to CYCLES_PER_BIT-1 := 0;          -- Timing counter for bit transmission
        
    begin
        -- Main UART transmitter process
        uart_tx_process: process(clk, reset)
        begin
            if reset = '1' then
                -- Reset all signals to initial state
                tx_state <= ST_IDLE;
                uart_txd <= '1';  -- Idle high for UART
                bit_counter <= 0;
                byte_index <= 0;
                current_byte <= (others => '0');
                bytes_sent <= (others => '0');
                bit_timer <= 0;
                tx_busy <= '0';
                tx_done <= '0';
                buffer_rd <= '0';
                
            elsif rising_edge(clk) then
                -- Default state for tx_done and buffer_rd (single clock pulse)
                tx_done <= '0';
                buffer_rd <= '0';
                
                case tx_state is
                    when ST_IDLE =>
                        uart_txd <= '1';  -- Idle high for UART
                        bit_timer <= 0;
                        
                        -- Start new transmission when buffer is not empty and not already transmitting
                        if buffer_empty = '0' and tx_busy = '0' then
                            buffer_rd <= '1';
                            byte_index <= 0;
                            tx_busy <= '1';
                            tx_state <= ST_LOAD_BYTE;
                        end if;
                        
                    when ST_LOAD_BYTE =>
                        
                        -- Extract the current byte to send based on byte_index (MSB first)
                        case byte_index is
                            when 0 => current_byte <= buffer_data(47 downto 40);
                            when 1 => current_byte <= buffer_data(39 downto 32);
                            when 2 => current_byte <= buffer_data(31 downto 24);
                            when 3 => current_byte <= buffer_data(23 downto 16);
                            when 4 => current_byte <= buffer_data(15 downto 8);
                            when 5 => current_byte <= buffer_data(7 downto 0);
                            when others => current_byte <= X"00";  -- Safety case, should never occur
                        end case;
                        bit_timer <= 0;
                        tx_state <= ST_START_BIT;
                        
                    when ST_START_BIT =>
                        uart_txd <= '0';  -- Start bit
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
                        uart_txd <= '1';  -- Stop bit
                        
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
                            tx_busy <= '0';     -- Release transmitter
                            tx_done <= '1'; -- Signal completion
                            tx_state <= ST_IDLE;  -- Return to idle state
                        end if;
                end case;
            end if;
        end process uart_tx_process;
    end Behavioral;