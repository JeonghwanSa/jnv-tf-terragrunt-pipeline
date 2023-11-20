resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = join("-", [lower("${var.aws_account_alias}"), "pipelineartifact"])
}

resource "aws_s3_bucket_ownership_controls" "bucketownership" {
  bucket = aws_s3_bucket.codepipeline_bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
resource "aws_s3_bucket_public_access_block" "publcaccess_block" {
  bucket = aws_s3_bucket.codepipeline_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "codepipeline_role" {
  name = join("-", ["codepipeline", "${var.aws_account_alias}", "codepipeline_role"])

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline_policy"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObject"
        ],
        Resource = [
          "${aws_s3_bucket.codepipeline_bucket.arn}",
          "${aws_s3_bucket.codepipeline_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild",
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "codestar-connections:UseConnection"
        ],
        Resource = [
          "${var.github_connection_arn}"
        ]
      }
    ]
  })
}

resource "aws_codepipeline" "terragrunt_pipeline" {
  name     = join("-", ["inf", "${var.jnv_region}", "${var.aws_account_alias}", "pipeline", "${var.jnv_environment}"])
  role_arn = aws_iam_role.codepipeline_role.arn
  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }
  stage {
    name = "Source"
    action {
      name             = "FetchCode"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      run_order        = 1
      output_artifacts = ["SourceArtifact"]
      configuration = {
        ConnectionArn    = var.github_connection_arn
        FullRepositoryId = var.github_fullrepository_id
        BranchName       = var.pipeline_branch
      }
    }
  }
  dynamic "stage" {
    for_each = var.need_plan == true ? [1] : []
    content {
      name = "TerraformPlan"
      action {
        category = "Build"
        configuration = {
          "ProjectName" = "${aws_codebuild_project.terragrunt_build_plan.name}"
        }
        input_artifacts = [
          "SourceArtifact",
        ]
        name      = "Plan"
        owner     = "AWS"
        provider  = "CodeBuild"
        run_order = 1
        version   = "1"
      }
    }
  }
  dynamic "stage" {
    for_each = var.need_approval == true ? [1] : []
    content {
      name = "Approval"
      action {
        name     = "Approval"
        category = "Approval"
        owner    = "AWS"
        provider = "Manual"
        version  = "1"
      }
    }
  }
  stage {
    name = "TerraformApply"
    action {
      category = "Build"
      configuration = {
        "ProjectName" = "${aws_codebuild_project.terragrunt_build_apply.name}"
      }
      input_artifacts = [
        "SourceArtifact",
      ]
      name      = "Apply"
      owner     = "AWS"
      provider  = "CodeBuild"
      run_order = 1
      version   = "1"
    }
  }
}

resource "aws_iam_role" "codebuild" {
  name = join("-", [var.aws_account_alias, "codebuild_role"])

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "codebuild_role_attach" {
  role       = aws_iam_role.codebuild.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_codebuild_project" "terragrunt_build_plan" {
  badge_enabled  = false
  build_timeout  = 60
  name           = join("", ["${var.aws_account_alias}", "TfPlan"])
  queued_timeout = 480
  service_role   = aws_iam_role.codebuild.arn
  artifacts {
    encryption_disabled    = false
    name                   = var.aws_account_alias
    override_artifact_name = true
    packaging              = "NONE"
    type                   = "CODEPIPELINE"
  }

  environment {
    compute_type                = var.build_compute_size
    image                       = var.build_image
    image_pull_credentials_type = var.build_image_pull_credentials_type
    privileged_mode             = var.build_privileged_mode
    type                        = "LINUX_CONTAINER"
  }

  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }

    s3_logs {
      encryption_disabled = false
      status              = "DISABLED"
    }
  }

  cache {
    modes = var.build_cache_config.modes
    type  = var.build_cache_config.type
  }

  source {
    git_clone_depth     = 0
    insecure_ssl        = false
    report_build_status = false
    type                = "CODEPIPELINE"
    buildspec           = "buildspec.plan.yml"
  }
}

resource "aws_codebuild_project" "terragrunt_build_apply" {
  badge_enabled  = false
  build_timeout  = 60
  name           = join("", ["${var.aws_account_alias}", "TfApply"])
  queued_timeout = 480
  service_role   = aws_iam_role.codebuild.arn
  artifacts {
    encryption_disabled    = false
    name                   = var.aws_account_alias
    override_artifact_name = true
    packaging              = "NONE"
    type                   = "CODEPIPELINE"
  }

  environment {
    compute_type                = var.build_compute_size
    image                       = var.build_image
    image_pull_credentials_type = var.build_image_pull_credentials_type
    privileged_mode             = var.build_privileged_mode
    type                        = "LINUX_CONTAINER"
  }

  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }

    s3_logs {
      encryption_disabled = false
      status              = "DISABLED"
    }
  }

  cache {
    modes = var.build_cache_config.modes
    type  = var.build_cache_config.type
  }

  source {
    git_clone_depth     = 0
    insecure_ssl        = false
    report_build_status = false
    type                = "CODEPIPELINE"
    buildspec           = "buildspec.apply.yml"
  }
}
