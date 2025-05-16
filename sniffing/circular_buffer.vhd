library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.constants.all;

entity circular_buffer is
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;  -- Active high reset
        
        -- Write port (from SPI sniffer)
        wr_data     : in  std_logic_vector(BUFFER_WIDTH_CONSTANT-1 downto 0);
        wr_en       : in  std_logic;
        
        -- Read port (to UART transmitter)
        rd_data     : out std_logic_vector(BUFFER_WIDTH_CONSTANT-1 downto 0);
        rd_en       : in  std_logic;
        
        -- Status signals
        empty       : out std_logic;
        full        : out std_logic;
        
        -- Read valid signal (to sync with UART)
        rd_valid    : out std_logic
    );
end entity circular_buffer;

architecture Behavioral of circular_buffer is
    -- Calculate buffer size
    constant BUFFER_DEPTH : integer := 2**BUFFER_DEPTH_CONSTANT;
    
    -- Buffer memory
    type buffer_array is array (0 to BUFFER_DEPTH-1) of std_logic_vector(BUFFER_WIDTH_CONSTANT-1 downto 0);
    signal buffer_mem : buffer_array := (others => (others => '0'));
    
    -- Pointers and status
    signal wr_ptr      : unsigned(BUFFER_DEPTH_CONSTANT-1 downto 0) := (others => '0');
    signal rd_ptr      : unsigned(BUFFER_DEPTH_CONSTANT-1 downto 0) := (others => '0');
    signal count       : unsigned(BUFFER_DEPTH_CONSTANT downto 0) := (others => '0');
    signal empty_i     : std_logic := '1';
    signal full_i      : std_logic := '0';
    signal rd_valid_i  : std_logic := '0';
    
begin
    -- Connect internal status signals to outputs
    empty <= empty_i;
    full <= full_i;
    rd_valid <= rd_valid_i;
    
    -- Buffer process
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                -- Reset buffer
                wr_ptr <= (others => '0');
                rd_ptr <= (others => '0');
                count <= (others => '0');
                empty_i <= '1';
                full_i <= '0';
                rd_valid_i <= '0';
            else
                -- Handle read and write operations
                
                -- Write operation
                if wr_en = '1' and full_i = '0' then
                    -- Store data in buffer
                    buffer_mem(to_integer(wr_ptr)) <= wr_data;
                    
                    -- Update write pointer
                    wr_ptr <= wr_ptr + 1;
                    
                    -- Update count and flags
                    if rd_en = '1' and empty_i = '0' then
                        -- Simultaneous read and write, count stays the same
                        null;  -- pointers update, but count remains unchanged
                    else
                        -- Only write, count increases
                        count <= count + 1;
                    end if;
                end if;
                
                -- Read operation
                if rd_en = '1' and empty_i = '0' then
                    -- Data already available on rd_data
                    rd_valid_i <= '1';
                    
                    -- Update read pointer
                    rd_ptr <= rd_ptr + 1;
                    
                    -- Update count and flags
                    if not (wr_en = '1' and full_i = '0') then
                        -- Only read, count decreases
                        count <= count - 1;
                    end if;
                else
                    rd_valid_i <= '0';
                end if;

                -- Update empty and full flags inside process
                if count = 0 then
                    empty_i <= '1';
                else
                    empty_i <= '0';
                end if;

                if count = BUFFER_DEPTH then
                    full_i <= '1';
                else
                    full_i <= '0';
                end if;
            end if;
        end if;
    end process;
    
    -- Continuous read data output
    rd_data <= buffer_mem(to_integer(rd_ptr));
    
end architecture Behavioral;
