import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_card.dart';
import '../../services/support_service.dart';

class SupportDashboard extends StatefulWidget {
  const SupportDashboard({super.key});

  @override
  State<SupportDashboard> createState() => _SupportDashboardState();
}

class _SupportDashboardState extends State<SupportDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupportService _supportService = SupportService();
  String _selectedFilter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Tickets Dashboard'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getTicketsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading tickets: ${snapshot.error}',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  );
                }

                // Filter tickets by search query if needed
                final allTickets = snapshot.data?.docs ?? [];
                final tickets = _searchQuery.isNotEmpty 
                    ? _filterTicketsBySearch(allTickets)
                    : allTickets;
                
                if (tickets.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.support_agent,
                          size: 72,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Support Tickets',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No tickets match your search criteria'
                              : _selectedFilter != 'all'
                                  ? 'No ${_selectedFilter.replaceAll('_', ' ')} tickets found'
                                  : 'There are no support tickets yet',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tickets.length,
                  itemBuilder: (context, index) {
                    final ticket = tickets[index].data() as Map<String, dynamic>;
                    final ticketId = tickets[index].id;
                    return _buildTicketCard(context, ticket, ticketId);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by email, name, or issue...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                _buildFilterChip('Open', 'open'),
                _buildFilterChip('In Progress', 'in_progress'),
                _buildFilterChip('Resolved', 'resolved'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        onSelected: (selected) {
          setState(() {
            _selectedFilter = value;
          });
        },
        backgroundColor: Colors.grey.shade200,
        selectedColor: AppTheme.primaryColor.withOpacity(0.2),
        checkmarkColor: AppTheme.primaryColor,
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.primaryColor : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Stream<QuerySnapshot> _getTicketsStream() {
    Query query = _firestore.collection('support_tickets');
    
    // Apply status filter
    if (_selectedFilter == 'resolved') {
      query = query.where('resolved', isEqualTo: true);
    } else if (_selectedFilter == 'in_progress') {
      query = query.where('status', isEqualTo: 'in_progress');
    } else if (_selectedFilter == 'open') {
      query = query.where('status', isEqualTo: 'open')
                   .where('resolved', isEqualTo: false);
    }
    
    // Apply search filter if present
    if (_searchQuery.isNotEmpty) {
      // Here we're just doing a local filter because Firestore doesn't support
      // complex text search without additional services like Algolia
      return query.orderBy('createdAt', descending: true).snapshots();
    }
    
    return query.orderBy('createdAt', descending: true).snapshots();
  }

  // Add this helper method to filter tickets by search query
  List<QueryDocumentSnapshot> _filterTicketsBySearch(List<QueryDocumentSnapshot> tickets) {
    if (_searchQuery.isEmpty) return tickets;
    
    final searchLower = _searchQuery.toLowerCase();
    return tickets.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      
      final email = (data['email'] as String? ?? '').toLowerCase();
      final name = (data['name'] as String? ?? '').toLowerCase();
      final description = (data['issueDescription'] as String? ?? '').toLowerCase();
      final category = (data['issueCategory'] as String? ?? '').toLowerCase();
      
      return email.contains(searchLower) ||
             name.contains(searchLower) ||
             description.contains(searchLower) ||
             category.contains(searchLower);
    }).toList();
  }

  Widget _buildTicketCard(BuildContext context, Map<String, dynamic> ticket, String ticketId) {
    final createdAt = ticket['createdAt'] as Timestamp?;
    final formattedDate = createdAt != null
        ? DateFormat('MMM d, yyyy • h:mm a').format(createdAt.toDate())
        : 'Unknown date';

    final status = ticket['status'] as String? ?? 'open';
    final resolved = ticket['resolved'] as bool? ?? false;
    final category = ticket['issueCategory'] as String? ?? 'General';
    final description = ticket['issueDescription'] as String? ?? '';
    final name = ticket['name'] as String? ?? 'Anonymous';
    final email = ticket['email'] as String? ?? 'No email provided';
    final adminResponses = ticket['adminResponses'] as List<dynamic>? ?? [];

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (resolved) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Resolved';
    } else if (status == 'in_progress') {
      statusColor = Colors.orange;
      statusIcon = Icons.pending;
      statusText = 'In Progress';
    } else {
      statusColor = Colors.blue;
      statusIcon = Icons.help_outline;
      statusText = 'Open';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: CustomCard(
        child: InkWell(
          onTap: () => _showTicketDetailsDialog(context, ticket, ticketId),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            statusIcon,
                            size: 16,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'ID: ${ticketId.substring(0, 8)}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  description.length > 100 ? '${description.substring(0, 100)}...' : description,
                  style: const TextStyle(
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formattedDate,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    Row(
                      children: [
                        if (adminResponses.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.message,
                                  size: 14,
                                  color: AppTheme.primaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${adminResponses.length} ${adminResponses.length == 1 ? 'Reply' : 'Replies'}',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTicketDetailsDialog(BuildContext context, Map<String, dynamic> ticket, String ticketId) {
    final TextEditingController responseController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final createdAt = ticket['createdAt'] as Timestamp?;
            final formattedDate = createdAt != null
                ? DateFormat('MMM d, yyyy • h:mm a').format(createdAt.toDate())
                : 'Unknown date';
                
            final status = ticket['status'] as String? ?? 'open';
            final resolved = ticket['resolved'] ?? false;
            final description = ticket['issueDescription'] ?? '';
            final adminResponses = ticket['adminResponses'] as List<dynamic>? ?? [];
            final userReplies = ticket['userReplies'] as List<dynamic>? ?? [];
            final deviceInfo = ticket['deviceInfo'] as Map<String, dynamic>? ?? {};
            
            // Process messages in chronological order
            List<Map<String, dynamic>> messages = [];
            
            // Add the initial message (the ticket description)
            messages.add({
              'text': description,
              'timestamp': ticket['createdAt'],
              'isAdmin': false,
              'isInitial': true,
              'isUser': true,
            });
            
            // Add admin responses if available
            for (var response in adminResponses) {
              if (response is Map<String, dynamic>) {
                messages.add({
                  'text': response['text'] ?? 'No content',
                  'timestamp': response['timestamp'],
                  'isAdmin': true,
                  'isInitial': false,
                  'isUser': false,
                });
              }
            }
            
            // Add user replies if available
            for (var reply in userReplies) {
              if (reply is Map<String, dynamic>) {
                messages.add({
                  'text': reply['text'] ?? 'No content',
                  'timestamp': reply['timestamp'],
                  'isAdmin': false,
                  'isInitial': false,
                  'isUser': true,
                });
              }
            }
            
            // Sort all messages by timestamp
            messages.sort((a, b) {
              final aTimestamp = a['timestamp'] as Timestamp?;
              final bTimestamp = b['timestamp'] as Timestamp?;
              
              if (aTimestamp == null && bTimestamp == null) return 0;
              if (aTimestamp == null) return -1; // Null timestamps go first
              if (bTimestamp == null) return 1;
              
              return aTimestamp.compareTo(bTimestamp);
            });
            
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.support_agent, size: 24),
                  const SizedBox(width: 8),
                  const Text('Ticket Details'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              content: Container(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.7,
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ticket ID: $ticketId',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Submitted: $formattedDate',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildStatusDropdown(ticketId, status, resolved, setState),
                        const SizedBox(width: 16),
                        TextButton.icon(
                          onPressed: () {
                            _toggleResolved(ticketId, resolved);
                            Navigator.of(context).pop();
                          },
                          icon: Icon(
                            resolved ? Icons.pending : Icons.check_circle,
                            color: resolved ? Colors.orange : Colors.green,
                          ),
                          label: Text(
                            resolved ? 'Reopen Ticket' : 'Mark Resolved',
                            style: TextStyle(
                              color: resolved ? Colors.orange : Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: StreamBuilder<DocumentSnapshot>(
                        stream: _firestore.collection('support_tickets').doc(ticketId).snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Error: ${snapshot.error}',
                                style: TextStyle(color: Colors.red[700]),
                              ),
                            );
                          }

                          // Get the latest ticket data
                          final Map<String, dynamic>? ticketData = 
                              snapshot.data?.data() as Map<String, dynamic>?;
                          
                          if (ticketData == null) {
                            return Center(
                              child: Text(
                                'Ticket not found or deleted',
                                style: TextStyle(color: Colors.red[700]),
                              ),
                            );
                          }

                          // Process messages from the updated data
                          List<Map<String, dynamic>> messages = [];
                          
                          // Add the initial message (the ticket description)
                          messages.add({
                            'text': ticketData['issueDescription'] ?? description,
                            'timestamp': ticketData['createdAt'] ?? ticket['createdAt'],
                            'isAdmin': false,
                            'isInitial': true,
                            'isUser': true,
                          });
                          
                          // Add admin responses if available
                          List<dynamic> adminResponses = ticketData['adminResponses'] as List<dynamic>? ?? [];
                          for (var response in adminResponses) {
                            if (response is Map<String, dynamic>) {
                              messages.add({
                                'text': response['text'] ?? 'No content',
                                'timestamp': response['timestamp'],
                                'isAdmin': true,
                                'isInitial': false,
                                'isUser': false,
                              });
                            }
                          }
                          
                          // Add user replies if available
                          List<dynamic> userReplies = ticketData['userReplies'] as List<dynamic>? ?? [];
                          for (var reply in userReplies) {
                            if (reply is Map<String, dynamic>) {
                              messages.add({
                                'text': reply['text'] ?? 'No content',
                                'timestamp': reply['timestamp'],
                                'isAdmin': false,
                                'isInitial': false,
                                'isUser': true,
                              });
                            }
                          }
                          
                          // Sort all messages by timestamp
                          messages.sort((a, b) {
                            final aTimestamp = a['timestamp'] as Timestamp?;
                            final bTimestamp = b['timestamp'] as Timestamp?;
                            
                            if (aTimestamp == null && bTimestamp == null) return 0;
                            if (aTimestamp == null) return -1; // Null timestamps go first
                            if (bTimestamp == null) return 1;
                            
                            return aTimestamp.compareTo(bTimestamp);
                          });
                          
                          final isResolved = ticketData['resolved'] as bool? ?? false;

                          return ListView(
                            children: [
                              const Text(
                                'Issue Description:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  ticketData['issueDescription'] ?? '',
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              const Text(
                                'Conversation:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              
                              // Messages and admin reply boxes
                              for (int i = 1; i < messages.length; i++) ... [
                                _buildMessageBubble(messages[i]),
                                
                                // Show reply box after user messages if not resolved
                                if (messages[i]['isUser'] == true && !isResolved) ... [
                                  const SizedBox(height: 8),
                                  _buildAdminReplyBox(ticketId),
                                ]
                              ],
                              
                              // Show a reply box at the end if last message was from user and ticket is not resolved
                              if (messages.isNotEmpty && 
                                  messages.last['isUser'] == true && 
                                  !isResolved) ... [
                                const SizedBox(height: 8),
                                _buildAdminReplyBox(ticketId),
                              ],
                              
                              // Device info section
                              if (deviceInfo.isNotEmpty) ... [
                                const SizedBox(height: 16),
                                const Text(
                                  'Device Information:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: deviceInfo.entries.map((e) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: RichText(
                                          text: TextSpan(
                                            style: DefaultTextStyle.of(context).style,
                                            children: [
                                              TextSpan(
                                                text: '${e.key}: ',
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              TextSpan(text: '${e.value}'),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final bool isAdmin = message['isAdmin'] == true;
    final messageDate = message['timestamp'] as Timestamp?;
    final formattedDate = messageDate != null
        ? DateFormat('MMM d, yyyy • h:mm a').format(messageDate.toDate())
        : 'Unknown date';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isAdmin 
              ? AppTheme.primaryColor.withOpacity(0.05) 
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isAdmin 
                ? AppTheme.primaryColor.withOpacity(0.3) 
                : Colors.grey.shade300,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  isAdmin ? 'Admin' : 'User',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isAdmin ? AppTheme.primaryColor : Colors.grey.shade700,
                  ),
                ),
                const Spacer(),
                Text(
                  formattedDate,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              message['text'] as String? ?? '',
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminReplyBox(String ticketId) {
    final TextEditingController replyController = TextEditingController();
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextField(
            controller: replyController,
            decoration: const InputDecoration(
              hintText: 'Type your reply as admin...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            maxLines: 3,
            minLines: 1,
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              if (replyController.text.trim().isNotEmpty) {
                _addResponse(ticketId, replyController.text.trim());
                replyController.clear();
              }
            },
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Send Response'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown(String ticketId, String currentStatus, bool resolved, StateSetter setState) {
    return DropdownButton<String>(
      value: currentStatus,
      items: const [
        DropdownMenuItem(
          value: 'open',
          child: Text('Open'),
        ),
        DropdownMenuItem(
          value: 'in_progress',
          child: Text('In Progress'),
        ),
      ],
      onChanged: resolved
          ? null
          : (newValue) {
              if (newValue != null && newValue != currentStatus) {
                _updateTicketStatus(ticketId, newValue);
                setState(() {});
              }
            },
    );
  }

  Future<void> _updateTicketStatus(String ticketId, String newStatus) async {
    try {
      await _firestore.collection('support_tickets').doc(ticketId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating ticket status: $e');
    }
  }

  Future<void> _toggleResolved(String ticketId, bool currentResolvedStatus) async {
    try {
      await _firestore.collection('support_tickets').doc(ticketId).update({
        'resolved': !currentResolvedStatus,
        'status': !currentResolvedStatus ? 'resolved' : 'open',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error toggling resolved status: $e');
    }
  }

  Future<void> _addResponse(String ticketId, String responseText) async {
    try {
      await _supportService.addAdminResponseToTicket(ticketId, responseText);
    } catch (e) {
      print('Error adding response: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 