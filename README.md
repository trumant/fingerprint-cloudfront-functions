# Fingerprint Cloudfront Functions

The functions here demonstrate how we can use [JA3 or JA4 TLS client
fingerprinting](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/adding-cloudfront-headers.html#tls-related-versions) to control traffic to our origin.

`echo_fingerprint.js` responds to requests with an HTTP Status 404 and includes
the fingerprints as response headers: `x-ja3-fingerprint` and `x-ja4-fingerprint`.
This function can be useful for simply understanding how AWS fingerprints a particular
client on a particular Cloudfront distribution.

Here is an example response output from invoking the function with `curl -v`

```
< HTTP/2 404 
< server: CloudFront
< date: Sun, 23 Feb 2025 20:44:08 GMT
< content-length: 0
< x-ja3-fingerprint: 375c6162a492dfbf2795909110ce8424
< x-ja4-fingerprint: t13d4907h2_0d8feac7bc37_7395dae3b2f3
< x-cache: FunctionGeneratedResponse from cloudfront
< via: 1.1 c1d7effc96a4e7ef2f2297d393d28d04.cloudfront.net (CloudFront)
< x-amz-cf-pop: PHL50-C1
< alt-svc: h3=":443"; ma=86400
< x-amz-cf-id: -Ouht2jmE0ltRnb-j000q6miPBAyvumRoKiD_Z1uStEP18cdujQ5Cg==
< 
```

`gate_on_fingerprint.js` checks all incoming requests JA3 fingerprint value
against a JSON allowlist stored in Cloudfront Key Value Store.

The data in KV Store might look like the following example in which the first
2 fingerprint values are allowed and the third is disallowed:

```json
{
  "data":[
    {
      "key":"375c6162a492dfbf2795909110ce8424",
      "value": "true"
    },
    {
      "key":"773906b0efdefa24a7f2b8eb6985bf37",
      "value": "true"
    },
    {
      "key":"06c5844b8643740902c45410712542e0",
      "value": "false"
    }
  ]
}
```

If the request matches one of the first 2 fingerprints, the function responds with:

```
< HTTP/2 200 
< server: CloudFront
< date: Sun, 23 Feb 2025 21:44:42 GMT
< content-length: 0
< x-ja3-fingerprint: 375c6162a492dfbf2795909110ce8424
< x-cache: FunctionGeneratedResponse from cloudfront
< via: 1.1 17eb4ce9c34597b3328325a19f8138fe.cloudfront.net (CloudFront)
< x-amz-cf-pop: JFK50-P6
< alt-svc: h3=":443"; ma=86400
< x-amz-cf-id: IbISWf6cWJvj9HrAi9X1jkmKdGskgmyJLEhWg0jfoexuTpUiXm5zww==
< 
```
This is done simply to illustrate the logic, but normally your function would respond with the request allowing it to be sent to the origin for further processing.

If the request fingerprint matches the 3rd fingerprint or none of the fingerprints, the function
responds with:

```
< HTTP/2 401 
< server: CloudFront
< date: Sun, 23 Feb 2025 21:44:50 GMT
< content-length: 0
< x-cache: FunctionGeneratedResponse from cloudfront
< via: 1.1 17eb4ce9c34597b3328325a19f8138fe.cloudfront.net (CloudFront)
< x-amz-cf-pop: JFK50-P6
< alt-svc: h3=":443"; ma=86400
< x-amz-cf-id: PFdLqMxBDAnnHWD2mZ9OyDHGZk4xcAyfh1osmLmj2haIC3GmSmlYhQ==
< 
```

## Terraform example

See `/terraform/main.tf` that shows how the Cloudfront distribution and supporting resources can be configured to implement the example.

In this configuration, the `gate_on_fingerprint.js` function processes all requests sent to `/gate/*` and all other requests sent to the distribution are processed by the `echo_fingerprint.js` function.