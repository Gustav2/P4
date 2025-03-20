library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity fifo_test is
    port (
        clk : in std_logic;
        data_out : out std_logic_vector(7 downto 0);
        wr_en : out std_logic;
        tx_ready : in std_logic
    );
end fifo_test;

architecture behavior of fifo_test is
begin
    process(clk)
    variable counter : std_logic_vector(7 downto 0) := (others => '0');
    begin
        if rising_edge(clk) then
            if tx_ready = '0' then  -- FIFO ready to accept data
                counter := counter + 1;
                data_out <= counter;
                wr_en <= '0';  -- Enable write
            else
                wr_en <= '1';  -- Disable write
            end if;
        end if;
    end process;
end behavior;
