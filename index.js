const express = require('express');
const mongoose = require('mongoose');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const app = express();
const nodemailer = require('nodemailer');

// Enable JSON body parsing
app.use(express.json());

// Set trust proxy
app.set('trust proxy', 1);

// Connect to MongoDB with your connection string
mongoose.connect(process.env.MONGODB_URI, {
    useNewUrlParser: true,
    useUnifiedTopology: true,
    serverSelectionTimeoutMS: 5000,
    retryWrites: true
}).then(() => {
    console.log('Connected to MongoDB');
}).catch(err => {
    console.error('MongoDB connection error:', err);
});

// Admin schema
const adminSchema = new mongoose.Schema({
    username: { type: String, required: true, unique: true },
    password: { type: String, required: true }
});

const Admin = mongoose.model('Admin', adminSchema);

// Key schema (updated with HWID tracking)
const keySchema = new mongoose.Schema({
    key: { type: String, required: true, unique: true },
    hwid: String,
    lastHwidReset: Date,
    hwidResetCount: { type: Number, default: 0 },
    createdAt: { type: Date, default: Date.now },
    expiresAt: Date,
    type: String,
    email: { type: String, required: true },
    uses: { type: Number, default: 0 },
    active: { type: Boolean, default: true },
    purchaseId: String
});

const Key = mongoose.model('Key', keySchema);

// Add this after your other schemas
const preGeneratedKeySchema = new mongoose.Schema({
    key: { type: String, required: true, unique: true },
    isAssigned: { type: Boolean, default: false },
    assignedTo: String,
    assignedAt: Date,
    purchaseId: String
});

const PreGeneratedKey = mongoose.model('PreGeneratedKey', preGeneratedKeySchema);

// Store valid keys
const validKeys = new Map();

// Get script from environment variable
const mainScript = process.env.MAIN_SCRIPT;

// Middleware to verify admin token
const verifyAdmin = async (req, res, next) => {
    const token = req.headers['x-admin-token'];
    if (!token) return res.status(401).send('Access denied');

    try {
        const verified = jwt.verify(token, process.env.JWT_SECRET);
        req.admin = verified;
        next();
    } catch (err) {
        res.status(400).send('Invalid token');
    }
};

// Admin panel route
app.get('/admin', (req, res) => {
    res.send(`
        <!DOCTYPE html>
        <html>
        <head>
            <title>SMAX Admin Panel</title>
            <style>
                body { font-family: Arial; max-width: 1200px; margin: 0 auto; padding: 20px; }
                .container { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
                .section { margin: 20px 0; padding: 20px; border: 1px solid #eee; border-radius: 4px; }
                input, select, button { margin: 5px; padding: 8px; }
                button { background: #007bff; color: white; border: none; border-radius: 4px; cursor: pointer; }
                button:hover { background: #0056b3; }
                .generate-btn { background: #28a745; }
                .generate-btn:hover { background: #218838; }
                table { width: 100%; border-collapse: collapse; margin-top: 20px; }
                th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }
                .action-btn { margin: 2px; padding: 4px 8px; font-size: 12px; }
                .revoke-btn { background: #dc3545; }
                .reset-btn { background: #17a2b8; }
            </style>
            <script>
                async function login() {
                    const username = document.getElementById('username').value;
                    const password = document.getElementById('password').value;
                    
                    const response = await fetch('/admin/login', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ username, password })
                    });
                    
                    if (response.ok) {
                        const data = await response.json();
                        localStorage.setItem('adminToken', data.token);
                        location.reload();
                    } else {
                        alert('Login failed');
                    }
                }

                async function generateSingleKey() {
                    const token = localStorage.getItem('adminToken');
                    if (!token) return alert('Please login first');

                    const email = document.getElementById('keyEmail').value;
                    const type = document.getElementById('keyType').value;
                    const duration = type === 'duration' ? document.getElementById('keyDuration').value : null;

                    const response = await fetch('/admin/generate-key', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                            'x-admin-token': token
                        },
                        body: JSON.stringify({ email, type, duration })
                    });

                    if (response.ok) {
                        const data = await response.json();
                        alert('Generated key: ' + data.key);
                        loadKeys();
                    } else {
                        alert('Failed to generate key');
                    }
                }

                async function generateBulkKeys() {
                    const token = localStorage.getItem('adminToken');
                    if (!token) return alert('Please login first');

                    const response = await fetch('/admin/generate-keys', {
                        method: 'GET',
                        headers: {
                            'x-admin-token': token
                        }
                    });

                    if (response.ok) {
                        alert('Generated 500 new keys successfully!');
                        loadKeys();
                    } else {
                        alert('Failed to generate keys');
                    }
                }

                function showDurationField() {
                    const type = document.getElementById('keyType').value;
                    document.getElementById('durationField').style.display = type === 'duration' ? 'inline' : 'none';
                }

                async function loadKeys() {
                    const token = localStorage.getItem('adminToken');
                    if (!token) return;

                    const response = await fetch('/admin/keys', {
                        headers: {
                            'x-admin-token': token
                        }
                    });

                    if (response.ok) {
                        const keys = await response.json();
                        const tbody = document.getElementById('keysTable').getElementsByTagName('tbody')[0];
                        tbody.innerHTML = '';

                        keys.forEach(key => {
                            const row = tbody.insertRow();
                            row.innerHTML = \`
                                <td>\${key.key}</td>
                                <td>\${key.type}</td>
                                <td>\${key.email || '-'}</td>
                                <td>\${new Date(key.createdAt).toLocaleDateString()}</td>
                                <td>\${key.expiresAt ? new Date(key.expiresAt).toLocaleDateString() : 'Never'}</td>
                                <td>\${key.hwid || 'Not Set'}</td>
                                <td>\${key.lastHwidReset ? new Date(key.lastHwidReset).toLocaleDateString() : 'Never'}</td>
                                <td>\${key.hwidResetCount}</td>
                                <td>\${key.uses}</td>
                                <td>\${key.active ? 'Active' : 'Revoked'}</td>
                                <td>
                                    <button class="action-btn revoke-btn" onclick="revokeKey('\${key.key}')">Revoke</button>
                                    <button class="action-btn reset-btn" onclick="resetHWID('\${key.key}')">Reset HWID</button>
                                </td>
                            \`;
                        });
                    }
                }

                async function revokeKey(key) {
                    const token = localStorage.getItem('adminToken');
                    if (!token) return;

                    const response = await fetch(\`/admin/revoke-key/\${key}\`, {
                        method: 'POST',
                        headers: {
                            'x-admin-token': token
                        }
                    });

                    if (response.ok) {
                        loadKeys();
                    } else {
                        alert('Failed to revoke key');
                    }
                }

                async function resetHWID(key) {
                    const token = localStorage.getItem('adminToken');
                    if (!token) return;

                    const response = await fetch('/reset-hwid', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                            'x-admin-token': token
                        },
                        body: JSON.stringify({ key })
                    });

                    if (response.ok) {
                        loadKeys();
                    } else {
                        alert('Failed to reset HWID');
                    }
                }

                window.onload = function() {
                    const token = localStorage.getItem('adminToken');
                    if (token) {
                        document.getElementById('loginForm').style.display = 'none';
                        document.getElementById('adminPanel').style.display = 'block';
                        loadKeys();
                    }
                }
            </script>
        </head>
        <body>
            <div class="container">
                <div id="loginForm">
                    <h2>Admin Login</h2>
                    <input type="text" id="username" placeholder="Username">
                    <input type="password" id="password" placeholder="Password">
                    <button onclick="login()">Login</button>
                </div>
                
                <div id="adminPanel" style="display: none;">
                    <h2>Admin Panel</h2>
                    
                    <div class="section">
                        <h3>Generate Single Key</h3>
                        <input type="email" id="keyEmail" placeholder="Email (optional)">
                        <select id="keyType" onchange="showDurationField()">
                            <option value="lifetime">Lifetime</option>
                            <option value="duration">Duration</option>
                        </select>
                        <input type="number" id="durationField" placeholder="Duration (days)" style="display: none;">
                        <button onclick="generateSingleKey()" class="generate-btn">Generate Key</button>
                    </div>

                    <div class="section">
                        <h3>Generate Bulk Keys</h3>
                        <button onclick="generateBulkKeys()" class="generate-btn">Generate 500 Lifetime Keys</button>
                    </div>
                    
                    <div class="section">
                        <h3>Key Management</h3>
                        <table id="keysTable">
                            <thead>
                                <tr>
                                    <th>Key</th>
                                    <th>Type</th>
                                    <th>Email</th>
                                    <th>Created</th>
                                    <th>Expires</th>
                                    <th>HWID</th>
                                    <th>Last Reset</th>
                                    <th>Reset Count</th>
                                    <th>Uses</th>
                                    <th>Status</th>
                                    <th>Actions</th>
                                </tr>
                            </thead>
                            <tbody></tbody>
                        </table>
                    </div>
                </div>
            </div>
        </body>
        </html>
    `);
});

// Admin login
app.post('/admin/login', async (req, res) => {
    const { username, password } = req.body;
    
    const admin = await Admin.findOne({ username });
    if (!admin) return res.status(400).send('Invalid credentials');

    const validPassword = await bcrypt.compare(password, admin.password);
    if (!validPassword) return res.status(400).send('Invalid credentials');

    const token = jwt.sign({ id: admin._id }, process.env.JWT_SECRET);
    res.json({ token });
});

// Admin endpoints (protected)
app.post('/admin/generate-key', verifyAdmin, async (req, res) => {
    const { type, email, duration } = req.body;
    const key = Math.random().toString(36).substring(2) + 
               Math.random().toString(36).substring(2) + 
               Math.random().toString(36).substring(2);
    
    try {
        await Key.create({
            key,
            type: type || 'lifetime',
            email: email || 'admin-generated',
            expiresAt: type === 'duration' ? new Date(Date.now() + duration * 24 * 60 * 60 * 1000) : null,
            uses: 0,
            active: true,
            createdAt: new Date(),
            hwid: null,
            hwidResetCount: 0,
            lastHwidReset: null
        });
        res.json({ key });
    } catch (err) {
        res.status(500).send('Error generating key');
    }
});

app.get('/admin/keys', verifyAdmin, async (req, res) => {
    try {
        const keys = await Key.find().sort('-createdAt');
        res.json(keys);
    } catch (err) {
        res.status(500).send('Error fetching keys');
    }
});

app.post('/admin/revoke-key/:key', verifyAdmin, async (req, res) => {
    try {
        await Key.updateOne({ key: req.params.key }, { active: false });
        res.send('Key revoked');
    } catch (err) {
        res.status(500).send('Error revoking key');
    }
});

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

// Function to generate email content
function generateEmailContent(key) {
    return `Thank you for purchasing SMAX! Your unique key is: ${key}

Instructions:
1. Launch Roblox
2. Execute the script
3. Enter your key when prompted
4. Enjoy!

Important:
- This key is unique to you
- Do not share your key
- Join our Discord for support: https://discord.gg/ebwwsfzKyh`;
}

// Add endpoint to generate 500 keys
app.get('/admin/generate-keys', verifyAdmin, async (req, res) => {
    try {
        const keys = [];
        for (let i = 0; i < 500; i++) {
            const key = Math.random().toString(36).substring(2) + 
                       Math.random().toString(36).substring(2) + 
                       Math.random().toString(36).substring(2);
            keys.push({ key });
        }
        
        await PreGeneratedKey.insertMany(keys);
        res.send('Generated 500 new keys');
    } catch (err) {
        console.error('Error generating keys:', err);
        res.status(500).send('Error generating keys');
    }
});

// Add nodemailer setup
const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
        user: process.env.EMAIL_USER, // Your Gmail
        pass: process.env.EMAIL_PASS  // Your app-specific password
    }
});

// Test the email configuration on startup
transporter.verify(function(error, success) {
    if (error) {
        console.error('Email configuration error:', error);
    } else {
        console.log('Email server is ready to send messages');
    }
});

// Modified purchase webhook with Shoppy data structure
app.post('/new-purchase', async (req, res) => {
    try {
        console.log('=== NEW PURCHASE WEBHOOK START ===');
        console.log('Request body:', req.body);
        console.log('Environment variables check:');
        console.log('EMAIL_USER set:', !!process.env.EMAIL_USER);
        console.log('EMAIL_PASS set:', !!process.env.EMAIL_PASS);
        
        // Extract email from Shoppy's nested structure
        const email = req.body?.data?.order?.email;
        const orderId = req.body?.data?.order?.id;

        if (!email) {
            console.error('❌ Invalid webhook data - missing email');
            return res.status(400).send('Invalid data');
        }

        console.log('✓ Valid webhook data received');
        console.log('Buyer email:', email);

        // Find an unassigned key
        const preGenKey = await PreGeneratedKey.findOne({ isAssigned: false });
        if (!preGenKey) {
            console.error('❌ No available keys in database');
            return res.status(500).send('No available keys');
        }

        console.log('✓ Found unassigned key:', preGenKey.key);

        try {
            // Create entry in main keys collection
            await Key.create({
                key: preGenKey.key,
                expiresAt: null,
                type: 'lifetime',
                email: email,
                uses: 0,
                active: true,
                createdAt: new Date(),
                hwid: null,
                hwidResetCount: 0,
                lastHwidReset: null
            });
            console.log('✓ Key saved to database');
        } catch (dbErr) {
            console.error('❌ Database error:', dbErr);
            throw dbErr;
        }

        try {
            // Mark the pre-generated key as assigned
            preGenKey.isAssigned = true;
            preGenKey.assignedTo = email;
            preGenKey.assignedAt = new Date();
            preGenKey.purchaseId = orderId;
            await preGenKey.save();
            console.log('✓ Pre-generated key marked as assigned');
        } catch (assignErr) {
            console.error('❌ Error marking key as assigned:', assignErr);
            throw assignErr;
        }

        console.log('📧 Attempting to send email...');
        console.log('Email configuration:', {
            from: process.env.EMAIL_USER,
            to: email
        });

        try {
            const mailOptions = {
                from: process.env.EMAIL_USER,
                to: email,
                subject: 'Your SMAX Purchase',
                text: `Thank you for purchasing SMAX! Your unique key is: ${preGenKey.key}

Instructions:
1. Launch Roblox
2. Execute the script
3. Enter your key when prompted
4. Enjoy!

Important:
- This key is unique to you
- Do not share your key
- Join our Discord for support: https://discord.gg/ebwwsfzKyh`
            };

            const info = await transporter.sendMail(mailOptions);
            console.log('✓ Email sent successfully');
            console.log('Email response:', info);
        } catch (emailErr) {
            console.error('❌ Email sending failed');
            console.error('Error details:', emailErr);
            console.error('Full error:', JSON.stringify(emailErr, null, 2));
        }

        res.status(200).send('OK');
        console.log('✓ Purchase webhook completed successfully');
        console.log('=== NEW PURCHASE WEBHOOK END ===');

    } catch (err) {
        console.error('❌ FATAL ERROR in purchase webhook');
        console.error('Error stack:', err.stack);
        res.status(500).send('Error');
    }
});

// Update verify endpoint
app.post('/verify', async (req, res) => {
    const { key, hwid } = req.body;
    
    try {
        console.log('Verify request:', { key, hwid }); // Debug log
        
        const keyData = await Key.findOne({ key });
        if (!keyData || !keyData.active) {
            console.log('Invalid or inactive key:', key);
            return res.send('invalid_key');
        }
        
        // Check expiration only if expiresAt is not null
        if (keyData.expiresAt && keyData.expiresAt < new Date()) {
            console.log('Key expired:', key);
            return res.send('expired_key');
        }
        
        // Clean and standardize HWID format
        const cleanHWID = hwid.trim().toUpperCase();
        const storedHWID = keyData.hwid ? keyData.hwid.trim().toUpperCase() : null;
        
        // If no HWID is set, assign it
        if (!storedHWID) {
            keyData.hwid = cleanHWID;
            keyData.uses += 1;
            await keyData.save();
            console.log('New HWID set:', { key, hwid: cleanHWID });
            return res.send('valid');
        }
        
        // If HWID is set, verify it matches
        if (storedHWID !== cleanHWID) {
            console.log('HWID mismatch:', {
                stored: storedHWID,
                received: cleanHWID
            });
            return res.send('invalid_hwid');
        }
        
        keyData.uses += 1;
        await keyData.save();
        console.log('Valid key used:', { key, hwid: cleanHWID });
        res.send('valid');
    } catch (err) {
        console.error('Verify error:', err);
        res.status(500).send('Error');
    }
});

app.get('/setup-admin', async (req, res) => {
    try {
        const hashedPassword = await bcrypt.hash('admin1312', 10);
        await Admin.create({
            username: 'admin1312',
            password: hashedPassword
        });
        res.send('Admin created successfully');
    } catch (err) {
        res.status(500).send('Error creating admin: ' + err.message);
    }
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

// Add near other routes
app.get('/health', (req, res) => {
    res.status(200).send('OK');
});

// Fix HWID reset endpoint
app.post('/reset-hwid', async (req, res) => {
    const { key } = req.body;
    
    try {
        const keyData = await Key.findOne({ key });
        if (!keyData || !keyData.active) return res.send('invalid_key');

        // Check if HWID is already reset
        if (!keyData.hwid) return res.send('no_hwid_set');

        // Check if 24 hours have passed since last reset
        if (keyData.lastHwidReset) {
            const hoursSinceReset = (Date.now() - keyData.lastHwidReset) / (1000 * 60 * 60);
            if (hoursSinceReset < 24) {
                return res.send(`wait_${Math.ceil(24 - hoursSinceReset)}`);
            }
        }

        // Reset HWID
        keyData.hwid = null;
        keyData.lastHwidReset = new Date();
        keyData.hwidResetCount += 1;
        await keyData.save();
        
        res.send('success');
    } catch (err) {
        console.error('HWID reset error:', err);
        res.status(500).send('Error');
    }
});

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
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
