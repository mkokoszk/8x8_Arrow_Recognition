library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.wagi_mlp_pkg.ALL;

entity tb_strzalki is end entity;

architecture sim of tb_strzalki is
    signal clk         : std_logic := '0';
    signal rst         : std_logic := '1';
    signal frame_in    : std_logic_vector(63 downto 0) := (others => '0');
    signal frame_valid : std_logic := '0';
    signal cmd_out     : std_logic_vector(1 downto 0);
    signal cmd_valid   : std_logic;
    signal frame_cnt   : std_logic_vector(2 downto 0);

    signal lfsr        : std_logic_vector(15 downto 0) := x"ACE1";

    constant FRAME_UP    : std_logic_vector(63 downto 0) := "00010000" & "00111000" & "01010100" & "00010000" & "00010000" & "00010000" & "00010000" & "00000000";
    constant FRAME_LEFT  : std_logic_vector(63 downto 0) := "00000000" & "00010000" & "00100000" & "01111110" & "00100000" & "00010000" & "00000000" & "00000000";
    constant FRAME_RIGHT : std_logic_vector(63 downto 0) := "00000000" & "00001000" & "00000100" & "01111110" & "00000100" & "00001000" & "00000000" & "00000000";
    constant FRAME_X     : std_logic_vector(63 downto 0) := "10000010" & "01000100" & "00101000" & "00010000" & "00101000" & "01000100" & "10000010" & "00000000";
    
    constant FRAME_EMPTY : std_logic_vector(63 downto 0) := (others => '0');
    constant FRAME_FULL  : std_logic_vector(63 downto 0) := (others => '1');

    -- Procedura TYLKO wysyła ramkę (nie czeka potem w ciemno)
    procedure send_frame(
        signal fin  : out std_logic_vector(63 downto 0);
        signal fval : out std_logic;
        constant dat: in  std_logic_vector(63 downto 0)) is
    begin
        fin  <= dat;
        fval <= '1';
        wait until rising_edge(clk);
        fval <= '0';
    end procedure;

begin
    DUT: entity work.rozpoznawanie_strzalek
        port map (clk, rst, frame_in, frame_valid, cmd_out, cmd_valid, frame_cnt);

    clk <= not clk after 5 ns;

    process(clk) begin
        if rising_edge(clk) then
            if rst = '1' then
                lfsr <= x"ACE1";
            else
                lfsr <= lfsr(14 downto 0) & (lfsr(15) xor lfsr(13) xor lfsr(12) xor lfsr(10));
            end if;
        end if;
    end process;

    process 
        variable tests_passed : integer := 0;
        variable tests_total  : integer := 0;
        variable random_noise : std_logic_vector(63 downto 0);
    begin
        wait for 20 ns; rst <= '0';
        report "=== ROZPOCZECIE WERYFIKACJI (SCOREBOARD) ===";

        -- ---------------------------------------------------------------------
        -- SCENARIUSZ 1: Czysta strzalka w LEWO ("01")
        -- ---------------------------------------------------------------------
        for i in 1 to 5 loop 
            send_frame(frame_in, frame_valid, FRAME_LEFT); 
            wait for 500 ns; -- Dajemy czas na przetworzenie klatek 1-5
        end loop;
        send_frame(frame_in, frame_valid, FRAME_LEFT); -- Wysłanie 6. klatki
        wait until cmd_valid = '1'; -- Natychmiastowe nasłuchiwanie wyniku!
        
        tests_total := tests_total + 1;
        if cmd_out = "01" then 
            tests_passed := tests_passed + 1; 
            report "[PASS] Scenariusz 1: Rozpoznano LEWO";
        else 
            report "[FAIL] Scenariusz 1: Blad klasyfikacji LEWO!" severity error; 
        end if;
        wait for 100 ns; -- Chwila oddechu dla układu przed kolejnym testem

        -- ---------------------------------------------------------------------
        -- SCENARIUSZ 2: Strzalka w PRAWO z losowym szumem LFSR ("10")
        -- ---------------------------------------------------------------------
        for i in 1 to 5 loop 
            send_frame(frame_in, frame_valid, FRAME_RIGHT); 
            wait for 500 ns;
        end loop;
        random_noise := lfsr & lfsr & lfsr & lfsr;
        send_frame(frame_in, frame_valid, FRAME_RIGHT xor random_noise); -- 6. klatka zaszumiona
        wait until cmd_valid = '1';
        
        tests_total := tests_total + 1;
        if cmd_out = "10" then 
            tests_passed := tests_passed + 1; 
            report "[PASS] Scenariusz 2: Rozpoznano PRAWO pomimo szumu LFSR";
        else 
            report "[FAIL] Scenariusz 2: Voter nie odfiltrowal szumu!" severity error; 
        end if;
        wait for 100 ns;

        -- ---------------------------------------------------------------------
        -- SCENARIUSZ 3: EDGE CASE - Pusta klatka ("11")
        -- ---------------------------------------------------------------------
        for i in 1 to 5 loop 
            send_frame(frame_in, frame_valid, FRAME_EMPTY); 
            wait for 500 ns;
        end loop;
        send_frame(frame_in, frame_valid, FRAME_EMPTY); -- 6. klatka pusta
        wait until cmd_valid = '1';
        
        tests_total := tests_total + 1;
        if cmd_out = "11" then 
            tests_passed := tests_passed + 1; 
            report "[PASS] Scenariusz 3 (Edge Case): Pusta klatka odrzucona";
        else 
            report "[FAIL] Scenariusz 3: Uklad podjal zla decyzje!" severity error; 
        end if;

        -- ---------------------------------------------------------------------
        -- WYNIKI SCOREBOARD
        -- ---------------------------------------------------------------------
        report "==================================================";
        report "SCOREBOARD FINALNY: ZALICZONO " & integer'image(tests_passed) & " Z " & integer'image(tests_total) & " TESTOW.";
        if tests_passed = tests_total then
            report "STATUS WERYFIKACJI: ZAKONCZONA POMYSLNIE. SYSTEM GOTOWY DO WDROZENIA." severity note;
        end if;
        report "==================================================";

        wait for 50 ns;
        assert false report "ZAKONCZENIE SYMULACJI (To nie jest blad)" severity failure;
    end process;
end architecture sim;
