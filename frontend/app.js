const express = require("express");
const axios = require("axios");
const path = require("path");

const app = express();

const PORT = process.env.PORT || 3000;
const API_URL = process.env.API_URL || "http://api:8000";

app.use(express.json());
app.use(express.static(path.join(__dirname, "views")));

app.get("/health", async (req, res) => {
  try {
    await axios.get(`${API_URL}/health`);
    res.status(200).json({ status: "ok" });
  } catch (error) {
    res.status(503).json({ status: "degraded", error: "api unavailable" });
  }
});

app.post("/submit", async (req, res) => {
  try {
    const response = await axios.post(`${API_URL}/jobs`);
    res.status(201).json(response.data);
  } catch (err) {
    res.status(500).json({ error: "something went wrong" });
  }
});

app.get("/status/:id", async (req, res) => {
  const jobId = req.params.id;

  try {
    let response;

    try {
      response = await axios.get(`${API_URL}/jobs/${jobId}`);
    } catch (err) {
      if (err.response && err.response.status === 404) {
        response = await axios.get(`${API_URL}/status/${jobId}`);
      } else {
        throw err;
      }
    }

    res.json(response.data);
  } catch (err) {
    const statusCode = err.response?.status || 500;
    const payload = err.response?.data || { error: "something went wrong" };
    res.status(statusCode).json(payload);
  }
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Frontend running on port ${PORT}`);
});
