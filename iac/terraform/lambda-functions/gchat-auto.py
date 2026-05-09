import os
import re
from dotenv import load_dotenv
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

SCOPES = ['https://www.googleapis.com/auth/chat.messages.create']

def get_image_number(filename):
    match = re.match(r'^(\d+)', filename)
    return int(match.group(1)) if match else float('inf')

def send_image_to_chat():
    home_dir = os.path.expanduser('~')
    
    dotenv_path = os.path.join(home_dir, '.env')
    load_dotenv(dotenv_path)
    
    space_name = os.getenv('SPACE_NAME')
    
    if not space_name:
        print("Error: SPACE_NAME variable not found in the .env file")
        return

    images_dir = os.path.join(home_dir, "images", "auto")
    if not os.path.exists(images_dir):
        print(f"Error: Directory not found at {images_dir}")
        return

    image_files = [f for f in os.listdir(images_dir) if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
    if not image_files:
        print("Error: No images found in the directory.")
        return

    image_files.sort(key=get_image_number)

    state_file = os.path.join(images_dir, ".current_image_index")
    current_index = 0
    if os.path.exists(state_file):
        with open(state_file, 'r') as f:
            content = f.read().strip()
            if content.isdigit():
                current_index = int(content)

    if current_index >= len(image_files):
        current_index = 0

    image_filename = image_files[current_index]
    image_path = os.path.join(images_dir, image_filename)

    credentials_path = os.path.join(home_dir, 'credentials-google-api.json')
    token_path = os.path.join(home_dir, 'token-google-api.json')

    creds = None
    if os.path.exists(token_path):
        creds = Credentials.from_authorized_user_file(token_path, SCOPES)
        
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not os.path.exists(credentials_path):
                print(f"Error: Credentials file not found at {credentials_path}")
                return
            flow = InstalledAppFlow.from_client_secrets_file(credentials_path, SCOPES)
            creds = flow.run_local_server(port=0)
        
        with open(token_path, 'w') as token:
            token.write(creds.to_json())

    chat_service = build('chat', 'v1', credentials=creds)

    try:
        print(f"Starting upload to space: {space_name}...")
        print(f"Selected image: {image_filename}")
        
        media = MediaFileUpload(image_path, mimetype='image/jpeg')
        
        upload_response = chat_service.media().upload(
            parent=space_name,
            body={'filename': image_filename},
            media_body=media
        ).execute()

        upload_token = upload_response['attachmentDataRef']['attachmentUploadToken']

        print("Sending message...")
        message_body = {
            'text': 'Bom dia prezados,\n\nEm conformidade com a Lei Geral da Proteção de Dados (LGPD) no tratamento de dados realizados diariamente nos procedimentos da Dcide LTDA, segue a dica de hoje.',
            'attachment': [  
                {
                    'attachmentDataRef': {
                        'attachmentUploadToken': upload_token
                    }
                }
            ]
        }

        chat_service.spaces().messages().create(
            parent=space_name,
            body=message_body
        ).execute()

        print("Message sent successfully!")

        next_index = (current_index + 1) % len(image_files)
        with open(state_file, 'w') as f:
            f.write(str(next_index))

    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == '__main__':
    send_image_to_chat()