part of 'admin_screen.dart';

// ══════════════════════════════════
//    تبويب: المستخدمون
// ══════════════════════════════════
extension AdminUsersTabX on _AdminScreenState {
  Widget _buildUsersTab(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 20 : 12),
      child: _SectionAnimator(
        delay: 0,
        child: _buildCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _buildSectionHeader(Icons.people,
                        'المستخدمون (${users.length})'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh,
                        color: Color(0xFF2E7D32)),
                    onPressed: loadUsers,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              users.isEmpty
                  ? Center(
                child: Text('لا يوجد مستخدمون',
                    style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade500
                            : Colors.grey)),
              )
                  : isDesktop
                  ? GridView.builder(
                shrinkWrap: true,
                physics:
                const NeverScrollableScrollPhysics(),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 3,
                ),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(
                        milliseconds:
                        300 + (index * 60)),
                    curve: Curves.easeOutCubic,
                    builder: (_, value, child) =>
                        Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset:
                            Offset(20 * (1 - value), 0),
                            child: child,
                          ),
                        ),
                    child: _buildUserCard(user, isDark),
                  );
                },
              )
                  : ListView.separated(
                shrinkWrap: true,
                physics:
                const NeverScrollableScrollPhysics(),
                itemCount: users.length,
                separatorBuilder: (_, __) => Divider(
                    color: isDark
                        ? Colors.grey.shade800
                        : Colors.grey.shade200),
                itemBuilder: (context, index) {
                  final user = users[index];
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(
                        milliseconds:
                        300 + (index * 80)),
                    curve: Curves.easeOutCubic,
                    builder: (_, value, child) =>
                        Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset:
                            Offset(20 * (1 - value), 0),
                            child: child,
                          ),
                        ),
                    child: _buildUserListTile(user),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(UserModel user, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
        isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: user.isAdmin
              ? const Color(0xFF2E7D32).withOpacity(0.3)
              : user.isSpecial
              ? Colors.amber.withOpacity(0.3)
              : Colors.blue.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: user.isAdmin
                ? const Color(0xFF2E7D32)
                : user.isSpecial
                ? Colors.amber.shade700
                : Colors.blue,
            child: Text(
              user.name.isNotEmpty
                  ? user.name[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(user.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
                Text(user.email,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showChangeRoleDialog(user),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: user.isAdmin
                    ? const Color(0xFFE8F5E9)
                    : user.isSpecial
                    ? const Color(0xFFFFF8E1)
                    : const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: user.isAdmin
                      ? const Color(0xFF2E7D32)
                      : user.isSpecial
                      ? Colors.amber
                      : Colors.blue,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user.roleLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: user.isAdmin
                          ? const Color(0xFF2E7D32)
                          : user.isSpecial
                          ? Colors.amber.shade800
                          : Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.edit,
                    size: 11,
                    color: user.isAdmin
                        ? const Color(0xFF2E7D32)
                        : user.isSpecial
                        ? Colors.amber.shade800
                        : Colors.blue,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserListTile(UserModel user) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: user.isAdmin
            ? const Color(0xFF2E7D32)
            : user.isSpecial
            ? Colors.amber.shade700
            : Colors.blue,
        child: Text(
          user.name.isNotEmpty
              ? user.name[0].toUpperCase()
              : '?',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(user.name,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(user.email,
              style: const TextStyle(fontSize: 12)),
          Text(user.phone,
              style: const TextStyle(
                  fontSize: 12, color: Colors.grey)),
        ],
      ),
      trailing: GestureDetector(
        onTap: () => _showChangeRoleDialog(user),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: user.isAdmin
                ? const Color(0xFFE8F5E9)
                : user.isSpecial
                ? const Color(0xFFFFF8E1)
                : const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: user.isAdmin
                  ? const Color(0xFF2E7D32)
                  : user.isSpecial
                  ? Colors.amber
                  : Colors.blue,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                user.roleLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: user.isAdmin
                      ? const Color(0xFF2E7D32)
                      : user.isSpecial
                      ? Colors.amber.shade800
                      : Colors.blue,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.edit,
                size: 12,
                color: user.isAdmin
                    ? const Color(0xFF2E7D32)
                    : user.isSpecial
                    ? Colors.amber.shade800
                    : Colors.blue,
              ),
            ],
          ),
        ),
      ),
    );
  }

// ══════════════════════════════════
}