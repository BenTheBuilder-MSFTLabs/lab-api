const express = require('express');
const os = require('os'); // Import the os module
const app = express();
const port = 80;

// Default welcome page
app.get('/', (req, res) => {
    res.send(`
        <h1>Test Web API</h1>
        <p>This server acts as demo API Solution running NodeJS.</p>
        <p>Endpoints:</p>
        <ul>
            <li><a href="/time">/time</a> - Returns the current time in ISO 8601 format.</li>
            <li><a href="/server">/server</a> - Returns server information.</li>
        </ul>
        <p>Server is running on port ${port}.</p>
    `);
});

// Time endpoint
app.get('/time', (req, res) => {
    const currentTime = new Date().toISOString();
    res.json({ time: currentTime });
});

// Server info endpoint
app.get('/server', (req, res) => {
    const serverInfo = {
        hostname: os.hostname(),
        platform: os.platform(),
        architecture: os.arch(),
        uptime: os.uptime(),
        memory: {
            total: os.totalmem(),
            free: os.freemem()
        },
        cpus: os.cpus().length
    };
    res.json(serverInfo);
});

app.listen(port, () => {
    console.log(`Server is running at http://localhost:${port}`);
});