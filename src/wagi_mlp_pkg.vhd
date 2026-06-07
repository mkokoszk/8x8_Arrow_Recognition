-- =============================================================================
-- PLIK AUTOMATYCZNIE WYGENEROWANY PRZEZ export_do_vhdl.py
-- Zawiera wagi sieci MLP w formacie stałoprzecinkowym Q8 (skala = 256)
--
-- Format Q8: rzeczywista waga = wartość_integer / 256
-- Przykład: waga 0.347 → 89 (integer)
--
-- Architektura:
--   Wejście: 16 cech (sumy wierszy i kolumn siatki 8x8)
--   Warstwa ukryta: 32 neurony + ReLU
--   Wyjście: 4 neurony (0=Góra, 1=Lewo, 2=Prawo, 3=Krzyżyk)
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package wagi_mlp_pkg is

  -- Stałe określające rozmiary sieci
  constant N_INPUT  : integer := 16;  -- liczba cech wejściowych
  constant N_HIDDEN : integer := 32;  -- neurony warstwy ukrytej
  constant N_OUTPUT : integer := 4;   -- klasy wyjściowe
  constant Q_BITS   : integer := 8;   -- bity ułamkowe (skala = 2^Q_BITS = 256)

  type t_W1_row is array (0 to 31) of signed(15 downto 0);
  type t_W1 is array (0 to 15) of t_W1_row;
  constant W1 : t_W1 := (
    (to_signed(147, 16), to_signed(239, 16), to_signed(0, 16), to_signed(0, 16), to_signed(-59, 16), to_signed(-205, 16), to_signed(62, 16), to_signed(0, 16), to_signed(-106, 16), to_signed(31, 16), to_signed(-125, 16), to_signed(192, 16), to_signed(-68, 16), to_signed(0, 16), to_signed(-57, 16), to_signed(-29, 16), to_signed(120, 16), to_signed(74, 16), to_signed(-22, 16), to_signed(-21, 16), to_signed(194, 16), to_signed(-61, 16), to_signed(136, 16), to_signed(154, 16), to_signed(-170, 16), to_signed(-42, 16), to_signed(101, 16), to_signed(0, 16), to_signed(45, 16), to_signed(-193, 16), to_signed(-165, 16), to_signed(20, 16)),
    (to_signed(99, 16), to_signed(96, 16), to_signed(0, 16), to_signed(0, 16), to_signed(-65, 16), to_signed(-248, 16), to_signed(197, 16), to_signed(0, 16), to_signed(-194, 16), to_signed(-11, 16), to_signed(3, 16), to_signed(98, 16), to_signed(-45, 16), to_signed(0, 16), to_signed(129, 16), to_signed(1, 16), to_signed(-51, 16), to_signed(-70, 16), to_signed(-3, 16), to_signed(-50, 16), to_signed(77, 16), to_signed(42, 16), to_signed(240, 16), to_signed(245, 16), to_signed(-206, 16), to_signed(-181, 16), to_signed(59, 16), to_signed(0, 16), to_signed(-87, 16), to_signed(-100, 16), to_signed(-154, 16), to_signed(-65, 16)),
    (to_signed(116, 16), to_signed(28, 16), to_signed(0, 16), to_signed(0, 16), to_signed(-54, 16), to_signed(-103, 16), to_signed(206, 16), to_signed(0, 16), to_signed(-213, 16), to_signed(47, 16), to_signed(113, 16), to_signed(80, 16), to_signed(78, 16), to_signed(0, 16), to_signed(99, 16), to_signed(-56, 16), to_signed(-31, 16), to_signed(56, 16), to_signed(-82, 16), to_signed(-115, 16), to_signed(-13, 16), to_signed(-13, 16), to_signed(240, 16), to_signed(171, 16), to_signed(-62, 16), to_signed(-126, 16), to_signed(51, 16), to_signed(0, 16), to_signed(24, 16), to_signed(-70, 16), to_signed(-142, 16), to_signed(-50, 16)),
    (to_signed(-146, 16), to_signed(-231, 16), to_signed(0, 16), to_signed(0, 16), to_signed(89, 16), to_signed(243, 16), to_signed(-189, 16), to_signed(0, 16), to_signed(241, 16), to_signed(-58, 16), to_signed(244, 16), to_signed(-63, 16), to_signed(83, 16), to_signed(0, 16), to_signed(140, 16), to_signed(-44, 16), to_signed(53, 16), to_signed(-24, 16), to_signed(101, 16), to_signed(117, 16), to_signed(-99, 16), to_signed(-60, 16), to_signed(-78, 16), to_signed(-188, 16), to_signed(313, 16), to_signed(242, 16), to_signed(-208, 16), to_signed(0, 16), to_signed(-75, 16), to_signed(130, 16), to_signed(296, 16), to_signed(9, 16)),
    (to_signed(44, 16), to_signed(142, 16), to_signed(0, 16), to_signed(0, 16), to_signed(-77, 16), to_signed(-83, 16), to_signed(160, 16), to_signed(0, 16), to_signed(11, 16), to_signed(26, 16), to_signed(-71, 16), to_signed(110, 16), to_signed(-22, 16), to_signed(0, 16), to_signed(-8, 16), to_signed(-19, 16), to_signed(158, 16), to_signed(-53, 16), to_signed(54, 16), to_signed(34, 16), to_signed(74, 16), to_signed(-45, 16), to_signed(65, 16), to_signed(106, 16), to_signed(-87, 16), to_signed(103, 16), to_signed(253, 16), to_signed(0, 16), to_signed(64, 16), to_signed(5, 16), to_signed(-85, 16), to_signed(84, 16)),
    (to_signed(81, 16), to_signed(131, 16), to_signed(0, 16), to_signed(0, 16), to_signed(-90, 16), to_signed(-43, 16), to_signed(69, 16), to_signed(0, 16), to_signed(-73, 16), to_signed(11, 16), to_signed(-7, 16), to_signed(-47, 16), to_signed(-20, 16), to_signed(0, 16), to_signed(-11, 16), to_signed(-42, 16), to_signed(150, 16), to_signed(44, 16), to_signed(131, 16), to_signed(14, 16), to_signed(105, 16), to_signed(-14, 16), to_signed(88, 16), to_signed(183, 16), to_signed(-84, 16), to_signed(104, 16), to_signed(181, 16), to_signed(0, 16), to_signed(83, 16), to_signed(-84, 16), to_signed(-97, 16), to_signed(95, 16)),
    (to_signed(226, 16), to_signed(174, 16), to_signed(0, 16), to_signed(0, 16), to_signed(38, 16), to_signed(-69, 16), to_signed(199, 16), to_signed(0, 16), to_signed(-88, 16), to_signed(-84, 16), to_signed(-119, 16), to_signed(179, 16), to_signed(-92, 16), to_signed(0, 16), to_signed(-128, 16), to_signed(21, 16), to_signed(76, 16), to_signed(31, 16), to_signed(37, 16), to_signed(83, 16), to_signed(202, 16), to_signed(-13, 16), to_signed(160, 16), to_signed(110, 16), to_signed(-175, 16), to_signed(-17, 16), to_signed(168, 16), to_signed(0, 16), to_signed(93, 16), to_signed(-99, 16), to_signed(-232, 16), to_signed(60, 16)),
    (to_signed(77, 16), to_signed(-22, 16), to_signed(0, 16), to_signed(0, 16), to_signed(5, 16), to_signed(-57, 16), to_signed(191, 16), to_signed(0, 16), to_signed(-22, 16), to_signed(-12, 16), to_signed(-4, 16), to_signed(40, 16), to_signed(-8, 16), to_signed(0, 16), to_signed(127, 16), to_signed(-29, 16), to_signed(85, 16), to_signed(80, 16), to_signed(37, 16), to_signed(-24, 16), to_signed(-5, 16), to_signed(66, 16), to_signed(102, 16), to_signed(242, 16), to_signed(-24, 16), to_signed(29, 16), to_signed(101, 16), to_signed(0, 16), to_signed(56, 16), to_signed(-27, 16), to_signed(-85, 16), to_signed(-9, 16)),
    (to_signed(191, 16), to_signed(214, 16), to_signed(0, 16), to_signed(0, 16), to_signed(5, 16), to_signed(2, 16), to_signed(-18, 16), to_signed(0, 16), to_signed(18, 16), to_signed(32, 16), to_signed(-98, 16), to_signed(129, 16), to_signed(-186, 16), to_signed(0, 16), to_signed(-75, 16), to_signed(27, 16), to_signed(264, 16), to_signed(173, 16), to_signed(113, 16), to_signed(109, 16), to_signed(240, 16), to_signed(104, 16), to_signed(-130, 16), to_signed(45, 16), to_signed(17, 16), to_signed(131, 16), to_signed(120, 16), to_signed(0, 16), to_signed(139, 16), to_signed(-173, 16), to_signed(-75, 16), to_signed(120, 16)),
    (to_signed(36, 16), to_signed(108, 16), to_signed(0, 16), to_signed(0, 16), to_signed(59, 16), to_signed(-97, 16), to_signed(9, 16), to_signed(0, 16), to_signed(65, 16), to_signed(-58, 16), to_signed(3, 16), to_signed(-41, 16), to_signed(-64, 16), to_signed(0, 16), to_signed(-22, 16), to_signed(16, 16), to_signed(136, 16), to_signed(152, 16), to_signed(69, 16), to_signed(57, 16), to_signed(153, 16), to_signed(21, 16), to_signed(-20, 16), to_signed(10, 16), to_signed(-74, 16), to_signed(173, 16), to_signed(157, 16), to_signed(0, 16), to_signed(70, 16), to_signed(-58, 16), to_signed(-11, 16), to_signed(-23, 16)),
    (to_signed(71, 16), to_signed(98, 16), to_signed(0, 16), to_signed(0, 16), to_signed(75, 16), to_signed(257, 16), to_signed(-145, 16), to_signed(0, 16), to_signed(130, 16), to_signed(-54, 16), to_signed(48, 16), to_signed(-62, 16), to_signed(-300, 16), to_signed(0, 16), to_signed(126, 16), to_signed(-3, 16), to_signed(292, 16), to_signed(-94, 16), to_signed(-94, 16), to_signed(-212, 16), to_signed(35, 16), to_signed(-171, 16), to_signed(-56, 16), to_signed(50, 16), to_signed(172, 16), to_signed(185, 16), to_signed(187, 16), to_signed(0, 16), to_signed(-187, 16), to_signed(136, 16), to_signed(254, 16), to_signed(109, 16)),
    (to_signed(244, 16), to_signed(-203, 16), to_signed(0, 16), to_signed(0, 16), to_signed(-78, 16), to_signed(165, 16), to_signed(243, 16), to_signed(0, 16), to_signed(0, 16), to_signed(13, 16), to_signed(134, 16), to_signed(-75, 16), to_signed(-43, 16), to_signed(0, 16), to_signed(328, 16), to_signed(64, 16), to_signed(8, 16), to_signed(-293, 16), to_signed(-231, 16), to_signed(-306, 16), to_signed(-305, 16), to_signed(-156, 16), to_signed(135, 16), to_signed(153, 16), to_signed(11, 16), to_signed(-207, 16), to_signed(215, 16), to_signed(0, 16), to_signed(-281, 16), to_signed(206, 16), to_signed(-126, 16), to_signed(13, 16)),
    (to_signed(-93, 16), to_signed(-12, 16), to_signed(0, 16), to_signed(0, 16), to_signed(91, 16), to_signed(-63, 16), to_signed(21, 16), to_signed(0, 16), to_signed(57, 16), to_signed(41, 16), to_signed(-93, 16), to_signed(105, 16), to_signed(238, 16), to_signed(0, 16), to_signed(-151, 16), to_signed(22, 16), to_signed(-246, 16), to_signed(229, 16), to_signed(157, 16), to_signed(238, 16), to_signed(-41, 16), to_signed(265, 16), to_signed(-125, 16), to_signed(-280, 16), to_signed(124, 16), to_signed(59, 16), to_signed(-185, 16), to_signed(0, 16), to_signed(266, 16), to_signed(45, 16), to_signed(199, 16), to_signed(-68, 16)),
    (to_signed(-190, 16), to_signed(-76, 16), to_signed(0, 16), to_signed(0, 16), to_signed(123, 16), to_signed(-113, 16), to_signed(-143, 16), to_signed(0, 16), to_signed(-12, 16), to_signed(3, 16), to_signed(-132, 16), to_signed(119, 16), to_signed(164, 16), to_signed(0, 16), to_signed(-318, 16), to_signed(36, 16), to_signed(-180, 16), to_signed(112, 16), to_signed(104, 16), to_signed(245, 16), to_signed(-46, 16), to_signed(297, 16), to_signed(-89, 16), to_signed(-299, 16), to_signed(-31, 16), to_signed(204, 16), to_signed(-200, 16), to_signed(0, 16), to_signed(270, 16), to_signed(73, 16), to_signed(261, 16), to_signed(-18, 16)),
    (to_signed(-82, 16), to_signed(64, 16), to_signed(0, 16), to_signed(0, 16), to_signed(42, 16), to_signed(47, 16), to_signed(-172, 16), to_signed(0, 16), to_signed(-6, 16), to_signed(-14, 16), to_signed(-218, 16), to_signed(-3, 16), to_signed(-23, 16), to_signed(0, 16), to_signed(-121, 16), to_signed(10, 16), to_signed(199, 16), to_signed(99, 16), to_signed(98, 16), to_signed(211, 16), to_signed(88, 16), to_signed(251, 16), to_signed(-246, 16), to_signed(-50, 16), to_signed(16, 16), to_signed(197, 16), to_signed(-37, 16), to_signed(0, 16), to_signed(93, 16), to_signed(-8, 16), to_signed(182, 16), to_signed(58, 16)),
    (to_signed(42, 16), to_signed(8, 16), to_signed(0, 16), to_signed(0, 16), to_signed(38, 16), to_signed(50, 16), to_signed(7, 16), to_signed(0, 16), to_signed(76, 16), to_signed(56, 16), to_signed(50, 16), to_signed(25, 16), to_signed(55, 16), to_signed(0, 16), to_signed(45, 16), to_signed(0, 16), to_signed(-38, 16), to_signed(-46, 16), to_signed(81, 16), to_signed(118, 16), to_signed(18, 16), to_signed(79, 16), to_signed(75, 16), to_signed(120, 16), to_signed(-3, 16), to_signed(-38, 16), to_signed(116, 16), to_signed(0, 16), to_signed(96, 16), to_signed(76, 16), to_signed(67, 16), to_signed(-67, 16))
  );

  type t_b1 is array (0 to 31) of signed(15 downto 0);
  constant b1 : t_b1 := (to_signed(104, 16), to_signed(47, 16), to_signed(-82, 16), to_signed(-86, 16), to_signed(-11, 16), to_signed(143, 16), to_signed(133, 16), to_signed(-63, 16), to_signed(99, 16), to_signed(-31, 16), to_signed(157, 16), to_signed(36, 16), to_signed(121, 16), to_signed(-6, 16), to_signed(95, 16), to_signed(-43, 16), to_signed(-17, 16), to_signed(59, 16), to_signed(72, 16), to_signed(120, 16), to_signed(86, 16), to_signed(29, 16), to_signed(130, 16), to_signed(179, 16), to_signed(103, 16), to_signed(64, 16), to_signed(92, 16), to_signed(-67, 16), to_signed(87, 16), to_signed(94, 16), to_signed(104, 16), to_signed(3, 16));

  type t_W2_row is array (0 to 3) of signed(15 downto 0);
  type t_W2 is array (0 to 31) of t_W2_row;
  constant W2 : t_W2 := (
    (to_signed(234, 16), to_signed(-19, 16), to_signed(-326, 16), to_signed(77, 16)),
    (to_signed(-99, 16), to_signed(-99, 16), to_signed(-173, 16), to_signed(240, 16)),
    (to_signed(0, 16), to_signed(0, 16), to_signed(0, 16), to_signed(0, 16)),
    (to_signed(0, 16), to_signed(0, 16), to_signed(0, 16), to_signed(0, 16)),
    (to_signed(-279, 16), to_signed(-129, 16), to_signed(94, 16), to_signed(-321, 16)),
    (to_signed(-68, 16), to_signed(205, 16), to_signed(29, 16), to_signed(-123, 16)),
    (to_signed(212, 16), to_signed(-167, 16), to_signed(-195, 16), to_signed(36, 16)),
    (to_signed(0, 16), to_signed(0, 16), to_signed(0, 16), to_signed(0, 16)),
    (to_signed(-279, 16), to_signed(274, 16), to_signed(169, 16), to_signed(-240, 16)),
    (to_signed(2, 16), to_signed(89, 16), to_signed(-12, 16), to_signed(-46, 16)),
    (to_signed(164, 16), to_signed(122, 16), to_signed(-36, 16), to_signed(-247, 16)),
    (to_signed(-42, 16), to_signed(-205, 16), to_signed(-48, 16), to_signed(50, 16)),
    (to_signed(-3, 16), to_signed(-216, 16), to_signed(304, 16), to_signed(-116, 16)),
    (to_signed(0, 16), to_signed(0, 16), to_signed(0, 16), to_signed(0, 16)),
    (to_signed(109, 16), to_signed(114, 16), to_signed(-332, 16), to_signed(-296, 16)),
    (to_signed(0, 16), to_signed(0, 16), to_signed(0, 16), to_signed(0, 16)),
    (to_signed(-230, 16), to_signed(280, 16), to_signed(-342, 16), to_signed(181, 16)),
    (to_signed(-143, 16), to_signed(-265, 16), to_signed(235, 16), to_signed(193, 16)),
    (to_signed(-289, 16), to_signed(-148, 16), to_signed(265, 16), to_signed(115, 16)),
    (to_signed(-242, 16), to_signed(-220, 16), to_signed(126, 16), to_signed(7, 16)),
    (to_signed(-212, 16), to_signed(-113, 16), to_signed(-76, 16), to_signed(217, 16)),
    (to_signed(-219, 16), to_signed(-387, 16), to_signed(344, 16), to_signed(212, 16)),
    (to_signed(258, 16), to_signed(-56, 16), to_signed(-163, 16), to_signed(-57, 16)),
    (to_signed(175, 16), to_signed(-50, 16), to_signed(-287, 16), to_signed(12, 16)),
    (to_signed(-174, 16), to_signed(151, 16), to_signed(115, 16), to_signed(-182, 16)),
    (to_signed(-278, 16), to_signed(212, 16), to_signed(182, 16), to_signed(-6, 16)),
    (to_signed(242, 16), to_signed(93, 16), to_signed(-333, 16), to_signed(140, 16)),
    (to_signed(0, 16), to_signed(0, 16), to_signed(0, 16), to_signed(0, 16)),
    (to_signed(-204, 16), to_signed(-234, 16), to_signed(205, 16), to_signed(156, 16)),
    (to_signed(74, 16), to_signed(273, 16), to_signed(127, 16), to_signed(-201, 16)),
    (to_signed(-335, 16), to_signed(85, 16), to_signed(133, 16), to_signed(-233, 16)),
    (to_signed(-100, 16), to_signed(54, 16), to_signed(-99, 16), to_signed(59, 16))
  );

  type t_b2 is array (0 to 3) of signed(15 downto 0);
  constant b2 : t_b2 := (to_signed(-41, 16), to_signed(9, 16), to_signed(9, 16), to_signed(65, 16));

end package wagi_mlp_pkg;
