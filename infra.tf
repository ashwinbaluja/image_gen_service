provider "aws" {
  region = "us-east-2"
}

resource "aws_s3_bucket" "images_bucket" {
  bucket        = "image-generation-service-bucket-cs310fp"
  force_destroy = true
}

resource "aws_s3_bucket" "model_bucket" {
  bucket        = "model-bucket-cs310fp"
  force_destroy = true
}


resource "aws_s3_bucket_cors_configuration" "images_bucket_cors" {
  bucket = aws_s3_bucket.images_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_dynamodb_table" "images_table" {
  name         = "Images"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "image_id"

  attribute {
    name = "image_id"
    type = "S"
  }
  attribute {
    name = "prompt"
    type = "S"
  }
  global_secondary_index {
    name            = "PromptIndex"
    hash_key        = "prompt"
    projection_type = "ALL"
  }
}

resource "aws_dynamodb_table" "embeddings_table" {
  name         = "Embeddings"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "embedding_id"

  attribute {
    name = "embedding_id"
    type = "S"
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "image_service_lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_policy"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.images_bucket.arn,
          "${aws_s3_bucket.images_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ],
        Resource = [
          aws_dynamodb_table.images_table.arn,
          aws_dynamodb_table.embeddings_table.arn,
          "${aws_dynamodb_table.images_table.arn}/index/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "sagemaker:InvokeEndpoint"
        ],
        Resource = aws_sagemaker_endpoint.clip_endpoint.arn
      },
      {
        Effect = "Allow",
        Action = [
          "bedrock:InvokeModel"
        ],
        Resource = "arn:aws:bedrock:us-west-2::foundation-model/amazon.titan-image-generator-v2:0"
      }
    ]
  })
}

data "archive_file" "generate_images_zip" {
  type        = "zip"
  source_file = "${path.module}/lambdas/generate_images_lambda.py"
  output_path = "${path.module}/lambda_functions/generate_images.zip"
}

data "archive_file" "get_image_zip" {
  type        = "zip"
  source_file = "${path.module}/lambdas/get_image_lambda.py"
  output_path = "${path.module}/lambda_functions/get_image.zip"
}

data "archive_file" "upload_image_zip" {
  type        = "zip"
  source_file = "${path.module}/lambdas/upload_image_lambda.py"
  output_path = "${path.module}/lambda_functions/upload_image.zip"
}

data "archive_file" "get_embedding_zip" {
  type        = "zip"
  source_file = "${path.module}/lambdas/get_embedding_lambda.py"
  output_path = "${path.module}/lambda_functions/get_embedding.zip"
}

data "archive_file" "find_similar_image_zip" {
  type        = "zip"
  source_file = "${path.module}/lambdas/find_similar_image_lambda.py"
  output_path = "${path.module}/lambda_functions/find_similar_image.zip"
}

resource "aws_lambda_function" "generate_images" {
  function_name = "generate_images"
  filename      = data.archive_file.generate_images_zip.output_path
  handler       = "generate_images_lambda.lambda_handler"
  runtime       = "python3.13"
  timeout       = 60
  memory_size   = 256
  role          = aws_iam_role.lambda_role.arn
  layers        = ["arn:aws:lambda:us-east-2:336392948345:layer:AWSSDKPandas-Python313:1"]

  environment {
    variables = {
      BUCKET_NAME  = aws_s3_bucket.images_bucket.bucket
      IMAGES_TABLE = aws_dynamodb_table.images_table.name
    }
  }
}

resource "aws_lambda_function" "get_image" {
  function_name = "get_image"
  filename      = data.archive_file.get_image_zip.output_path
  handler       = "get_image_lambda.lambda_handler"
  runtime       = "python3.13"
  timeout       = 60
  memory_size   = 128
  role          = aws_iam_role.lambda_role.arn
  layers        = ["arn:aws:lambda:us-east-2:336392948345:layer:AWSSDKPandas-Python313:1"]

  environment {
    variables = {
      BUCKET_NAME  = aws_s3_bucket.images_bucket.bucket
      IMAGES_TABLE = aws_dynamodb_table.images_table.name
    }
  }
}

resource "aws_lambda_function" "upload_image" {
  function_name = "upload_image"
  filename      = data.archive_file.upload_image_zip.output_path
  handler       = "upload_image_lambda.lambda_handler"
  runtime       = "python3.13"
  timeout       = 60
  memory_size   = 128
  role          = aws_iam_role.lambda_role.arn
  layers        = ["arn:aws:lambda:us-east-2:336392948345:layer:AWSSDKPandas-Python313:1"]

  environment {
    variables = {
      BUCKET_NAME  = aws_s3_bucket.images_bucket.bucket
      IMAGES_TABLE = aws_dynamodb_table.images_table.name
    }
  }
}

resource "aws_lambda_function" "get_embedding" {
  function_name = "get_embedding"
  filename      = data.archive_file.get_embedding_zip.output_path
  handler       = "get_embedding_lambda.lambda_handler"
  runtime       = "python3.13"
  timeout       = 60
  memory_size   = 256
  role          = aws_iam_role.lambda_role.arn
  layers        = ["arn:aws:lambda:us-east-2:336392948345:layer:AWSSDKPandas-Python313:1"]

  environment {
    variables = {
      BUCKET_NAME        = aws_s3_bucket.images_bucket.bucket
      EMBEDDINGS_TABLE   = aws_dynamodb_table.embeddings_table.name
      SAGEMAKER_ENDPOINT = aws_sagemaker_endpoint.clip_endpoint.name
    }
  }
}

resource "aws_lambda_function" "find_similar_image" {
  function_name = "find_similar_image"
  filename      = data.archive_file.find_similar_image_zip.output_path
  handler       = "find_similar_image_lambda.lambda_handler"
  runtime       = "python3.13"
  timeout       = 60
  memory_size   = 256
  role          = aws_iam_role.lambda_role.arn
  layers        = ["arn:aws:lambda:us-east-2:336392948345:layer:AWSSDKPandas-Python313:1"]

  environment {
    variables = {
      BUCKET_NAME        = aws_s3_bucket.images_bucket.bucket
      IMAGES_TABLE       = aws_dynamodb_table.images_table.name
      EMBEDDINGS_TABLE   = aws_dynamodb_table.embeddings_table.name
      SAGEMAKER_ENDPOINT = aws_sagemaker_endpoint.clip_endpoint.name
      IMAGES_PROMPT_GSI  = tolist(aws_dynamodb_table.images_table.global_secondary_index)[0].name
    }
  }
}

resource "aws_api_gateway_rest_api" "image_service_api" {
  name        = "ImageServiceAPI"
  description = "api"
}

resource "aws_api_gateway_resource" "images_resource" {
  rest_api_id = aws_api_gateway_rest_api.image_service_api.id
  parent_id   = aws_api_gateway_rest_api.image_service_api.root_resource_id
  path_part   = "images"
}

resource "aws_api_gateway_method" "get_images" {
  rest_api_id   = aws_api_gateway_rest_api.image_service_api.id
  resource_id   = aws_api_gateway_resource.images_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_images_integration" {
  rest_api_id             = aws_api_gateway_rest_api.image_service_api.id
  resource_id             = aws_api_gateway_resource.images_resource.id
  http_method             = aws_api_gateway_method.get_images.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.generate_images.invoke_arn
}

resource "aws_api_gateway_method" "post_images" {
  rest_api_id   = aws_api_gateway_rest_api.image_service_api.id
  resource_id   = aws_api_gateway_resource.images_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "post_images_integration" {
  rest_api_id             = aws_api_gateway_rest_api.image_service_api.id
  resource_id             = aws_api_gateway_resource.images_resource.id
  http_method             = aws_api_gateway_method.post_images.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.upload_image.invoke_arn
}

resource "aws_api_gateway_resource" "image_id_resource" {
  rest_api_id = aws_api_gateway_rest_api.image_service_api.id
  parent_id   = aws_api_gateway_resource.images_resource.id
  path_part   = "{image_id}"
}

resource "aws_api_gateway_method" "get_image_by_id" {
  rest_api_id   = aws_api_gateway_rest_api.image_service_api.id
  resource_id   = aws_api_gateway_resource.image_id_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_image_by_id_integration" {
  rest_api_id             = aws_api_gateway_rest_api.image_service_api.id
  resource_id             = aws_api_gateway_resource.image_id_resource.id
  http_method             = aws_api_gateway_method.get_image_by_id.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_image.invoke_arn
}

resource "aws_api_gateway_resource" "embeddings_resource" {
  rest_api_id = aws_api_gateway_rest_api.image_service_api.id
  parent_id   = aws_api_gateway_rest_api.image_service_api.root_resource_id
  path_part   = "embeddings"
}

resource "aws_api_gateway_resource" "embedding_id_resource" {
  rest_api_id = aws_api_gateway_rest_api.image_service_api.id
  parent_id   = aws_api_gateway_resource.embeddings_resource.id
  path_part   = "{embedding_id}"
}

resource "aws_api_gateway_method" "get_embedding_by_id" {
  rest_api_id   = aws_api_gateway_rest_api.image_service_api.id
  resource_id   = aws_api_gateway_resource.embedding_id_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_embedding_by_id_integration" {
  rest_api_id             = aws_api_gateway_rest_api.image_service_api.id
  resource_id             = aws_api_gateway_resource.embedding_id_resource.id
  http_method             = aws_api_gateway_method.get_embedding_by_id.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_embedding.invoke_arn
}

resource "aws_api_gateway_resource" "similarity_resource" {
  rest_api_id = aws_api_gateway_rest_api.image_service_api.id
  parent_id   = aws_api_gateway_rest_api.image_service_api.root_resource_id
  path_part   = "similarity"
}

resource "aws_api_gateway_method" "get_similarity" {
  rest_api_id   = aws_api_gateway_rest_api.image_service_api.id
  resource_id   = aws_api_gateway_resource.similarity_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_similarity_integration" {
  rest_api_id             = aws_api_gateway_rest_api.image_service_api.id
  resource_id             = aws_api_gateway_resource.similarity_resource.id
  http_method             = aws_api_gateway_method.get_similarity.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.find_similar_image.invoke_arn
}

resource "aws_lambda_permission" "api_gateway_permission" {
  count        = 5
  statement_id = "AllowAPIGatewayInvoke-${count.index}"
  action       = "lambda:InvokeFunction"
  function_name = element([
    aws_lambda_function.generate_images.function_name,
    aws_lambda_function.get_image.function_name,
    aws_lambda_function.upload_image.function_name,
    aws_lambda_function.get_embedding.function_name,
    aws_lambda_function.find_similar_image.function_name,
  ], count.index)
  principal  = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.image_service_api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "image_service_deployment" {
  depends_on = [
    aws_api_gateway_integration.get_images_integration,
    aws_api_gateway_integration.post_images_integration,
    aws_api_gateway_integration.get_image_by_id_integration,
    aws_api_gateway_integration.get_embedding_by_id_integration,
    aws_api_gateway_integration.get_similarity_integration
  ]
  rest_api_id = aws_api_gateway_rest_api.image_service_api.id
  stage_name  = "prod"
}

resource "null_resource" "clip_model_build" {
  provisioner "local-exec" {
    command = "python3.13 package.py"
  }
}

resource "aws_s3_bucket_object" "clip_model_tar" {
  bucket = aws_s3_bucket.model_bucket.bucket
  key    = "clip-model.tar.gz"
  source = "${path.module}/clip-model.tar.gz" # Path to the tar.gz generated by package.py

  depends_on = [null_resource.clip_model_build]
}

resource "aws_sagemaker_model" "clip_model" {
  name               = "clip-model"
  execution_role_arn = aws_iam_role.sagemaker_role.arn

  primary_container {
    image          = "763104351884.dkr.ecr.us-east-2.amazonaws.com/huggingface-pytorch-inference:1.10.2-transformers4.17.0-gpu-py38-cu113-ubuntu20.04"
    model_data_url = "s3://${aws_s3_bucket_object.clip_model_tar.bucket}/${aws_s3_bucket_object.clip_model_tar.key}"

    environment = {
      SAGEMAKER_PROGRAM = "inference.py"
    }
  }

  depends_on = [aws_s3_bucket_object.clip_model_tar]
}

resource "aws_sagemaker_endpoint_configuration" "clip_endpoint_config" {
  name = "clip-endpoint-config"

  production_variants {
    variant_name           = "AllTraffic"
    model_name             = aws_sagemaker_model.clip_model.name
    instance_type          = "ml.t2.medium"
    initial_instance_count = 1
  }
}

resource "aws_sagemaker_endpoint" "clip_endpoint" {
  name                 = "clip-endpoint"
  endpoint_config_name = aws_sagemaker_endpoint_configuration.clip_endpoint_config.name
}

resource "aws_iam_role" "sagemaker_role" {
  name = "sagemaker_execution_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "sagemaker.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "sagemaker_policy" {
  name = "sagemaker_policy"
  role = aws_iam_role.sagemaker_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject"
        ],
        Resource = aws_s3_bucket_object.clip_model_tar.arn
      },
      {
        Effect = "Allow",
        Action = [
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ],
        Resource = "arn:aws:ecr:us-east-2:763104351884:repository/huggingface-pytorch-inference"
      },
      {
        Effect   = "Allow",
        Action   = "ecr:GetAuthorizationToken",
        Resource = "*"
      }
    ]
  })
}
