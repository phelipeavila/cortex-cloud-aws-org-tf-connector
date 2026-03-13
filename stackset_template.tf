#---------------------------------------
# StackSet CF Template Definition
#---------------------------------------
# This file defines the CloudFormation template body that the StackSet
# deploys into member accounts. It mirrors the IAM policies and roles
# from iam_policies.tf / iam_roles.tf but uses CF-native syntax
# (Fn::Sub, Ref, etc.) since StackSets require a CF template.

locals {
  #---------------------------------------
  # StackSet CF Template Parameters
  #---------------------------------------
  cf_base_parameters = {
    CortexPlatformRoleName = { Type = "String" }
    ExternalID             = { Type = "String" }
    OutpostRoleArn         = { Type = "String" }
  }

  cf_ads_parameters = var.enable_modules.ads ? {
    OutpostAccountId   = { Type = "String" }
    KmsAccountADS      = { Type = "String" }
    CopySnapshotSuffix = { Type = "String" }
  } : {}

  cf_dspm_parameters = var.enable_modules.dspm ? {
    MTKmsAccountDSPM = { Type = "String" }
  } : {}

  cf_scanner_parameters = local.scanner_enabled ? {
    CortexPlatformScannerRoleName = { Type = "String" }
  } : {}

  cf_parameters = merge(
    local.cf_base_parameters,
    local.cf_ads_parameters,
    local.cf_dspm_parameters,
    local.cf_scanner_parameters,
  )

  #---------------------------------------
  # StackSet CF Resources
  #---------------------------------------

  cf_platform_managed_arns = concat(
    [
      { "Fn::Sub" = "arn:$${AWS::Partition}:iam::aws:policy/ReadOnlyAccess" },
      { "Fn::Sub" = "arn:$${AWS::Partition}:iam::aws:policy/AmazonMemoryDBReadOnlyAccess" },
      { "Fn::Sub" = "arn:$${AWS::Partition}:iam::aws:policy/SecurityAudit" },
      { "Fn::Sub" = "arn:$${AWS::Partition}:iam::aws:policy/AmazonSQSReadOnlyAccess" },
      { "Fn::Sub" = "arn:$${AWS::Partition}:iam::aws:policy/AWSOrganizationsReadOnlyAccess" },
      { Ref = "CortexDISCOVERYPolicy" },
    ],
    var.enable_modules.ads ? [{ Ref = "CortexADSPolicy" }] : [],
    var.enable_modules.dspm ? [{ Ref = "CortexDSPMPolicy" }] : [],
    var.enable_modules.automation ? [{ Ref = "CortexAutomationPolicy" }] : [],
  )

  cf_platform_depends_on = compact([
    "CortexDISCOVERYPolicy",
    var.enable_modules.ads ? "CortexADSPolicy" : "",
    var.enable_modules.dspm ? "CortexDSPMPolicy" : "",
    var.enable_modules.automation ? "CortexAutomationPolicy" : "",
  ])

  cf_platform_role = {
    CortexPlatformRole = {
      Type = "AWS::IAM::Role"
      Properties = {
        RoleName          = { Ref = "CortexPlatformRoleName" }
        ManagedPolicyArns = local.cf_platform_managed_arns
        AssumeRolePolicyDocument = {
          Version = "2012-10-17"
          Statement = [
            {
              Effect    = "Allow"
              Principal = { AWS = [{ Ref = "OutpostRoleArn" }] }
              Action    = "sts:AssumeRole"
              Condition = { StringEquals = { "sts:ExternalId" = { Ref = "ExternalID" } } }
            },
            {
              Effect    = "Allow"
              Principal = { Service = "export.rds.amazonaws.com" }
              Action    = "sts:AssumeRole"
            }
          ]
        }
        Policies = []
        Tags     = []
      }
      DependsOn = local.cf_platform_depends_on
    }
  }

  # Discovery Policy (always deployed)
  cf_discovery_policy = {
    CortexDISCOVERYPolicy = {
      Type = "AWS::IAM::ManagedPolicy"
      Properties = {
        ManagedPolicyName = "Cortex-DISCOVERY-Policy-${var.resource_suffix}${local.ou_name_suffix}"
        PolicyDocument = {
          Version = "2012-10-17"
          Statement = [{
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
            Effect   = "Allow"
            Resource = "*"
          }]
        }
      }
    }
  }

  # ADS Policy (conditional)
  cf_ads_policy = var.enable_modules.ads ? {
    CortexADSPolicy = {
      Type = "AWS::IAM::ManagedPolicy"
      Properties = {
        ManagedPolicyName = "Cortex-ADS-Policy-${var.resource_suffix}${local.ou_name_suffix}"
        PolicyDocument = {
          Version = "2012-10-17"
          Statement = [
            { Sid = "ModifySnapshotAttribute", Effect = "Allow", Action = ["ec2:ModifySnapshotAttribute"], Resource = [{ "Fn::Sub" = "arn:$${AWS::Partition}:ec2:*::snapshot/*" }], Condition = { StringEquals = { "ec2:Add/userId" = { Ref = "OutpostAccountId" }, "ec2:ResourceTag/managed_by" = "paloaltonetworks" } } },
            { Sid = "DeleteSnapshot", Effect = "Allow", Action = ["ec2:DeleteSnapshot"], Resource = [{ "Fn::Sub" = "arn:$${AWS::Partition}:ec2:*::snapshot/*" }], Condition = { StringEquals = { "ec2:ResourceTag/managed_by" = "paloaltonetworks" } } },
            { Sid = "TagSnapshot", Effect = "Allow", Action = ["ec2:CreateTags"], Resource = [{ "Fn::Sub" = "arn:$${AWS::Partition}:ec2:*::snapshot/*" }], Condition = { StringEquals = { "ec2:CreateAction" = ["CreateSnapshot", "CopySnapshot", "CreateSnapshots", "CopyImage"] } } },
            { Sid = "CreateSnapshotAccessVolume", Effect = "Allow", Action = ["ec2:CreateSnapshot"], Resource = [{ "Fn::Sub" = "arn:$${AWS::Partition}:ec2:*:*:volume/*" }] },
            { Sid = "CreateSnapshot", Effect = "Allow", Action = ["ec2:CreateSnapshot"], Condition = { StringEquals = { "aws:RequestTag/managed_by" = "paloaltonetworks" } }, Resource = [{ "Fn::Sub" = "arn:$${AWS::Partition}:ec2:*::snapshot/*" }] },
            { Sid = "CopySnapshotSource", Effect = "Allow", Action = ["ec2:CopySnapshot"], Condition = { StringEquals = { "aws:ResourceTag/managed_by" = "paloaltonetworks" } }, Resource = [{ "Fn::Sub" = "arn:$${AWS::Partition}:ec2:*::snapshot/snap-*" }] },
            { Sid = "CopySnapshotDestination", Effect = "Allow", Action = ["ec2:CopySnapshot"], Condition = { StringEquals = { "aws:RequestTag/managed_by" = "paloaltonetworks" } }, Resource = [{ "Fn::Sub" = "arn:$${AWS::Partition}:ec2:*::snapshot/$${CopySnapshotSuffix}" }] },
            { Sid = "DescribeSnapshots", Effect = "Allow", Action = ["ec2:DescribeSnapshots"], Resource = "*" },
            { Sid = "DescribeAndGenerateKeyWithoutPlaintext", Effect = "Allow", Action = ["kms:DescribeKey", "kms:GenerateDataKeyWithoutPlaintext"], Resource = [{ "Fn::Sub" = "arn:$${AWS::Partition}:kms:*:$${KmsAccountADS}:key/*" }], Condition = { StringLike = { "kms:ViaService" = "ec2.*.amazonaws.com" } } },
            { Sid = "TargetKeyGrant", Effect = "Allow", Action = ["kms:CreateGrant"], Resource = [{ "Fn::Sub" = "arn:$${AWS::Partition}:kms:*:*:key/*" }], Condition = { StringLike = { "kms:ViaService" = "ec2.*.amazonaws.com" }, Bool = { "kms:GrantIsForAWSResource" = "true" }, "ForAllValues:StringEquals" = { "kms:GrantOperations" = ["Decrypt", "Encrypt"] } } },
            { Sid = "ScanningKeyGrant", Effect = "Allow", Action = ["kms:CreateGrant"], Resource = [{ "Fn::Sub" = "arn:$${AWS::Partition}:kms:*:$${KmsAccountADS}:key/*" }], Condition = { StringLike = { "kms:ViaService" = "ec2.*.amazonaws.com" }, Bool = { "kms:GrantIsForAWSResource" = "true" }, "ForAllValues:StringEquals" = { "kms:GrantOperations" = ["Encrypt"] } } },
            { Sid = "CreateSnapshotsAccessInstanceAndVolume", Effect = "Allow", Action = ["ec2:CreateSnapshots"], Resource = [{ "Fn::Sub" = "arn:$${AWS::Partition}:ec2:*:*:instance/*" }, { "Fn::Sub" = "arn:$${AWS::Partition}:ec2:*:*:volume/*" }] },
            { Sid = "CreateSnapshotsAccessSnapshot", Effect = "Allow", Action = ["ec2:CreateSnapshots"], Resource = [{ "Fn::Sub" = "arn:$${AWS::Partition}:ec2:*::snapshot/*" }], Condition = { StringEquals = { "aws:RequestTag/managed_by" = "paloaltonetworks" } } },
            { Sid = "CopyImageAccessImage", Effect = "Allow", Action = ["ec2:CopyImage"], Resource = [{ "Fn::Sub" = "arn:$${AWS::Partition}:ec2:*::image/*" }] },
            { Sid = "CopyImageAccessSnapshot", Effect = "Allow", Action = ["ec2:CopyImage"], Condition = { StringEquals = { "aws:RequestTag/managed_by" = "paloaltonetworks" } }, Resource = [{ "Fn::Sub" = "arn:$${AWS::Partition}:ec2:*::snapshot/*" }] },
            { Sid = "DescribeImages", Effect = "Allow", Action = ["ec2:DescribeImages"], Resource = "*" },
            { Sid = "DeregisterImage", Effect = "Allow", Action = ["ec2:DeregisterImage"], Resource = [{ "Fn::Sub" = "arn:$${AWS::Partition}:ec2:*::image/*" }], Condition = { StringEquals = { "ec2:ResourceTag/managed_by" = "paloaltonetworks" } } },
            { Sid = "TagImages", Effect = "Allow", Action = ["ec2:CreateTags"], Resource = [{ "Fn::Sub" = "arn:$${AWS::Partition}:ec2:*::image/*" }], Condition = { StringEquals = { "ec2:CreateAction" = ["CopyImage"], "aws:RequestTag/managed_by" = "paloaltonetworks" } } }
          ]
        }
      }
    }
  } : {}

  # DSPM Policy (conditional)
  cf_dspm_policy = var.enable_modules.dspm ? {
    CortexDSPMPolicy = {
      Type = "AWS::IAM::ManagedPolicy"
      Properties = {
        ManagedPolicyName = "Cortex-DSPM-Policy-${var.resource_suffix}${local.ou_name_suffix}"
        PolicyDocument = {
          Version = "2012-10-17"
          Statement = [
            { Condition = { StringEquals = { "aws:ResourceTag/managed_by" = "paloaltonetworks" } }, Action = ["rds:DeleteDBClusterSnapshot", "rds:DeleteDBSnapshot", "redshift:DeleteClusterSnapshot"], Resource = ["*"], Effect = "Allow" },
            { Action = ["rds:AddTagsToResource", "rds:CancelExportTask", "rds:CreateDBClusterSnapshot", "rds:CreateDBSnapshot", "rds:Describe*", "rds:List*", "rds:StartExportTask"], Resource = ["*"], Effect = "Allow" },
            { Action = ["s3:PutObject*", "s3:ListBucket", "s3:GetObject*", "s3:DeleteObject*", "s3:GetBucketLocation"], Resource = ["arn:aws:s3:::cortex-artifact*", "arn:aws:s3:::cortex-artifact*/*"], Effect = "Allow" },
            { Action = ["s3:List*", "s3:Get*"], Resource = ["arn:aws:s3:::*"], Effect = "Allow" },
            { Sid = "DescribeAndGenerateKeyWithoutPlaintext", Effect = "Allow", Action = ["kms:DescribeKey", "kms:GenerateDataKeyWithoutPlaintext"], Resource = { "Fn::Join" = ["", ["arn:", { Ref = "AWS::Partition" }, ":kms:*:", { Ref = "MTKmsAccountDSPM" }, ":key/*"]] } },
            { Sid = "TargetKeyGrant", Effect = "Allow", Action = ["kms:CreateGrant"], Resource = { "Fn::Join" = ["", ["arn:", { Ref = "AWS::Partition" }, ":kms:*:*:key/*"]] } },
            { Sid = "ScanningKeyGrant", Effect = "Allow", Action = ["kms:CreateGrant"], Resource = { "Fn::Join" = ["", ["arn:", { Ref = "AWS::Partition" }, ":kms:*:", { Ref = "MTKmsAccountDSPM" }, ":key/*"]] } },
            { Effect = "Allow", Action = ["iam:PassRole"], Resource = [{ "Fn::Join" = ["", ["arn:aws:iam::", { Ref = "AWS::AccountId" }, ":role/", { Ref = "CortexPlatformRoleName" }, "*"]] }] },
            { Sid = "DynamoDBAndCloudWatchAccess", Effect = "Allow", Action = ["dynamodb:DescribeTable", "dynamodb:Scan", "cloudwatch:GetMetricStatistics"], Resource = ["*"] },
            { Sid = "RedshiftServerlessAccess", Effect = "Allow", Action = ["redshift-serverless:DeleteResourcePolicy", "redshift-serverless:GetResourcePolicy", "redshift-serverless:PutResourcePolicy"], Resource = ["*"] },
            { Sid = "RedshiftSnapshotAccess", Effect = "Allow", Action = ["redshift:AuthorizeSnapshotAccess", "redshift:CopyClusterSnapshot", "redshift:CreateClusterSnapshot", "redshift:CreateSnapshotCopyGrant", "redshift:CreateTags", "redshift:DeleteSnapshotCopyGrant", "redshift:DisableSnapshotCopy", "redshift:EnableSnapshotCopy", "redshift:RevokeSnapshotAccess"], Resource = ["*"] },
            { Sid = "RedshiftDescribeAndListAccess", Effect = "Allow", Action = ["redshift:Describe*", "redshift:List*"], Resource = ["*"] }
          ]
        }
      }
    }
  } : {}

  # Automation Policy (conditional)
  cf_automation_policy = var.enable_modules.automation ? {
    CortexAutomationPolicy = {
      Type = "AWS::IAM::ManagedPolicy"
      Properties = {
        ManagedPolicyName = "Cortex-Automation-Policy-${var.resource_suffix}${local.ou_name_suffix}"
        PolicyDocument = {
          Version = "2012-10-17"
          Statement = [
            { Sid = "ACMPermissions", Effect = "Allow", Action = ["acm:UpdateCertificateOptions"], Resource = "*" },
            { Sid = "ELBPermissions", Effect = "Allow", Action = ["elasticloadbalancing:ModifyLoadBalancerAttributes"], Resource = "*" },
            { Sid = "RDSPermissions", Effect = "Allow", Action = ["rds:AddTagsToResource", "rds:CreateTenantDatabase", "rds:ModifyDBCluster", "rds:ModifyDBClusterSnapshotAttribute", "rds:ModifyDBInstance", "rds:ModifyDBSnapshotAttribute", "rds:ModifyEventSubscription"], Resource = "*" },
            { Sid = "S3Permissions", Effect = "Allow", Action = ["s3:PutBucketAcl", "s3:PutBucketLogging", "s3:PutBucketPolicy", "s3:PutBucketPublicAccessBlock", "s3:PutBucketVersioning", "s3:GetBucketPolicy", "s3:GetBucketPublicAccessBlock", "s3:GetEncryptionConfiguration", "s3:DeleteBucketPolicy", "s3:PutObject", "s3:GetObject", "s3:GetBucketWebsite", "s3:GetBucketAcl", "s3:DeleteBucketWebsite", "s3:PutBucketOwnershipControls", "s3:CreateBucket", "s3:ListAllMyBuckets"], Resource = "*" },
            { Sid = "EC2Permissions", Effect = "Allow", Action = ["ec2:AuthorizeSecurityGroupIngress", "ec2:ModifyImageAttribute", "ec2:ModifyInstanceAttribute", "ec2:ModifyInstanceMetadataOptions", "ec2:ModifySnapshotAttribute", "ec2:RevokeSecurityGroupEgress", "ec2:RevokeSecurityGroupIngress", "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup", "ec2:DescribeSecurityGroups", "ec2:DescribeInstances", "ec2:AuthorizeSecurityGroupEgress", "ec2:StartInstances", "ec2:StopInstances", "ec2:TerminateInstances", "ec2:RunInstances", "ec2:CreateTags", "ec2:CreateSnapshot", "ec2:DescribeVpcs", "ec2:DescribeSubnets", "ec2:DescribeIpamResourceDiscoveries", "ec2:DescribeIpamResourceDiscoveryAssociations", "ec2:DescribeImages", "ec2:CreateNetworkAcl", "ec2:GetIpamDiscoveredPublicAddresses", "ec2:ModifySubnetAttribute", "ec2:ModifyNetworkInterfaceAttribute", "ec2:DescribeRegions"], Resource = "*" },
            { Sid = "CloudTrailPermissions", Effect = "Allow", Action = ["cloudtrail:UpdateTrail", "cloudtrail:StartLogging", "cloudtrail:DescribeTrails"], Resource = "*" },
            { Sid = "EKSPermissions", Effect = "Allow", Action = ["eks:UpdateClusterConfig", "eks:DescribeCluster", "eks:AssociateAccessPolicy"], Resource = "*" },
            { Sid = "ECSPermissions", Effect = "Allow", Action = ["ecs:UpdateClusterSettings"], Resource = "*" },
            { Sid = "IAMPermissions", Effect = "Allow", Action = ["iam:DeleteLoginProfile", "iam:GetAccountAuthorizationDetails", "iam:GetAccountPasswordPolicy", "iam:PassRole", "iam:PutUserPolicy", "iam:RemoveRoleFromInstanceProfile", "iam:UpdateAccessKey", "iam:UpdateAccountPasswordPolicy"], Resource = "*" },
            { Sid = "KMSPermissions", Effect = "Allow", Action = ["kms:CreateGrant", "kms:Decrypt", "kms:DescribeKey", "kms:GenerateDataKey", "kms:EnableKeyRotation"], Resource = "*" },
            { Sid = "LAMBDAPermissions", Effect = "Allow", Action = ["lambda:GetFunctionConfiguration", "lambda:GetFunctionUrlConfig", "lambda:GetPolicy", "lambda:InvokeFunction", "lambda:UpdateFunctionUrlConfig"], Resource = "*" },
            { Sid = "SecretsManagerPermissions", Effect = "Allow", Action = ["secretsmanager:CreateSecret", "secretsmanager:RotateSecret", "secretsmanager:TagResource"], Resource = "*" },
            { Sid = "CostExplorerPermissions", Effect = "Allow", Action = ["ce:GetCostAndUsage", "ce:GetCostForecast"], Resource = "*" },
            { Sid = "BudgetsPermissions", Effect = "Allow", Action = ["budgets:DescribeBudgets", "budgets:DescribeNotificationsForBudget"], Resource = "*" },
            { Sid = "SSMPermissions", Effect = "Allow", Action = ["ssm:SendCommand", "ssm:ListCommands", "ssm:ListInventoryEntries"], Resource = "*" }
          ]
        }
      }
    }
  } : {}

  # Scanner Role (conditional)
  cf_scanner_principals = compact([
    var.enable_modules.dspm ? "arn:aws:iam::${var.outpost_account_id}:role/dspm_scanner" : "",
    var.enable_modules.registry ? "arn:aws:iam::${var.outpost_account_id}:role/registry_scanner" : "",
    var.enable_modules.serverless ? "arn:aws:iam::${var.outpost_account_id}:role/scanner_of_serverless" : "",
  ])

  cf_scanner_policies = concat(
    var.enable_modules.dspm ? [
      {
        PolicyName = "Cortex-DSPM-Scanner-Policy"
        PolicyDocument = {
          Version = "2012-10-17"
          Statement = [
            { Action = ["s3:PutObject*", "s3:List*", "s3:Get*", "s3:DeleteObject*"], Resource = ["arn:aws:s3:::cortex-artifact*", "arn:aws:s3:::cortex-artifact*/*"], Effect = "Allow" },
            { Sid = "DescribeAndGenerateKeyWithoutPlaintext", Effect = "Allow", Action = ["kms:DescribeKey", "kms:GenerateDataKeyWithoutPlaintext"], Resource = { "Fn::Join" = ["", ["arn:", { Ref = "AWS::Partition" }, ":kms:*:", { Ref = "MTKmsAccountDSPM" }, ":key/*"]] } },
            { Effect = "Allow", Action = ["iam:PassRole"], Resource = [{ "Fn::Join" = ["", ["arn:aws:iam::", { Ref = "AWS::AccountId" }, ":role/", { Ref = "CortexPlatformScannerRoleName" }, "*"]] }] },
            { Sid = "DynamoDBAndCloudWatchAccess", Effect = "Allow", Action = ["dynamodb:DescribeTable", "dynamodb:Scan", "cloudwatch:GetMetricStatistics"], Resource = ["*"] }
          ]
        }
      }
    ] : [],
    var.enable_modules.registry ? [
      {
        PolicyName = "ECRAccessPolicy"
        PolicyDocument = {
          Version   = "2012-10-17"
          Statement = [{ Sid = "ECRAccessSid", Action = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:GetAuthorizationToken"], Resource = "*", Effect = "Allow" }]
        }
      }
    ] : [],
    var.enable_modules.serverless ? [
      {
        PolicyName = "LAMBDAAccessPolicy"
        PolicyDocument = {
          Version   = "2012-10-17"
          Statement = [{ Sid = "LAMBDAAccessSid", Action = ["lambda:GetFunction", "lambda:GetFunctionConfiguration", "lambda:GetLayerVersion", "iam:GetRole"], Resource = "*", Effect = "Allow" }]
        }
      }
    ] : [],
  )

  cf_scanner_role = local.scanner_enabled ? {
    CortexPlatformScannerRole = {
      Type = "AWS::IAM::Role"
      Properties = {
        RoleName = { "Fn::Sub" = "$${CortexPlatformScannerRoleName}-${var.resource_suffix}${local.ou_name_suffix}" }
        ManagedPolicyArns = [
          { "Fn::Sub" = "arn:$${AWS::Partition}:iam::aws:policy/ReadOnlyAccess" },
          { "Fn::Sub" = "arn:$${AWS::Partition}:iam::aws:policy/AmazonMemoryDBReadOnlyAccess" }
        ]
        AssumeRolePolicyDocument = {
          Version = "2012-10-17"
          Statement = [
            {
              Effect    = "Allow"
              Principal = { AWS = local.cf_scanner_principals }
              Action    = "sts:AssumeRole"
              Condition = { StringEquals = { "sts:ExternalId" = { Ref = "ExternalID" } } }
            }
          ]
        }
        Policies = local.cf_scanner_policies
        Tags     = []
      }
    }
  } : {}

  cf_resources = merge(
    local.cf_platform_role,
    local.cf_discovery_policy,
    local.cf_ads_policy,
    local.cf_dspm_policy,
    local.cf_automation_policy,
    local.cf_scanner_role,
  )
}
