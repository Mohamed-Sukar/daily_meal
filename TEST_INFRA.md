# Test Infrastructure & Strategy Specification: أكلة النهاردة (Daily Meal)

**Document Version:** 1.0.0  
**Author:** Teamwork Preview Test Writer Track A (`teamwork_preview_test_writer_track_a`)  
**Date:** 2026-09-07  
**Integrity Mode:** Opaque-Box Development Verification  
**Test Framework:** Flutter Test (`flutter_test` / Dart 3.12.0 / Flutter 3.44.0)

---

## 1. Executive Summary & Strategy Overview

The testing suite for **أكلة النهاردة** is engineered according to a strict **4-tier opaque-box methodology**. Every test case is derived directly from authoritative requirements (`ORIGINAL_REQUEST.md`), the architectural blueprint (`PROJECT.md`), and the mined specifications (`architecture_report.md` & `spec_report.md`).

The test suite validates the core domestic problem: *"هناكل إيه النهاردة؟"* by enforcing:
1. **Intelligent Cooldown & Diversity**: Filtering out meals cooked within the cooldown period (14-day default), preventing consecutive repetition of proteins and carbohydrates, elevating Friday specials on Fridays, and executing a 5-tier progressive relaxation fallback cascade when the candidate pool is constrained.
2. **Local Persistence & Data Integrity**: CRUD operations on the Meal Vault, snapshot retention with `onDelete: SetNull` cascading on cooking logs in `meal_history`, and singleton configuration management in `app_settings`.
3. **Material Design 3 & Arabic RTL Localization**: RTL directionality, right-to-left navigation bar ordering, Arabic pluralization, and adaptive layout integrity.
4. **Reactive State Coordination & Discovery**: Unidirectional data flow where vault additions, history logs, or settings changes immediately propagate to recalculate downstream recommendations and feed the Spin the Wheel roulette.
5. **Real-World Household Simulation**: Multi-day domestic cooking cycles (7-day Egyptian menu flow, 15-day cooldown expiration, and low-inventory quarantine).

---

## 2. 4-Tier Test Matrix

| Tier | Category | Focus Areas | Executable Test Target | Test Count |
|------|----------|-------------|------------------------|------------|
| **Tier 1** | **Feature Coverage** | $\ge 5$ test cases per feature across R1 (Vault CRUD, History, Settings), R2 (Cooldown & Scoring Engine), R3 (Settings & Notifications), and R4 (RTL Layout & Riverpod Reactivity). | `test/unit/cooldown_engine_test.dart`<br>`test/unit/database_test.dart`<br>`test/widget/rtl_layout_test.dart`<br>`test/widget/riverpod_reactivity_test.dart` | 29 |
| **Tier 2** | **Boundary & Corner Cases** | Empty meal vault, constrained vaults ($<3$ meals), all meals on cooldown, macro conflicts, 1-day and 60-day limits, name validation, clamp logic, and layout overflow. | `test/unit/cooldown_engine_test.dart`<br>`test/unit/database_test.dart`<br>`test/widget/rtl_layout_test.dart`<br>`test/widget/riverpod_reactivity_test.dart` | 15 |
| **Tier 3** | **Cross-Feature Interactions** | Adding custom meal $\rightarrow$ instant candidate inclusion; Cook Today $\rightarrow$ history log $+$ cooldown $+$ card replacement; Leftover $\rightarrow$ fatigue context update without cooldown; Cooldown slider update $\rightarrow$ instant meal release; Spin the Wheel $\rightarrow$ winner cook flow; History undo $\rightarrow$ instant card restoration. | `test/widget/riverpod_reactivity_test.dart`<br>`test/e2e/full_flow_test.dart` | 8 |
| **Tier 4** | **Real-World Scenarios** | 7-day authentic Egyptian household cooking simulation; 15-day cooldown expiration journey; low-inventory quarantine degradation; full 4-tab user navigation flow. | `test/e2e/full_flow_test.dart` | 4 |
| **Total** | | **Comprehensive Test Suite** | **`flutter test`** | **58** |

---

## 3. Directory Layout & Architecture

The test suite is co-located strictly under `test/`, matching `PROJECT.md` § Code Layout:

```text
test/
├── contracts/ or support/
│   ├── contracts.dart             # Type-safe domain models & enums (Meal, History, Settings)
│   ├── seed_catalog.dart          # 20 authentic Egyptian starter recipes
│   ├── reference_engine.dart      # Authoritative pure mathematical Cooldown Engine
│   └── in_memory_repository.dart  # Reactive DAOs & state coordinator
├── unit/
│   ├── cooldown_engine_test.dart  # Tier 1 (R2) & Tier 2 algorithmic tests (17 tests)
│   └── database_test.dart         # Tier 1 (R1) & Tier 2 persistence & validation tests (15 tests)
├── widget/
│   ├── rtl_layout_test.dart       # Tier 1 (R4) & Tier 2 Arabic RTL UI tests (8 tests)
│   └── riverpod_reactivity_test.dart # Tier 1 (R4/R2) & Tier 3 reactivity tests (8 tests)
├── e2e/
│   └── full_flow_test.dart        # Tier 3 (Cross-Feature) & Tier 4 (Real-World) tests (9 tests)
└── widget_test.dart               # Default Flutter counter smoke test (1 test)
```

---

## 4. Expected Output Derivation & Mathematical Specifications

Expected test values are derived from mathematical equations and specification rules rather than implementation internal state:

### 4.1 Cooldown Window Exclusion Formula
$$\Delta d = \text{daysBetween}(\text{lastCooked}(m), T_{\text{today}})$$
$$\text{IsExcluded}(m) \iff \Delta d \le C_{\text{days}}$$
- For $C_{\text{days}} = 14$: meals cooked within the last 14 days ($1 \dots 14$ days ago) are excluded. A meal cooked 15 days ago is immediately eligible.
- For $C_{\text{days}} = 1$: yesterday's meal ($\Delta d = 1$) is excluded; a meal cooked 2 days ago ($\Delta d = 2$) is eligible.

### 4.2 Macronutrient Repeat Prevention
$$\text{lastProtein} = h_{\text{last}}.\text{proteinType}, \quad \text{lastCarbs} = h_{\text{last}}.\text{carbsType}$$
- If $F_{\text{protein}} == \text{true}$ and $m.\text{proteinType} == \text{lastProtein} \implies \text{Excluded}$.
- If $F_{\text{carbs}} == \text{true}$ and $m.\text{carbsType} == \text{lastCarbs} \implies \text{Excluded}$.

### 4.3 Friday Special Scoring & Ranking
$$\text{Score}(m) = S_{\text{recency}}(m) + S_{\text{friday}}(m) + S_{\text{favorite}}(m) + S_{\text{budget}}(m) + Jitter(m)$$
Where:
- $S_{\text{recency}} = 25.0$ for untried meals, or $\min\left(20.0, \frac{\Delta d - C_{\text{days}}}{2.0}\right)$.
- $S_{\text{friday}} = +15.0$ if $T_{\text{today}}$ is Friday and $m.\text{isFridaySpecial}$; $-5.0$ on non-Fridays.
- $S_{\text{favorite}} = +5.0$.
- $S_{\text{budget}} = +2.0$.
- $Jitter = \left((T_{\text{today}}.\text{day} \times 17 + m.\text{id} \times 31) \pmod{100}\right) / 25.0$.

### 4.4 5-Level Graceful Degradation Cascade
Triggered whenever candidate pool count $< 3$:
- **Level 0**: Strict ($C_{\text{days}}$, no repeat protein, no repeat carbs).
- **Level 1**: Relax Carbs ($C_{\text{days}}$, no repeat protein, allow repeat carbs).
- **Level 2**: Halve Cooldown ($\min(C_{\text{days}}, \max(1, \lfloor C_{\text{days}} / 2 \rfloor))$, no repeat protein).
- **Level 3**: Relax Protein ($\min(C_{\text{days}}, \max(1, \lfloor C_{\text{days}} / 4 \rfloor))$, allow repeat protein & carbs).
- **Level 4**: Emergency Non-Same-Day (exclude only meals where $\Delta d == 0$).
- **Level 5**: Minimal Inventory (return all distinct meals in DB; empty list if 0 meals).

---

## 5. Execution Commands

### 5.1 Run the Full Test Suite
```bash
flutter test
```

### 5.2 Run Individual Test Suites
```bash
# Recommendation Engine & Cooldown Unit Tests
flutter test test/unit/cooldown_engine_test.dart

# Database, CRUD, History & Settings Unit Tests
flutter test test/unit/database_test.dart

# Arabic RTL & Material 3 Layout Widget Tests
flutter test test/widget/rtl_layout_test.dart

# Riverpod Reactivity & Spin the Wheel Tests
flutter test test/widget/riverpod_reactivity_test.dart

# Cross-Feature & End-to-End Real-World Scenario Tests
flutter test test/e2e/full_flow_test.dart
```

### 5.3 Static Analysis & Quality Gate
```bash
flutter analyze test
```

---

## 6. Test Integrity, Determinism & Independence

1. **Deterministic Clocks**: All time-dependent tests inject a normalized `today` or use `nowProvider`, preventing non-deterministic flakiness from system clocks or local timezones.
2. **State Isolation**: Every test creates its own fresh instance of `InMemoryMealsDao`, `InMemoryMealHistoryDao`, or `AppStateCoordinator`. No state leaks across test boundaries.
3. **Disposal & Teardown**: Every test suite registers `tearDown` hooks that cancel stream subscriptions and close broadcast controllers, guaranteeing clean process termination with zero orphaned async handlers.
4. **No Facade Tests**: Every test assertion inspects domain properties (candidate meal IDs, macro types, cooldown relaxation levels, stream emissions, or widget coordinates) to verify genuine business logic.
