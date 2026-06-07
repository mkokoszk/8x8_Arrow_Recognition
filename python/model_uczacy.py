"""
=============================================================================
EKSPORT WAG SIECI MLP DO VHDL – IMPLEMENTACJA NA FPGA
=============================================================================

Ten skrypt:
  1. Trenuje uproszczoną sieć MLP używając tylko 16 cech (sumy wierszy + kolumn)
     – te cechy są BARDZO łatwe do obliczenia w logice VHDL (same dodawania)
  2. Konwertuje wagi float → stałoprzecinkowe Q8 (mnożnik 256, 16-bitowe int)
  3. Generuje gotowy plik VHDL z wagami jako stałymi (CONSTANT)

Dlaczego Q8 (fixed-point)?
  FPGA nie ma sprzętowego wsparcia dla liczb zmiennoprzecinkowych (float).
  Zamiast tego mnożymy wszystkie wagi przez 256 i zaokrąglamy do int.
  Np. waga 0.347 → round(0.347 * 256) = 89 (integer)
  Podział przez 256 jest potem realizowany przez przesunięcie bitowe >> 8.

Architektura sieci (uproszczona pod FPGA):
  Wejście:   16 cech (sumy 8 wierszy + sumy 8 kolumn, każda 0–8)
  Warstwa 1: 32 neurony + ReLU
  Warstwa 2: 4 neurony (wyjście klas)
  Klasa = indeks neuronu o największej wartości (argmax)
=============================================================================
"""

import numpy as np
from sklearn.neural_network import MLPClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report

# ── Skala Q8: wagi float mnożymy przez 256 przed zapisem do VHDL ──────────
Q_SCALE = 256

# =============================================================================
# CZĘŚĆ 1 – SZABLONY (identyczne jak w głównym kodzie)
# =============================================================================

TEMPLATE_UP = np.array([
    [0,0,0,1,0,0,0,0],
    [0,0,1,1,1,0,0,0],
    [0,1,0,1,0,1,0,0],
    [0,0,0,1,0,0,0,0],
    [0,0,0,1,0,0,0,0],
    [0,0,0,1,0,0,0,0],
    [0,0,0,1,0,0,0,0],
    [0,0,0,0,0,0,0,0],
], dtype=float)

TEMPLATE_LEFT = np.array([
    [0,0,0,0,0,0,0,0],
    [0,0,0,1,0,0,0,0],
    [0,0,1,0,0,0,0,0],
    [0,1,1,1,1,1,1,0],
    [0,0,1,0,0,0,0,0],
    [0,0,0,1,0,0,0,0],
    [0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0],
], dtype=float)

TEMPLATE_RIGHT = np.array([
    [0,0,0,0,0,0,0,0],
    [0,0,0,0,1,0,0,0],
    [0,0,0,0,0,1,0,0],
    [0,1,1,1,1,1,1,0],
    [0,0,0,0,0,1,0,0],
    [0,0,0,0,1,0,0,0],
    [0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0],
], dtype=float)

TEMPLATE_X = np.array([
    [1,0,0,0,0,0,1,0],
    [0,1,0,0,0,1,0,0],
    [0,0,1,0,1,0,0,0],
    [0,0,0,1,0,0,0,0],
    [0,0,1,0,1,0,0,0],
    [0,1,0,0,0,1,0,0],
    [1,0,0,0,0,0,1,0],
    [0,0,0,0,0,0,0,0],
], dtype=float)

TEMPLATES = {"up": TEMPLATE_UP, "left": TEMPLATE_LEFT,
             "right": TEMPLATE_RIGHT, "x": TEMPLATE_X}
LABEL_MAP  = {"up": 0, "left": 1, "right": 2, "x": 3}
LABEL_NAMES = ["Góra", "Lewo", "Prawo", "Krzyżyk"]


# =============================================================================
# CZĘŚĆ 2 – UPROSZCZONA EKSTRAKCJA CECH (tylko 16 cech)
# =============================================================================
# Wybieramy TYLKO sumy wierszy i kolumn, bo:
#   • w VHDL to zwykłe dodawanie 8 sygnałów 1-bitowych → wynik 4-bitowy
#   • nie potrzeba mnożeń ani dzielenia na etapie ekstrakcji cech
#   • 16 wartości 0–8 → normalizujemy do 0–255 (mnożymy × 255/8 ≈ ×32)

def extract_features_fpga(grid: np.ndarray) -> np.ndarray:
    """
    Wyciąga 16 cech przyjaznych FPGA:
      cechy [0..7]  = suma każdego wiersza (0–8)
      cechy [8..15] = suma każdej kolumny (0–8)

    Normalizacja do [0,1] przez podzielenie przez 8
    (w VHDL: wartość 0–8 bez normalizacji, skalujemy wagi zamiast wejść)
    """
    row_sums = grid.sum(axis=1) / 8.0   # 8 wartości
    col_sums = grid.sum(axis=0) / 8.0   # 8 wartości
    return np.concatenate([row_sums, col_sums])  # wektor 16 wartości


# =============================================================================
# CZĘŚĆ 3 – AUGMENTACJA I BUDOWANIE ZBIORU DANYCH
# =============================================================================

def augment(template, n_samples=400, noise_prob=0.08):
    samples = []
    for _ in range(n_samples):
        noise = np.random.rand(8, 8) < noise_prob
        noisy = np.logical_xor(template.astype(bool), noise).astype(float)
        samples.append(noisy)
    return samples

def build_dataset(n_per_class=400):
    X_list, y_list = [], []
    for name, template in TEMPLATES.items():
        for sample in augment(template, n_per_class):
            X_list.append(extract_features_fpga(sample))
            y_list.append(LABEL_MAP[name])
    return np.array(X_list), np.array(y_list)


# =============================================================================
# CZĘŚĆ 4 – TRENOWANIE UPROSZCZONEJ SIECI (16 → 32 → 4)
# =============================================================================

print("Buduję zbiór danych...")
X, y = build_dataset(n_per_class=500)
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

print("Trenuję sieć MLP (16 → 32 → 4)...")
model = MLPClassifier(
    hidden_layer_sizes=(32,),   # jedna warstwa ukryta: 32 neurony
    activation="relu",
    solver="adam",
    max_iter=1000,
    random_state=42,
)
model.fit(X_train, y_train)

y_pred = model.predict(X_test)
print("\n=== Raport klasyfikacji ===")
print(classification_report(y_test, y_pred, target_names=LABEL_NAMES))


# =============================================================================
# CZĘŚĆ 5 – KONWERSJA WAG NA FIXED-POINT Q8
# =============================================================================
# Schemat: waga_int = round(waga_float × 256)
# W VHDL obliczenia: wynik = (wejście × waga_int) >> 8
# To zastępuje mnożenie przez liczbę zmiennoprzecinkową prostym przesunięciem.

def to_fixed(arr: np.ndarray, scale: int = Q_SCALE) -> np.ndarray:
    """Konwertuje tablicę float → int (Q8 fixed-point)."""
    return np.round(arr * scale).astype(int)

# Wyciągnij wagi z wytrenowanego modelu sklearn
# model.coefs_[0] → wagi warstwy 1 (kształt: 16×32)
# model.coefs_[1] → wagi warstwy 2 (kształt: 32×4)
# model.intercepts_[0] → biasy warstwy 1 (32 wartości)
# model.intercepts_[1] → biasy warstwy 2 (4 wartości)

W1 = to_fixed(model.coefs_[0])          # (16, 32)
b1 = to_fixed(model.intercepts_[0])     # (32,)
W2 = to_fixed(model.coefs_[1])          # (32, 4)
b2 = to_fixed(model.intercepts_[1])     # (4,)

print(f"\nWagi warstwy 1: {W1.shape}, zakres [{W1.min()} .. {W1.max()}]")
print(f"Wagi warstwy 2: {W2.shape}, zakres [{W2.min()} .. {W2.max()}]")


# =============================================================================
# CZĘŚĆ 6 – GENEROWANIE PLIKU VHDL Z WAGAMI
# =============================================================================
# Generujemy plik wagi_mlp_pkg.vhd zawierający stałe VHDL.
# Ten plik jest importowany przez główny moduł VHDL sieci MLP.

def int_to_vhdl(val: int, bits: int = 16) -> str:
    """Zamienia liczbę całkowitą na VHDL signed literal."""
    return f"to_signed({val}, {bits})"

def array_to_vhdl_constant(name: str, arr: np.ndarray, bits: int = 16) -> str:
    """Generuje VHDL CONSTANT dla tablicy 1D lub 2D."""
    if arr.ndim == 1:
        n = arr.shape[0]
        type_def = f"  type t_{name} is array (0 to {n-1}) of signed({bits-1} downto 0);\n"
        values = ", ".join(int_to_vhdl(v, bits) for v in arr)
        const = f"  constant {name} : t_{name} := ({values});\n"
        return type_def + const
    else:
        rows, cols = arr.shape
        type_def = (
            f"  type t_{name}_row is array (0 to {cols-1}) of signed({bits-1} downto 0);\n"
            f"  type t_{name} is array (0 to {rows-1}) of t_{name}_row;\n"
        )
        row_strs = []
        for r in range(rows):
            vals = ", ".join(int_to_vhdl(v, bits) for v in arr[r])
            row_strs.append(f"    ({vals})")
        const = f"  constant {name} : t_{name} := (\n" + ",\n".join(row_strs) + "\n  );\n"
        return type_def + const

vhdl_package = f"""\
-- =============================================================================
-- PLIK AUTOMATYCZNIE WYGENEROWANY PRZEZ export_do_vhdl.py
-- Zawiera wagi sieci MLP w formacie stałoprzecinkowym Q8 (skala = {Q_SCALE})
--
-- Format Q8: rzeczywista waga = wartość_integer / {Q_SCALE}
-- Przykład: waga 0.347 → {round(0.347 * Q_SCALE)} (integer)
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
  constant Q_BITS   : integer := 8;   -- bity ułamkowe (skala = 2^Q_BITS = {Q_SCALE})

{array_to_vhdl_constant("W1", W1)}
{array_to_vhdl_constant("b1", b1)}
{array_to_vhdl_constant("W2", W2)}
{array_to_vhdl_constant("b2", b2)}
end package wagi_mlp_pkg;
"""

with open("wagi_mlp_pkg.vhd", "w", encoding="utf-8") as f:
    f.write(vhdl_package)

print("\nWygenerowano plik: wagi_mlp_pkg.vhd")
print("Teraz skompiluj oba pliki VHDL w Vivado / Quartus:")
print("  1. wagi_mlp_pkg.vhd   (pakiet z wagami)")
print("  2. rozpoznawanie_strzalek.vhd  (logika sieci)")