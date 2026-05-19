const https = require('https');

exports.handler = async (event) => {
    const slackWebhookUrl = process.env.SLACK_WEBHOOK_URL;
    
    const finding = event.detail || event;
    const message = {
        text: `*SECURITY ALERT FIRED*\n*Event:* ${finding.eventName || 'Unknown'}\n*Source IP:* ${finding.sourceIPAddress || 'N/A'}\n*User ARN:* ${finding.userIdentity?.arn || 'N/A'}\n*Time:* ${finding.eventTime || new Date().toISOString()}\n*Region:* ${finding.awsRegion || 'us-east-1'}\n*Error:* ${finding.errorCode || 'N/A'}`
    };

    const url = new URL(slackWebhookUrl);
    
    return new Promise((resolve, reject) => {
        const req = https.request({
            hostname: url.hostname,
            path: url.pathname + url.search,
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
        }, (res) => {
            resolve({ statusCode: res.statusCode, body: 'Alert sent' });
        });
        req.on('error', reject);
        req.write(JSON.stringify(message));
        req.end();
    });
};