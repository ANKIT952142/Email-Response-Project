import boto3
import json
import email
from email import policy
from email.parser import BytesParser

# Initialize S3 client
s3_client = boto3.client('s3')

def lambda_handler(event, context):
    # Check if the event contains S3 records
    if 'Records' in event:
        for record in event['Records']:
            # Get the bucket name and object key from the S3 event
            s3_bucket = record['s3']['bucket']['name']
            s3_object_key = record['s3']['object']['key']

            # Retrieve the email from S3
            try:
                s3_object = s3_client.get_object(Bucket=s3_bucket, Key=s3_object_key)
                email_content = s3_object['Body'].read()

                # Debug log to verify email content retrieval
                print(f"Email content: {email_content[:500]}")  # Print first 500 chars for inspection

                # Parse the email content to extract the subject
                msg = BytesParser(policy=policy.default).parsebytes(email_content)
                
                # Log all headers for verification
                print(f"Email headers: {msg.items()}")

                subject = msg['subject']
                print(f"Email subject: {subject}")  # Debug log to verify subject

                # Print the response based on the subject content
                if "Accepted" in subject:
                    print("Response: Accepted")
                elif "Rejected" in subject:
                    print("Response: Rejected")
                else:
                    print("Response: Unknown")

                # Optionally, print the email body if needed
                body = msg.get_body(preferencelist=('plain', 'html')).get_content()
                print(f"Email body: {body}")
                
                return {
                    'statusCode': 200,
                    'body': json.dumps("Response received and printed successfully.")
                }

            except Exception as e:
                print(f"Error processing email: {str(e)}")  # Additional error log
                return {
                    'statusCode': 500,
                    'body': json.dumps(f"Error processing email: {str(e)}")
                }

    print("No S3 records found in event.")  # Log if no S3 records are present
    return {
        'statusCode': 400,
        'body': json.dumps("No S3 records found in event.")
    }