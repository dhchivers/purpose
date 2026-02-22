# Firebase Configuration Setup

## Storing API Keys in Firestore

To securely store your OpenAI API key in Firestore:

### 1. Create the Config Collection

In the Firebase Console:

1. Go to **Firestore Database** → https://console.firebase.google.com/project/altruency-purpose/firestore
2. Click **Start collection**
3. Collection ID: `config`
4. Click **Next**
5. Document ID: `api_keys`
6. Add field:
   - Field: `openai_key`
   - Type: `string`
   - Value: `your-openai-api-key-here`
7. Click **Save**

### 2. Update Your API Key

Replace `your-openai-api-key-here` with your actual OpenAI API key from https://platform.openai.com/api-keys

### 3. Security Rules (Future)

When you tighten security rules, add this to `firestore.rules`:

```javascript
// Config collection - admins can write, authenticated users can read
match /config/{document} {
  allow read: if request.auth != null;
  allow write: if request.auth != null && 
    get(/databases/$(database)/documents/users/$(request.auth.uid)).data.userType == 'admin';
}
```

### 4. How It Works

The app now:
1. **First**, tries to fetch the API key from Firestore `config/api_keys/openai_key`
2. **Falls back** to the hardcoded value in `ai_config.dart` if Firestore fetch fails
3. **Caches** the key in memory to avoid repeated Firestore calls

### 5. Deployed vs Local Development

**For deployed app (production)**:
- Uses the key from Firestore collection
- No code changes needed to update the key
- Just update the value in Firebase Console

**For local development**:
- Update the `defaultValue` in `lib/core/config/ai_config.dart` with your key
- Or set up the Firestore collection locally

### 6. Using the Firebase Emulator (Optional)

For local development with emulator:

```bash
firebase emulators:start
```

Then seed the config collection:
```bash
firebase emulators:exec --only firestore "./seed-config.sh"
```

## Benefits of This Approach

✅ **Secure**: Keys not in source code  
✅ **Flexible**: Update keys without redeploying  
✅ **Cached**: Fast access after first fetch  
✅ **Fallback**: Still works if Firestore is unavailable
