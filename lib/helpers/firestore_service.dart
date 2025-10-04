// // lib/helpers/firestore_service.dart

// import 'package:cloud_firestore/cloud_firestore.dart';
// import '../models/transaction.dart' as model;
// import '../models/bill.dart';
// import '../models/savings.dart';

// class FirestoreService {
//   final FirebaseFirestore _db = FirebaseFirestore.instance;

//   // --- Transaction Functions ---

//   Future<void> addTransaction(model.Transaction transaction, String userId) {
//     return _db
//         .collection('users')
//         .doc(userId)
//         .collection('transactions')
//         .add(transaction.toMap());
//   }

//   Stream<List<model.Transaction>> getTransactions(String userId) {
//     return _db
//         .collection('users')
//         .doc(userId)
//         .collection('transactions')
//         .orderBy('date', descending: true)
//         .snapshots()
//         .map((snapshot) => snapshot.docs
//             .map((doc) => model.Transaction.fromMap(doc.data(), id: doc.id))
//             .toList());
//   }

//   Future<void> deleteTransaction(String transactionId, String userId) {
//     return _db
//         .collection('users')
//         .doc(userId)
//         .collection('transactions')
//         .doc(transactionId)
//         .delete();
//   }

//   // --- Category Functions ---

//   Future<void> addCategory(String name, String userId) {
//     // In Firestore, we might manage categories differently, but for now, this works.
//     return _db
//         .collection('users')
//         .doc(userId)
//         .collection('categories')
//         .doc(name) // Use name as ID to prevent duplicates
//         .set({'name': name});
//   }

//   Stream<List<Map<String, dynamic>>> getCategories(String userId) {
//     return _db
//         .collection('users')
//         .doc(userId)
//         .collection('categories')
//         .snapshots()
//         .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
//   }
  
//   // Note: We'll need to adjust how we get category IDs later if needed.
//   // For now, the existing logic in other files is okay.

//   // --- Savings Functions ---

//   Future<void> addSavingsGoal(SavingsGoal goal, String userId) {
//     return _db
//         .collection('users')
//         .doc(userId)
//         .collection('savings')
//         .add(goal.toMap());
//   }

//   Stream<List<SavingsGoal>> getSavingsGoals(String userId) {
//     return _db
//         .collection('users')
//         .doc(userId)
//         .collection('savings')
//         .snapshots()
//         .map((snapshot) => snapshot.docs
//             .map((doc) => SavingsGoal.fromMap(doc.data(), id: doc.id))
//             .toList());
//   }
  
//   Future<void> updateSavingsGoal(SavingsGoal goal, String userId) {
//      return _db
//         .collection('users')
//         .doc(userId)
//         .collection('savings')
//         .doc(goal.id)
//         .update(goal.toMap());
//   }

//   Future<void> deleteSavingsGoal(String goalId, String userId) {
//     return _db
//         .collection('users')
//         .doc(userId)
//         .collection('savings')
//         .doc(goalId)
//         .delete();
//   }

//   // --- Bill Functions ---

//   Future<void> addBill(Bill bill, String userId) {
//     return _db
//         .collection('users')
//         .doc(userId)
//         .collection('bills')
//         .add(bill.toMap());
//   }

//   Stream<List<Bill>> getBills(String userId) {
//     return _db
//         .collection('users')
//         .doc(userId)
//         .collection('bills')
//         .orderBy('dueDate')
//         .snapshots()
//         .map((snapshot) => snapshot.docs
//             .map((doc) => Bill.fromMap(doc.data(), id: doc.id))
//             .toList());
//   }
  
//   Future<void> deleteBill(String billId, String userId) {
//     return _db
//         .collection('users')
//         .doc(userId)
//         .collection('bills')
//         .doc(billId)
//         .delete();
//   }
// }