import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/support_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_card.dart';
import '../widgets/empty_state.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  final SupportService _supportService = SupportService();
  bool _isLoading = true;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    // Add debug print for authentication status
    final user = FirebaseAuth.instance.currentUser;
    print('DEBUG: Current user: ${user?.uid ?? 'Not logged in'}');
    
    // Force setState after a delay to clear loading state if it's stuck
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isLoading) {
        print('DEBUG: Forcing _isLoading to false after timeout');
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Support Tickets'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      const Text(
                        'Error loading tickets',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _error = null;
                          });
                          // This will trigger the stream to reconnect
                        },
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : StreamBuilder<QuerySnapshot>(
                  stream: _supportService.getUserSupportTickets(),
                  builder: (context, snapshot) {
                    print('DEBUG: StreamBuilder connectionState: ${snapshot.connectionState}');
                    print('DEBUG: StreamBuilder hasData: ${snapshot.hasData}');
                    print('DEBUG: StreamBuilder hasError: ${snapshot.hasError}');
                    if (snapshot.hasError) {
                      print('DEBUG: StreamBuilder error: ${snapshot.error}');
                    }
                    
                    if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                            const SizedBox(height: 16),
                            const Text(
                              'Error loading tickets',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              snapshot.error.toString(),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      );
                    }

                    if (_isLoading) {
                      setState(() {
                        _isLoading = false;
                      });
                    }

                    // Get the tickets from the snapshot
                    final tickets = snapshot.data?.docs ?? [];
                    print('DEBUG: Number of tickets: ${tickets.length}');
                    
                    if (tickets.isEmpty) {
                      print('DEBUG: No tickets found');
                      return const EmptyState(
                        icon: Icons.support_agent,
                        title: 'No Support Tickets',
                        message: 'You haven\'t submitted any support tickets yet.',
                      );
                    }

                    // Sort tickets by updatedAt timestamp in descending order
                    final sortedTickets = List<QueryDocumentSnapshot>.from(tickets);
                    sortedTickets.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aTime = aData['updatedAt'] as Timestamp?;
                      final bTime = bData['updatedAt'] as Timestamp?;
                      
                      if (aTime == null && bTime == null) return 0;
                      if (aTime == null) return 1;
                      if (bTime == null) return -1;
                      return bTime.compareTo(aTime); // Descending order
                    });

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: sortedTickets.length,
                      itemBuilder: (context, index) {
                        final ticket = sortedTickets[index].data() as Map<String, dynamic>;
                        final ticketId = sortedTickets[index].id;
                        return _buildTicketCard(ticket, ticketId);
                      },
                    );
                  },
                ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket, String ticketId) {
    final createdAt = ticket['createdAt'] as Timestamp?;
    final formattedDate = createdAt != null
        ? DateFormat('MMM d, yyyy • h:mm a').format(createdAt.toDate())
        : 'Unknown date';

    final status = ticket['status'] as String? ?? 'open';
    final resolved = ticket['resolved'] as bool? ?? false;
    final category = ticket['issueCategory'] ?? 'General';
    final description = ticket['issueDescription'] ?? '';
    final adminResponses = ticket['adminResponses'] as List<dynamic>? ?? [];
    final userReplies = ticket['userReplies'] as List<dynamic>? ?? [];
    final totalMessages = adminResponses.length + userReplies.length;

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
        onTap: () => _showTicketDetailsDialog(context, ticket, ticketId),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Container(
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
                          Flexible(
                            child: Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
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
                        overflow: TextOverflow.ellipsis,
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
                  Flexible(
                    child: Text(
                      formattedDate,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (totalMessages > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.message,
                                size: 14,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$totalMessages ${totalMessages == 1 ? 'Message' : 'Messages'}',
                                style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
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
    );
  }

  void _showTicketDetailsDialog(BuildContext context, Map<String, dynamic> ticket, String ticketId) {
    // Navigate to a full screen instead of showing a dialog
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TicketDetailsScreen(
          ticket: ticket,
          ticketId: ticketId,
        ),
      ),
    );
  }
}

class TicketDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;
  final String ticketId;

  const TicketDetailsScreen({
    Key? key,
    required this.ticket,
    required this.ticketId,
  }) : super(key: key);

  @override
  State<TicketDetailsScreen> createState() => _TicketDetailsScreenState();
}

class _TicketDetailsScreenState extends State<TicketDetailsScreen> {
  final SupportService _supportService = SupportService();
  final TextEditingController _replyController = TextEditingController();

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String description = widget.ticket['issueDescription'] ?? 'No description provided';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket Details'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('support_tickets').doc(widget.ticketId).snapshots(),
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
            'timestamp': ticketData['createdAt'] ?? widget.ticket['createdAt'],
            'isAdmin': false,
            'isInitial': true,
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

          // Get latest status
          final updatedResolved = ticketData['resolved'] ?? false;
          final updatedStatus = ticketData['status'] ?? 'open';
          final String category = ticketData['issueCategory'] ?? 'General';
          
          Color statusColor;
          String statusText;

          if (updatedResolved) {
            statusColor = Colors.green;
            statusText = 'Resolved';
          } else if (updatedStatus == 'in_progress') {
            statusColor = Colors.orange;
            statusText = 'In Progress';
          } else {
            statusColor = Colors.blue;
            statusText = 'Open';
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ticket Info Section
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.support_agent, color: Colors.indigo),
                            const SizedBox(width: 8),
                            const Text(
                              'Support Ticket',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: statusColor.withOpacity(0.5)),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            const Icon(Icons.category, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              'Category: $category',
                              style: const TextStyle(
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.numbers, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              'ID: ${widget.ticketId}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              'Submitted: ${_formatTimestamp(ticketData['createdAt'])}',
                              style: const TextStyle(
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Conversation Section
                const Text(
                  'Conversation',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Message List
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: messages.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _buildMessageBubble(
                        messages[index], 
                        context, 
                        FirebaseAuth.instance.currentUser?.uid ?? ''
                      ),
                    ),
                  ),
                ),
                
                // Reply Box
                if (!updatedResolved)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _replyController,
                            decoration: InputDecoration(
                              hintText: 'Type your reply...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            maxLines: null,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: Colors.indigo,
                          borderRadius: BorderRadius.circular(24),
                          child: InkWell(
                            onTap: () async {
                              if (_replyController.text.trim().isEmpty) return;
                              final reply = _replyController.text.trim();
                              _replyController.clear();
                              await _submitReply(context, widget.ticketId, reply);
                            },
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              child: const Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return 'Invalid date';
    }
    
    return DateFormat('MMM d, yyyy • h:mm a').format(date);
  }

  Future<void> _submitReply(BuildContext context, String ticketId, String reply) async {
    try {
      await _supportService.addUserReplyToTicket(ticketId, reply);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reply sent successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error adding reply: $e');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending reply: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, BuildContext context, String currentUserId) {
    final bool isAdmin = message['isAdmin'] == true;
    final bool isCurrentUser = !isAdmin; // User messages should be on right side
    
    final bubbleColor = isAdmin 
        ? Colors.indigo.withOpacity(0.9) // Change admin bubble color to indigo
        : Colors.blue.withOpacity(0.9);
        
    final textColor = Colors.white;
    final alignment = isCurrentUser ? Alignment.centerRight : Alignment.centerLeft;
    
    // Format the timestamp
    String formattedTime = '';
    if (message['timestamp'] != null) {
      DateTime messageTime;
      if (message['timestamp'] is Timestamp) {
        messageTime = (message['timestamp'] as Timestamp).toDate();
      } else if (message['timestamp'] is DateTime) {
        messageTime = message['timestamp'] as DateTime;
      } else {
        messageTime = DateTime.now();
      }
      formattedTime = DateFormat('MMM d, h:mm a').format(messageTime);
    }

    return Container(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.6,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isAdmin)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Admin',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber, // Change admin name color to amber
                      fontSize: 12,
                    ),
                  ),
                ),
              Text(
                message['text'] ?? '',
                style: TextStyle(color: textColor),
              ),
              const SizedBox(height: 4),
              Text(
                formattedTime,
                style: TextStyle(
                  color: Colors.grey.shade100,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 