library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_transmitter_tb is
end uart_transmitter_tb;

architecture Behavioral of uart_transmitter_tb is
    signal clk           : std_logic := '0';
    signal rst_n         : std_logic := '0';
    signal uart_txd      : std_logic;
    signal buffer_data   : std_logic_vector(47 downto 0) := (others => '0');
    signal buffer_wr     : std_logic := '0';
    signal buffer_rd_addr: std_logic_vector(7 downto 0);

    constant CLK_PERIOD : time := 83.333 ns; -- 12 MHz

begin
    -- Instantiate the UART transmitter
    uut: entity work.uart_transmitter
    port map (
        clk           => clk,
        rst_n         => rst_n,
        uart_txd      => uart_txd,
        buffer_data   => buffer_data,
        buffer_wr     => buffer_wr,
        buffer_rd_addr => buffer_rd_addr
    );

    -- Generate 12 MHz clock
    clk_process : process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;

    -- Stimulus process
    stim_proc : process
    begin
        -- Reset
        rst_n <= '0';
        wait for 100 ns;
        rst_n <= '1';
        wait for 100 ns;

        -- Write a test pattern: ASCII "ABCDEF"
        buffer_data <= x"5F5470000000";  -- 'F','E','D','C','B','A' (LSB first)
        buffer_wr <= '1';
        wait for CLK_PERIOD;
        buffer_wr <= '0';

        -- Wait for transmission to complete (~10 ms for 6 bytes at 115200)
        wait for 60 ms;

        -- End simulation
        assert false report "Simulation completed" severity failure;
        wait;
    end process;
end Behavioral;
