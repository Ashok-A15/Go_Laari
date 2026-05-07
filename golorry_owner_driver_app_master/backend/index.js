const functions = require("firebase-functions");
const admin = require("firebase-admin");
const express = require("express");
const cors = require("cors");

admin.initializeApp();
const db = admin.firestore();
const auth = admin.auth();

const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

// --- Middleware: Verify Auth & Roles ---
const authenticate = async (req, res, next) => {
  const token = req.headers.authorization?.split("Bearer ")[1];
  if (!token) return res.status(401).json({ error: "Unauthorized" });

  try {
    const decodedToken = await auth.verifyIdToken(token);
    req.user = decodedToken;
    next();
  } catch (error) {
    res.status(401).json({ error: "Invalid token" });
  }
};

const isOwner = (req, res, next) => {
  if (req.user.role !== "owner") {
    return res.status(403).json({ error: "Forbidden: Owner access only" });
  }
  next();
};

// --- API Endpoints ---

/**
 * @endpoint POST /owner/create-driver
 * @description Creates a new driver account linked to the owner
 */
app.post("/owner/create-driver", authenticate, isOwner, async (req, res) => {
  const { name, email, password, phone, vehicleNumber } = req.body;
  const ownerId = req.user.uid;

  if (!name || !email || !password || !phone || !vehicleNumber) {
    return res.status(400).json({ error: "Missing required fields" });
  }

  try {
    // 1. Create User in Firebase Auth
    const userRecord = await auth.createUser({
      email,
      password,
      displayName: name,
      phoneNumber: phone.startsWith("+") ? phone : `+91${phone}`, // Defaulting to IN format
    });

    // 2. Set Custom Claims (Roles)
    await auth.setCustomUserClaims(userRecord.uid, { role: "driver", ownerId });

    // 3. Store Profile in Firestore
    const driverData = {
      uid: userRecord.uid,
      ownerId: ownerId,
      name,
      email,
      phone,
      vehicleNumber,
      status: "active",
      role: "driver",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection("drivers").doc(userRecord.uid).set(driverData);

    res.status(201).json({
      message: "Driver account created successfully",
      driver: { uid: userRecord.uid, email, name },
    });
  } catch (error) {
    console.error("Error creating driver:", error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * @endpoint GET /owner/drivers
 * @description Fetches all drivers for the logged-in owner
 */
app.get("/owner/drivers", authenticate, isOwner, async (req, res) => {
  const ownerId = req.user.uid;

  try {
    const snapshot = await db.collection("drivers")
      .where("ownerId", "==", ownerId)
      .get();

    const drivers = snapshot.docs.map(doc => doc.data());
    res.status(200).json({ drivers });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * @endpoint PATCH /owner/drivers/:driverId/status
 * @description Deactivates or Activates a driver
 */
app.patch("/owner/drivers/:driverId/status", authenticate, isOwner, async (req, res) => {
  const { driverId } = req.params;
  const { status } = req.body; // 'active' or 'inactive'
  const ownerId = req.user.uid;

  if (!["active", "inactive"].includes(status)) {
    return res.status(400).json({ error: "Invalid status value" });
  }

  try {
    const driverRef = db.collection("drivers").doc(driverId);
    const doc = await driverRef.get();

    if (!doc.exists) return res.status(404).json({ error: "Driver not found" });
    if (doc.data().ownerId !== ownerId) return res.status(403).json({ error: "Unauthorized access to this driver" });

    await driverRef.update({ status });

    res.status(200).json({ message: `Driver marked as ${status}` });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * @endpoint GET /driver/profile
 * @description Allows drivers to see their own profile and owner info
 */
app.get("/driver/profile", authenticate, async (req, res) => {
  if (req.user.role !== "driver") return res.status(403).json({ error: "Access denied" });

  try {
    const doc = await db.collection("drivers").doc(req.user.uid).get();
    if (!doc.exists) return res.status(404).json({ error: "Driver profile not found" });

    res.status(200).json(doc.data());
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

exports.api = functions.https.onRequest(app);
