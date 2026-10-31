# Evidence — Local Google Cloud ADC OAuth Consent

<img width="689" height="365" alt="Local Google Cloud ADC OAuth Consent" src="https://github.com/user-attachments/assets/ea2cf14c-6322-4028-84bf-69aacfd07b2d" />


**Project:** MedCloud 360  
**Phase:** 0 — Terraform Bootstrap  
**Step:** 0.2 — Organization IAM, Billing and Terraform Authentication Validation  
**Evidence reference:** PH0-STEP02-ADC-001  
**Captured date:** 2026-10-31  
**Evidence classification:** Public, sanitized description  
**Evidence source:** Engineer-provided screenshot of the Google Auth Library OAuth consent screen and corresponding Windows PowerShell authentication output

## Purpose

Document the **interactive Google Cloud authorization prompt** displayed during local Application Default Credentials (ADC) configuration for Terraform bootstrap.

## Observed evidence

| Item | Screenshot observation | Interpretation |
| --- | --- | --- |
| Consent application | Google Auth Library | OAuth authorization interface launched during local ADC login |
| Authorization scope 1 | Access to view and manage Google Cloud resources and see the account email | Broad OAuth scope requested; actual operations remain subject to IAM permissions |
| Authorization scope 2 | View and sign in to Google Cloud SQL instances | Cloud SQL OAuth authorization scope requested |
| User action available | **Continue** / **Cancel** | Interactive consent choice shown; screenshot alone does not prove that Continue was selected |
| Command initiating browser login | `gcloud auth application-default login` | Initiates local ADC credential setup |
| Terminal result after consent | Credentials saved to local ADC file | Browser authorization completed according to terminal output |
| Validation command | `gcloud auth application-default print-access-token 1>$null` | Token output redirected to null |
| Validation result | `Terraform ADC verified successfully` | Confirmed a token could be acquired after login |

## Reproduction commands

Run in the **VS Code integrated Windows PowerShell terminal**, using the approved local engineering identity:

```powershell
# Initial check without exposing access tokens
gcloud auth application-default print-access-token 1>$null

# Interactive ADC authentication; opens browser OAuth consent
gcloud auth application-default login

# Validate authentication without printing an access token
gcloud auth application-default print-access-token 1>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Terraform ADC verified successfully"
} else {
    Write-Host "Terraform ADC verification failed"
}
```

## Security notes

- The original screenshot includes a personal account identifier. Keep the original private; only publish a redacted version.
- Do **not** publish the full transient OAuth authorization URL or its state/code challenge query parameters.
- Do **not** commit the local `application_default_credentials.json`, credentials, access tokens or refresh tokens.
- The OAuth consent screen is not evidence that broad permissions were actually exercised. Effective access is governed by IAM.
- Local ADC supports authorized workstation-based Terraform bootstrap. **GitHub Actions will authenticate through Workload Identity Federation**, not with user ADC files.

## Conclusion

**Result: PASS — Local ADC successfully configured and verified based on the terminal output.**

The screenshot illustrates the consent step of the authentication workflow. The PowerShell output is the authoritative evidence of successful credential creation and token acquisition. Project-level quotas, permissions, and Terraform provisioning require separate validation.

> **Image handling:** The original screenshot is held as source evidence outside this public repository; this record does not assert that an image file has been committed. Attach a redacted image to this folder when a supported upload path is available.
