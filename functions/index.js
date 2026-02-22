const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Cloud Function to proxy OpenAI API requests
 * This solves CORS issues when calling OpenAI from web clients
 */
exports.openaiProxy = functions.https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated to use AI features",
    );
  }

  try {
    // Get API key from Firestore
    const configDoc = await admin
        .firestore()
        .collection("config")
        .doc("api_keys")
        .get();

    if (!configDoc.exists) {
      throw new functions.https.HttpsError(
          "failed-precondition",
          "OpenAI API key not configured in Firestore",
      );
    }

    const openaiKey = configDoc.data().openai_key;
    if (!openaiKey) {
      throw new functions.https.HttpsError(
          "failed-precondition",
          "OpenAI API key not found in configuration",
      );
    }

    // Make request to OpenAI API
    const fetch = (await import("node-fetch")).default;
    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${openaiKey}`,
      },
      body: JSON.stringify(data.requestBody),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error("OpenAI API error:", response.status, errorText);
      throw new functions.https.HttpsError(
          "internal",
          `OpenAI API request failed: ${response.status}`,
      );
    }

    const responseData = await response.json();
    
    // Convert to plain JSON to avoid Int64 serialization issues on web
    return JSON.parse(JSON.stringify(responseData));
  } catch (error) {
    console.error("Error in openaiProxy:", error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError(
        "internal",
        "Failed to process OpenAI request",
        error.message,
    );
  }
});
