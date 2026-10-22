import { writeFile } from "node:fs/promises";

const required = [
  "FIREBASE_API_KEY",
  "FIREBASE_AUTH_DOMAIN",
  "FIREBASE_PROJECT_ID",
  "FIREBASE_MESSAGING_SENDER_ID",
  "FIREBASE_APP_ID",
];
const missing = required.filter((key) => !process.env[key]);

if (missing.length) {
  console.error(`Missing Firebase web configuration: ${missing.join(", ")}`);
  console.error("Set these environment variables in Render using the Firebase Web app config.");
  process.exit(1);
}

const config = {
  apiKey: process.env.FIREBASE_API_KEY,
  authDomain: process.env.FIREBASE_AUTH_DOMAIN,
  projectId: process.env.FIREBASE_PROJECT_ID,
  storageBucket: process.env.FIREBASE_STORAGE_BUCKET || "",
  messagingSenderId: process.env.FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.FIREBASE_APP_ID,
};

await writeFile(
  new URL("../web/firebase-config.js", import.meta.url),
  `export const firebaseConfig = ${JSON.stringify(config)};\n`,
  { mode: 0o644 },
);
console.log("Generated Firebase web configuration.");
