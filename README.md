# MediCoreSystem

## Getting Started

To get started with the project locally, ensure you have Node.js installed.

Follow these steps:

```sh
# Step 1: Clone the repository using the project's Git URL.
git clone <YOUR_GIT_URL>

# Step 2: Navigate to the project directory.
cd <YOUR_PROJECT_NAME>

# Step 3: Install the necessary dependencies.
npm i

# Step 4: Start the development server with auto-reloading and an instant preview.
npm run dev
```

**Edit a file directly in GitHub**

- Navigate to the desired file(s).
- Click the "Edit" button (pencil icon) at the top right of the file view.
- Make your changes and commit the changes.

**Use GitHub Codespaces**

- Navigate to the main page of your repository.
- Click on the "Code" button (green button) near the top right.
- Select the "Codespaces" tab.
- Click on "New codespace" to launch a new Codespace environment.
- Edit files directly within the Codespace and commit and push your changes once you're done.

## What technologies are used for this project?

This project is built with:

- Vite
- TypeScript
- React
- shadcn-ui
- Tailwind CSS
- Firebase (Firestore, Hosting)
- Supabase (Auth, Database)
- Google OAuth (Authentication)

## Authentication with Google

This project uses **Supabase Auth with Google OAuth** for secure user authentication.

### Setting up Google OAuth in Supabase

1. **Create a Google OAuth Application:**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project
   - Enable **Google+ API**
   - Create OAuth 2.0 Credentials (Web Application)
   - Add authorized redirect URIs:
     - `https://<your-supabase-project>.supabase.co/auth/v1/callback`
     - `http://localhost:5173/` (for local development)

2. **Configure in Supabase:**
   - Go to your Supabase project > Authentication > Providers
   - Enable the Google provider
   - Paste your Google OAuth Client ID and Client Secret

3. **Add Google Sign-In in Your App:**
   - Your Supabase client is already configured in `src/integrations/supabase/client.ts`
   - Use `supabase.auth.signInWithOAuth({ provider: 'google' })` to trigger Google login

### Environment Variables

Create a `.env.local` file with:
```
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your_anon_key
VITE_FIREBASE_PROJECT_ID=your_firebase_project
VITE_FIREBASE_API_KEY=your_firebase_api_key
```

### Email Verification with Supabase

Supabase handles email verification automatically when you enable it:
- Verification emails are sent via Supabase's email service (or your custom SMTP)
- Configure email templates in Supabase Dashboard > Authentication > Email Templates
- Users verify via the confirmation link sent to their email

No third-party email service is required—Supabase manages email verification internally.

## How can I deploy this project?

### Firebase Hosting

```sh
# Step 1: Install Firebase CLI
npm install -g firebase-tools

# Step 2: Login to Firebase
firebase login

# Step 3: Initialize Firebase
firebase init

# Step 4: Build and deploy
npm run build
firebase deploy
```

### Google Cloud Run / App Engine

Alternatively, deploy to Google Cloud Run or App Engine for serverless scalability.

Set environment variables from your Firebase/Supabase project:
- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`
- `VITE_FIREBASE_PROJECT_ID`
- `VITE_FIREBASE_API_KEY`
