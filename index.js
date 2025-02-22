const express = require('express');
const mongoose = require('mongoose');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
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

// Admin schema
const adminSchema = new mongoose.Schema({
    username: { type: String, required: true, unique: true },
    password: { type: String, required: true }
});

const Admin = mongoose.model('Admin', adminSchema);

// Key schema (expanded)
const keySchema = new mongoose.Schema({
    key: { type: String, required: true, unique: true },
    hwid: String,
    createdAt: { type: Date, default: Date.now },
    expiresAt: Date,
    type: String,
    email: String,
    uses: { type: Number, default: 0 },
    active: { type: Boolean, default: true }
});

const Key = mongoose.model('Key', keySchema);

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
                body { font-family: Arial; max-width: 800px; margin: 0 auto; padding: 20px; background: #f5f5f5; }
                .container { margin-top: 20px; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
                table { width: 100%; border-collapse: collapse; margin-top: 20px; }
                th, td { padding: 12px; text-align: left; border: 1px solid #ddd; }
                th { background: #f8f9fa; }
                button { padding: 8px 16px; background: #007bff; color: white; border: none; border-radius: 4px; cursor: pointer; }
                button:hover { background: #0056b3; }
                button:disabled { background: #ccc; }
                input, select { padding: 8px; margin: 5px; border: 1px solid #ddd; border-radius: 4px; }
                .login-container { max-width: 400px; margin: 100px auto; }
                .error { color: red; margin-top: 10px; }
            </style>
        </head>
        <body>
            <div id="loginForm" class="login-container container">
                <h2>Admin Login</h2>
                <div>
                    <input type="text" id="username" placeholder="Username">
                </div>
                <div>
                    <input type="password" id="password" placeholder="Password">
                </div>
                <div>
                    <button onclick="login()">Login</button>
                </div>
                <div id="loginError" class="error"></div>
            </div>

            <div id="adminPanel" style="display: none;">
                <div class="container">
                    <h2>Generate Key</h2>
                    <div>
                        <input type="text" id="email" placeholder="Email">
                        <select id="type">
                            <option value="lifetime">Lifetime</option>
                            <option value="monthly">Monthly</option>
                            <option value="weekly">Weekly</option>
                        </select>
                        <input type="number" id="duration" placeholder="Duration (days)">
                        <button onclick="generateKey()">Generate Key</button>
                    </div>
                </div>

                <div class="container">
                    <h2>Key Management</h2>
                    <table id="keysTable">
                        <thead>
                            <tr>
                                <th>Key</th>
                                <th>Type</th>
                                <th>Email</th>
                                <th>Created</th>
                                <th>Expires</th>
                                <th>Uses</th>
                                <th>Status</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody></tbody>
                    </table>
                </div>
            </div>

            <script>
                let token = localStorage.getItem('adminToken');
                
                async function login() {
                    const username = document.getElementById('username').value;
                    const password = document.getElementById('password').value;
                    const errorDiv = document.getElementById('loginError');
                    
                    try {
                        const response = await fetch('/admin/login', {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({ username, password })
                        });
                        
                        if (response.ok) {
                            const data = await response.json();
                            token = data.token;
                            localStorage.setItem('adminToken', token);
                            showAdminPanel();
                            loadKeys();
                            errorDiv.textContent = '';
                        } else {
                            errorDiv.textContent = 'Invalid credentials';
                        }
                    } catch (err) {
                        errorDiv.textContent = 'Login failed';
                    }
                }

                async function generateKey() {
                    const email = document.getElementById('email').value;
                    const type = document.getElementById('type').value;
                    const duration = document.getElementById('duration').value;
                    
                    try {
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
                        }
                    } catch (err) {
                        alert('Error generating key');
                    }
                }

                async function loadKeys() {
                    try {
                        const response = await fetch('/admin/keys', {
                            headers: { 'x-admin-token': token }
                        });
                        
                        if (response.ok) {
                            const keys = await response.json();
                            const tbody = document.querySelector('#keysTable tbody');
                            tbody.innerHTML = '';
                            
                            keys.forEach(key => {
                                const tr = document.createElement('tr');
                                tr.innerHTML = \`
                                    <td>\${key.key}</td>
                                    <td>\${key.type}</td>
                                    <td>\${key.email || '-'}</td>
                                    <td>\${new Date(key.createdAt).toLocaleDateString()}</td>
                                    <td>\${key.expiresAt ? new Date(key.expiresAt).toLocaleDateString() : 'Never'}</td>
                                    <td>\${key.uses}</td>
                                    <td>\${key.active ? 'Active' : 'Revoked'}</td>
                                    <td>
                                        <button onclick="revokeKey('\${key.key}')" \${!key.active ? 'disabled' : ''}>
                                            \${key.active ? 'Revoke' : 'Revoked'}
                                        </button>
                                    </td>
                                \`;
                                tbody.appendChild(tr);
                            });
                        }
                    } catch (err) {
                        console.error('Error loading keys:', err);
                    }
                }

                async function revokeKey(key) {
                    try {
                        const response = await fetch(\`/admin/revoke-key/\${key}\`, {
                            method: 'POST',
                            headers: { 'x-admin-token': token }
                        });
                        
                        if (response.ok) {
                            loadKeys();
                        }
                    } catch (err) {
                        alert('Error revoking key');
                    }
                }

                function showAdminPanel() {
                    document.getElementById('loginForm').style.display = 'none';
                    document.getElementById('adminPanel').style.display = 'block';
                }

                if (token) {
                    showAdminPanel();
                    loadKeys();
                }
            </script>
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
    const key = Math.random().toString(36).substring(2);
    
    try {
        await Key.create({
            key,
            type,
            email,
            expiresAt: duration ? new Date(Date.now() + duration * 24 * 60 * 60 * 1000) : null
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

// Verify key endpoint (updated with more security)
app.post('/verify', async (req, res) => {
    const { key, hwid } = req.body;
    
    try {
        const keyData = await Key.findOne({ key });
        if (!keyData || !keyData.active) return res.send('invalid_key');
        
        if (keyData.expiresAt && keyData.expiresAt < new Date()) {
            return res.send('expired_key');
        }
        
        if (keyData.hwid && keyData.hwid !== hwid) {
            return res.send('invalid_hwid');
        }
        
        if (!keyData.hwid) {
            keyData.hwid = hwid;
            keyData.uses += 1;
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
