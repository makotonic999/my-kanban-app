# フロントエンド(React SPA)の静的ホスティング。
# S3 は非公開（パブリックアクセス完全遮断）、CloudFront + OAC(Origin Access Control) 経由でのみ配信。

resource "random_id" "frontend_suffix" {
  byte_length = 4
}

# 配信元の S3 バケット（非公開）。名前衝突を避けるためランダムサフィックスを付与。
resource "aws_s3_bucket" "frontend" {
  bucket = "${local.name}-frontend-${random_id.frontend_suffix.hex}"
  tags   = { Name = "${local.name}-frontend" }
}

# パブリックアクセスを完全にブロック（CloudFront 経由のみ）。
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  versioning_configuration {
    status = "Enabled"
  }
}

# CloudFront が S3 にアクセスするための OAC（SigV4 署名、IAM は使わない新方式）。
resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${local.name}-frontend-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# SPA のクライアントサイドルーティング用 CloudFront Function。
# 拡張子の無いパス（/board など）を index.html にフォールバックさせる。
resource "aws_cloudfront_function" "spa_router" {
  name    = "${local.name}-spa-router"
  runtime = "cloudfront-js-2.0"
  comment = "Rewrite non-asset requests to /index.html for SPA routing"
  publish = true
  code    = <<-JS
    function handler(event) {
      var request = event.request;
      var uri = request.uri;
      // 拡張子を含まない（= アセットでない）リクエストは index.html に書き換える。
      if (!uri.includes('.')) {
        request.uri = '/index.html';
      }
      return request;
    }
  JS
}

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  default_root_object = "index.html"
  comment             = "${local.name} frontend"
  price_class         = "PriceClass_200" # 北米・欧州・アジア（コスト最適）

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "s3-frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-frontend"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # AWS 管理のキャッシュポリシー "CachingOptimized"。
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.spa_router.arn
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true # 独自ドメインは後続。まずは *.cloudfront.net
  }

  tags = { Name = "${local.name}-frontend" }
}

# S3 バケットポリシー: この CloudFront ディストリビューションからの読み取りのみ許可。
data "aws_iam_policy_document" "frontend_s3" {
  statement {
    sid       = "AllowCloudFrontRead"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.frontend.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend_s3.json
}

output "frontend_bucket" {
  description = "フロントエンド配信元 S3 バケット名（デプロイ時の同期先）"
  value       = aws_s3_bucket.frontend.bucket
}

output "frontend_cloudfront_domain" {
  description = "フロントエンドの公開 URL（CloudFront ドメイン）"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "frontend_distribution_id" {
  description = "CloudFront ディストリビューション ID（キャッシュ無効化に使用）"
  value       = aws_cloudfront_distribution.frontend.id
}
