
resource "aws_iam_role" "codebuild_role" {
  name = "${var.APP_NAME}-codebuild-role"

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

resource "aws_iam_policy" "codebuild_policy" {
  name        = "${var.APP_NAME}-codebuild-policy"
  path        = "/service-role/"
  description = "Policy used in trust relationship with CodeBuild"
  # TODO - Restrict policy to specific ECR (receive ECR ARN from ecr.tf)
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "WriteLogsToCloudWatch",
      "Effect" : "Allow",
      "Action" : [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource" : "arn:aws:logs:*:*:*"
    }, {
      "Sid": "SeeBuildBucket",
      "Effect":"Allow",
      "Action": "s3:ListBucket",
      "Resource": ["${aws_s3_bucket.codepipeline_build_repository.arn}"]
    }, {
      "Sid": "GetAndPutArtifactsInBuildBucket",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject"
      ],
      "Resource": ["${aws_s3_bucket.codepipeline_build_repository.arn}/*"]
    }, {
      "Sid": "ManageFrontEndBucket",
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": [
        "${aws_s3_bucket.frontend.arn}",
        "${aws_s3_bucket.frontend.arn}/*"
      ]
    }, {
      "Sid": "ManageArtifactsInBuildBucket",
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": [
        "${aws_s3_bucket.codepipeline_build_repository.arn}",
        "${aws_s3_bucket.codepipeline_build_repository.arn}/*"
      ]
    }, {
      "Sid": "PublishDockerImagesToECR",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:CompleteLayerUpload",
        "ecr:GetAuthorizationToken",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:BatchDeleteImage",
        "ecr:UploadLayerPart"
      ],
      "Resource": "*"      
    }
  ]
}
POLICY
}

resource "aws_iam_policy_attachment" "codebuild_policy_attachment" {
  name       = "aclu-codebuild-policy-attachment"
  policy_arn = "${aws_iam_policy.codebuild_policy.arn}"
  roles      = ["${aws_iam_role.codebuild_role.id}"]
}

resource "aws_codebuild_project" "aclu" {
  name          = "${var.APP_NAME}-codebuild"
  description   = "Automates build process for ACLU project."
  build_timeout = "60"
  service_role  = "${aws_iam_role.codebuild_role.arn}"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/docker:1.12.1"
    type            = "LINUX_CONTAINER"
    privileged_mode = "true"

    environment_variable {
      "name"  = "IMAGES_REPO_URL"
      "value" = "${aws_ecr_repository.aclu.repository_url}"
    }

    environment_variable {
      "name"  = "IMAGES_REPO_NAME"
      "value" = "${aws_ecr_repository.aclu.name}"
    }

    environment_variable {
      "name"  = "AWS_DEFAULT_REGION"
      "value" = "${var.REGION}"
    }

    environment_variable {
      "name"  = "API_URL"
      "value" = "${var.API_DOMAIN}"
    }

    environment_variable {
      "name"  = "FRONTEND_BUCKET"
      "value" = "${aws_s3_bucket.frontend.id}"
    }

    environment_variable {
      "name"  = "MONGO_HOST"
      "value" = "UPDATE_THIS_VARIABLE"
    }

    environment_variable {
      "name"  = "MONGO_PORT"
      "value" = "UPDATE_THIS_VARIABLE"
    }

    environment_variable {
      "name"  = "MONGO_USERNAME"
      "value" = "UPDATE_THIS_VARIABLE"
    }
    
    environment_variable {
      "name"  = "MONGO_PASSWORD"
      "value" = "UPDATE_THIS_VARIABLE"
    }

    environment_variable {
      "name"  = "MONGO_DBNAME"
      "value" = "UPDATE_THIS_VARIABLE"
    }
  }

  source {
    type     = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }
  
  tags = "${var.GLOBAL_TAGS}"
}