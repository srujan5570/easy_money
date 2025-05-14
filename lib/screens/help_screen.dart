import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_card.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../services/support_service.dart';
import '../screens/my_tickets_screen.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _issueController = TextEditingController();
  bool _isSubmitting = false;
  String _selectedIssueCategory = 'Spin Issues';
  bool _showDeviceInfo = false;
  String _deviceModel = 'Android';
  String _osVersion = 'Android 13';
  bool _includeScreenshot = false;
  
  final List<String> _issueCategories = [
    'Spin Issues',
    'Withdrawal Problems',
    'Ad-related Issues',
    'Referral System',
    'Account Problems',
    'App Performance',
    'UPI ID Issues',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    // Set the current user's email if available
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null && user.email!.isNotEmpty) {
      _emailController.text = user.email!;
    }
    
    // Get device info for display
    _getDeviceInfo();
  }
  
  Future<void> _getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        setState(() {
          _deviceModel = androidInfo.model;
          _osVersion = 'Android ${androidInfo.version.release}';
        });
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        setState(() {
          _deviceModel = iosInfo.model;
          _osVersion = '${iosInfo.systemName} ${iosInfo.systemVersion}';
        });
      }
    } catch (e) {
      print('Error getting device info: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _issueController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      // Instantiate the support service
      final supportService = SupportService();
      
      // Submit the support ticket
      await supportService.submitSupportTicket(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        issueCategory: _selectedIssueCategory,
        issueDescription: _issueController.text.trim(),
        includeDeviceInfo: _showDeviceInfo,
        includeScreenshot: _includeScreenshot,
      );
      
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showSuccessDialog();
        _nameController.clear();
        _emailController.clear();
        _issueController.clear();
        setState(() {
          _includeScreenshot = false;
          _showDeviceInfo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting issue: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text('Thank You!'),
          ],
        ),
        content: const Text(
          'Your issue has been submitted successfully. Our support team will get back to you within 24 hours.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'help2easymoney@gmail.com',
      query: 'subject=Help%20with%20Easy%20Money%20App',
    );

    try {
      await launchUrl(emailUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch email client: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyTicketsScreen()),
              );
            },
            icon: const Icon(Icons.history),
            label: const Text('My Tickets'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildFaqSection(),
            const SizedBox(height: 32),
            const Text(
              'Contact Support',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildContactOptions(),
            const SizedBox(height: 32),
            const Text(
              'Report an Issue',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildReportForm(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqSection() {
    final faqs = [
      {
        'question': 'How do I earn money in this app?',
        'answer': 'You can earn money through multiple methods in Easy Money:\n\n'
            '• Daily Spins: You get 5 free spins daily. Each spin can win you points that convert to real money.\n'
            '• Ad Rewards: Watch video advertisements to earn extra spins when you run out of your daily quota.\n'
            '• Referral Program: Invite friends using your unique referral code. You earn ₹2 for each friend who joins using your code.\n'
            '• Bonus Points: Occasional promotional events and daily login bonuses provide additional earning opportunities.\n\n'
            'All earnings are tracked in your profile and can be withdrawn once you reach the minimum threshold.'
      },
      {
        'question': 'How many spins do I get per day?',
        'answer': 'You receive a total of 5 free spins each day. These spins reset automatically at midnight (12:00 AM) your local time.\n\n'
            'If you\'ve used all your daily spins, you can still earn more by:\n'
            '• Watching reward ads: Each completed video ad gives you 1 additional spin\n'
            '• Reaching specific milestones in the app\n'
            '• Participating in special events\n\n'
            'The app tracks your remaining spins in the Spin screen and your Profile section. Make sure to use all your spins before they reset!'
      },
      {
        'question': 'When and how can I withdraw my earnings?',
        'answer': 'You can withdraw your earnings once your balance reaches ₹10 or more. The withdrawal process is simple:\n\n'
            '1. Go to the Wallet screen from the main navigation\n'
            '2. Tap on "Withdraw"\n'
            '3. Ensure your UPI ID is correctly entered in your profile settings\n'
            '4. Enter the amount you wish to withdraw (minimum ₹10)\n'
            '5. Confirm the transaction\n\n'
            'Processing times:\n'
            '• Standard withdrawals are processed within 24-48 hours\n'
            '• First-time withdrawals may require additional verification\n'
            '• Withdrawals requested on weekends or holidays might take longer\n\n'
            'You\'ll receive a notification when your withdrawal is complete. If you face any issues, contact our support team immediately.'
      },
      {
        'question': 'How does the referral system work?',
        'answer': 'Our referral program is designed to reward you for bringing new users to Easy Money:\n\n'
            '1. Share your unique referral code: Find it in your Profile section\n'
            '2. When a friend installs the app and enters your code, they need to complete the registration process\n'
            '3. Both you and your friend receive ₹2 bonus immediately after your friend completes registration\n\n'
            'Additional benefits:\n'
            '• There\'s no limit to how many friends you can refer\n'
            '• Your referral earnings can be withdrawn just like regular earnings\n'
            '• You can track all your referrals in the Profile section\n\n'
            'The referral bonus is credited instantly and added to your withdrawable balance. The more friends you invite, the more you earn!'
      },
      {
        'question': 'My spins are not resetting at midnight',
        'answer': 'If your spins aren\'t resetting at midnight, try these troubleshooting steps:\n\n'
            '1. Force close the app completely and reopen it\n'
            '2. Check your device\'s date and time settings - make sure they\'re set to automatic\n'
            '3. Ensure you have a stable internet connection\n'
            '4. Clear the app cache (Settings > Apps > Easy Money > Storage > Clear Cache)\n'
            '5. Update to the latest version of the app\n\n'
            'Technical details:\n'
            '• Spin resets are triggered the first time you open the app after midnight\n'
            '• If the app remains open in the background during midnight, you may need to restart it\n'
            '• The reset is based on your device\'s local time zone\n\n'
            'If the issue persists after trying these steps, please contact our support team with details of your device model and OS version.'
      },
      {
        'question': 'Why am I not seeing any ads?',
        'answer': 'If you\'re unable to view advertisements, consider these possible causes and solutions:\n\n'
            '1. Internet Connection: Ads require a stable internet connection. Try switching between Wi-Fi and mobile data.\n'
            '2. Ad Inventory: Sometimes ad providers have limited inventory for your region. Try again later.\n'
            '3. Device Settings: Check if you have any ad blockers or restrictive settings enabled on your device.\n'
            '4. App Version: Ensure you\'re using the latest version of Easy Money.\n'
            '5. Device Storage: Low storage can prevent ads from loading properly.\n\n'
            'If none of these solutions work, restart your device completely and try again. Ads typically refresh every few hours, so if they\'re not available now, they might be available later.'
      },
      {
        'question': 'How do points convert to real money?',
        'answer': 'In Easy Money, points are directly convertible to INR at a fixed rate:\n\n'
            '• 1000 points = ₹1 (Indian Rupee)\n'
            '• Point values from spins range from 100 to 5000 points (₹0.10 to ₹5)\n'
            '• Referral bonuses are credited as 2000 points (₹2)\n\n'
            'Your points/earnings are automatically calculated and displayed in rupees in your profile and wallet sections. There\'s no need for manual conversion.\n\n'
            'All withdrawals are processed based on this conversion rate, and the minimum withdrawal amount is ₹10 (10,000 points). The conversion rate remains constant regardless of how many points you accumulate.'
      },
      {
        'question': 'Is the app safe and legitimate?',
        'answer': 'Yes, Easy Money is a legitimate rewards app:\n\n'
            '• Security: We use industry-standard encryption and Firebase authentication to protect your data\n'
            '• Payments: All transactions are processed through secure payment gateways\n'
            '• Privacy: We only collect essential information needed to provide our services and never share it with unauthorized third parties\n'
            '• Business Model: We generate revenue through advertisements and partnerships, allowing us to share earnings with users\n\n'
            'Important note: While Easy Money offers a legitimate way to earn small amounts of money in your spare time, it\'s designed as a supplementary income source, not a primary one. Always use caution with any app requesting financial information and review our privacy policy for complete details on how your data is handled.'
      }
    ];

    return CustomCard(
      child: ExpansionPanelList(
        elevation: 0,
        expandedHeaderPadding: EdgeInsets.zero,
        dividerColor: Colors.grey.shade200,
        expansionCallback: (int index, bool isExpanded) {
          setState(() {
            for (int i = 0; i < _expandedList.length; i++) {
              _expandedList[i] = i == index && !isExpanded;
            }
          });
        },
        children: List.generate(faqs.length, (index) {
          if (index >= _expandedList.length) {
            _expandedList.add(false);
          }
          return ExpansionPanel(
            headerBuilder: (context, isExpanded) {
              return ListTile(
                title: Text(
                  faqs[index]['question']!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              );
            },
            body: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                faqs[index]['answer']!,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
            ),
            isExpanded: _expandedList[index],
            canTapOnHeader: true,
          );
        }),
      ),
    );
  }

  List<bool> _expandedList = [];

  Widget _buildContactOptions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: CustomCard(
                child: InkWell(
                  onTap: _launchEmail,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.email_outlined,
                            color: AppTheme.primaryColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Email Support',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'help2easymoney@gmail.com',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Response within 24 hours',
                          style: TextStyle(
                            color: Colors.green.shade600,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomCard(
                child: InkWell(
                  onTap: _launchWhatsapp,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chat,
                            color: Colors.green.shade600,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'WhatsApp Support',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '+91 9876543210',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Available 10AM-7PM IST',
                          style: TextStyle(
                            color: Colors.green.shade600,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CustomCard(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 18,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Support Hours',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSupportHoursRow('Monday - Friday', '10:00 AM - 7:00 PM IST'),
                _buildSupportHoursRow('Saturday', '10:00 AM - 2:00 PM IST'),
                _buildSupportHoursRow('Sunday & Holidays', 'Closed (Email Only)'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'For urgent matters, please use WhatsApp during business hours for faster response.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSupportHoursRow(String day, String hours) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              day,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              hours,
              style: TextStyle(
                fontWeight: day.contains('Sunday') || day.contains('Holiday') 
                    ? FontWeight.bold 
                    : FontWeight.normal,
                color: day.contains('Sunday') || day.contains('Holiday')
                    ? Colors.red.shade700
                    : Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchWhatsapp() async {
    final whatsappUrl = 'https://wa.me/919876543210?text=Hello,%20I%20need%20help%20with%20Easy%20Money%20App.';
    final Uri uri = Uri.parse(whatsappUrl);
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch WhatsApp')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildReportForm() {
    return CustomCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Introduction text
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'Please provide as much detail as possible so we can help you quickly. Our support team typically responds within 24 hours on business days.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ),
              
              // Issue Category Dropdown
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Issue Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                value: _selectedIssueCategory,
                items: _issueCategories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (String? value) {
                  setState(() {
                    _selectedIssueCategory = value!;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select an issue category';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Your Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Email Field
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                readOnly: _emailController.text.isNotEmpty,
                enableInteractiveSelection: true,
                style: _emailController.text.isNotEmpty 
                  ? TextStyle(color: Colors.grey.shade700) 
                  : null,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Device Information
              if (_showDeviceInfo)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Device Information',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _showDeviceInfo = false;
                              });
                            },
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This information helps us troubleshoot your issue more efficiently:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDeviceInfoRow('Device Model', _deviceModel),
                      _buildDeviceInfoRow('OS Version', _osVersion),
                      _buildDeviceInfoRow('App Version', '1.0.0'),
                      const SizedBox(height: 8),
                    ],
                  ),
                )
              else
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showDeviceInfo = true;
                    });
                  },
                  icon: Icon(
                    Icons.phone_android,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                  label: Text(
                    'Include Device Information',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 13,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),
                ),
              const SizedBox(height: 16),
              
              // Issue Description Field
              TextFormField(
                controller: _issueController,
                decoration: InputDecoration(
                  labelText: 'Describe your issue',
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                  prefixIcon: const Icon(Icons.message_outlined),
                  helperText: 'Please include steps to reproduce the issue if applicable',
                  helperStyle: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please describe your issue';
                  }
                  if (value.trim().length < 10) {
                    return 'Please provide more details (at least 10 characters)';
                  }
                  return null;
                },
              ),
              
              // Allow screenshots
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 20.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _includeScreenshot,
                        onChanged: (value) {
                          setState(() {
                            _includeScreenshot = value!;
                          });
                        },
                        activeColor: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'I\'ll send screenshots to help2easymoney@gmail.com after submitting this form',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Submit Button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Submit',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              
              // Privacy note
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  'Your information will only be used to resolve this specific issue and won\'t be shared with third parties.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDeviceInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label + ':',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 