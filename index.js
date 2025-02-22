const express = require('express');
const app = express();
app.use(express.json());

// Store valid keys
const validKeys = new Map();

// Add a root route
app.get('/', (req, res) => {
    res.send('Key System Server Running');
});

// Generate test key route
app.get('/generate-test', (req, res) => {
    const key = generateKey();
    validKeys.set(key, {
        date: new Date(),
        type: 'test'
    });
    console.log('Generated new test key:', key);
    res.send(key);
});

// View all keys
app.get('/keys', (req, res) => {
    const keys = Array.from(validKeys.entries()).map(([key, data]) => ({
        key,
        ...data
    }));
    console.log('Current keys:', keys);
    res.json(keys);
});

// Endpoint for Shoppy webhook
app.post('/new-purchase', (req, res) => {
    const key = generateKey();
    validKeys.set(key, {
        date: new Date(),
        email: req.body.email
    });
    console.log('New purchase key generated:', key);
    res.send('OK');
});

// Endpoint for script verification
app.post('/verify', (req, res) => {
    const { key } = req.body;
    console.log('Received verification request for key:', key);
    console.log('Valid keys:', Array.from(validKeys.keys()));
    console.log('Is key valid?', validKeys.has(key));

    if (validKeys.has(key)) {
        console.log('Key verified successfully');
        res.send('valid');
    } else {
        console.log('Invalid key attempted');
        res.send('invalid');
    }
});

// Clear all keys (for testing)
app.get('/clear-keys', (req, res) => {
    validKeys.clear();
    console.log('All keys cleared');
    res.send('All keys cleared');
});

function generateKey() {
    return Math.random().toString(36).substring(2);
}

const PORT = 3000;
app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
    console.log('Available endpoints:');
    console.log('- GET  /              (Check server status)');
    console.log('- GET  /generate-test (Generate test key)');
    console.log('- GET  /keys          (View all keys)');
    console.log('- POST /verify        (Verify a key)');
    console.log('- POST /new-purchase  (Generate key for purchase)');
    console.log('- GET  /clear-keys    (Clear all keys)');
});
