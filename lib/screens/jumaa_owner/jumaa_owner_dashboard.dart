import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class JumaaOwnerDashboard extends StatefulWidget {
  const JumaaOwnerDashboard({super.key});

  @override
  State<JumaaOwnerDashboard> createState() => _JumaaOwnerDashboardState();
}

class _JumaaOwnerDashboardState extends State<JumaaOwnerDashboard> {
  final SupabaseClient _supabase = Supabase.instance.client;

  int _currentIndex = 0;
  bool _loading = true;

  String _name = 'JUMAA Owner';
  String _email = '';

  int _properties = 0;
  int _users = 0;
  int _owners = 0;
  int _landlords = 0;
  int _tenants = 0;
  int _units = 0;
  int _payments = 0;
  int _pendingPayments = 0;

  List<Map<String, dynamic>> _recentActivity = [];

  final Color _purple = const Color(0xFF7C3AED);
  final Color _pink = const Color(0xFFEC4899);
  final Color _blue = const Color(0xFF2563EB);
  final Color _green = const Color(0xFF059669);
  final Color _orange = const Color(0xFFF97316);
  final Color _cyan = const Color(0xFF0891B2);

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    try {
      // Load the owner profile independently.
      try {
        final profile = await _supabase
            .from('profiles')
            .select('full_name,email,role')
            .eq('id', user.id)
            .maybeSingle();

        if (mounted) {
          setState(() {
            _name =
                profile?['full_name']?.toString().trim().isNotEmpty == true
                    ? profile!['full_name'].toString()
                    : 'JUMAA Owner';

            _email =
                profile?['email']?.toString() ?? user.email ?? '';
          });
        }
      } catch (e) {
        debugPrint('JUMAA OWNER: profile query failed: $e');
      }

      // ----------------------------------------------------------
      // PROPERTIES
      // ----------------------------------------------------------
      try {
        final rows = await _supabase
            .from('properties')
            .select('id');

        if (mounted) {
          setState(() {
            _properties = rows.length;
          });
        }

        debugPrint(
          'JUMAA OWNER: properties=$_properties',
        );
      } catch (e) {
        debugPrint(
          'JUMAA OWNER: properties query failed: $e',
        );
      }

      // ----------------------------------------------------------
      // USERS / ROLES
      // ----------------------------------------------------------
      try {
        final rows = await _supabase
            .from('profiles')
            .select('id,role');

        final profiles = List<Map<String, dynamic>>.from(rows);

        final owners = profiles.where(
          (p) =>
              p['role']?.toString().toLowerCase().trim() ==
              'owner',
        ).length;

        final landlords = profiles.where(
          (p) =>
              p['role']?.toString().toLowerCase().trim() ==
              'landlord',
        ).length;

        final tenants = profiles.where(
          (p) =>
              p['role']?.toString().toLowerCase().trim() ==
              'tenant',
        ).length;

        final users = profiles.where(
          (p) =>
              p['role']?.toString().toLowerCase().trim() !=
              'jumaa_owner',
        ).length;

        if (mounted) {
          setState(() {
            _users = users;
            _owners = owners;
            _landlords = landlords;
            _tenants = tenants;
          });
        }

        debugPrint(
          'JUMAA OWNER: users=$_users '
          'owners=$_owners '
          'landlords=$_landlords '
          'tenants=$_tenants',
        );
      } catch (e) {
        debugPrint(
          'JUMAA OWNER: profiles query failed: $e',
        );
      }

      // ----------------------------------------------------------
      // UNITS
      // ----------------------------------------------------------
      try {
        final rows = await _supabase
            .from('units')
            .select('id');

        if (mounted) {
          setState(() {
            _units = rows.length;
          });
        }

        debugPrint(
          'JUMAA OWNER: units=$_units',
        );
      } catch (e) {
        debugPrint(
          'JUMAA OWNER: units query failed: $e',
        );
      }

      // ----------------------------------------------------------
      // SUBSCRIPTION PAYMENTS
      // Revenue deliberately remains 0.0 for now.
      // ----------------------------------------------------------
      try {
        final rows = await _supabase
            .from('subscription_payments')
            .select(
              'id,owner_id,property_id,amount,status,reference,created_at',
            )
            .order('created_at', ascending: false)
            .limit(50);

        final payments =
            List<Map<String, dynamic>>.from(rows);

        final pending = payments.where((payment) {
          return payment['status']
                  ?.toString()
                  .toLowerCase()
                  .trim() ==
              'pending';
        }).length;

        if (mounted) {
          setState(() {
            _payments = payments.length;
            _pendingPayments = pending;
          });
        }

        debugPrint(
          'JUMAA OWNER: payments=$_payments '
          'pending=$_pendingPayments',
        );
      } catch (e) {
        debugPrint(
          'JUMAA OWNER: subscription payments query failed: $e',
        );
      }

      // ----------------------------------------------------------
      // RECENT ACTIVITY
      // Build activity independently so one failed table does
      // not break the entire dashboard.
      // ----------------------------------------------------------
      final activity = <Map<String, dynamic>>[];

      try {
        final rows = await _supabase
            .from('profiles')
            .select('id,email,full_name,role,created_at')
            .neq('role', 'jumaa_owner')
            .order('created_at', ascending: false)
            .limit(8);

        for (final row in List<Map<String, dynamic>>.from(rows)) {
          activity.add({
            'type': 'user',
            'title': 'User account',
            'subtitle':
                '${row['full_name'] ?? row['email'] ?? 'User'} joined JUMAA',
            'created_at': row['created_at'],
          });
        }
      } catch (e) {
        debugPrint(
          'JUMAA OWNER: user activity failed: $e',
        );
      }

      try {
        final rows = await _supabase
            .from('properties')
            .select('id,name,created_at')
            .order('created_at', ascending: false)
            .limit(8);

        for (final row in List<Map<String, dynamic>>.from(rows)) {
          activity.add({
            'type': 'property',
            'title': 'Property registered',
            'subtitle':
                row['name']?.toString() ?? 'New property',
            'created_at': row['created_at'],
          });
        }
      } catch (e) {
        debugPrint(
          'JUMAA OWNER: property activity failed: $e',
        );
      }

      try {
        final rows = await _supabase
            .from('subscription_payments')
            .select(
              'id,status,reference,created_at',
            )
            .order('created_at', ascending: false)
            .limit(8);

        for (final row in List<Map<String, dynamic>>.from(rows)) {
          activity.add({
            'type': 'payment',
            'title': 'Subscription payment',
            'subtitle':
                '${row['status'] ?? 'Unknown'} • '
                '${row['reference'] ?? 'No reference'}',
            'created_at': row['created_at'],
          });
        }
      } catch (e) {
        debugPrint(
          'JUMAA OWNER: payment activity failed: $e',
        );
      }

      activity.sort((a, b) {
        final aDate =
            DateTime.tryParse(
                  a['created_at']?.toString() ?? '',
                ) ??
                DateTime.fromMillisecondsSinceEpoch(0);

        final bDate =
            DateTime.tryParse(
                  b['created_at']?.toString() ?? '',
                ) ??
                DateTime.fromMillisecondsSinceEpoch(0);

        return bDate.compareTo(aDate);
      });

      if (mounted) {
        setState(() {
          _recentActivity = activity.take(8).toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint(
        'JUMAA OWNER DASHBOARD ERROR: $e',
      );

      if (mounted) {
        setState(() => _loading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Dashboard loaded with some unavailable data.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _home(),
            _analytics(),
            _activityPage(),
            _profile(),
          ],
        ),
      ),
      bottomNavigationBar: _bottomNavigation(),
    );
  }

  Widget _home() {
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _topBar()),
          SliverToBoxAdapter(child: _profileHeader()),
          SliverToBoxAdapter(child: _quickStats()),
          SliverToBoxAdapter(child: _sectionTitle('Quick actions')),
          SliverToBoxAdapter(child: _quickActions()),
          SliverToBoxAdapter(child: _sectionTitle('Recent activity')),
          SliverToBoxAdapter(child: _activityFeed()),
          SliverToBoxAdapter(child: _sectionTitle('Platform overview')),
          SliverToBoxAdapter(child: _overviewCard()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'JUMAA',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: _purple,
              ),
            ),
          ),
          _roundButton(Icons.search_rounded, _showSearch),
          const SizedBox(width: 7),
          _roundButton(
            Icons.notifications_none_rounded,
            () => setState(() => _currentIndex = 2),
            badge: _pendingPayments > 0,
          ),
        ],
      ),
    );
  }

  Widget _profileHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 11),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_purple, _pink, _orange],
              ),
            ),
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              padding: const EdgeInsets.all(3),
              child: CircleAvatar(
                backgroundColor: const Color(0xFFF1ECFF),
                child: Icon(
                  Icons.business_rounded,
                  size: 27,
                  color: _purple,
                ),
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: _loading
                ? const LinearProgressIndicator()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: _blue,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'JUMAA Platform Owner',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_email.isNotEmpty)
                        Text(
                          _email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: _showProfileMenu,
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
    );
  }

  Widget _quickStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        children: [
          _statCard(
            'Properties',
            '$_properties',
            Icons.apartment_rounded,
            _purple,
          ),
          const SizedBox(width: 7),
          _statCard(
            'Users',
            '$_users',
            Icons.people_alt_rounded,
            _blue,
          ),
          const SizedBox(width: 7),
          _statCard(
            'Revenue',
            'KSh 0.00',
            Icons.payments_rounded,
            _green,
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        height: 86,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: .16),
              color.withValues(alpha: .05),
            ],
          ),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: color.withValues(alpha: .10),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: color),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          if (title == 'Recent activity')
            GestureDetector(
              onTap: () => setState(() => _currentIndex = 2),
              child: Text(
                'View all',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _purple,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _quickActions() {
    final actions = [
      ('Users', Icons.people_alt_rounded, _blue, () => _showUsers()),
      (
        'Properties',
        Icons.home_work_rounded,
        _purple,
        () => _showProperties(),
      ),
      (
        'Payments',
        Icons.account_balance_wallet_rounded,
        _green,
        () => _showPayments(),
      ),
      (
        'Reports',
        Icons.bar_chart_rounded,
        _orange,
        () => setState(() => _currentIndex = 1),
      ),
    ];

    return SizedBox(
      height: 88,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, index) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final action = actions[index];

          return InkWell(
            borderRadius: BorderRadius.circular(17),
            onTap: action.$4,
            child: Container(
              width: 80,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(17),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                    color: Colors.black.withValues(alpha: .04),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: action.$3.withValues(alpha: .12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      action.$2,
                      color: action.$3,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    action.$1,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _activityFeed() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_recentActivity.isEmpty) {
      return _emptyCard(
        Icons.timeline_rounded,
        'No activity yet',
        'New platform activity will appear here.',
      );
    }

    return Column(
      children: _recentActivity
          .take(4)
          .map((activity) => _feedCard(activity))
          .toList(),
    );
  }

  Widget _feedCard(Map<String, dynamic> activity) {
    final type = activity['type']?.toString();

    final icon = type == 'property'
        ? Icons.home_work_rounded
        : type == 'payment'
            ? Icons.payments_rounded
            : Icons.person_add_alt_1_rounded;

    final color = type == 'property'
        ? _purple
        : type == 'payment'
            ? _green
            : _blue;

    final date = DateTime.tryParse(
      activity['created_at']?.toString() ?? '',
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 3, 16, 6),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .11),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['title']?.toString() ?? 'Activity',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activity['subtitle']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _timeAgo(date),
            style: TextStyle(
              fontSize: 8,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_purple, _pink],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'JUMAA platform',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Icon(
                Icons.insights_rounded,
                color: Colors.white,
                size: 27,
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '$_properties properties • $_units units • $_users users',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _miniOverview('Owners', _owners, Icons.person_rounded),
              _miniOverview(
                'Landlords',
                _landlords,
                Icons.manage_accounts_rounded,
              ),
              _miniOverview('Tenants', _tenants, Icons.home_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniOverview(String label, int value, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 15),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _analytics() {
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 25),
        children: [
          _pageHeader(
            'Analytics',
            'Real-time JUMAA platform overview',
            Icons.insights_rounded,
            _purple,
          ),
          const SizedBox(height: 15),
          _analyticsGrid(),
          const SizedBox(height: 15),
          _analyticsCard(
            'Users',
            [
              ('Property Owners', _owners, _purple),
              ('Landlords', _landlords, _orange),
              ('Tenants', _tenants, _blue),
            ],
          ),
          const SizedBox(height: 12),
          _analyticsCard(
            'Platform',
            [
              ('Properties', _properties, _purple),
              ('Units', _units, _cyan),
              ('Payments', _payments, _green),
              ('Pending', _pendingPayments, _orange),
            ],
          ),
          const SizedBox(height: 12),
          _revenueCard(),
        ],
      ),
    );
  }

  Widget _analyticsGrid() {
    return Row(
      children: [
        Expanded(
          child: _metricBox(
            'Properties',
            '$_properties',
            Icons.apartment_rounded,
            _purple,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _metricBox(
            'Units',
            '$_units',
            Icons.door_front_door_rounded,
            _cyan,
          ),
        ),
      ],
    );
  }

  Widget _metricBox(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      height: 105,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 21),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _analyticsCard(
    String title,
    List<(String, int, Color)> items,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: item.$3,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.$1,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  Text(
                    '${item.$2}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _revenueCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_green, _cyan],
        ),
        borderRadius: BorderRadius.circular(19),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.payments_rounded,
            color: Colors.white,
            size: 30,
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Revenue',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'KSh 0.00',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activityPage() {
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 25),
        children: [
          _pageHeader(
            'Activity',
            'Latest activity across JUMAA',
            Icons.notifications_active_rounded,
            _orange,
          ),
          const SizedBox(height: 14),
          if (_recentActivity.isEmpty)
            _emptyCard(
              Icons.timeline_rounded,
              'No activity',
              'Platform activity will appear here.',
            )
          else
            ..._recentActivity.map(_feedCard),
        ],
      ),
    );
  }

  Widget _profile() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
      children: [
        _pageHeader(
          'My Profile',
          'JUMAA platform owner account',
          Icons.person_rounded,
          _purple,
        ),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_purple, _pink],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 29,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.business_rounded,
                  color: Color(0xFF7C3AED),
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _profileTile(
          Icons.person_outline_rounded,
          'Name',
          _name,
        ),
        _profileTile(
          Icons.email_outlined,
          'Email',
          _email.isEmpty ? 'Not available' : _email,
        ),
        _profileTile(
          Icons.verified_user_outlined,
          'Account type',
          'JUMAA Owner',
        ),
        _profileTile(
          Icons.admin_panel_settings_outlined,
          'Role',
          'jumaa_owner',
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _logout,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text(
            'Log out',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _profileTile(
    IconData icon,
    String title,
    String value,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: _purple, size: 20),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageHeader(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyCard(
    IconData icon,
    String title,
    String message,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundButton(
    IconData icon,
    VoidCallback onPressed, {
    bool badge = false,
  }) {
    return Stack(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: onPressed,
            icon: Icon(icon, size: 19),
          ),
        ),
        if (badge)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: _pink,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 1.3,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _bottomNavigation() {
    return NavigationBar(
      height: 63,
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) {
        setState(() => _currentIndex = index);
      },
      backgroundColor: Colors.white,
      elevation: 4,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.insights_outlined),
          selectedIcon: Icon(Icons.insights_rounded),
          label: 'Analytics',
        ),
        NavigationDestination(
          icon: Icon(Icons.notifications_none_rounded),
          selectedIcon: Icon(Icons.notifications_rounded),
          label: 'Activity',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Me',
        ),
      ],
    );
  }

  Future<void> _showUsers() async {
    try {
      final rows = await _supabase
          .from('profiles')
          .select('id,email,full_name,role,created_at')
          .neq('role', 'jumaa_owner')
          .order('created_at', ascending: false);

      if (!mounted) return;

      _showListSheet(
        'JUMAA Users',
        Icons.people_alt_rounded,
        _blue,
        List<Map<String, dynamic>>.from(rows),
        (item) {
          final role = item['role']?.toString() ?? 'unknown';

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: _blue.withValues(alpha: .12),
              child: Icon(Icons.person_rounded, color: _blue),
            ),
            title: Text(
              item['full_name']?.toString().trim().isNotEmpty == true
                  ? item['full_name'].toString()
                  : item['email']?.toString() ?? 'User',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${item['email'] ?? ''}\n$role',
              style: const TextStyle(fontSize: 10),
            ),
            isThreeLine: true,
          );
        },
      );
    } catch (e) {
      _showError('Could not load users: $e');
    }
  }

  Future<void> _showProperties() async {
    try {
      final rows = await _supabase
          .from('properties')
          .select(
            'id,name,description,location,address,phone,email,owner_id,landlord_id,county,subcounty,created_at',
          )
          .order('created_at', ascending: false);

      if (!mounted) return;

      _showListSheet(
        'Properties',
        Icons.home_work_rounded,
        _purple,
        List<Map<String, dynamic>>.from(rows),
        (item) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: _purple.withValues(alpha: .12),
              child: Icon(
                Icons.apartment_rounded,
                color: _purple,
              ),
            ),
            title: Text(
              item['name']?.toString() ?? 'Property',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${item['location'] ?? item['address'] ?? 'Location unavailable'}\n'
              'Owner: ${item['owner_id'] ?? 'Not assigned'}',
              style: const TextStyle(fontSize: 10),
            ),
            isThreeLine: true,
          );
        },
      );
    } catch (e) {
      _showError('Could not load properties: $e');
    }
  }

  Future<void> _showPayments() async {
    try {
      final rows = await _supabase
          .from('subscription_payments')
          .select(
            'id,owner_id,property_id,amount,monthly_rate,units_count,months_covered,credit_generated,payment_method,reference,status,paid_at,created_at',
          )
          .order('created_at', ascending: false);

      if (!mounted) return;

      _showListSheet(
        'Subscription Payments',
        Icons.payments_rounded,
        _green,
        List<Map<String, dynamic>>.from(rows),
        (item) {
          final status = item['status']?.toString() ?? 'unknown';

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: _green.withValues(alpha: .12),
              child: Icon(
                Icons.payments_rounded,
                color: _green,
              ),
            ),
            title: Text(
              'KSh ${item['amount'] ?? '0'}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${status.toUpperCase()}\n'
              'Reference: ${item['reference'] ?? 'N/A'}',
              style: const TextStyle(fontSize: 10),
            ),
            isThreeLine: true,
          );
        },
      );
    } catch (e) {
      _showError('Could not load payments: $e');
    }
  }

  void _showListSheet(
    String title,
    IconData icon,
    Color color,
    List<Map<String, dynamic>> rows,
    Widget Function(Map<String, dynamic>) builder,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8F8FC),
      builder: (_) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * .82,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: color.withValues(alpha: .12),
                        child: Icon(icon, color: color),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$title (${rows.length})',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: rows.isEmpty
                      ? Center(
                          child: _emptyCard(
                            icon,
                            'Nothing here yet',
                            'No records were found.',
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: rows.length,
                          separatorBuilder: (_, index) =>
                              const SizedBox(height: 5),
                          itemBuilder: (_, index) => Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: builder(rows[index]),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSearch() async {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Search JUMAA',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Name, email or property',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final query = controller.text.trim();

                if (query.isEmpty) return;

                Navigator.pop(dialogContext);

                await _performSearch(query);
              },
              child: const Text('Search'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performSearch(String query) async {
    try {
      final users = await _supabase
          .from('profiles')
          .select('id,email,full_name,role')
          .or('email.ilike.%$query%,full_name.ilike.%$query%')
          .limit(20);

      final properties = await _supabase
          .from('properties')
          .select('id,name,location,address,owner_id')
          .or('name.ilike.%$query%,location.ilike.%$query%,address.ilike.%$query%')
          .limit(20);

      if (!mounted) return;

      final userRows = List<Map<String, dynamic>>.from(users);
      final propertyRows = List<Map<String, dynamic>>.from(properties);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFFF8F8FC),
        builder: (_) {
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * .75,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Search results',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Results for "$query"',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Users',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  if (userRows.isEmpty)
                    _emptyCard(
                      Icons.people_alt_rounded,
                      'No users found',
                      'Try another search term.',
                    )
                  else
                    ...userRows.map(
                      (user) => _searchResult(
                        Icons.person_rounded,
                        _blue,
                        user['full_name']?.toString() ??
                            user['email']?.toString() ??
                            'User',
                        '${user['email'] ?? ''} • ${user['role'] ?? ''}',
                      ),
                    ),
                  const SizedBox(height: 15),
                  const Text(
                    'Properties',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  if (propertyRows.isEmpty)
                    _emptyCard(
                      Icons.apartment_rounded,
                      'No properties found',
                      'Try another search term.',
                    )
                  else
                    ...propertyRows.map(
                      (property) => _searchResult(
                        Icons.apartment_rounded,
                        _purple,
                        property['name']?.toString() ?? 'Property',
                        '${property['location'] ?? property['address'] ?? ''}',
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      _showError('Search failed: $e');
    }
  }

  Widget _searchResult(
    IconData icon,
    Color color,
    String title,
    String subtitle,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .12),
          child: Icon(icon, color: color, size: 19),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 9),
        ),
      ),
    );
  }

  void _showProfileMenu() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: const Text('Refresh dashboard'),
                onTap: () {
                  Navigator.pop(context);
                  _loadDashboard();
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Log out'),
                onTap: () {
                  Navigator.pop(context);
                  _logout();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    await _supabase.auth.signOut();

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/',
      (route) => false,
    );
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _timeAgo(DateTime? date) {
    if (date == null) return '';

    final difference = DateTime.now().difference(date);

    if (difference.inMinutes < 1) return 'now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';

    return '${date.day}/${date.month}';
  }
}
