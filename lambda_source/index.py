import json
import urllib.request
import urllib.parse
import ssl
import time
import boto3

def handler(event, context):
    """
    Lambda handler adapted for Terraform aws_lambda_invocation.

    Supports three deployment modes:
      - organization:  sends organization_id, fetches csp_org_id via Organizations API
      - account_group: sends account_group (OU ID), no org API call
      - account:       sends empty organization_id and account_group

    IMPORTANT: Keep provisioning_method as "CF" in the event data.
    Do NOT change it to "TF" - the Cortex backend expects "CF".
    """
    error = ""
    count = 0
    MAX_TRIES = 5

    account_id = event.get("AccountId", "")
    role_arn = event.get("RoleArn", "")
    external_id = event.get("ExternalID", "")
    template_id = event.get("TemplateId", "")
    upload_output_url = event.get("UploadOutputUrl", "")
    template_version = event.get("TemplateVersion", {})
    connector_id = event.get("ConnectorId", "")
    module_permission_scope = event.get("ModulePermissionScope", {})
    organization_id = event.get("OrganizationId", "")
    account_group = event.get("AccountGroup", "")
    needs_org_api = event.get("NeedsOrgApi", False)

    resources_data = {
        "audit_logs_byob": event.get("audit_logs_byob"),
        "outpost_scanner": event.get("outpost_scanner")
    }

    while count < MAX_TRIES:
        count += 1
        try:
            context_ssl = ssl.create_default_context()

            csp_org_id = ""
            if needs_org_api:
                org_client = boto3.client("organizations")
                org_details = org_client.describe_organization()
                csp_org_id = org_details["Organization"]["Id"] if org_details and "Organization" in org_details else ""

            data = {
                "operation": "create_connector",
                "resources_data": resources_data,
                "provisioning_method": "CF",
                "account_id": account_id,
                "account_name": "",
                "account_group": account_group,
                "organization_id": organization_id,
                "credentials": {
                    "role_arn": role_arn,
                    "external_id": external_id
                },
                "template_id": template_id,
                "template_version": template_version,
                "csp_org_id": csp_org_id,
                "connector_id": connector_id,
                "module_permission_scope": module_permission_scope
            }

            data_json = json.dumps(data).encode('utf-8')
            req = urllib.request.Request(upload_output_url, data=data_json, method='PUT')
            req.add_header('Content-Type', 'application/json')

            with urllib.request.urlopen(req, context=context_ssl, timeout=10) as response:
                if response.status == 200:
                    result = {"Success": True, "Upload Status Code": response.status, "Resources Data": resources_data}
                    print(result)
                    return result

                print({"Success": False, "retry": count, "error": response.read().decode('utf-8'), "Upload Status Code": response.status})
        except Exception as e:
            error = str(e)
            print({"Success": False, "retry": count, "error": error})
            time.sleep(3)

    return {"Success": False, "error": error, "Status": "Failed to send"}
