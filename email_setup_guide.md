# Email Setup Guide for Easy Money App

This guide will help you set up a Gmail account to send verification emails through your app.

## Step 1: Create a Gmail Account for Your App

It's recommended to create a dedicated Gmail account for your app rather than using your personal account:

1. Go to [Gmail Sign Up](https://accounts.google.com/signup)
2. Follow the steps to create a new account
3. Use a professional name like `noreply@yourdomain.com` or `easymoneyapp@gmail.com`

## Step 2: Enable App Passwords in Google Account

Gmail's normal password won't work for SMTP connections. You need to generate an App Password:

1. Go to your [Google Account Security Settings](https://myaccount.google.com/security)
2. Enable 2-Step Verification if it's not already enabled
3. After enabling 2-Step Verification, go to [App passwords](https://myaccount.google.com/apppasswords)
4. Select "Other (Custom name)" from the dropdown menu
5. Enter "Easy Money App" as the name
6. Click "Generate"
7. Google will display a 16-character password. **Copy this password immediately** as you won't be able to see it again

## Step 3: Configure Your App

1. Open the `.env` file in your project root directory
2. Replace the placeholder values with your actual Gmail credentials:

```
EMAIL_USERNAME=your_app_email@gmail.com
EMAIL_PASSWORD=your_16_character_app_password
EMAIL_FROM_NAME=Easy Money App
```

3. Make sure not to commit this file to public repositories as it contains sensitive information

## Step 4: Test Email Sending

1. In the `lib/services/email_service.dart` file, set `sendRealEmails = true` temporarily:

```dart
// In debug mode, we can choose whether to actually send emails or just simulate
bool sendRealEmails = true; // Change to true to test real email sending
```

2. Run the app in debug mode and try to register a new user or request an OTP
3. Check your console logs to verify if the email was sent successfully
4. Check the inbox of the target email address to confirm receipt
5. After testing, set `sendRealEmails = false` again to avoid sending real emails during development

## Troubleshooting

If you encounter issues sending emails:

1. **Authentication Failed**: Double-check your app password and make sure you're using the App Password, not your regular Gmail password

2. **Gmail Blocks**: If Gmail blocks the connection, you might need to:
   - Allow less secure apps: Visit [Less secure app access](https://myaccount.google.com/lesssecureapps) 
   - Unlock captcha: Visit [Display Unlock Captcha](https://accounts.google.com/DisplayUnlockCaptcha)

3. **Email Quota**: Be aware that Gmail has sending limits:
   - 500 emails per day for regular Gmail accounts
   - 2000 emails per day for Google Workspace accounts

## Production Considerations

For a production app with many users, consider:

1. Using a professional email service like SendGrid, Mailgun, or AWS SES
2. Setting up DKIM and SPF records to improve email deliverability
3. Moving email sending logic to a backend service to keep API keys secure 