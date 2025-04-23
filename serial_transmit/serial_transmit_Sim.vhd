  
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all; 


ENTITY usb_speed_test_tb IS
END usb_speed_test_tb;

ARCHITECTURE BEHAVIORAL OF usb_speed_test_tb IS

  SIGNAL finished : STD_LOGIC:= '0';
  CONSTANT period_time : TIME := 83333 ps;
  SIGNAL CLK : STD_LOGIC ;
  SIGNAL rst_n : STD_LOGIC ;
  SIGNAL uart_txd : STD_LOGIC ;
  SIGNAL led_out : STD_LOGIC_VECTOR (7 downto 0);
  COMPONENT usb_speed_test IS
  
  PORT (
    clk         : in  STD_LOGIC;                     
            rst_n       : in  STD_LOGIC;                     
            uart_txd    : out STD_LOGIC;                     
            led_out     : out STD_LOGIC_VECTOR(7 downto 0)   
    
  );
  END COMPONENT;
  
BEGIN
  Sim_finished : PROCESS 
    
  BEGIN
    wait for 100000 us;
    finished <= '1';
    wait;
  END PROCESS;
  usb_speed_test1 : usb_speed_test  PORT MAP (
    CLK => CLK,
    rst_n => rst_n,
    uart_txd => uart_txd,
    led_out => led_out
  );
  Sim_clk : PROCESS 
    
  BEGIN
    WHILE finished /= '1' LOOP
      clk <= '1';
      wait for period_time/2;
      clk <= '0';
      wait for period_time/2;
    END LOOP;
  
    wait;
  END PROCESS;
  Sim_rst_n : PROCESS
  BEGIN
    WHILE finished /= '1' LOOP
      wait;
    END LOOP;
  
    wait;
  END PROCESS;
  
END BEHAVIORAL;