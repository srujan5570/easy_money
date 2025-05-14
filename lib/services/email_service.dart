import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EmailService {
  // Email configuration
  final String _fromEmail = 'your_app_email@gmail.com'; // Replace with your app's email
  final String _fromName = 'Easy Money App';
  
  // Get SMTP server for sending emails
  SmtpServer _getSmtpServer() {
    // Get credentials from .env file
    String username = dotenv.env['EMAIL_USERNAME'] ?? '';
    String password = dotenv.env['EMAIL_PASSWORD'] ?? '';
    
    if (username.isEmpty || password.isEmpty) {
      if (kDebugMode) {
        print('Warning: Email credentials not configured properly in .env file');
      }
      // Fallback to default values for development/testing
      username = 'your_app_email@gmail.com';
      password = 'your_app_password';
    }
    
    // For Gmail, use an App Password (not your regular password)
    // Generate one at https://myaccount.google.com/apppasswords
    return gmail(username, password);
  }
  
  Future<void> sendOtpEmail({
    required String email,
    required String otp,
    bool isNewUser = false,
  }) async {
    final subject = isNewUser 
        ? 'Verify Your Email for Easy Money App' 
        : 'Your Verification Code for Easy Money App';
    
    final htmlContent = '''
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 5px;">
      <h2 style="color: #4CAF50; text-align: center;">Easy Money App</h2>
      <p>Hello,</p>
      <p>${isNewUser ? 'Thank you for creating an account with Easy Money App!' : 'You requested a verification code for your Easy Money App account.'}</p>
      <p>Your verification code is:</p>
      <div style="background-color: #f5f5f5; padding: 15px; text-align: center; font-size: 24px; letter-spacing: 5px; font-weight: bold; border-radius: 4px; margin: 20px 0;">
        $otp
      </div>
      <p>Please enter this code in the app to ${isNewUser ? 'complete your registration' : 'verify your action'}.</p>
      <p>If you don't see this email in your inbox, please check your spam folder.</p>
      <p>If you didn't request this code, you can safely ignore this email.</p>
      <p>Thanks,<br>The Easy Money Team</p>
    </div>
    ''';

    await _sendEmail(
      recipientEmail: email,
      subject: subject,
      htmlContent: htmlContent,
    );
  }
  
  // Send password reset email with instructions
  Future<void> sendPasswordResetEmail({
    required String email,
  }) async {
    final subject = 'Password Reset Instructions for Easy Money App';
    
    final htmlContent = '''
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 5px;">
      <h2 style="color: #4CAF50; text-align: center;">Easy Money App</h2>
      <p>Hello,</p>
      <p>We received a request to reset your password for your Easy Money App account.</p>
      <p>You will receive a separate email from Firebase with a link to reset your password. Please follow the instructions in that email to create a new password.</p>
      <p>If the email doesn't arrive within a few minutes, please check your spam folder.</p>
      <p>If you didn't request a password reset, you can safely ignore this email.</p>
      <p>Thanks,<br>The Easy Money Team</p>
    </div>
    ''';

    await _sendEmail(
      recipientEmail: email,
      subject: subject,
      htmlContent: htmlContent,
    );
  }
  
  Future<void> _sendEmail({
    required String recipientEmail,
    required String subject,
    required String htmlContent,
  }) async {
    try {
      // Get SMTP server
      final smtpServer = _getSmtpServer();
      
      // Create the message
      final message = Message()
        ..from = Address(
          dotenv.env['EMAIL_USERNAME'] ?? 'your_app_email@gmail.com', 
          dotenv.env['EMAIL_FROM_NAME'] ?? 'Easy Money App'
        )
        ..recipients.add(recipientEmail)
        ..subject = subject
        ..html = htmlContent;
      
      // Send the email
      final sendReport = await send(message, smtpServer);
      
      if (kDebugMode) {
        print('Message sent: ${sendReport.toString()}');
      }
    } catch (e) {
      print('Error sending email: $e');
      rethrow;
    }
  }
} 