"""
=============================================================================
TESTY MODELU UCZĄCEGO – ROZPOZNAWANIE STRZAŁEK I KRZYŻYKA
=============================================================================

Uruchomienie:
    python testy_modelu.py

Co jest testowane:
    1. Poprawność ekstrakcji cech (wymiar, zakres wartości, symetria)
    2. Augmentacja (liczba próbek, binarność, poziom szumu)
    3. Budowanie zbioru danych (rozmiary, balans klas, brak NaN)
    4. Trenowanie modelu (architektura, dokładność > 85%)
    5. Dokładność na czystych wzorcach (idealne szablony)
    6. Odporność na szum (przy szumie 5–20%)
    7. Pewność predykcji (czy model jest wystarczająco pewny)
    8. Testy graniczne (pusta/pełna/losowa siatka)
=============================================================================
"""

import numpy as np
from sklearn.neural_network import MLPClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score

# Importujemy tylko funkcje które faktycznie istnieją w model_uczacy.py
from model_uczacy import (
    extract_features_fpga,   # ekstrakcja 16 cech (sumy wierszy + kolumn)
    augment,                 # generowanie zaszumionych próbek
    build_dataset,           # budowanie zbioru treningowego
    TEMPLATES,               # słownik szablonów {nazwa: macierz 8x8}
    LABEL_MAP,               # mapowanie nazw na liczby {nazwa: 0/1/2/3}
    LABEL_NAMES,             # lista etykiet ["Góra", "Lewo", "Prawo", "Krzyżyk"]
)

# =============================================================================
# FUNKCJE POMOCNICZE – definiujemy lokalnie to czego brakuje w model_uczacy.py
# =============================================================================

def build_and_train_mlp(X_train: np.ndarray, y_train: np.ndarray) -> MLPClassifier:
    """
    Trenuje sieć MLP na podanych danych.
    Architektura: 16 wejść → 32 neurony ukryte → 4 klasy wyjściowe
    (taka sama jak w model_uczacy.py)
    """
    model = MLPClassifier(
        hidden_layer_sizes=(32,),
        activation="relu",
        solver="adam",
        max_iter=1000,
        random_state=42,
    )
    model.fit(X_train, y_train)
    return model


def predict(model: MLPClassifier, grid: np.ndarray) -> dict:
    """
    Rozpoznaje symbol w macierzy 8×8.
    Zwraca słownik z klasą, etykietą, pewnością i wszystkimi prawdopodobieństwami.
    """
    features = extract_features_fpga(grid).reshape(1, -1)
    proba = model.predict_proba(features)[0]
    pred_idx = int(np.argmax(proba))
    pred_name = list(LABEL_MAP.keys())[pred_idx]
    return {
        "class":      pred_name,
        "label":      LABEL_NAMES[pred_idx],
        "confidence": float(proba[pred_idx]),
        "proba_all":  {name: float(p) for name, p in zip(LABEL_NAMES, proba)},
    }


# =============================================================================
# HELPERS – raportowanie wyników testów
# =============================================================================

_passed = 0
_failed = 0

def check(condition: bool, test_name: str, detail: str = ""):
    """Sprawdza warunek i drukuje PASSED lub FAILED."""
    global _passed, _failed
    if condition:
        _passed += 1
        print(f"  ✓ PASSED  {test_name}")
    else:
        _failed += 1
        msg = f" ({detail})" if detail else ""
        print(f"  ✗ FAILED  {test_name}{msg}")

def section(title: str):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")

def summary():
    total = _passed + _failed
    print(f"\n{'='*60}")
    print(f"  WYNIKI: {_passed}/{total} testów zaliczonych")
    if _failed == 0:
        print("  STATUS: ✓ WSZYSTKIE TESTY PRZESZŁY POMYŚLNIE")
    else:
        print(f"  STATUS: ✗ {_failed} TESTÓW NIEUDANYCH")
    print(f"{'='*60}\n")


# =============================================================================
# SEKCJA 1 – TESTY EKSTRAKCJI CECH
# =============================================================================

def test_ekstrakcja_cech():
    section("1. EKSTRAKCJA CECH")

    template = TEMPLATES["up"]
    feat = extract_features_fpga(template)

    # Test 1.1: Wektor cech ma 16 elementów (8 wierszy + 8 kolumn)
    check(
        feat.shape == (16,),
        "Wektor cech ma 16 elementów",
        f"otrzymano {feat.shape}"
    )

    # Test 1.2: Zakres wartości [0, 1]
    check(
        feat.min() >= 0.0 and feat.max() <= 1.0,
        "Wszystkie cechy mieszczą się w zakresie [0, 1]",
        f"min={feat.min():.3f}, max={feat.max():.3f}"
    )

    # Test 1.3: Pusta siatka → wszystkie cechy = 0
    feat_empty = extract_features_fpga(np.zeros((8, 8)))
    check(
        np.all(feat_empty == 0.0),
        "Pusta siatka → wszystkie cechy = 0.0"
    )

    # Test 1.4: Pełna siatka → wszystkie cechy = 1.0
    feat_full = extract_features_fpga(np.ones((8, 8)))
    check(
        np.allclose(feat_full, 1.0),
        "Pełna siatka → wszystkie cechy = 1.0"
    )

    # Test 1.5: Strzałka w lewo i prawo mają różne centroidy kolumn
    feat_left  = extract_features_fpga(TEMPLATES["left"])
    feat_right = extract_features_fpga(TEMPLATES["right"])
    # Sumy kolumn (cechy [8..15]) powinny być przesunięte w różnych kierunkach
    centroid_left  = np.average(np.arange(8), weights=feat_left[8:])
    centroid_right = np.average(np.arange(8), weights=feat_right[8:])
    check(
        centroid_left < centroid_right,
        f"Centroid kolumny: lewo ({centroid_left:.2f}) < prawo ({centroid_right:.2f})"
    )

    # Test 1.6: Różne szablony mają różne wektory cech
    feat_up = extract_features_fpga(TEMPLATES["up"])
    feat_x  = extract_features_fpga(TEMPLATES["x"])
    check(
        not np.allclose(feat_up, feat_x),
        "Różne szablony mają różne wektory cech"
    )


# =============================================================================
# SEKCJA 2 – TESTY AUGMENTACJI
# =============================================================================

def test_augmentacja():
    section("2. AUGMENTACJA DANYCH")

    template = TEMPLATES["up"]
    samples = augment(template, n_samples=50)

    # Test 2.1: Liczba próbek
    check(len(samples) == 50, "augment() zwraca dokładnie 50 próbek")

    # Test 2.2: Rozmiar każdej próbki
    check(
        all(s.shape == (8, 8) for s in samples),
        "Każda próbka ma kształt (8, 8)"
    )

    # Test 2.3: Wartości binarne (tylko 0.0 i 1.0)
    check(
        all(np.all((s == 0.0) | (s == 1.0)) for s in samples),
        "Próbki zawierają tylko wartości 0.0 i 1.0"
    )

    # Test 2.4: Szum nie zmienia zbyt wielu pikseli (przy noise_prob=0.08)
    avg_diff = np.mean([np.sum(np.abs(s - template)) for s in samples])
    check(
        avg_diff < 15,
        f"Średnia liczba zmienionych pikseli = {avg_diff:.1f} (oczekiwane < 15)"
    )

    # Test 2.5: Próbki są różne od siebie (losowość działa)
    unique = len(set(tuple(s.flatten()) for s in samples[:20]))
    check(unique > 15, f"Próbki są różne od siebie ({unique}/20 unikalnych)")


# =============================================================================
# SEKCJA 3 – TESTY ZBIORU DANYCH
# =============================================================================

def test_zbior_danych():
    section("3. BUDOWANIE ZBIORU DANYCH")

    X, y = build_dataset(n_per_class=100)

    # Test 3.1: Całkowita liczba próbek = 4 klasy × 100
    check(
        X.shape[0] == 400,
        f"Zbiór ma 400 próbek (4 × 100)",
        f"otrzymano {X.shape[0]}"
    )

    # Test 3.2: Każda próbka ma 16 cech
    check(
        X.shape[1] == 16,
        f"Każda próbka ma 16 cech",
        f"otrzymano {X.shape[1]}"
    )

    # Test 3.3: Zbiór zbalansowany
    counts = [int(np.sum(y == i)) for i in range(4)]
    check(
        all(c == 100 for c in counts),
        f"Zbiór zbalansowany: {counts} (po 100 na klasę)"
    )

    # Test 3.4: Etykiety w zakresie 0–3
    check(
        int(y.min()) == 0 and int(y.max()) == 3,
        "Etykiety w zakresie [0, 3]"
    )

    # Test 3.5: Brak NaN i Inf
    check(
        np.all(np.isfinite(X)),
        "Żadna cecha nie jest NaN ani Inf"
    )


# =============================================================================
# SEKCJA 4 – TESTY TRENOWANIA MODELU
# =============================================================================

def test_trenowanie(model: MLPClassifier, X_test: np.ndarray, y_test: np.ndarray):
    section("4. TRENOWANIE MODELU")

    # Test 4.1: Model jest wytrenowany
    check(hasattr(model, 'coefs_'), "Model posiada wagi (jest wytrenowany)")

    # Test 4.2: Poprawna liczba zestawów wag (wejście→ukryta, ukryta→wyjście)
    check(
        len(model.coefs_) == 2,
        f"Sieć ma 2 zestawy wag (wejście→ukryta, ukryta→wyjście)"
    )

    # Test 4.3: Warstwa wejściowa przyjmuje 16 cech
    check(
        model.coefs_[0].shape[0] == 16,
        f"Warstwa wejściowa: 16 cech → {model.coefs_[0].shape[1]} neuronów"
    )

    # Test 4.4: Warstwa wyjściowa ma 4 neurony (4 klasy)
    check(
        model.coefs_[-1].shape[1] == 4,
        "Warstwa wyjściowa: 4 neurony (4 klasy)"
    )

    # Test 4.5: Dokładność na zbiorze testowym > 85%
    acc = accuracy_score(y_test, model.predict(X_test))
    check(
        acc > 0.85,
        f"Dokładność na zbiorze testowym = {acc:.1%} (próg: 85%)"
    )

    # Test 4.6: predict_proba() zwraca 4 prawdopodobieństwa sumujące się do 1
    feat = extract_features_fpga(TEMPLATES["up"]).reshape(1, -1)
    proba = model.predict_proba(feat)[0]
    check(len(proba) == 4, "predict_proba() zwraca 4 wartości")
    check(
        abs(proba.sum() - 1.0) < 1e-6,
        f"Prawdopodobieństwa sumują się do 1.0 (suma={proba.sum():.6f})"
    )


# =============================================================================
# SEKCJA 5 – TESTY DOKŁADNOŚCI NA CZYSTYCH WZORCACH
# =============================================================================

def test_czyste_wzorce(model: MLPClassifier):
    section("5. ROZPOZNAWANIE CZYSTYCH WZORCÓW")

    for name, template in TEMPLATES.items():
        result = predict(model, template)
        check(
            result["class"] == name,
            f"'{LABEL_NAMES[LABEL_MAP[name]]}' → predykcja: '{result['label']}' "
            f"(pewność: {result['confidence']:.1%})",
            f"oczekiwano '{name}', otrzymano '{result['class']}'"
        )


# =============================================================================
# SEKCJA 6 – TESTY ODPORNOŚCI NA SZUM
# =============================================================================

def test_odpornosc_na_szum(model: MLPClassifier):
    section("6. ODPORNOŚĆ NA SZUM")

    for noise in [0.05, 0.10, 0.15, 0.20]:
        correct = sum(
            predict(model, sample)["class"] == name
            for name, template in TEMPLATES.items()
            for sample in augment(template, n_samples=50, noise_prob=noise)
        )
        total = 50 * len(TEMPLATES)
        acc = correct / total
        threshold = 0.80 if noise <= 0.15 else 0.60
        check(
            acc >= threshold,
            f"Szum {noise*100:.0f}%: dokładność = {acc:.1%} (próg: {threshold:.0%})"
        )


# =============================================================================
# SEKCJA 7 – TESTY PEWNOŚCI PREDYKCJI
# =============================================================================

def test_pewnosc_predykcji(model: MLPClassifier):
    section("7. PEWNOŚĆ PREDYKCJI")

    # Na czystych wzorcach pewność powinna być > 70%
    for name, template in TEMPLATES.items():
        result = predict(model, template)
        check(
            result["confidence"] > 0.70,
            f"'{LABEL_NAMES[LABEL_MAP[name]]}': pewność {result['confidence']:.1%} > 70%"
        )

    # Słownik predict() zawiera oczekiwane klucze
    result = predict(model, TEMPLATES["up"])
    check(
        set(result.keys()) == {"class", "label", "confidence", "proba_all"},
        "predict() zwraca słownik z kluczami: class, label, confidence, proba_all"
    )


# =============================================================================
# SEKCJA 8 – TESTY GRANICZNE
# =============================================================================

def test_graniczne(model: MLPClassifier):
    section("8. TESTY GRANICZNE")

    # Pusta siatka
    try:
        predict(model, np.zeros((8, 8)))
        check(True, "Pusta siatka nie powoduje błędu")
    except Exception as e:
        check(False, "Pusta siatka nie powoduje błędu", str(e))

    # Pełna siatka
    try:
        predict(model, np.ones((8, 8)))
        check(True, "Pełna siatka nie powoduje błędu")
    except Exception as e:
        check(False, "Pełna siatka nie powoduje błędu", str(e))

    # Losowa siatka
    try:
        rng = np.random.default_rng(0)
        random_grid = (rng.random((8, 8)) > 0.5).astype(float)
        result = predict(model, random_grid)
        check(True, f"Losowa siatka nie powoduje błędu (predykcja: {result['label']})")
    except Exception as e:
        check(False, "Losowa siatka nie powoduje błędu", str(e))

    # Deterministyczność: ta sama siatka = ten sam wynik
    r1 = predict(model, TEMPLATES["right"])
    r2 = predict(model, TEMPLATES["right"])
    check(
        r1["class"] == r2["class"] and abs(r1["confidence"] - r2["confidence"]) < 1e-9,
        "Model deterministyczny: ta sama siatka → ten sam wynik"
    )


# =============================================================================
# GŁÓWNA FUNKCJA
# =============================================================================

if __name__ == "__main__":
    print("\n" + "="*60)
    print("  TESTY MODELU – ROZPOZNAWANIE STRZAŁEK I KRZYŻYKA")
    print("="*60)

    # Przygotowanie: zbuduj dane i wytrenuj model
    print("\nPrzygotowanie: generuję dane i trenuję model...")
    X, y = build_dataset(n_per_class=300)
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    model = build_and_train_mlp(X_train, y_train)
    print("Model gotowy. Rozpoczynam testy...\n")

    # Uruchom wszystkie sekcje
    test_ekstrakcja_cech()
    test_augmentacja()
    test_zbior_danych()
    test_trenowanie(model, X_test, y_test)
    test_czyste_wzorce(model)
    test_odpornosc_na_szum(model)
    test_pewnosc_predykcji(model)
    test_graniczne(model)

    summary()