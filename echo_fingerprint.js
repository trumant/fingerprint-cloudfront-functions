function handler(event) {
    const request = event.request;
    const headers = request.headers;
    const ja3_fingerprint = headers['cloudfront-viewer-ja3-fingerprint'] ? headers['cloudfront-viewer-ja3-fingerprint'].value : 'unknown';
    const ja4_fingerprint = headers['cloudfront-viewer-ja4-fingerprint'] ? headers['cloudfront-viewer-ja4-fingerprint'].value : 'unknown';
    var response = {
        statusCode: 404,
        statusDescription: 'Not Found',
        headers:
            { "x-ja3-fingerprint": { "value": ja3_fingerprint },
              "x-ja4-fingerprint": { "value": ja4_fingerprint }
            },
        }
    return response;
}