-- =============================================================================
-- ROZPOZNAWANIE STRZAŁEK – 6 KLATEK + GŁOSOWANIE WIĘKSZOŚCIOWE
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.wagi_mlp_pkg.ALL;

entity rozpoznawanie_strzalek is
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        frame_in    : in  std_logic_vector(63 downto 0);
        frame_valid : in  std_logic;
        cmd_out     : out std_logic_vector(1 downto 0);
        cmd_valid   : out std_logic;
        frame_cnt   : out std_logic_vector(2 downto 0)
    );
end entity rozpoznawanie_strzalek;

architecture rtl of rozpoznawanie_strzalek is
    constant N_FRAMES : integer := 6;
    type t_grid is array (0 to 7, 0 to 7) of std_logic;
    type t_features is array (0 to 15) of signed(7 downto 0);
    type t_hidden is array (0 to N_HIDDEN - 1) of signed(31 downto 0);
    type t_output is array (0 to N_OUTPUT - 1) of signed(31 downto 0);
    type t_votes is array (0 to N_OUTPUT - 1) of integer range 0 to N_FRAMES;

    type t_state is (S_IDLE, S_FEATURES, S_HIDDEN, S_OUTPUT, S_VOTE, S_DECIDE, S_EMIT);

    signal state        : t_state;
    signal grid         : t_grid;
    signal features     : t_features;
    signal hidden_post  : t_hidden;
    signal output_vals  : t_output;
    signal votes        : t_votes;
    signal frame_count  : integer range 0 to N_FRAMES;
    signal frame_result : integer range 0 to N_OUTPUT - 1;
    signal frame_corrected : std_logic_vector(63 downto 0);

begin
    -- Sprzętowa korekcja lustrzanego odbicia (Endianness mismatch)
    -- Odwracamy kolejność bitów w każdym z 8 wierszy:
    gen_rows: for r in 0 to 7 generate
        gen_cols: for c in 0 to 7 generate
            frame_corrected(r*8 + c) <= frame_in(r*8 + (7 - c));
        end generate;
    end generate;

    frame_cnt <= std_logic_vector(to_unsigned(frame_count, 3));

    process(clk)
        variable acc     : signed(31 downto 0);
        variable max_val : signed(31 downto 0);
        variable max_idx : integer range 0 to N_OUTPUT - 1;
        variable row_sum : integer range 0 to 8;
        variable col_sum : integer range 0 to 8;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state       <= S_IDLE;
                cmd_valid   <= '0';
                cmd_out     <= "00";
                frame_count <= 0;
                votes       <= (others => 0);
            else
                cmd_valid <= '0';
                case state is
                    when S_IDLE =>
                        if frame_valid = '1' then
                            for i in 0 to 7 loop
                                for j in 0 to 7 loop
                                    grid(i, j) <= frame_corrected(i * 8 + j);
                                end loop;
                            end loop;
                            state <= S_FEATURES;
                        end if;

                    when S_FEATURES =>
                        for i in 0 to 7 loop
                            row_sum := 0;
                            for j in 0 to 7 loop
                                if grid(i, j) = '1' then row_sum := row_sum + 1; end if;
                            end loop;
                            features(i) <= to_signed(row_sum, 8);
                        end loop;
                        for j in 0 to 7 loop
                            col_sum := 0;
                            for i in 0 to 7 loop
                                if grid(i, j) = '1' then col_sum := col_sum + 1; end if;
                            end loop;
                            features(j + 8) <= to_signed(col_sum, 8);
                        end loop;
                        state <= S_HIDDEN;

                    when S_HIDDEN =>
                        for h in 0 to N_HIDDEN - 1 loop
                            acc := resize(b1(h), 32);
                            for f in 0 to N_INPUT - 1 loop
                                -- Mnozenie przed resize, by uniknac 64-bitowego wyniku!
                                acc := acc + resize(features(f) * W1(f)(h), 32);
                            end loop;
                            acc := shift_right(acc, Q_BITS);
                            
                            -- ReLU
                            if acc < 0 then
                                hidden_post(h) <= (others => '0');
                            else
                                hidden_post(h) <= acc;
                            end if;
                        end loop;
                        state <= S_OUTPUT;

                    when S_OUTPUT =>
                        for c in 0 to N_OUTPUT - 1 loop
                            acc := resize(b2(c), 32);
                            for h in 0 to N_HIDDEN - 1 loop
                                -- Mnozenie przed resize
                                acc := acc + resize(hidden_post(h) * W2(h)(c), 32);
                            end loop;
                            output_vals(c) <= shift_right(acc, Q_BITS);
                        end loop;
                        
                        max_val := output_vals(0); max_idx := 0;
                        for c in 1 to N_OUTPUT - 1 loop
                            if output_vals(c) > max_val then
                                max_val := output_vals(c); max_idx := c;
                            end if;
                        end loop;
                        frame_result <= max_idx;
                        state <= S_VOTE;

                    when S_VOTE =>
                        votes(frame_result) <= votes(frame_result) + 1;
                        if frame_count = N_FRAMES - 1 then
                            frame_count <= 0; state <= S_DECIDE;
                        else
                            frame_count <= frame_count + 1; state <= S_IDLE;
                        end if;

                    when S_DECIDE =>
                        max_idx := 0;
                        for c in 1 to N_OUTPUT - 1 loop
                            if votes(c) > votes(max_idx) then max_idx := c; end if;
                        end loop;
                        cmd_out <= std_logic_vector(to_unsigned(max_idx, 2));
                        votes <= (others => 0);
                        state <= S_EMIT;

                    when S_EMIT =>
                        cmd_valid <= '1';
                        state     <= S_IDLE;
                end case;
            end if;
        end if;
    end process;
end architecture rtl;