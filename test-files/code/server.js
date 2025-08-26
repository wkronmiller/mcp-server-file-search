// Node.js Express server configuration
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

// Database connection
mongoose.connect('mongodb://localhost:27017/testdb', {
    useNewUrlParser: true,
    useUnifiedTopology: true
});

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.get('/api/users', (req, res) => {
    res.json({ message: 'Users endpoint' });
});

app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});

// Keywords: javascript, nodejs, express, mongodb, REST API, backend