"""Authorize the Google account locally. Never commit or share the token.

Create a Google Cloud OAuth client of type Desktop and enable Google Drive API.
Set StudentLab_DRIVE_CLIENT_ID and StudentLab_DRIVE_CLIENT_SECRET in your local
environment, then run from BE:
  pip install -r requirements-drive-setup.txt
  python -m scripts.authorize_drive_account

Sign in as studentlabdmi@gmail.com. Copy the displayed refresh token into the
deployment secret StudentLab_DRIVE_REFRESH_TOKEN. Do not store it in Git.
"""
import os

from dotenv import load_dotenv

load_dotenv(override=False)


def main():
    client_id = os.getenv('StudentLab_DRIVE_CLIENT_ID', '').strip()
    client_secret = os.getenv('StudentLab_DRIVE_CLIENT_SECRET', '').strip()
    if not client_id or not client_secret:
        raise SystemExit('Configura ID e segreto del client OAuth solo sul tuo computer.')
    from google_auth_oauthlib.flow import InstalledAppFlow

    config = {'installed': {
        'client_id': client_id,
        'client_secret': client_secret,
        'auth_uri': 'https://accounts.google.com/o/oauth2/auth',
        'token_uri': 'https://oauth2.googleapis.com/token',
        'redirect_uris': ['http://localhost'],
    }}
    flow = InstalledAppFlow.from_client_config(config, scopes=[
        'https://www.googleapis.com/auth/drive',
    ])
    credentials = flow.run_local_server(host='localhost', port=0,
        open_browser=True, access_type='offline', prompt='consent')
    if not credentials.refresh_token:
        raise SystemExit('Google non ha restituito un token di aggiornamento.')
    print('Imposta StudentLab_DRIVE_REFRESH_TOKEN come segreto del backend:')
    print(credentials.refresh_token)
    print('Non condividere o inserire questo valore nella ZIP.')


if __name__ == '__main__':
    main()
