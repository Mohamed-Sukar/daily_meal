import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/seed/initial_meals.dart';
import '../../../core/database/tables/meals_table.dart';
import 'models/cloud_meal.dart';

final vaultAdminRepositoryProvider = Provider<VaultAdminRepository>((ref) {
  return VaultAdminRepository(
    firestore: FirebaseFirestore.instance,
    storage: FirebaseStorage.instance,
  );
});

final vaultMealsStreamProvider = StreamProvider.autoDispose<List<CloudMeal>>((ref) {
  final repo = ref.watch(vaultAdminRepositoryProvider);
  return repo.streamVaultMeals();
});

final stagingMealsStreamProvider = StreamProvider.autoDispose<List<CloudMeal>>((ref) {
  final repo = ref.watch(vaultAdminRepositoryProvider);
  return repo.streamStagingMeals();
});

class VaultAdminRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  VaultAdminRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _vaultRef =>
      _firestore.collection('vault_meals');

  CollectionReference<Map<String, dynamic>> get _stagingRef =>
      _firestore.collection('staging_meals');

  /// Stream all approved meals from `vault_meals`
  Stream<List<CloudMeal>> streamVaultMeals() {
    return _vaultRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CloudMeal.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Stream all user-suggested meals waiting in `staging_meals`
  Stream<List<CloudMeal>> streamStagingMeals() {
    return _stagingRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CloudMeal.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Add a new meal directly to `vault_meals`
  Future<void> addVaultMeal(CloudMeal meal) async {
    final docRef = _vaultRef.doc();
    final newMeal = meal.copyWith(id: docRef.id, status: 'approved');
    await docRef.set(newMeal.toMap());
  }

  /// Update an existing meal in `vault_meals`
  Future<void> updateVaultMeal(CloudMeal meal) async {
    await _vaultRef.doc(meal.id).update(meal.toMap());
  }

  /// Toggle whether a meal is a starter pack meal for new users
  Future<void> toggleStarterMeal(CloudMeal meal) async {
    final updated = meal.copyWith(isStarterMeal: !meal.isStarterMeal);
    await _vaultRef.doc(meal.id).update({'isStarterMeal': updated.isStarterMeal});
  }

  /// Delete a meal from `vault_meals`
  Future<void> deleteVaultMeal(String mealId) async {
    await _vaultRef.doc(mealId).delete();
  }

  /// Approve a staging meal: copy to `vault_meals` then delete from `staging_meals`
  Future<void> approveStagingMeal(CloudMeal stagingMeal) async {
    final docRef = _vaultRef.doc();
    final approvedMeal = stagingMeal.copyWith(
      id: docRef.id,
      status: 'approved',
    );
    await docRef.set(approvedMeal.toMap());
    await _stagingRef.doc(stagingMeal.id).delete();
  }

  /// Reject / delete a staging meal
  Future<void> rejectStagingMeal(String stagingId) async {
    await _stagingRef.doc(stagingId).delete();
  }

  /// Upload image bytes to Firebase Storage and return the download URL
  Future<String?> uploadMealImage(Uint8List bytes, String fileName) async {
    try {
      final sanitizedName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final ref = _storage.ref().child('meal_images/$sanitizedName');
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final uploadTask = await ref.putData(bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      return null;
    }
  }

  /// Import the 20 initial Egyptian meals into the cloud vault
  Future<int> seedInitialMeals() async {
    int count = 0;
    for (final companion in initialEgyptianMealsSeed) {
      final pType = companion.proteinType.value;
      final cType = companion.carbsType.value;
      final cat = companion.category.value;

      String proteinStr = 'other';
      if (pType == ProteinType.chicken) {
        proteinStr = 'chicken';
      } else if (pType == ProteinType.beef) {
        proteinStr = 'beef';
      } else if (pType == ProteinType.fish) {
        proteinStr = 'fish';
      } else if (pType == ProteinType.legume || pType == ProteinType.none) {
        proteinStr = 'meatless';
      }

      String carbsStr = 'none';
      if (cType == CarbsType.rice) {
        carbsStr = 'rice';
      } else if (cType == CarbsType.pasta) {
        carbsStr = 'pasta';
      } else if (cType == CarbsType.bread) {
        carbsStr = 'bread';
      }

      String catStr = 'popular';
      if (cat == MealCategory.egyptianTraditional) {
        catStr = 'tabeekh';
      } else if (cat == MealCategory.ovenBaked) {
        catStr = 'casserole';
      } else if (cat == MealCategory.fastFood) {
        catStr = 'dry_sandwich';
      } else if (cat == MealCategory.seafood) {
        catStr = 'seafood';
      }

      final meal = CloudMeal(
        id: '',
        name: companion.name.value,
        category: catStr,
        proteinType: proteinStr,
        carbsType: carbsStr,
        prepTimeMinutes: companion.prepTime.value,
        isFridaySpecial: companion.isFridaySpecial.value,
        isBudgetFriendly: companion.isBudgetFriendly.value,
        createdAt: DateTime.now(),
        status: 'approved',
      );

      await addVaultMeal(meal);
      count++;
    }
    return count;
  }
}
