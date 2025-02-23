// a bucket to serve as our origin
module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "fingerprint-allowlist-demo"

  versioning = {
    enabled = true
  }
}

// enable origin access control
resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = module.s3_bucket.s3_bucket_bucket_regional_domain_name

  policy = data.aws_iam_policy_document.s3_policy.json
}

// allow the cloudfront distribution to read from our bucket
// see https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html#oac-permission-to-access-s3
data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions = ["s3:GetObject"]
    resources = ["${module.s3_bucket.s3_bucket_id}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["${module.cloudfront.cloudfront_distribution_arn}"]
    }
  }
}

// our echo function
resource "aws_cloudfront_function" "echo" {
  name    = "echo-fingerprint"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = file("../echo_fingerprint.js")
}

// a key value store to hold our allowlist
resource "aws_cloudfront_key_value_store" "gate_store" {
  name    = "fingerprint_allowlist"
}

// our example allowlist entries
resource "aws_cloudfrontkeyvaluestore_key" "fingerprint_1" {
  key_value_store_arn = aws_cloudfront_key_value_store.gate_store.arn
  key                 = "375c6162a492dfbf2795909110ce8424"
  value               = "true"
}

resource "aws_cloudfrontkeyvaluestore_key" "fingerprint_2" {
  key_value_store_arn = aws_cloudfront_key_value_store.gate_store.arn
  key                 = "773906b0efdefa24a7f2b8eb6985bf37"
  value               = "true"
}

resource "aws_cloudfrontkeyvaluestore_key" "fingerprint_3" {
  key_value_store_arn = aws_cloudfront_key_value_store.gate_store.arn
  key                 = "06c5844b8643740902c45410712542e0"
  value               = "false"
}

// our gating function
resource "aws_cloudfront_function" "gate" {
  name    = "gate-on-fingerprint"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = file("../gate_on_fingerprint.js")
  key_value_store_associations = [aws_cloudfront_key_value_store.gate_store.arn]
}

// a cloudfront origin request policy to ensure we get the headers we want in our functions
resource "aws_cloudfront_origin_request_policy" "fingerprint-demo" {
  name = "fingerprint-demo"
  cookies_config {
    cookie_behavior = "all"
  }
  headers_config {
    header_behavior = "allViewerAndWhitelistCloudFront"
    headers {
      items = [
        "cloudfront-viewer-asn",
        "cloudfront-viewer-header-order",
        "cloudfront-viewer-http-version",
        "cloudfront-viewer-ja3-fingerprint",
        "cloudfront-viewer-ja4-fingerprint",
        "cloudfront-viewer-latitude",
        "cloudfront-viewer-longitude",
        "cloudfront-viewer-tls"
      ]
    }
  }
  query_strings_config {
    query_string_behavior = "all"
  }
}

module "cloudfront" {
  source = "terraform-aws-modules/cloudfront/aws"

  comment             = "Fingerprint CloudFront"
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_All"
  retain_on_delete    = false
  wait_for_deployment = false
  
  create_origin_access_control = true
  origin_access_control = {
    s3_oac = {
      description      = "CloudFront access to S3"
      origin_type      = "s3"
      signing_behavior = "always"
      signing_protocol = "sigv4"
    }
  }

  origin = {
    s3_one = {
      domain_name = module.s3_bucket.s3_bucket_bucket_regional_domain_name
      origin_access_control = "s3_oac"
    }  
  }

  default_cache_behavior = {
    target_origin_id       = "s3_one"
    viewer_protocol_policy = "https-only"

    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true
    query_string    = true

    cache_policy_name            = "Managed-CachingOptimized"
    origin_request_policy_name   = aws_cloudfront_origin_request_policy.fingerprint-demo.name
    response_headers_policy_name = "Managed-SimpleCORS"

    function_association = {
      viewer-request = {
        function_arn = aws_cloudfront_function.echo.arn
        include_body = false
      }
    }
  }

  ordered_cache_behavior = [
    {
      path_pattern           = "/gate/*"
      target_origin_id       = "s3_one"
      viewer_protocol_policy = "https-only"

      allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods  = ["GET", "HEAD"]
      compress        = true
      query_string    = true

      cache_policy_name            = "Managed-CachingOptimized"
      origin_request_policy_name   = aws_cloudfront_origin_request_policy.fingerprint-demo.name
      response_headers_policy_name = "Managed-SimpleCORS"

      function_association = {
        viewer-request = {
          function_arn = aws_cloudfront_function.gate.arn
          include_body = false
        }
      }
    }
  ]
}