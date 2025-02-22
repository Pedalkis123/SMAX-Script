const express = require('express');
const mongoose = require('mongoose');
const app = express();

// Enable JSON body parsing
app.use(express.json());

// Connect to MongoDB
mongoose.connect(process.env.MONGODB_URI, {
    useNewUrlParser: true,
    useUnifiedTopology: true
}).then(() => {
    console.log('Connected to MongoDB');
}).catch(err => {
    console.error('MongoDB connection error:', err);
});

// Key schema
const keySchema = new mongoose.Schema({
    key: { type: String, required: true, unique: true },
    hwid: String,
    date: Date,
    type: String,
    email: String
});

const Key = mongoose.model('Key', keySchema);

// Store valid keys
const validKeys = new Map();

// Get script from environment variable
const mainScript = process.env.MAIN_SCRIPT;

// Root endpoint
app.get('/', (req, res) => {
    res.send('SMAX Key System Server Running');
});

// Generate test key
app.get('/generate-test', async (req, res) => {
    const key = Math.random().toString(36).substring(2);
    try {
        await Key.create({
            key,
            date: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days
            type: "test"
        });
        console.log('Generated test key:', key);
        res.send(key);
    } catch (err) {
        console.error(err);
        res.status(500).send('Error generating key');
    }
});

// View all keys
app.get('/keys', async (req, res) => {
    try {
        const keys = await Key.find();
        res.json(keys);
    } catch (err) {
        console.error(err);
        res.status(500).send('Error fetching keys');
    }
});

// Verify key endpoint
app.post('/verify', async (req, res) => {
    const { key, hwid } = req.body;
    try {
        const keyData = await Key.findOne({ key });
        if (!keyData) return res.send('invalid_key');
        
        if (keyData.hwid && keyData.hwid !== hwid) {
            return res.send('invalid_hwid');
        }
        
        if (!keyData.hwid) {
            keyData.hwid = hwid;
            await keyData.save();
        }
        
        res.send('valid');
    } catch (err) {
        console.error(err);
        res.status(500).send('Error');
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

// Get script endpoint (protected)
app.get('/getscript', (req, res) => {
    res.send(mainScript);
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
    console.log('- GET  /getscript     (Get protected script)');
});
