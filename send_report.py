import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime

# Your email and app password
sender_email = "gangsofroomates.com"
app_password = "hlnw ihil mhjj czvp"  # App password, not your Gmail login
receiver_email = "paras.dhiman030804.com"

# Email content
subject = f"AWS Monitoring Report - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
body = """
<html>
  <body>
    <h2>AWS Monitoring Report</h2>
    <p>This is a test email from the monitoring script.</p>
  </body>
</html>
"""

# Setup the MIME
msg = MIMEMultipart("alternative")
msg["Subject"] = subject
msg["From"] = sender_email
msg["To"] = receiver_email

# Attach body
msg.attach(MIMEText(body, "html"))

try:
    # Connect to Gmail
    server = smtplib.SMTP("smtp.gmail.com", 587)
    server.starttls()
    server.login(sender_email, app_password)
    server.sendmail(sender_email, receiver_email, msg.as_string())
    server.quit()
    print("✅ Email sent successfully.")
except Exception as e:
    print("❌ Failed to send email:", str(e))

