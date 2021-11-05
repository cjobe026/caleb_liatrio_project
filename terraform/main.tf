terraform {
  required_version = ">= 1.0.0"
    required_providers {
    local = {
      source = "hashicorp/local"
      version = "2.1.0"
    }
  }
}

provider "aws" {
  version = ">= 3.63.0"
  region  = var.region
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
  version                = "~> 1.11"
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

data "aws_availability_zones" "available" {
}



resource "aws_security_group" "worker_group_mgmt_one" {
  name_prefix = "worker_group_mgmt_one"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
    ]
  }
}
# Create VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.10.0"

  name                 = "test-vpc"
  cidr                 = "10.0.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets       = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}
# Create EKS
module "eks" {
  source       = "terraform-aws-modules/eks/aws"
  cluster_name    = var.cluster_name
  cluster_version = "1.17"
  subnets         = module.vpc.private_subnets
  version = "17.22.0"
  cluster_create_timeout = "1h"
  cluster_endpoint_private_access = true 

  vpc_id = module.vpc.vpc_id

  worker_groups = [
    {
      name                          = "worker-group-1"
      instance_type                 = "t2.small"
      asg_desired_capacity          = 1
      additional_security_group_ids = [aws_security_group.worker_group_mgmt_one.id]
    },
  ]

}

# Kubernetes deploy
resource "kubernetes_deployment" "kube_deploy" {
  metadata {
    name = "cloud-deploy"
    labels = {
      test = "ApiApp"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        test = "ApiApp"
      }
    }

    template {
      metadata {
        labels = {
          test = "ApiApp"
        }
      }

      spec {
        container {
          image = "cjobe026/api_project:1.0"
          name  = "api-app"
          port {
              container_port = 80
          }
          resources {
            limits {
              cpu    = "1"
              memory = "512Mi"
            }
            requests {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
        }
      }
    }
  }
}

# Create LB service on cluster
resource "kubernetes_service" "kube_LoadBalancer" {
  metadata {
    name = "cloud-deploy"
  }
  spec {
    selector = {
      test = "ApiApp"
    }
    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}

#Render Blueprint from template
resource "local_file" "init" {
  content = templatefile("${path.module}/templates/apiCanaryBlueprint.tpl", {
    load_balancer_endpoint = "${kubernetes_service.kube_LoadBalancer.load_balancer_ingress[0].hostname}"
  })
  filename = "${path.module}/files/canary_full/nodejs/node_modules/apiCanaryBlueprint.js"
}
    
#Zipping Blueprint 
data "archive_file" "zipped_blue_print" {
  type             = "zip"
  source_dir      = "${path.module}/files/canary_full"
  output_file_mode = "0666"
  output_path      = "${path.module}/files/canary_full.zip"
  depends_on = [resource.local_file.init]
}

#Random string generation
resource "random_pet" "pet_name" {
  length    = 3
  separator = "-"
}

# S3 bucket for storing synthetics canary test objects
resource "aws_s3_bucket" "s3_test_storage" {
  acl    = "private"
  bucket = "${random_pet.pet_name.id}-bucket"
  tags = {
    Name        = "test_storage"
    Environment = "Dev"
  }
  force_destroy = true
}

# Policy creation
data "aws_iam_policy_document" "identity_policy" {
  statement {
    actions   = ["s3:PutObject","s3:GetBucketLocation","s3:ListAllMyBuckets","cloudwatch:PutMetricData","logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"]
    resources = ["*"]
    effect = "Allow"
  }
  statement {
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.s3_test_storage.arn]
    effect = "Allow"
  }
    statement {
    actions = [
      "cloudwatch:PutMetricData",
    ]
    resources = [
      "*",
    ]
    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"

      values = [
        "CloudWatchSynthetics"
      ]
    }
}
}

# Role policy creation
data "aws_iam_policy_document" "execution_role_policy" {
    statement { 
    actions   = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Adding policy
resource "aws_iam_policy" "policy" {
  name        = "${random_pet.pet_name.id}-policy"
  description = "execution role for testing api app"
  policy = data.aws_iam_policy_document.identity_policy.json
}
    
# Creating a role with role policy
resource "aws_iam_role" "execution_role_add" {
  name = "execution_role"
  assume_role_policy = data.aws_iam_policy_document.execution_role_policy.json
}
    
# Policy attached to role
resource "aws_iam_role_policy_attachment" "attachment" {
  role       = aws_iam_role.execution_role_add.name
  policy_arn = aws_iam_policy.policy.arn
}

# Canary created and started
resource "aws_synthetics_canary" "create_canary" {
  name                 = "api-app-canary"
  artifact_s3_location = "s3://${aws_s3_bucket.s3_test_storage.bucket}/"
  execution_role_arn   = aws_iam_role.execution_role_add.arn
  handler              = "apiCanaryBlueprint.handler"
  zip_file             = "files/canary_full.zip"
  runtime_version      = "syn-nodejs-puppeteer-3.3"
  start_canary         = true
  schedule {
    expression = "rate(10 minutes)"
  }
  depends_on = [data.archive_file.zipped_blue_print, resource.kubernetes_service.kube_LoadBalancer]
}

