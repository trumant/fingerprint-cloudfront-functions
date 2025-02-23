import cf from 'cloudfront';

const response401 = {
    statusCode: 401,
    statusDescription: 'Unauthorized'
};

async function handler(event) {
    const request = event.request;
    const headers = request.headers;
    const ja3_fingerprint = headers['cloudfront-viewer-ja3-fingerprint'] ? headers['cloudfront-viewer-ja3-fingerprint'].value : 'unknown';
    let allow = await fingerprintInAllowlist(ja3_fingerprint);

    if (allow) {
        // TODO: this is just to demonstrate the functionality
        // normally we would simply return the request so the origin processes it
        let response = {
            statusCode: 200,
            statusDescription: 'OK',
            headers: { "x-ja3-fingerprint": { "value": ja3_fingerprint } },
        }
        return response;
    } else {
        return response401;
    }
}
 
async function fingerprintInAllowlist(fingerprint) {
    try {
        // initialize cloudfront kv store and get the key value 
        const kvsHandle = cf.kvs();
        let allow = await kvsHandle.get(fingerprint, { format: 'json'});
        console.log(`Found fingerprint: ${fingerprint} in allowlist with value of:${allow}`);
        return allow;
    } catch (err) {
        console.log(`Error reading value for key: ${fingerprint}, error: ${err}`);
        return false;
    }
}
