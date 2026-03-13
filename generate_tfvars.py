#!/usr/bin/env python3
"""Generate terraform.tfvars from a Cortex XDR CloudFormation template.

Requires: PyYAML (pip install pyyaml)

Usage:
    python generate_tfvars.py <cf-template.yml> [-o terraform.tfvars] [--force]
"""

import argparse
import os
import re
import sys

import yaml

# ---------------------------------------------------------------------------
# Known compatible template versions (the TF module was built against these)
# ---------------------------------------------------------------------------
KNOWN_VERSIONS = {
    "DISCOVERY-assets_discovery": "1.0.5",
    "BASE-base_organization": "1.4.0",
    "BASE-base_account_group": "1.4.0",
    "BASE-base_account": "1.3.0",
    "AUDIT_LOGS-audit_logs_byob": "1.1.0",
    "ADS-agentless_disk_scanning": "1.1.5",
    "DSPM-data_security_posture_management": "1.2.0",
    "OUTPOST_SCANNER-outpost_scanner": "1.2.0",
    "REGISTRY-registry_scanning": "1.0.1",
    "SERVERLESS-serverless_scanning": "1.1.0",
    "AUTOMATION-automation": "1.0.3",
}

CF_KEY_TO_TF_KEY = {
    "DISCOVERY-assets_discovery": "discovery",
    "BASE-base_organization": "base",
    "BASE-base_account_group": "base",
    "BASE-base_account": "base",
    "AUDIT_LOGS-audit_logs_byob": "audit_logs",
    "ADS-agentless_disk_scanning": "ads",
    "DSPM-data_security_posture_management": "dspm",
    "OUTPOST_SCANNER-outpost_scanner": "outpost_scanner",
    "REGISTRY-registry_scanning": "registry",
    "SERVERLESS-serverless_scanning": "serverless",
    "AUTOMATION-automation": "automation",
}

# ---------------------------------------------------------------------------
# CloudFormation YAML tag handling
# ---------------------------------------------------------------------------

def _cf_constructor(loader, tag_suffix, node):
    """Handle CF-specific YAML tags (!Ref, !Sub, !GetAtt, etc.)."""
    if isinstance(node, yaml.ScalarNode):
        return {"__cf_tag": tag_suffix, "value": loader.construct_scalar(node)}
    if isinstance(node, yaml.SequenceNode):
        return {"__cf_tag": tag_suffix, "value": loader.construct_sequence(node)}
    if isinstance(node, yaml.MappingNode):
        return {"__cf_tag": tag_suffix, "value": loader.construct_mapping(node)}
    return None


yaml.add_multi_constructor("!", _cf_constructor, Loader=yaml.SafeLoader)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _scalar(val):
    """Unwrap a value that might be a CF tag wrapper or a plain scalar."""
    if isinstance(val, dict) and "__cf_tag" in val:
        return val["value"]
    return val


def _get_param_default(params, key):
    """Return the Default value for a CF parameter, or None."""
    p = params.get(key)
    if p is None:
        return None
    return _scalar(p.get("Default"))


def _deep_str_search(obj, needle):
    """Recursively search an object tree for a substring in string leaves."""
    if isinstance(obj, str):
        return needle in obj
    if isinstance(obj, dict):
        return any(_deep_str_search(v, needle) for v in obj.values())
    if isinstance(obj, list):
        return any(_deep_str_search(v, needle) for v in obj)
    return False


def _account_id_from_arn(arn):
    """Extract the AWS account ID from an IAM role ARN.

    ARN format: arn:<partition>:iam::<account-id>:role/<name>
    """
    m = re.search(r":iam::(\d+):", str(arn))
    return m.group(1) if m else ""

def detect_deployment_mode(cf):
    """Detect deployment mode from the CF template's BASE key in TemplateVersion."""
    custom_res = cf.get("Resources", {}).get("MyCustomResource", {}).get("Properties", {})
    cf_versions = custom_res.get("TemplateVersion", {})
    if "BASE-base_account" in cf_versions:
        return "account"
    if "BASE-base_account_group" in cf_versions:
        return "account_group"
    if "BASE-base_organization" in cf_versions:
        return "organization"
    print(
        "Error: Could not detect deployment mode from TemplateVersion.\n"
        "Expected one of: BASE-base_account, BASE-base_account_group, BASE-base_organization",
        file=sys.stderr,
    )
    sys.exit(1)

# ---------------------------------------------------------------------------
# Core logic
# ---------------------------------------------------------------------------

def parse_cf(path):
    with open(path, "r") as f:
        return yaml.safe_load(f)


def check_versions(cf_versions, force=False):
    """Compare CF template versions against known compatible versions.

    Returns the version dict to use (from CF).  Exits if user declines.
    """
    mismatches = []
    for cf_key, cf_ver in cf_versions.items():
        known = KNOWN_VERSIONS.get(cf_key)
        if known and str(cf_ver) != known:
            mismatches.append((cf_key, known, str(cf_ver)))

    new_keys = [k for k in cf_versions if k not in KNOWN_VERSIONS]

    if not mismatches and not new_keys:
        return

    print("\n*** Template version mismatch detected ***\n", file=sys.stderr)

    if mismatches:
        print(f"  {'Module':<50} {'Expected':>10} {'CF Template':>12}", file=sys.stderr)
        print(f"  {'-'*50} {'-'*10} {'-'*12}", file=sys.stderr)
        for key, expected, actual in mismatches:
            print(f"  {key:<50} {expected:>10} {actual:>12}", file=sys.stderr)

    if new_keys:
        print(f"\n  Unknown modules in CF template: {', '.join(new_keys)}", file=sys.stderr)

    print(
        "\nThe Terraform module was built against the expected versions above.",
        file=sys.stderr,
    )
    print(
        "Proceeding with different versions may cause resource drift or errors.\n",
        file=sys.stderr,
    )

    if force:
        print("--force specified, continuing anyway.\n", file=sys.stderr)
        return

    answer = input("Continue anyway? [y/N] ").strip().lower()
    if answer not in ("y", "yes"):
        print("Aborted.", file=sys.stderr)
        sys.exit(1)


def detect_modules(cf):
    """Detect which Cortex modules are enabled in the CF template."""
    resources = cf.get("Resources", {})
    params = cf.get("Parameters", {})

    modules = {
        "audit_logs": "CloudTrailLogsQueue" in resources or "Audience" in params,
        "ads": "CortexADSPolicy" in resources,
        "dspm": "CortexDSPMPolicy" in resources,
        "registry": False,
        "serverless": False,
        "automation": "CortexAutomationPolicy" in resources,
    }

    scanner = resources.get("CortexPlatformScannerRole")
    if scanner:
        if _deep_str_search(scanner, "registry_scanner"):
            modules["registry"] = True
        if _deep_str_search(scanner, "scanner_of_serverless"):
            modules["serverless"] = True

    return modules


def extract_values(cf):
    """Extract all TF variable values from the parsed CF template."""
    params = cf.get("Parameters", {})
    resources = cf.get("Resources", {})
    custom_res = resources.get("MyCustomResource", {}).get("Properties", {})

    # --- PA infrastructure ---
    infra = {}
    outpost_arn = _get_param_default(params, "OutpostRoleArn") or ""
    infra["outpost_role_arn"] = outpost_arn

    explicit_account = _get_param_default(params, "OutpostAccountId")
    infra["outpost_account_id"] = str(explicit_account) if explicit_account else _account_id_from_arn(outpost_arn)

    infra["kms_account_ads"] = str(_get_param_default(params, "KmsAccountADS") or "")
    infra["kms_account_dspm"] = str(_get_param_default(params, "MTKmsAccountDSPM") or "")
    infra["collector_service_account"] = str(
        _get_param_default(params, "CollectorServiceAccountId") or ""
    )
    infra["audience"] = _get_param_default(params, "Audience") or ""

    copy_suffix = _get_param_default(params, "CopySnapshotSuffix") or "${*}"
    infra["copy_snapshot_suffix"] = copy_suffix.replace("${", "$${")

    # --- resource suffix from CortexPlatformRoleName ---
    role_name = _get_param_default(params, "CortexPlatformRoleName") or ""
    prefix = "CortexPlatformRole-"
    resource_suffix = role_name[len(prefix):] if role_name.startswith(prefix) else role_name

    # --- core params from MyCustomResource ---
    template_id = str(_scalar(custom_res.get("TemplateId", "")))
    upload_output_url = str(_scalar(custom_res.get("UploadOutputUrl", "")))
    external_id = str(_get_param_default(params, "ExternalID") or "")

    # --- template versions ---
    cf_versions = custom_res.get("TemplateVersion", {})
    template_versions = {}
    for cf_key, tf_key in CF_KEY_TO_TF_KEY.items():
        if cf_key in cf_versions:
            template_versions[tf_key] = str(cf_versions[cf_key])
        else:
            template_versions[tf_key] = KNOWN_VERSIONS.get(cf_key, "0.0.0")

    deployment_mode = detect_deployment_mode(cf)

    return {
        "infra": infra,
        "resource_suffix": resource_suffix,
        "external_id": external_id,
        "template_id": template_id,
        "upload_output_url": upload_output_url,
        "template_versions": template_versions,
        "cf_versions": cf_versions,
        "deployment_mode": deployment_mode,
    }


def generate_tfvars(source_filename, values, modules):
    """Build the terraform.tfvars content string."""
    infra = values["infra"]
    tv = values["template_versions"]
    mode = values["deployment_mode"]

    mode_labels = {
        "organization": "Organization Connector",
        "account_group": "Account Group (OU) Connector",
        "account": "Account Connector",
    }

    lines = []

    lines.append(f'#{"=" * 79}')
    lines.append(f"# Cortex XDR {mode_labels[mode]} - Terraform Variables")
    lines.append(f"# Generated from: {source_filename}")
    lines.append(f'#{"=" * 79}')
    lines.append("")

    # --- deployment mode ---
    lines.append("#---------------------------------------")
    lines.append("# Deployment Mode")
    lines.append("#---------------------------------------")
    lines.append(f'deployment_mode = "{mode}"')
    lines.append("")

    # --- PA infrastructure ---
    MODULE_REQUIRED = {
        "kms_account_ads":          "ads",
        "kms_account_dspm":         "dspm",
        "copy_snapshot_suffix":     "ads",
        "collector_service_account": "audit_logs",
        "audience":                 "audit_logs",
    }
    lines.append("#---------------------------------------")
    lines.append("# Palo Alto Networks Infrastructure")
    lines.append("#---------------------------------------")
    for key in [
        "outpost_role_arn",
        "outpost_account_id",
        "kms_account_ads",
        "kms_account_dspm",
        "collector_service_account",
        "audience",
        "copy_snapshot_suffix",
    ]:
        required_module = MODULE_REQUIRED.get(key)
        if required_module and not modules.get(required_module):
            continue
        val = infra.get(key, "")
        pad = max(1, 26 - len(key))
        lines.append(f'{key}{" " * pad}= "{val}"')
    lines.append("")

    # --- template versions ---
    lines.append("#---------------------------------------")
    lines.append("# Template Versions")
    lines.append("#---------------------------------------")
    lines.append("template_versions = {")
    version_order = [
        "discovery", "base", "audit_logs", "ads", "dspm",
        "outpost_scanner", "registry", "serverless", "automation",
    ]
    for k in version_order:
        pad = max(1, 16 - len(k))
        lines.append(f'  {k}{" " * pad}= "{tv[k]}"')
    lines.append("}")
    lines.append("")

    # --- core cortex params ---
    lines.append("#---------------------------------------")
    lines.append("# Values extracted from CloudFormation template")
    lines.append("#---------------------------------------")
    lines.append(f'external_id       = "{values["external_id"]}"')
    lines.append(f'template_id       = "{values["template_id"]}"')
    lines.append(f'upload_output_url = "{values["upload_output_url"]}"')
    lines.append("")
    lines.append("# Default resource suffix extracted from YAML")
    lines.append(f'resource_suffix = "{values["resource_suffix"]}"')
    lines.append("")

    # --- module toggles ---
    lines.append("#---------------------------------------")
    lines.append("# Module Toggles")
    lines.append("#---------------------------------------")
    lines.append("enable_modules = {")
    module_order = ["audit_logs", "ads", "dspm", "registry", "serverless", "automation"]
    for m in module_order:
        val = "true" if modules.get(m) else "false"
        pad = max(1, 11 - len(m))
        lines.append(f"  {m}{' ' * pad}= {val}")
    lines.append("}")
    lines.append("")

    # --- user input section (only when audit_logs is enabled) ---
    if modules.get("audit_logs"):
        lines.append("#---------------------------------------")
        lines.append("# Values requiring user input")
        lines.append("#---------------------------------------")
        lines.append("")
        if mode == "account":
            ct_hint = "(this account)"
        else:
            ct_hint = "(Management account)"
        lines.append(f"# TODO: Add your CloudTrail S3 bucket name {ct_hint}")
        lines.append('cloudtrail_logs_bucket = ""')
        lines.append("")
        lines.append(f"# TODO: Add your CloudTrail SNS topic ARN {ct_hint}")
        lines.append('cloudtrail_sns_arn = ""')

    # --- Organization / OU Configuration and Account Filtering ---
    if mode != "account":
        lines.append("")
        lines.append("#---------------------------------------")
        lines.append("# Organization / OU Configuration")
        lines.append("#---------------------------------------")
        if mode == "account_group":
            lines.append("# TODO: Set the target OU ID (must start with 'ou-')")
            lines.append('organizational_unit_id = ""')
        else:
            lines.append("# Target OU for the StackSet deployment.")
            lines.append("# Leave empty to auto-detect the organization root (requires Organizations API access).")
            lines.append('# organizational_unit_id = ""')

        lines.append("")
        lines.append("#---------------------------------------")
        lines.append("# Account Filtering (Optional)")
        lines.append("#---------------------------------------")
        lines.append("# By default the StackSet deploys to ALL accounts in the target OU.")
        lines.append("# Use ONE of the lists below to restrict which accounts receive the")
        lines.append("# deployment. Do NOT set both at the same time.")
        lines.append("")
        lines.append('# Deploy ONLY to these accounts:')
        lines.append('# include_account_ids = ["111111111111", "222222222222", "333333333333"]')
        lines.append("")
        lines.append('# Deploy to all accounts EXCEPT these:')
        lines.append('# exclude_account_ids = ["999999999999", "888888888888"]')

    return "\n".join(lines) + "\n"

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Generate terraform.tfvars from a Cortex XDR CloudFormation template."
    )
    parser.add_argument("cf_template", help="Path to the CF YAML template file")
    parser.add_argument(
        "-o", "--output",
        help="Output file path (default: print to stdout)",
        default=None,
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Skip interactive prompt on version mismatch",
    )
    args = parser.parse_args()

    if not os.path.isfile(args.cf_template):
        print(f"Error: file not found: {args.cf_template}", file=sys.stderr)
        sys.exit(1)

    cf = parse_cf(args.cf_template)

    # --- version check ---
    custom_res = cf.get("Resources", {}).get("MyCustomResource", {}).get("Properties", {})
    cf_versions = custom_res.get("TemplateVersion", {})
    check_versions(cf_versions, force=args.force)

    # --- extract & detect ---
    values = extract_values(cf)
    modules = detect_modules(cf)

    mode = values["deployment_mode"]
    print(f"Detected deployment mode: {mode}", file=sys.stderr)

    source_name = os.path.basename(args.cf_template)
    content = generate_tfvars(source_name, values, modules)

    if args.output:
        with open(args.output, "w") as f:
            f.write(content)
        print(f"Wrote {args.output}", file=sys.stderr)
    else:
        sys.stdout.write(content)


if __name__ == "__main__":
    main()
