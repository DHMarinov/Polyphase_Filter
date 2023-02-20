----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/24/2022 07:21:16 PM
-- Design Name: 
-- Module Name: Pipelined_Polyphase_Filter - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
-- It is equivalent to the trsnsposed version, however it seems to be less resource efficient!
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
use IEEE.math_real.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity Pipelined_Polyphase_Filter is
    Generic(
        DATA_WIDTH          : integer := 16;    --4
        CONVERSION_FACTOR   : integer := 8;
        TAPS_PER_PHASE      : integer := 15;
        DECIMATION_ARCH     : boolean := false  
    );
    Port (
        clk     : in STD_LOGIC;
        enable  : in STD_LOGIC;
        data_i  : in std_logic_vector(DATA_WIDTH-1 downto 0);
        data_o  : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end Pipelined_Polyphase_Filter;

architecture Behavioral of Pipelined_Polyphase_Filter is

constant Gain : integer := integer(ceil(log2(real(CONVERSION_FACTOR))));

signal phase_counter   : integer range 0 to CONVERSION_FACTOR-1 := 0;
signal phase_counter_q : integer range 0 to CONVERSION_FACTOR-1 := 0;

type p_reg_array is array (0 to CONVERSION_FACTOR*Taps_Per_Phase-1) of signed(2*Data_Width-1 downto 0);
signal p_reg : p_reg_array :=(others=>(others=>'0'));

signal product_sum  : signed(2*Data_Width-1 downto 0) := (others=>'0');
signal final_sum    : signed(2*Data_Width-1 downto 0) := (others=>'0');

type reg_array is array (0 to Taps_Per_Phase-1) of signed(DATA_WIDTH-1 downto 0);
signal a_reg : reg_array :=(others=>(others=>'0'));
signal b_reg : reg_array :=(others=>(others=>'0'));

type coefficients is array (0 to 31) of signed( 15 downto 0);
signal coeff: coefficients :=( 
"1111110011011010", "1111111101000011", "1111111101110000", "1111111111000101", "0000000001000111", "0000000011111010", "0000000111011011", "0000001011100101", 
"0000010000001110", "0000010101001001", "0000011010000111", "0000011110110101", "0000100011000001", "0000100110011100", "0000101000110110", "0000101010000101", 
"0000101010000101", "0000101000110110", "0000100110011100", "0000100011000001", "0000011110110101", "0000011010000111", "0000010101001001", "0000010000001110", 
"0000001011100101", "0000000111011011", "0000000011111010", "0000000001000111", "1111111111000101", "1111111101110000", "1111111101000011", "1111110011011010");

--type coefficients is array (0 to 119) of signed(15 downto 0);     
--signal coeff: coefficients :=( 
----x"0001", x"0002", x"0003", x"0004", x"0005", x"0006", x"0007", x"0008", 
--x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", 
--x"0001", x"0001", x"0000", x"0000", x"FFFF", x"FFFF", x"FFFD", x"FFFB", 
--x"FFF8", x"FFF6", x"FFF4", x"FFF2", x"FFF2", x"FFF3", x"FFF6", x"FFFC", 
--x"0004", x"0010", x"001E", x"002D", x"003D", x"004B", x"0056", x"005C", 
--x"005A", x"004E", x"0038", x"0015", x"FFE8", x"FFB0", x"FF71", x"FF2E", 
--x"FEEE", x"FEB7", x"FE90", x"FE80", x"FE8F", x"FEC3", x"FF21", x"FFAB", 
--x"0060", x"0141", x"0246", x"0368", x"049B", x"05D4", x"0704", x"081C", 
--x"0910", x"09D3", x"0A5B", x"0AA1", x"0AA1", x"0A5B", x"09D3", x"0910", 
--x"081C", x"0704", x"05D4", x"049B", x"0368", x"0246", x"0141", x"0060", 
--x"FFAB", x"FF21", x"FEC3", x"FE8F", x"FE80", x"FE90", x"FEB7", x"FEEE", 
--x"FF2E", x"FF71", x"FFB0", x"FFE8", x"0015", x"0038", x"004E", x"005A", 
--x"005C", x"0056", x"004B", x"003D", x"002D", x"001E", x"0010", x"0004", 
--x"FFFC", x"FFF6", x"FFF3", x"FFF2", x"FFF2", x"FFF4", x"FFF6", x"FFF8", 
--x"FFFB", x"FFFD", x"FFFF", x"FFFF", x"0000", x"0000", x"0001", x"0001", 
--x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000");


begin



--------------------------------------------------------------------------------
-- Filtering Process
--------------------------------------------------------------------------------
process(clk)
begin

if rising_edge (clk) then   
    if enable = '1' then
        -- Phase Counter
        if DECIMATION_ARCH = false then                     -- Interpolation
            if phase_counter < CONVERSION_FACTOR-1 then
                phase_counter <= phase_counter + 1;        
            else
                phase_counter <= 0;
            end if;  
        
        else                                                -- Decimation
            if phase_counter > 0 then
                phase_counter <= phase_counter - 1;        
            else
                phase_counter <= CONVERSION_FACTOR-1;
            end if;  
        end if;
        
        -- Filter loop
        for m in 0 to CONVERSION_FACTOR-1 loop                  -- Phase loop
            for t in 0 to Taps_Per_Phase-1 loop                 -- Sub-phase loop
                -- Input           
                if DECIMATION_ARCH = false then                 
                    if phase_counter = 0 then                  -- Input latching when interpolating 
                        a_reg( t ) <= signed(data_i);
                    end if;
                else
                    a_reg( t ) <= signed(data_i);
                end if;
    
                -- Coefficients
                b_reg( t ) <= coeff( t*CONVERSION_FACTOR + phase_counter);
                
                -- Multiplication 
                if t = Taps_Per_Phase-1 then        
                    p_reg( t*CONVERSION_FACTOR + CONVERSION_FACTOR-1 ) <= a_reg(t) * b_reg(t);
                else
                    p_reg( t*CONVERSION_FACTOR + CONVERSION_FACTOR-1 ) <= a_reg(t) * b_reg(t) + p_reg( (t+1)*CONVERSION_FACTOR );
                end if;
                
                -- Pipeline shifting
                if m < CONVERSION_FACTOR-1 then
                    p_reg( t*CONVERSION_FACTOR + m ) <= p_reg( t*CONVERSION_FACTOR + m + 1);
                end if;
        
            end loop;    
        end loop;
        
        -- Product Accumulator
        if DECIMATION_ARCH = true then                     -- Interpolation
            phase_counter_q <= phase_counter;             -- Counter buffering
            if phase_counter_q > 0 then
                product_sum <= p_reg(0) + product_sum;
            else
                product_sum <= (others=>'0');
                final_sum <= p_reg(0) + product_sum;
            end if;
        end if;
        
        -- Output stage
        if DECIMATION_ARCH = false then                     -- Interpolation
            data_o <= std_logic_vector( p_reg(0)(2*DATA_WIDTH-2-Gain downto DATA_WIDTH-1-Gain) );
        else
            data_o <= std_logic_vector( final_sum(2*DATA_WIDTH-2 downto DATA_WIDTH-1) );
        end if;
    end if;
    
end if;

end process;

end Behavioral;
