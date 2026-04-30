const express = require("express");
const axios = require("axios");
require("dotenv").config();
const cors = require("cors");

const app = express();
app.use(express.json());
app.use(cors());

// ─────────────────────────────────────────────
// 🔔 Send push with delay (10 seconds)
// ─────────────────────────────────────────────
app.post("/send-notification", async (req, res) => {
  const { userId, title, message, delaySeconds } = req.body;

  if (!userId) {
    return res.status(400).json({ error: "userId required" });
  }

  try {
    const sendAfter = new Date(
      Date.now() + (delaySeconds || 10) * 1000
    ).toISOString();

    const response = await axios.post(
      "https://onesignal.com/api/v1/notifications",
      {
        app_id: process.env.ONESIGNAL_APP_ID,

        include_aliases: {
          external_id: [userId],
        },

        target_channel: "push",

        headings: {
          en: title || "Notification",
        },

        contents: {
          en: message || "Hello from backend 🚀",
        },

        // ⭐ delay
        send_after: sendAfter,
      },
      {
        headers: {
          "Content-Type": "application/json",
          Authorization: `Basic ${process.env.ONESIGNAL_API_KEY}`,
        },
      }
    );

    console.log("✅ OneSignal sent:", response.data);

    res.json({
      success: true,
      send_after: sendAfter,
      data: response.data,
    });
  } catch (error) {
    console.error("❌ Error:", error.response?.data || error.message);

    res.status(500).json({
      error: error.response?.data || error.message,
    });
  }
});

// ─────────────────────────────────────────────
// 🚀 Start server
// ─────────────────────────────────────────────
app.listen(process.env.PORT, () => {
  console.log(`🚀 Server running on port ${process.env.PORT}`);
});