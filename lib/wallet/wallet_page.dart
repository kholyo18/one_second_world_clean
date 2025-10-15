// lib/wallet/wallet_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  bool loading = false;
  int coins = 0;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();
    setState(() => coins = (data?['coins'] ?? 0) as int);
  }

  Future<void> _addCoins(int amount) async {
    setState(() => loading = true);
    try {
      final HttpsCallable callable = FirebaseFunctions.instance
          .httpsCallable('creditCoinsAfterPurchase');
      final res =
          await callable.call<Map<String, dynamic>>({'amount': amount});
      final newBalance = (res.data['newBalance'] ?? coins) as int;
      if (mounted) {
        setState(() => coins = newBalance);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ تم شحن $amount كوينز بنجاح!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ حدث خطأ أثناء الشحن: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _tipPost({required String postId, required int amount}) async {
    setState(() => loading = true);
    try {
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('tipPost');
      final res = await callable
          .call<Map<String, dynamic>>({'postId': postId, 'coins': amount});
      final newBalance = (res.data['newBalance'] ?? coins) as int;
      if (mounted) {
        setState(() => coins = newBalance);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('👏 تم دعم المنشور بـ $amount كوينز!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ فشل في إرسال الدعم: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _buildCoinButton(int amount) {
    return ElevatedButton(
      onPressed: loading ? null : () => _addCoins(amount),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text('$amount 🪙'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('المحفظة'),
        centerTitle: true,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cs.surfaceVariant,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Text('الرصيد الحالي',
                            style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(
                          '$coins',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('كوينز',
                            style:
                                TextStyle(fontSize: 14, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'اختر العدد من الكوينز:',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildCoinButton(100),
                      _buildCoinButton(500),
                      _buildCoinButton(1000),
                      _buildCoinButton(2500),
                      _buildCoinButton(5000),
                    ],
                  ),
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    onPressed: loading
                        ? null
                        : () => _tipPost(postId: 'demo_post', amount: 100),
                    icon: const Icon(Icons.favorite),
                    label: const Text('دعم منشور بـ 100 كوينز'),
                  ),
                ],
              ),
            ),
    );
  }
}
