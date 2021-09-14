module "iam_assumable_role_admin" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "4.3.0"
  create_role                   = true
  role_name                     = "tf_emr_eks_job_role"
  provider_url                  = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = [aws_iam_policy.emr_eks_job_execution.arn]
  oidc_subjects_with_wildcards = ["system:serviceaccount:${kubernetes_namespace.emr-jobs.metadata[0].name}:emr-containers-sa-*-*-${data.aws_caller_identity.current.account_id}-1wu0n6f5pn56pyq0ztwvp2yhvpefs5"]
}

# Please note that the 1wu... string in the oidc_subjects_with_wildcards statement above is hard-coded as the Base36-encoded role name, tf_emr_eks_job_role
# If you change the role_name, you will need to update this value.
# See https://docs.aws.amazon.com/emr/latest/EMR-on-EKS-DevelopmentGuide/iam-execution-role.html for more info.


resource "aws_iam_policy" "emr_eks_job_execution" {
  name_prefix = "tf_emr_eks_job_execution"
  description = "EMR on EKS job execution policy for cluster ${module.eks.cluster_id}"
  policy      = data.aws_iam_policy_document.emr_eks_execution_policy.json
}

data "aws_iam_policy_document" "emr_eks_execution_policy" {
  statement {
    sid    = "emrEksS3Access"
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "emrEksCloudWatchAccess"
    effect = "Allow"

    actions = [
      "logs:PutLogEvents",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]

    resources = ["arn:aws:logs:*:*:*"]

  }
}
