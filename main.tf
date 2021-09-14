

provider "aws" {
  profile = "default"
}

data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Base VPC
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "emr-eks-vpc"
  cidr = "10.20.0.0/16"

  azs              = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets  = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"]
  database_subnets = ["10.20.10.0/24", "10.20.11.0/24", "10.20.12.0/24"]
  public_subnets   = ["10.20.101.0/24", "10.20.102.0/24", "10.20.103.0/24"]

  enable_nat_gateway   = true
  enable_dns_hostnames = true

  enable_dhcp_options              = true
  dhcp_options_domain_name         = "emreks.local"
  dhcp_options_domain_name_servers = ["AmazonProvidedDNS"]

  tags = {
    Terraform   = "true"
    Environment = "emr-eks-vpc"
  }
}

data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

// This is needed for us to be able to connect to the proper HTTP endpoint for aws-auth mappings
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.cluster.id]
    command     = "aws"
  }
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "17.9.0"
  cluster_name    = "terra_eks"
  cluster_version = "1.21"
  subnets         = module.vpc.private_subnets
  enable_irsa     = true

  tags = {
    Environment = "test"
    GithubRepo  = "terraform-aws-eks"
    GithubOrg   = "terraform-aws-modules"
  }

  vpc_id = module.vpc.vpc_id

  node_groups = {
    example = {
      desired_capacity = 3
      max_capacity     = 10
      min_capacity     = 1

      instance_types = ["m5.xlarge"]
      update_config = {
        max_unavailable_percentage = 50 # or set `max_unavailable`
      }
    }
  }

  map_roles = [
    {
      rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AWSServiceRoleForAmazonEMRContainers"
      username = "emr-containers"
      groups   = []
    },
  ]
}

resource "aws_emrcontainers_virtual_cluster" "example" {
  depends_on = [ kubernetes_namespace.emr-jobs ]
  container_provider {
    id   = module.eks.cluster_id
    type = "EKS"
    info {
      eks_info {
        namespace = "emr-jobs"
      }
    }
  }
  name = "example"
}

output "eks-endpoint" {
  value = module.eks.cluster_endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = module.eks.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "emr-virtual-cluster-id" {
  value = aws_emrcontainers_virtual_cluster.example.id
}

output "emr-eks-job-role" {
  value = module.iam_assumable_role_admin.iam_role_arn
}