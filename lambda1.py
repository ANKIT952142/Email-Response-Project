import boto3
import json

# Initialize SES client
ses_client = boto3.client('ses')

def lambda_handler(event, context):
    # Define the sender, recipient, and SES receiver email
    sender_email = "ankit952142@gmail.com"           # Verified SES email for sending
    recipient_email = "ankit952142@gmail.com"          # Email that receives the Accept/Reject decision links
    ses_receiver_email = "test@ankit101.awsapps.com"  # SES-monitored email that receives the decision

    # Define email subject and HTML body with "Accept" and "Reject" buttons
    subject = "Your Decision Required: Accept or Reject"
    
    # Add response code metadata and message body to each link
    body_html = f"""
    <html>
    <body>
        <p>Please choose an option:</p>
        <p>
            <a href="mailto:{ses_receiver_email}?subject=Accepted&body=I am accepting the data.&response_code=accept" 
               style="padding:10px 20px; color:white; background-color:green; text-decoration:none;">Accept</a>
            &nbsp;&nbsp;&nbsp;&nbsp;
            <a href="mailto:{ses_receiver_email}?subject=Rejected&body=I am rejecting the data.&response_code=reject" 
               style="padding:10px 20px; color:white; background-color:red; text-decoration:none;">Reject</a>
        </p>
    </body>
    </html>
    """

    try:
        # Send the email via SES
        response = ses_client.send_email(
            Source=sender_email,
            Destination={
                'ToAddresses': [recipient_email]
            },
            Message={
                'Subject': {
                    'Data': subject
                },
                'Body': {
                    'Html': {
                        'Data': body_html
                    }
                }
            }
        )
        return {
            'statusCode': 200,
            'body': json.dumps('Email sent successfully via SES')
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps(f"Error sending email: {str(e)}")
        }