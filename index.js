const express = require('express');
const app = express();

// Enable JSON body parsing
app.use(express.json());

// Store valid keys
const validKeys = new Map();

// Root endpoint
app.get('/', (req, res) => {
    res.send('SMAX Key System Server Running');
});

// Generate test key
app.get('/generate-test', (req, res) => {
    const key = generateKey();
    validKeys.set(key, {
        date: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days from now
        type: "test"
    });
    console.log('Generated test key:', key);
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

// Verify key endpoint
app.post('/verify', (req, res) => {
    const { key } = req.body;
    console.log('Received verification request for key:', key);
    console.log('Valid keys:', Array.from(validKeys.keys()));
    console.log('Is key valid?', validKeys.has(key));
    
    res.setHeader('Content-Type', 'text/plain');
    
    if (validKeys.has(key)) {
        console.log('Key verified successfully');
        res.send('valid');
    } else {
        console.log('Invalid key attempted');
        res.send('invalid');
    }
});

// New purchase endpoint (for Shoppy webhook)
app.post('/new-purchase', (req, res) => {
    const key = generateKey();
    validKeys.set(key, {
        date: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days from now
        email: req.body.email
    });
    console.log('New purchase key generated:', key);
    res.send('OK');
});

// Clear all keys (for testing)
app.get('/clear-keys', (req, res) => {
    validKeys.clear();
    console.log('All keys cleared');
    res.send('All keys cleared');
});

// Key generator function
function generateKey() {
    return Math.random().toString(36).substring(2) + Math.random().toString(36).substring(2);
}

// Error handling middleware
app.use((err, req, res, next) => {
    console.error('Error:', err);
    res.status(500).send('Internal Server Error');
});

// Handle CORS
app.use((req, res, next) => {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');
    next();
});

// Start server
const PORT = process.env.PORT || 3000;
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
