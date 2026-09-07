# Milestone 3 Adversarial Challenge Report: UI Presentation Layer

**Agent Identity**: `teamwork_preview_challenger_m3_1`  
**Date**: 2026-09-07  
**Verdict**: **REJECT**  
**Overall Risk Assessment**: **HIGH**

---

## 1. Executive Summary

As an Empirical Adversarial Challenger for Milestone 3, I conducted rigorous stress-testing against the Daily Meal presentation layer (`lib/features/home/presentation/`, `lib/features/vault/presentation/`, `lib/core/router/`, and connected views).

The UI was subjected to six adversarial stress dimensions:
1. Ultra-long Arabic meal titles (>150 characters)
2. Extreme preparation times (0, 1, 10, 99999, and negative numbers)
3. Zero-meal boundary state (0 candidates in Vault, Home, and Wheel)
4. High-volume scalability (120+ meals, fling scrolling, search querying, and chip filtering)
5. Rapid tab switching (rapid loop across all 4 StatefulShellRoute tabs)
6. Extreme viewport dimensions (320px width, 550px height) and accessibility text enlargement (`TextScaler.linear(1.4)`).

All verification was conducted empirically by writing and running the dedicated test suite:  
`test/widget/adversarial_ui_stress_test.dart`.

While the Home 3-card stack and quick action buttons demonstrated strong responsiveness and text wrapping, **five critical `RenderFlex` overflow defects were empirically reproduced**, directly violating the zero-overflow requirement. The verdict is **REJECT**.

---

## 2. Confirmed Vulnerabilities & Defect Analysis

### Defect 1 [CRITICAL/HIGH]: `AddEditMealDialog` 42px RenderFlex Overflow on Dropdown Row
- **File**: `lib/features/vault/presentation/add_edit_meal_dialog.dart:222, 245`
- **Verbatim Error**:
  ```
  A RenderFlex overflowed by 42 pixels on the right.
  The relevant error-causing widget was:
    DropdownButtonFormField<ProteinType>-[<'meal_form_protein_dropdown'>]
    DropdownButtonFormField:file:///.../lib/features/vault/presentation/add_edit_meal_dialog.dart:222:40
    DropdownButtonFormField<CarbsType>-[<'meal_form_carbs_dropdown'>]
    DropdownButtonFormField:file:///.../lib/features/vault/presentation/add_edit_meal_dialog.dart:245:40
  ```
- **Root Cause**: The two `DropdownButtonFormField` widgets inside the `Row` are wrapped in `Expanded`, giving each ~134px of width on standard mobile viewports (390px). However, neither dropdown specifies `isExpanded: true`. Consequently, the internal `DropdownButton` renders its item text intrinsically. Arabic options such as `"بقوليات / نباتي (كشري، فول، عدس)"` require ~176px, triggering a 42-pixel `RenderFlex` overflow on the right on any phone.
- **Remediation**:
  Add `isExpanded: true` to both `DropdownButtonFormField<ProteinType>` and `DropdownButtonFormField<CarbsType>`.

---

### Defect 2 [HIGH]: `MealVaultCard` 9px to 20px RenderFlex Overflow in `_buildMiniChip`
- **File**: `lib/features/vault/presentation/widgets/meal_vault_card.dart:240`
- **Verbatim Error**:
  ```
  A RenderFlex overflowed by 9.0 pixels on the right.
  The relevant error-causing widget was:
    Row:file:///.../lib/features/vault/presentation/widgets/meal_vault_card.dart:240:14
  ```
- **Root Cause**: In `_buildMiniChip`, the layout uses `Row(mainAxisSize: MainAxisSize.min, children: [Icon, SizedBox, Text])`. When a meal has a long tag (such as `ProteinType.legume`: `"بقوليات / نباتي (كشري، فول، عدس)"`), the chip content measures ~191px. Inside `MealVaultCard`, the expanded text column width is constrained to ~182px on standard mobile screens. Even though the chips are in a `Wrap`, an individual chip cannot shrink below its `Row` intrinsic width, triggering an overflow of 9 to 20 pixels.
- **Remediation**:
  Wrap the `Text` in `_buildMiniChip` with `Flexible` or `ConstrainedBox`, or provide a simplified short label / ellipsis for tags when displayed inside compact cards.

---

### Defect 3 [MEDIUM]: `SpinWheelDialog` 22px RenderFlex Overflow in Title Header
- **File**: `lib/features/home/presentation/widgets/spin_wheel_dialog.dart:115`
- **Verbatim Error**:
  ```
  A RenderFlex overflowed by 22 pixels on the right.
  ```
- **Root Cause**: The dialog's width is bounded by the fixed 260px Roulette wheel canvas. The header `Row` contains an unconstrained inner `Row(children: [Icon, SizedBox, Text('عجلة الحظ 🎡')])` (~232px) and a close `IconButton` (48px + padding = 50px). Total needed width is 282px, which exceeds the 260px boundary by 22px.
- **Remediation**:
  Wrap the inner title `Row` in `Expanded`, or remove the nested `Row` and use `Expanded(child: Text(...))` with a leading icon.

---

### Defect 4 [MEDIUM]: `SpinWheelDialog` 82px Vertical Overflow on Compact Screens (<=550px)
- **File**: `lib/features/home/presentation/widgets/spin_wheel_dialog.dart:111`
- **Verbatim Error**:
  ```
  A RenderFlex overflowed by 82 pixels on the right / bottom.
  ```
- **Root Cause**: `SpinWheelDialog` uses `Column(mainAxisSize: MainAxisSize.min)` with a fixed 260px wheel and no scrollable wrapper. When displayed on devices with <=550px height (compact phones, split-screen, or landscape orientation), the total dialog height (title + wheel + winner box + action buttons + padding = ~526px) exceeds the screen height minus system/dialog insets (~502px).
- **Remediation**:
  Wrap the dialog contents inside a `SingleChildScrollView` to permit scrolling on compact viewports.

---

### Defect 5 [HIGH]: `SettingsScreen` 298px RenderFlex Overflow on Cooldown Header Row
- **File**: `lib/features/settings/presentation/settings_screen.dart:38`
- **Verbatim Error**:
  ```
  A RenderFlex overflowed by 298 pixels on the right.
  The relevant error-causing widget was:
    Row:file:///.../lib/features/settings/presentation/settings_screen.dart:38:23
  ```
- **Root Cause**: In `SettingsScreen`, the cooldown card header uses:
  `Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('فترة استبعاد الأكلات (Cooldown)'), Container(...)])`.
  The title `Text` is not wrapped in `Expanded` or `Flexible`, causing an immediate 298px `RenderFlex` overflow upon tab navigation.
- **Remediation**:
  Wrap the header `Text` widget in `Expanded(child: Text(...))`.

---

## 3. Stress Dimension Results

| Dimension | Scenario | Expected Behavior | Actual Behavior | Result |
|---|---|---|---|---|
| **1. Ultra-Long Names** | 180+ char Arabic meal name in `MealCard` | Max 3 lines ellipsis, no overflow | Wraps gracefully with ellipsis, zero overflow | **PASS** |
| **1. Ultra-Long Names** | 180+ char Arabic meal name in `MealVaultCard` | Max 2 lines ellipsis, action buttons stay clickable | Wraps cleanly, buttons functional | **PASS** |
| **1. Ultra-Long Names** | 180+ char Arabic meal name in `DeleteMealDialog` | Dialog text auto-wraps, confirm/cancel buttons stay clickable | Full text displayed safely without overflow | **PASS** |
| **1. Ultra-Long Names** | 180+ char Arabic meal names in `SpinWheelDialog` | Wheel sectors truncate, winner banner handles multi-line | Wheel painter truncates text cleanly; however, header Row overflows by 22px | **FAIL (Defect 3)** |
| **2. Extreme Prep Times** | 0, 1, 10, 11, 99999, -5 mins in `formatPrepTime` | Correct grammatical Egyptian Arabic suffix ('دقائق' vs 'دقيقة') | Returns '0 دقائق', '1 دقائق', '10 دقائق', '11 دقيقة', '99999 دقيقة' | **PASS** |
| **2. Extreme Prep Times** | Form validation in `AddEditMealDialog` | Reject <= 0 and non-numeric inputs | Validation rejects 0 and negative inputs; however, opening dialog triggers Dropdown overflow | **FAIL (Defect 1)** |
| **3. 0-Meal Vault** | Home Screen empty state | Shows empty graphic, prompt, and CTA button to Vault | Renders clean centered empty state; CTA navigates to `/vault` | **PASS** |
| **3. 0-Meal Vault** | Vault Screen empty state | Shows 'خزنة الأكلات فارغة!' and 'أضف أكلتك الأولى' | Renders cleanly with zero items counter | **PASS** |
| **3. 0-Meal Vault** | Spin Wheel with < 2 candidates | Displays safety alert without math division-by-zero | Shows alert dialog gracefully; prevents spinning | **PASS** |
| **4. 100+ Meals** | 120 items in `MealVaultScreen` | Virtualized `ListView.builder` scrolls smoothly, search & filters work | Virtualization and search work fast; however, scrolling past legume meals triggers MiniChip overflow | **FAIL (Defect 2)** |
| **5. Rapid Tab Switching** | 20 rapid switches between all 4 tabs | Tab state preserved, zero exceptions | Navigation routes smoothly; however, entering Settings triggers Cooldown Row overflow | **FAIL (Defect 5)** |
| **6. Small Viewports** | 320px width phone with `QuickActions` | Action buttons ('طبخت دي النهاردة' / 'بواقي أكل') do not overflow | Both buttons fit within card on 320px screen without overflow | **PASS** |
| **6. Accessibility Scaling** | `TextScaler.linear(1.4)` on 360px screen | Text enlarges without breaking horizontal layouts | Action buttons resize gracefully | **PASS** |
| **6. Viewport Height** | 550px viewport height with `SpinWheelDialog` | Dialog fits or scrolls smoothly | Dialog overflows vertically by 82px due to lack of scroll view | **FAIL (Defect 4)** |

---

## 4. Robustness Commendations (Passed Areas)

1. **Text Truncation in Cards**: Both `MealCard` (`maxLines: 3, overflow: TextOverflow.ellipsis`) and `MealVaultCard` (`maxLines: 2, overflow: TextOverflow.ellipsis`) correctly resist 200+ character strings without overflowing.
2. **Wheel Canvas Painter**: The custom painter `_WheelPainter` in `SpinWheelDialog` safely truncates names to 14 characters (`_truncate(name, 14)`), preventing text collisions on the radial wheel.
3. **Empty States**: Both Home Screen and Vault Screen handle zero items gracefully with informative RTL Arabic text and direct action buttons.
4. **Quick Action Responsiveness**: The primary and secondary buttons in `QuickActions` withstand narrow 320px screens and 1.4x text scaling without breaking.

---

## 5. Verdict & Recommendation

- **Verdict**: **REJECT**
- **Action Required**: The Worker Agent must resolve the 5 identified `RenderFlex` overflow issues:
  1. Add `isExpanded: true` to both dropdowns in `AddEditMealDialog`.
  2. Protect `_buildMiniChip` inside `MealVaultCard` against exceeding available width.
  3. Wrap the title row in `SpinWheelDialog` with `Expanded`.
  4. Wrap `SpinWheelDialog` content in a `SingleChildScrollView`.
  5. Wrap `SettingsScreen` cooldown header title in `Expanded`.
