const express = require('express');
const axios = require('axios');
const path = require('path');

const app = express();
const PORT = Number(process.env.PORT || 3000);
const API_URL = process.env.API_URL || 'http://localhost:8000';

app.use(express.json());
app.use(express.static(path.join(__dirname, 'views')));

app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'views', 'index.html'));
});

app.get('/health', async (req, res) => {
  try {
    await axios.get(`${API_URL}/health`, { timeout: 2000 });
    res.json({ status: 'ok' });
  } catch (err) {
    res.status(503).json({ status: 'unhealthy', error: 'api unavailable' });
  }
});

app.post('/submit', async (req, res) => {
  try {
    const response = await axios.post(`${API_URL}/jobs`);
    res.status(201).json(response.data);
  } catch (err) {
    res.status(502).json({
      error: 'failed to submit job',
      detail: err.message,
    });
  }
});

app.get('/status/:id', async (req, res) => {
  try {
    const response = await axios.get(`${API_URL}/jobs/${req.params.id}`);
    res.json(response.data);
  } catch (err) {
    const statusCode = err.response?.status || 502;
    res.status(statusCode).json({
      error: 'failed to fetch job status',
      detail: err.response?.data || err.message,
    });
  }
});

app.listen(PORT, () => {
  console.log(`Frontend running on port ${PORT}`);
});
