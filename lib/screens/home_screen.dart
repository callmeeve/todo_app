import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isAscending = true;
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('You must be logged in to view tasks'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Todo App',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              FeatherIcons.filter,
              color: Colors.black,
            ),
            onPressed: () {
              setState(() {
                _isAscending = !_isAscending;
              });
            },
          ),
          IconButton(
            icon: const Icon(
              FeatherIcons.calendar,
              color: Colors.black,
            ),
            onPressed: () async {
              DateTime? pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2101),
              );
              if (pickedDate != null) {
                setState(() {
                  _selectedDate = pickedDate;
                });
              }
            },
          ),
        ],
      ),
      body: Container(
        margin: const EdgeInsets.all(16),
        child: StreamBuilder<QuerySnapshot>(
          stream: _getTaskStream(user.uid),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('Something went wrong'),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text('No tasks found'),
              );
            }

            return ListView(
              children: snapshot.data!.docs.map((DocumentSnapshot document) {
                Map<String, dynamic> data =
                    document.data()! as Map<String, dynamic>;
                return _buildTaskItem(document.id, data);
              }).toList(),
            );
          },
        ),
      ),
    );
  }

  Stream<QuerySnapshot> _getTaskStream(String userId) {
    if (_selectedDate == null) {
      return _firestore
          .collection('tasks')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: !_isAscending)
          .snapshots();
    } else {
      return _firestore
          .collection('tasks')
          .where('userId', isEqualTo: userId)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(_selectedDate!))
          .where('createdAt',
              isLessThanOrEqualTo: Timestamp.fromDate(
                  _selectedDate!.add(const Duration(days: 1))))
          .orderBy('createdAt', descending: !_isAscending)
          .snapshots();
    }
  }

  Widget _buildTaskItem(String taskId, Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        title: Text(data['title']),
        subtitle: Text(data['description']),
        trailing: IconButton(
          icon: const Icon(FeatherIcons.trash, color: Colors.black),
          onPressed: () async {
            User? user = _auth.currentUser;
            if (user != null) {
              DocumentSnapshot taskSnapshot =
                  await _firestore.collection('tasks').doc(taskId).get();
              if (taskSnapshot.exists && taskSnapshot['userId'] == user.uid) {
                _firestore.collection('tasks').doc(taskId).delete();
              } else {
                print('Permission denied: You can only delete your own tasks.');
              }
            } else {
              print('User not authenticated.');
            }
          },
        ),
      ),
    );
  }
}
