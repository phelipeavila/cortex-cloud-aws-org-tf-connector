#---------------------------------------
# Custom Managed Policies
#---------------------------------------

resource "aws_iam_policy" "cortex_ads" {
  count = var.enable_modules.ads ? 1 : 0
  name  = local.ads_policy_name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ModifySnapshotAttribute"
        Effect   = "Allow"
        Action   = "ec2:ModifySnapshotAttribute"
        Resource = ["arn:${data.aws_partition.current.partition}:ec2:*::snapshot/*"]
        Condition = {
          StringEquals = {
            "ec2:Add/userId"             = var.outpost_account_id
            "ec2:ResourceTag/managed_by" = "paloaltonetworks"
          }
        }
      },
      {
        Sid      = "DeleteSnapshot"
        Effect   = "Allow"
        Action   = "ec2:DeleteSnapshot"
        Resource = ["arn:${data.aws_partition.current.partition}:ec2:*::snapshot/*"]
        Condition = {
          StringEquals = {
            "ec2:ResourceTag/managed_by" = "paloaltonetworks"
          }
        }
      },
      {
        Sid      = "TagSnapshot"
        Effect   = "Allow"
        Action   = "ec2:CreateTags"
        Resource = ["arn:${data.aws_partition.current.partition}:ec2:*::snapshot/*"]
        Condition = {
          StringEquals = {
            "ec2:CreateAction" = ["CreateSnapshot", "CopySnapshot", "CreateSnapshots", "CopyImage"]
          }
        }
      },
      {
        Sid      = "CreateSnapshotAccessVolume"
        Effect   = "Allow"
        Action   = "ec2:CreateSnapshot"
        Resource = ["arn:${data.aws_partition.current.partition}:ec2:*:*:volume/*"]
      },
      {
        Sid    = "CreateSnapshot"
        Effect = "Allow"
        Action = "ec2:CreateSnapshot"
        Condition = {
          StringEquals = {
            "aws:RequestTag/managed_by" = "paloaltonetworks"
          }
        }
        Resource = ["arn:${data.aws_partition.current.partition}:ec2:*::snapshot/*"]
      },
      {
        Sid    = "CopySnapshotSource"
        Effect = "Allow"
        Action = "ec2:CopySnapshot"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/managed_by" = "paloaltonetworks"
          }
        }
        Resource = ["arn:${data.aws_partition.current.partition}:ec2:*::snapshot/snap-*"]
      },
      {
        Sid    = "CopySnapshotDestination"
        Effect = "Allow"
        Action = "ec2:CopySnapshot"
        Condition = {
          StringEquals = {
            "aws:RequestTag/managed_by" = "paloaltonetworks"
          }
        }
        Resource = ["arn:${data.aws_partition.current.partition}:ec2:*::snapshot/${var.copy_snapshot_suffix}"]
      },
      {
        Sid      = "DescribeSnapshots"
        Effect   = "Allow"
        Action   = "ec2:DescribeSnapshots"
        Resource = "*"
      },
      {
        Sid      = "DescribeAndGenerateKeyWithoutPlaintext"
        Effect   = "Allow"
        Action   = ["kms:DescribeKey", "kms:GenerateDataKeyWithoutPlaintext"]
        Resource = ["arn:${data.aws_partition.current.partition}:kms:*:${var.kms_account_ads}:key/*"]
        Condition = {
          StringLike = {
            "kms:ViaService" = "ec2.*.amazonaws.com"
          }
        }
      },
      {
        Sid      = "TargetKeyGrant"
        Effect   = "Allow"
        Action   = "kms:CreateGrant"
        Resource = ["arn:${data.aws_partition.current.partition}:kms:*:*:key/*"]
        Condition = {
          StringLike = {
            "kms:ViaService" = "ec2.*.amazonaws.com"
          }
          Bool = {
            "kms:GrantIsForAWSResource" = "true"
          }
          "ForAllValues:StringEquals" = {
            "kms:GrantOperations" = ["Decrypt", "Encrypt"]
          }
        }
      },
      {
        Sid      = "ScanningKeyGrant"
        Effect   = "Allow"
        Action   = "kms:CreateGrant"
        Resource = ["arn:${data.aws_partition.current.partition}:kms:*:${var.kms_account_ads}:key/*"]
        Condition = {
          StringLike = {
            "kms:ViaService" = "ec2.*.amazonaws.com"
          }
          Bool = {
            "kms:GrantIsForAWSResource" = "true"
          }
          "ForAllValues:StringEquals" = {
            "kms:GrantOperations" = ["Encrypt"]
          }
        }
      },
      {
        Sid    = "CreateSnapshotsAccessInstanceAndVolume"
        Effect = "Allow"
        Action = "ec2:CreateSnapshots"
        Resource = [
          "arn:${data.aws_partition.current.partition}:ec2:*:*:instance/*",
          "arn:${data.aws_partition.current.partition}:ec2:*:*:volume/*"
        ]
      },
      {
        Sid      = "CreateSnapshotsAccessSnapshot"
        Effect   = "Allow"
        Action   = "ec2:CreateSnapshots"
        Resource = ["arn:${data.aws_partition.current.partition}:ec2:*::snapshot/*"]
        Condition = {
          StringEquals = {
            "aws:RequestTag/managed_by" = "paloaltonetworks"
          }
        }
      },
      {
        Sid      = "CopyImageAccessImage"
        Effect   = "Allow"
        Action   = "ec2:CopyImage"
        Resource = ["arn:${data.aws_partition.current.partition}:ec2:*::image/*"]
      },
      {
        Sid    = "CopyImageAccessSnapshot"
        Effect = "Allow"
        Action = "ec2:CopyImage"
        Condition = {
          StringEquals = {
            "aws:RequestTag/managed_by" = "paloaltonetworks"
          }
        }
        Resource = ["arn:${data.aws_partition.current.partition}:ec2:*::snapshot/*"]
      },
      {
        Sid      = "DescribeImages"
        Effect   = "Allow"
        Action   = "ec2:DescribeImages"
        Resource = "*"
      },
      {
        Sid      = "DeregisterImage"
        Effect   = "Allow"
        Action   = "ec2:DeregisterImage"
        Resource = ["arn:${data.aws_partition.current.partition}:ec2:*::image/*"]
        Condition = {
          StringEquals = {
            "ec2:ResourceTag/managed_by" = "paloaltonetworks"
          }
        }
      },
      {
        Sid      = "TagImages"
        Effect   = "Allow"
        Action   = "ec2:CreateTags"
        Resource = ["arn:${data.aws_partition.current.partition}:ec2:*::image/*"]
        Condition = {
          StringEquals = {
            "ec2:CreateAction"          = ["CopyImage"]
            "aws:RequestTag/managed_by" = "paloaltonetworks"
          }
        }
      }
    ]
  })
  tags = local.tags
}

resource "aws_iam_policy" "cortex_discovery" {
  name = local.discovery_policy_name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "apigateway:GET",
          "appsync:GetApiCache",
          "athena:GetCapacityReservation",
          "athena:GetNamedQuery",
          "athena:ListCapacityReservations",
          "athena:ListDatabases",
          "athena:ListDataCatalogs",
          "athena:ListNamedQueries",
          "backup:DescribeFramework",
          "backup:DescribeReportPlan",
          "backup:ListFrameworks",
          "backup:ListReportPlans",
          "backup:ListTags",
          "batch:DescribeSchedulingPolicies",
          "batch:ListSchedulingPolicies",
          "cloudwatch:describeAlarms",
          "codebuild:BatchGetReportGroups",
          "codebuild:ListReportGroups",
          "codedeploy:BatchGetApplications",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:GetDeploymentGroup",
          "codedeploy:ListApplications",
          "codedeploy:ListDeploymentConfigs",
          "codedeploy:ListDeploymentGroups",
          "codedeploy:ListTagsForResource",
          "comprehend:ListEntityRecognizers",
          "comprehend:ListTagsForResource",
          "comprehendmedical:ListEntitiesDetectionV2Jobs",
          "config:DescribeAggregationAuthorizations",
          "connect-campaigns:DescribeCampaign",
          "connect-campaigns:ListCampaigns",
          "controltower:GetLandingZone",
          "controltower:ListLandingZones",
          "controltower:ListTagsForResource",
          "directconnect:DescribeConnections",
          "directconnect:DescribeDirectConnectGateways",
          "directconnect:DescribeVirtualInterfaces",
          "ds:DescribeDirectories",
          "ds:ListLogSubscriptions",
          "ds:ListTagsForResource",
          "ecs:DescribeCapacityProviders",
          "forecast:ListTagsForResource",
          "glue:GetBlueprint",
          "glue:GetBlueprintRun",
          "glue:GetBlueprintRuns",
          "glue:GetMLTransforms",
          "glue:GetSecurityConfigurations",
          "glue:GetTags",
          "glue:ListBlueprints",
          "guardduty:DescribePublishingDestination",
          "guardduty:ListDetectors",
          "guardduty:ListPublishingDestinations",
          "imagebuilder:GetDistributionConfiguration",
          "imagebuilder:GetImage",
          "imagebuilder:GetWorkflow",
          "imagebuilder:ListDistributionConfigurations",
          "imagebuilder:ListImageBuildVersions",
          "imagebuilder:ListImages",
          "imagebuilder:ListWorkflows",
          "kafka:ListClustersV2",
          "lakeformation:DescribeLakeFormationIdentityCenterConfiguration",
          "lakeformation:GetLFTag",
          "lakeformation:ListLFTags",
          "logs:DescribeSubscriptionFilters",
          "logs:GetDataProtectionPolicy",
          "logs:ListTagsLogGroup",
          "memorydb:DescribeSnapshots",
          "memorydb:DescribeSubnetGroups",
          "mq:DescribeConfiguration",
          "mq:ListConfigurations",
          "quicksight:DescribeUser",
          "quicksight:DescribeVPCConnection",
          "quicksight:ListUsers",
          "quicksight:ListVPCConnections",
          "rds:DescribeDBClusterSnapshots",
          "rds:DescribeDBSubnetGroups",
          "rds:DescribeGlobalClusters",
          "rds:ListTagsForResource",
          "redshift-serverless:GetEndpointAccess",
          "redshift-serverless:GetNamespace",
          "redshift-serverless:ListEndpointAccess",
          "redshift-serverless:ListNamespaces",
          "redshift-serverless:ListSnapshots",
          "redshift-serverless:ListTagsForResource",
          "redshift:DescribeClusterSubnetGroups",
          "redshift:DescribeEndpointAccess",
          "sagemaker:DescribeDataQualityJobDefinition",
          "sagemaker:DescribeFeatureGroup",
          "sagemaker:DescribeFlowDefinition",
          "sagemaker:DescribeModelPackageGroup",
          "sagemaker:DescribePipeline",
          "sagemaker:DescribeProject",
          "sagemaker:ListDataQualityJobDefinitions",
          "sagemaker:ListFeatureGroups",
          "sagemaker:ListFlowDefinitions",
          "sagemaker:ListImages",
          "sagemaker:ListModelPackageGroups",
          "sagemaker:ListProjects",
          "sagemaker:ListTags",
          "securityhub:GetFindingAggregator",
          "securityhub:ListFindingAggregators",
          "servicecatalog:DescribePortfolio",
          "servicecatalog:SearchProvisionedProducts",
          "ssm:ListResourceDataSync",
          "workspaces:DescribeTags",
          "workspaces:DescribeWorkspaceDirectories",
          "workspaces:DescribeWorkspaces",
          "xray:GetGroups",
          "xray:GetSamplingRules",
          "xray:ListTagsForResource"
        ]
        Resource = "*"
      }
    ]
  })
  tags = local.tags
}

resource "aws_iam_policy" "cortex_automation" {
  count = var.enable_modules.automation ? 1 : 0
  name  = local.automation_policy_name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ACMPermissions"
        Effect   = "Allow"
        Action   = ["acm:UpdateCertificateOptions"]
        Resource = "*"
      },
      {
        Sid      = "ELBPermissions"
        Effect   = "Allow"
        Action   = ["elasticloadbalancing:ModifyLoadBalancerAttributes"]
        Resource = "*"
      },
      {
        Sid    = "RDSPermissions"
        Effect = "Allow"
        Action = [
          "rds:AddTagsToResource",
          "rds:CreateTenantDatabase",
          "rds:ModifyDBCluster",
          "rds:ModifyDBClusterSnapshotAttribute",
          "rds:ModifyDBInstance",
          "rds:ModifyDBSnapshotAttribute",
          "rds:ModifyEventSubscription"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3Permissions"
        Effect = "Allow"
        Action = [
          "s3:PutBucketAcl",
          "s3:PutBucketLogging",
          "s3:PutBucketPolicy",
          "s3:PutBucketPublicAccessBlock",
          "s3:PutBucketVersioning",
          "s3:GetBucketPolicy",
          "s3:GetBucketPublicAccessBlock",
          "s3:GetEncryptionConfiguration",
          "s3:DeleteBucketPolicy",
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetBucketWebsite",
          "s3:GetBucketAcl",
          "s3:DeleteBucketWebsite",
          "s3:PutBucketOwnershipControls",
          "s3:CreateBucket",
          "s3:ListAllMyBuckets"
        ]
        Resource = "*"
      },
      {
        Sid    = "EC2Permissions"
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:ModifyImageAttribute",
          "ec2:ModifyInstanceAttribute",
          "ec2:ModifyInstanceMetadataOptions",
          "ec2:ModifySnapshotAttribute",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:TerminateInstances",
          "ec2:RunInstances",
          "ec2:CreateTags",
          "ec2:CreateSnapshot",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeIpamResourceDiscoveries",
          "ec2:DescribeIpamResourceDiscoveryAssociations",
          "ec2:DescribeImages",
          "ec2:CreateNetworkAcl",
          "ec2:GetIpamDiscoveredPublicAddresses",
          "ec2:ModifySubnetAttribute",
          "ec2:ModifyNetworkInterfaceAttribute",
          "ec2:DescribeRegions"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudTrailPermissions"
        Effect = "Allow"
        Action = [
          "cloudtrail:UpdateTrail",
          "cloudtrail:StartLogging",
          "cloudtrail:DescribeTrails"
        ]
        Resource = "*"
      },
      {
        Sid    = "EKSPermissions"
        Effect = "Allow"
        Action = [
          "eks:UpdateClusterConfig",
          "eks:DescribeCluster",
          "eks:AssociateAccessPolicy"
        ]
        Resource = "*"
      },
      {
        Sid      = "ECSPermissions"
        Effect   = "Allow"
        Action   = ["ecs:UpdateClusterSettings"]
        Resource = "*"
      },
      {
        Sid    = "IAMPermissions"
        Effect = "Allow"
        Action = [
          "iam:DeleteLoginProfile",
          "iam:GetAccountAuthorizationDetails",
          "iam:GetAccountPasswordPolicy",
          "iam:PassRole",
          "iam:PutUserPolicy",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:UpdateAccessKey",
          "iam:UpdateAccountPasswordPolicy"
        ]
        Resource = "*"
      },
      {
        Sid    = "KMSPermissions"
        Effect = "Allow"
        Action = [
          "kms:CreateGrant",
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey",
          "kms:EnableKeyRotation"
        ]
        Resource = "*"
      },
      {
        Sid    = "LAMBDAPermissions"
        Effect = "Allow"
        Action = [
          "lambda:GetFunctionConfiguration",
          "lambda:GetFunctionUrlConfig",
          "lambda:GetPolicy",
          "lambda:InvokeFunction",
          "lambda:UpdateFunctionUrlConfig"
        ]
        Resource = "*"
      },
      {
        Sid    = "SecretsManagerPermissions"
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret",
          "secretsmanager:RotateSecret",
          "secretsmanager:TagResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "CostExplorerPermissions"
        Effect = "Allow"
        Action = [
          "ce:GetCostAndUsage",
          "ce:GetCostForecast"
        ]
        Resource = "*"
      },
      {
        Sid    = "BudgetsPermissions"
        Effect = "Allow"
        Action = [
          "budgets:DescribeBudgets",
          "budgets:DescribeNotificationsForBudget"
        ]
        Resource = "*"
      },
      {
        Sid    = "SSMPermissions"
        Effect = "Allow"
        Action = [
          "ssm:SendCommand",
          "ssm:ListCommands",
          "ssm:ListInventoryEntries"
        ]
        Resource = "*"
      }
    ]
  })
  tags = local.tags
}

resource "aws_iam_policy" "cortex_dspm" {
  count = var.enable_modules.dspm ? 1 : 0
  name  = local.dspm_policy_name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds:DeleteDBClusterSnapshot",
          "rds:DeleteDBSnapshot",
          "redshift:DeleteClusterSnapshot"
        ]
        Resource = ["*"]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/managed_by" = "paloaltonetworks"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "rds:AddTagsToResource",
          "rds:CancelExportTask",
          "rds:CreateDBClusterSnapshot",
          "rds:CreateDBSnapshot",
          "rds:Describe*",
          "rds:List*",
          "rds:StartExportTask"
        ]
        Resource = ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject*",
          "s3:ListBucket",
          "s3:GetObject*",
          "s3:DeleteObject*",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::cortex-artifact*",
          "arn:aws:s3:::cortex-artifact*/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:List*", "s3:Get*"]
        Resource = ["arn:aws:s3:::*"]
      },
      {
        Sid      = "DescribeAndGenerateKeyWithoutPlaintext"
        Effect   = "Allow"
        Action   = ["kms:DescribeKey", "kms:GenerateDataKeyWithoutPlaintext"]
        Resource = "arn:${data.aws_partition.current.partition}:kms:*:${var.kms_account_dspm}:key/*"
      },
      {
        Sid      = "TargetKeyGrant"
        Effect   = "Allow"
        Action   = "kms:CreateGrant"
        Resource = "arn:${data.aws_partition.current.partition}:kms:*:*:key/*"
      },
      {
        Sid      = "ScanningKeyGrant"
        Effect   = "Allow"
        Action   = "kms:CreateGrant"
        Resource = "arn:${data.aws_partition.current.partition}:kms:*:${var.kms_account_dspm}:key/*"
      },
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.platform_role_name}*"
      },
      {
        Sid    = "DynamoDBAndCloudWatchAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:Scan",
          "cloudwatch:GetMetricStatistics"
        ]
        Resource = "*"
      },
      {
        Sid    = "RedshiftServerlessAccess"
        Effect = "Allow"
        Action = [
          "redshift-serverless:DeleteResourcePolicy",
          "redshift-serverless:GetResourcePolicy",
          "redshift-serverless:PutResourcePolicy"
        ]
        Resource = "*"
      },
      {
        Sid    = "RedshiftSnapshotAccess"
        Effect = "Allow"
        Action = [
          "redshift:AuthorizeSnapshotAccess",
          "redshift:CopyClusterSnapshot",
          "redshift:CreateClusterSnapshot",
          "redshift:CreateSnapshotCopyGrant",
          "redshift:CreateTags",
          "redshift:DeleteSnapshotCopyGrant",
          "redshift:DisableSnapshotCopy",
          "redshift:EnableSnapshotCopy",
          "redshift:RevokeSnapshotAccess"
        ]
        Resource = "*"
      },
      {
        Sid      = "RedshiftDescribeAndListAccess"
        Effect   = "Allow"
        Action   = ["redshift:Describe*", "redshift:List*"]
        Resource = "*"
      }
    ]
  })
  tags = local.tags
}
