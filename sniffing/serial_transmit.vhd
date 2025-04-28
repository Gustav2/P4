library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity usb_speed_test is
    Port (
        clk         : in  STD_LOGIC;                    -- 12MHz clock input
        rst_n       : in  STD_LOGIC;                    -- Reset signal (active low)
        uart_txd    : out STD_LOGIC;                    -- UART TX data
        led_out     : out STD_LOGIC_VECTOR(7 downto 0); -- LEDs for debugging
        data_in     : in  std_logic_vector(7 downto 0); -- New: data input (8 bits)
        data_valid  : in  std_logic                     -- New: data valid signal
    );
end usb_speed_test;
-- https://github.com/Arkady667/UART/blob/master/sources_1/new/tx.vhd
-- https://forum.digikey.com/t/uart-vhdl/12670/4

architecture Behavioral of usb_speed_test is
    -- Constants
    constant TEST_SIZE      : integer := 10_000_000;  -- Number of bytes to send
    constant CLK_FREQ       : integer := 12_000_000;  -- 12MHz system clock
    constant BAUD_RATE      : integer := 1_200_000;  -- Increased to 12Mbaud
    constant CYCLES_PER_BIT : integer := CLK_FREQ / BAUD_RATE;  -- 1 cycle per bit
    
    -- State machine
    type state_type is (IDLE, SEND_START, SEND_DATA, SEND_STOP, DATA_SENT);
    signal state : state_type := IDLE;
    
    -- Internal signals
    signal bit_counter     : integer range 0 to 7 := 0;
    signal data_pattern    : unsigned(7 downto 0);
    signal bytes_sent      : unsigned(31 downto 0) := (others => '0');
    signal current_byte    : std_logic_vector(7 downto 0) := (others => '0');
    signal transfer_active : std_logic := '0';
    
begin
    -- Output debug info on LEDs
    led_out <= std_logic_vector(bytes_sent(26 downto 19));
    
    -- Debug process
    -- Main process
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            -- Reset all signals
            state <= IDLE;
            uart_txd <= '1';  -- Idle high
            bit_counter <= 0;
            data_pattern <= (others => '0');
            bytes_sent <= (others => '0');
            current_byte <= (others => '0');
            transfer_active <= '0';
            
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    uart_txd <= '1';  -- Idle
                    bit_counter <= 0;
                    bytes_sent <= (others => '0');
                    transfer_active <= '1';
                    state <= SEND_START;
                    
                when SEND_START =>
                    uart_txd <= '0';  -- Start bit
                    if data_valid = '1' then
                        current_byte <= data_in;
                        state <= SEND_DATA;
                        bit_counter <= 0;
                    end if;
                    
                when SEND_DATA =>
                    uart_txd <= current_byte(bit_counter);
                    if bit_counter < 7 then
                        bit_counter <= bit_counter + 1;
                    else
                        state <= SEND_STOP;
                    end if;
                    
                when SEND_STOP =>
                    uart_txd <= '1';  -- Stop bit
                    data_pattern <= data_pattern + 1;
                    bytes_sent <= bytes_sent + 1;
                    
                    if bytes_sent >= TEST_SIZE-1 then
                        state <= DATA_SENT;
                        transfer_active <= '0';
                    else
                        state <= SEND_START;
                    end if;
                    
                when DATA_SENT =>
                    uart_txd <= '1';  -- Idle
                    -- Stay in this state until reset
            end case;
        end if;
    end process;

end Behavioral;