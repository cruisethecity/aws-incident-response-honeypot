/**
 * PCI DSS Full Environment Simulator Final
 * Generates normal application traffic mixed with malicious external scans.
 * Updated: Chaotic Jitter Implementation for Realistic SOC Analysis
 */

const net = require('net');
const { Client } = require('pg');

const DB_PASSWORD = process.env.DB_PASSWORD;
const DB_HOST = process.env.DB_HOST;
const TARGET_PORTS = [22, 80]; 

console.log(`[SYS] Initiating advanced enterprise traffic simulation to ${DB_HOST}`);

// 1. SIMULATE BURSTY MALICIOUS BRUTE FORCE Port 5432
function runBruteForce() {
    // Random jitter between 100ms and 800ms
    const randomDelay = Math.floor(Math.random() * 700) + 100; 
    setTimeout(async () => {
        const fakePassword = `Password${Math.floor(Math.random() * 10000)}`;
        const client = new Client({
            host: DB_HOST,
            port: 5432,
            user: 'db_admin',
            password: fakePassword,
            database: 'incident_db',
            connectionTimeoutMillis: 2000,
            ssl: { rejectUnauthorized: false }
        });

        try {
            await client.connect();
            console.log(`[FATAL] Database breached with password: ${fakePassword}`);
            await client.end();
        } catch (err) {
            console.log(`[ATTACK] Database login failed. Password rejected.`);
        }
        runBruteForce(); // Loop back randomly
    }, randomDelay);
}

// 2. SIMULATE RANDOM NETWORK SCAN Ports 22 and 80
function runPortScans() {
    // Random jitter between 200ms and 1500ms
    const randomDelay = Math.floor(Math.random() * 1300) + 200;
    setTimeout(() => {
        const randomPort = TARGET_PORTS[Math.floor(Math.random() * TARGET_PORTS.length)];
        const socket = new net.Socket();
        
        socket.setTimeout(1000); 
        
        socket.connect(randomPort, DB_HOST, () => {
            console.log(`[ATTACK] Unauthorized network access attempt on port ${randomPort}`);
            socket.destroy(); 
        });

        socket.on('timeout', () => {
            console.log(`[ATTACK] Port ${randomPort} scan blocked by Timeout`);
            socket.destroy();
        });

        socket.on('error', () => {
            console.log(`[ATTACK] Port ${randomPort} scan blocked by Refused`);
        });
        runPortScans(); // Loop back randomly
    }, randomDelay);
}

// 3. SIMULATE CHAOTIC BENIGN CUSTOMER TRAFFIC Port 5432
function runBenignTraffic() {
    // Random jitter between 500ms and 3000ms (more spaced out, human-like)
    const randomDelay = Math.floor(Math.random() * 2500) + 500;
    setTimeout(async () => {
        const client = new Client({
            host: DB_HOST,
            port: 5432,
            user: 'db_admin',
            password: DB_PASSWORD,
            database: 'incident_db',
            connectionTimeoutMillis: 2000,
            ssl: { rejectUnauthorized: false }
        });

        try {
            await client.connect();
            console.log(`[BENIGN] Normal application traffic successfully connected.`);
            await client.end();
        } catch (err) {
            console.log(`[BENIGN ERROR] Connection failed: ${err.message}`);
        }
        runBenignTraffic(); // Loop back randomly
    }, randomDelay);
}

// Start the chaotic simulation
runBruteForce();
runPortScans();
runBenignTraffic();