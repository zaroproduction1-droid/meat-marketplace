import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PendingBusinessesPage extends StatefulWidget {
  const PendingBusinessesPage({super.key});

  @override
  State<PendingBusinessesPage> createState() => _PendingBusinessesPageState();
}

class _PendingBusinessesPageState extends State<PendingBusinessesPage> {
  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _businesses = [];

  @override
  void initState() {
    super.initState();
    _loadPendingBusinesses();
  }

  Future<void> _loadPendingBusinesses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('businesses')
          .select('''
            id,
            legal_name,
            trading_name,
            business_type,
            verification_status,
            active,
            created_at
            ''')
          .eq('verification_status', 'pending')
          .order('created_at', ascending: true);

      if (!mounted) {
        return;
      }

      setState(() {
        _businesses = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _updateVerificationStatus({
    required String businessId,
    required String status,
  }) async {
    try {
      await Supabase.instance.client
          .from('businesses')
          .update({'verification_status': status})
          .eq('id', businessId);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved' ? 'Business approved.' : 'Business rejected.',
          ),
        ),
      );

      await _loadPendingBusinesses();
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  String _businessName(Map<String, dynamic> business) {
    final tradingName = business['trading_name'] as String?;

    if (tradingName != null && tradingName.trim().isNotEmpty) {
      return tradingName;
    }

    return business['legal_name'] as String? ?? 'Unnamed business';
  }

  String _businessType(String? value) {
    switch (value) {
      case 'supplier':
        return 'Supplier';
      case 'butcher':
        return 'Butcher';
      default:
        return value ?? 'Unknown';
    }
  }

  Future<void> _confirmAction({
    required Map<String, dynamic> business,
    required String status,
  }) async {
    final businessName = _businessName(business);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            status == 'approved' ? 'Approve Business' : 'Reject Business',
          ),
          content: Text(
            status == 'approved'
                ? 'Approve $businessName to access the marketplace?'
                : 'Reject $businessName?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(status == 'approved' ? 'Approve' : 'Reject'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _updateVerificationStatus(
        businessId: business['id'] as String,
        status: status,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Pending Businesses',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _loadPendingBusinesses,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 60,
                color: Color(0xFF741C1C),
              ),
              const SizedBox(height: 18),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loadPendingBusinesses,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_businesses.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 78,
                color: Color(0xFF741C1C),
              ),
              SizedBox(height: 20),
              Text(
                'No pending businesses',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 10),
              Text(
                'New business verification requests will appear here.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: _businesses.length,
          separatorBuilder: (context, index) {
            return const SizedBox(height: 14);
          },
          itemBuilder: (context, index) {
            final business = _businesses[index];

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _businessName(business),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_businessType(business['business_type'] as String?)),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: () {
                            _confirmAction(
                              business: business,
                              status: 'approved',
                            );
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Approve'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            _confirmAction(
                              business: business,
                              status: 'rejected',
                            );
                          },
                          icon: const Icon(Icons.close),
                          label: const Text('Reject'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
